import { Pool } from 'pg';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL environment variable is not configured.');
}

const databaseUrl = new URL(connectionString);
const isLocal =
  databaseUrl.hostname === 'localhost' ||
  databaseUrl.hostname === '127.0.0.1';

export const pool = new Pool({
  connectionString,
  ssl: isLocal ? false : { rejectUnauthorized: true },
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pool.on('error', error => {
  console.error('Unexpected PostgreSQL pool error:', error.message);
});

export async function checkDatabaseConnection(): Promise<boolean> {
  const result = await pool.query('SELECT 1 AS connected');
  return result.rows[0]?.connected === 1;
}

export async function closeDatabaseConnection(): Promise<void> {
  await pool.end();
}
