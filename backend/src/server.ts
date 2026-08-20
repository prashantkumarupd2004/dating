import http from 'http';
import { Server } from 'socket.io';
import app from './app';
import { config } from './config';
import { connectDB, disconnectDB } from './config/database';
import { connectRedis } from './config/redis';
import { setupSockets } from './sockets';
import { setIO } from './sockets/registry';
import { logger } from './utils/logger';
import { cleanupExpiredRingingCalls, watchdogActiveCalls, resetStaleListenerStatuses } from './modules/calls/calls.service';

const server = http.createServer(app);

export const io = new Server(server, {
  cors: { origin: config.allowedOrigins, methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  transports: ['websocket', 'polling'],
});

setIO(io);
setupSockets(io);

// Periodic cleanup of expired ringing calls (every 30 seconds)
let cleanupInterval: NodeJS.Timeout;
// Watchdog for orphaned IN_PROGRESS calls (participant heartbeat timeout)
let watchdogInterval: NodeJS.Timeout;

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

    // Heal listeners stuck BUSY from previous crash / restart BEFORE accepting traffic
    await resetStaleListenerStatuses();

    // Cleanup missed/expired ringing calls every 30s
    cleanupInterval = setInterval(() => {
      cleanupExpiredRingingCalls().catch(err => logger.error('Cleanup job failed', err));
    }, 30000);

    // Watchdog: terminate IN_PROGRESS calls whose participant heartbeat has timed out.
    // This is the billing-safety mechanism that fires when a participant force-kills their app.
    watchdogInterval = setInterval(() => {
      watchdogActiveCalls().catch(err => logger.error('[CALL_WATCHDOG] Watchdog job failed', err));
    }, config.call.watchdogIntervalMs);

    logger.info(`[CALL_WATCHDOG] Started — participantTimeout=${config.call.participantTimeoutMs}ms interval=${config.call.watchdogIntervalMs}ms`);
  } catch (err) {
    logger.error('Failed to start server', err);
    process.exit(1);
  }
};


process.on('SIGTERM', async () => {
  logger.info('SIGTERM: shutting down gracefully');
  clearInterval(cleanupInterval);
  clearInterval(watchdogInterval);
  const shutdownTimeout = setTimeout(() => process.exit(1), 10000);
  server.close(async () => {
    clearTimeout(shutdownTimeout);
    await disconnectDB();
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  logger.info('SIGINT: shutting down gracefully');
  clearInterval(cleanupInterval);
  clearInterval(watchdogInterval);
  const shutdownTimeout = setTimeout(() => process.exit(1), 10000);
  server.close(async () => {
    clearTimeout(shutdownTimeout);
    await disconnectDB();
    process.exit(0);
  });
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', reason);
  process.exit(1);
});

process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception', err);
  process.exit(1);
});

start();
