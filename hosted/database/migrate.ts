import 'dotenv/config';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { pool, closeDatabaseConnection } from './connection';

const LOCK_KEY = 82413001;

async function migrate() {
  const client = await pool.connect();
  let lockAcquired = false;

  try {
    await client.query('SELECT pg_advisory_lock($1)', [LOCK_KEY]);
    lockAcquired = true;
    console.log('Migration lock acquired.');

    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const directory = path.join(__dirname, 'migrations');
    const files = (await readdir(directory))
      .filter(file =>
        /^\d{3}_(core_pos|orders_billing_payments|operations_inventory_tax)\.sql$/.test(file)
      )
      .sort();

    for (const file of files) {
      const result = await client.query(
        'SELECT 1 FROM schema_migrations WHERE name = $1',
        [file]
      );

      if (result.rowCount) {
        console.log(`Already applied: ${file}`);
        continue;
      }

      let sql = await readFile(path.join(directory, file), 'utf8');
      sql = sql.replace(/^\s*BEGIN\s*;/i, '');
      sql = sql.replace(/COMMIT\s*;\s*$/i, '');

      console.log(`Applying: ${file}`);
      await client.query('BEGIN');

      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (name) VALUES ($1)',
          [file]
        );
        await client.query('COMMIT');
        console.log(`Applied: ${file}`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    console.log('Database migrations completed.');
  } finally {
    try {
      if (lockAcquired) {
        await client.query('SELECT pg_advisory_unlock($1)', [LOCK_KEY]);
        console.log('Migration lock released.');
      }
    } finally {
      client.release();
      await closeDatabaseConnection();
    }
  }
}

migrate().catch(error => {
  console.error('Migration failed:', error);
  process.exitCode = 1;
});
