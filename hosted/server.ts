import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import {
  checkDatabaseConnection,
  closeDatabaseConnection,
} from './database/connection';

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', async (_req, res) => {
  try {
    const databaseConnected = await checkDatabaseConnection();

    res.status(databaseConnected ? 200 : 503).json({
      status: databaseConnected ? 'ok' : 'degraded',
      service: 'cafe-pos-hosted',
      database: databaseConnected ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Health check failed:', error);

    res.status(503).json({
      status: 'error',
      service: 'cafe-pos-hosted',
      database: 'disconnected',
      timestamp: new Date().toISOString(),
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`CAFE POS hosted server listening on port ${PORT}`);
});

async function shutdown() {
  console.log('Shutting down hosted server...');

  server.close(async () => {
    await closeDatabaseConnection();
    process.exit(0);
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
