import { Server, Socket } from 'socket.io';
import { redis } from '../config/redis';
import { prisma } from '../config/database';
import { logger } from '../utils/logger';

// Redis TTL for presence key (seconds).
// Flutter sends presence:heartbeat every 25s — keep TTL comfortably above that.
const PRESENCE_TTL = 40;

// How long (ms) to wait before treating a disconnect as permanent and
// broadcasting OFFLINE. Short grace allows brief network flaps to reconnect
// without flickering the user-facing online indicator.
const DISCONNECT_GRACE_MS = 8_000;

export const setupPresenceHandlers = (io: Server, socket: Socket): void => {
  const userId = (socket as any).userId as string;

  socket.on('presence:online', async (data: { listenerId?: string }) => {
    const listenerId = data?.listenerId;
    if (!listenerId) return;
    (socket as any).listenerId = listenerId;
    socket.join(`listener:${listenerId}`);
    try {
      await redis.setex(`presence:${listenerId}`, PRESENCE_TTL, socket.id);
      await prisma.listener.update({
        where: { id: listenerId },
        data: { onlineStatus: 'ONLINE' },
      });
      io.emit('listener:status', { listenerId, status: 'ONLINE' });
      logger.info(`[PRESENCE] Listener ${listenerId} is ONLINE (socketId=${socket.id})`);
    } catch (err) {
      logger.error('presence:online error', err);
    }
  });

  // Only manual "Go Offline" button sets OFFLINE in DB
  socket.on('presence:offline', async () => {
    const listenerId = (socket as any).listenerId as string | undefined;
    if (!listenerId) return;
    (socket as any).listenerId = undefined;
    try {
      await redis.del(`presence:${listenerId}`);
      await prisma.listener.update({
        where: { id: listenerId },
        data: { onlineStatus: 'OFFLINE' },
      });
      io.emit('listener:status', { listenerId, status: 'OFFLINE' });
      logger.info(`[PRESENCE] Listener ${listenerId} manually went OFFLINE`);
    } catch (err) {
      logger.error('presence:offline error', err);
    }
  });

  socket.on('presence:heartbeat', async () => {
    const listenerId = (socket as any).listenerId as string | undefined;
    if (!listenerId) return;
    try {
      await redis.expire(`presence:${listenerId}`, PRESENCE_TTL);
    } catch (err) {
      logger.error('presence:heartbeat error', err);
    }
  });

  // On disconnect: wait a short grace period to allow the client to
  // reconnect (e.g. brief network blip). If they don't reconnect and
  // re-announce presence, treat them as offline and broadcast to all clients.
  socket.on('disconnect', () => {
    const listenerId = (socket as any).listenerId as string | undefined;
    if (!listenerId) return;

    logger.info(`[PRESENCE] Listener ${listenerId} socket disconnected — starting ${DISCONNECT_GRACE_MS}ms grace period`);

    setTimeout(async () => {
      try {
        // Check if listener has reconnected with a new socket during grace period.
        // If they re-emitted presence:online, a fresh Redis key exists.
        const currentSocketId = await redis.get(`presence:${listenerId}`);
        if (currentSocketId && currentSocketId !== socket.id) {
          // Listener reconnected — do nothing
          logger.info(`[PRESENCE] Listener ${listenerId} reconnected (newSocket=${currentSocketId}) — no OFFLINE broadcast`);
          return;
        }

        // Grace period elapsed and listener didn't reconnect — broadcast OFFLINE.
        await redis.del(`presence:${listenerId}`);
        await prisma.listener.update({
          where: { id: listenerId },
          data: { onlineStatus: 'OFFLINE' },
        });
        io.emit('listener:status', { listenerId, status: 'OFFLINE' });
        logger.info(`[PRESENCE] Listener ${listenerId} declared OFFLINE after grace period`);
      } catch (err) {
        logger.error(`[PRESENCE] Error handling disconnect for listener ${listenerId}:`, err);
      }
    }, DISCONNECT_GRACE_MS);
  });
};

