import { Server, Socket } from 'socket.io';
import { redis } from '../config/redis';
import { prisma } from '../config/database';
import { logger } from '../utils/logger';

const PRESENCE_TTL = 35; // seconds

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
      logger.info(`Listener ${listenerId} is ONLINE`);
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
      logger.info(`Listener ${listenerId} manually went OFFLINE`);
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

  // On disconnect: do NOT change DB onlineStatus.
  // Listener stays ONLINE in DB so users can still see them.
  // When app reopens, socket reconnects and auto-emits presence:online again.
  socket.on('disconnect', () => {
    const listenerId = (socket as any).listenerId as string | undefined;
    if (!listenerId) return;
    // Only clear Redis presence key (ephemeral), NOT the DB status
    redis.del(`presence:${listenerId}`).catch(() => {});
    logger.info(`Listener ${listenerId} socket disconnected — DB status unchanged (still ONLINE)`);
  });
};
