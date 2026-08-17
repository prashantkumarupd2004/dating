import http from 'http';
import { Server } from 'socket.io';
import app from './app';
import { config } from './config';
import { connectDB, disconnectDB } from './config/database';
import { connectRedis } from './config/redis';
import { setupSockets } from './sockets';
import { setIO } from './sockets/registry';
import { logger } from './utils/logger';
import { cleanupExpiredRingingCalls } from './modules/calls/calls.service';

const server = http.createServer(app);

export const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  transports: ['websocket', 'polling'],
});

setIO(io);
setupSockets(io);

// Periodic cleanup of expired ringing calls (every 30 seconds)
let cleanupInterval: NodeJS.Timeout;

const start = async (): Promise<void> => {
  try {
    await connectDB();
    try {
      await connectRedis();
    } catch (redisErr) {
      logger.warn('Redis unavailable — presence features disabled. Start Redis to enable them.');
    }
    server.listen(config.port, () => {
      logger.info(`Server running on port ${config.port} [${config.env}]`);
    });

    // Start cleanup interval for missed calls
    cleanupInterval = setInterval(() => {
      cleanupExpiredRingingCalls().catch(err => logger.error('Cleanup job failed', err));
    }, 30000); // Every 30 seconds
  } catch (err) {
    logger.error('Failed to start server', err);
    process.exit(1);
  }
};

process.on('SIGTERM', async () => {
  logger.info('SIGTERM: shutting down gracefully');
  clearInterval(cleanupInterval);
  server.close(async () => {
    await disconnectDB();
    process.exit(0);
  });
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', reason);
});

start();
