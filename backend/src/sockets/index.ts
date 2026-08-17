import { Server, Socket } from 'socket.io';
import { verifyAccessToken } from '../utils/jwt';
import { logger } from '../utils/logger';
import { setupPresenceHandlers } from './presence.handler';
import { setupCallHandlers } from './call.handler';

export const setupSockets = (io: Server): void => {
  // JWT authentication middleware
  io.use(async (socket: Socket, next) => {
    try {
      const token = socket.handshake.auth.token as string;
      if (!token) return next(new Error('Authentication required'));
      const payload = verifyAccessToken(token);
      (socket as any).userId = payload.userId;
      (socket as any).userType = payload.type;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const userId = (socket as any).userId as string;
    const userType = (socket as any).userType as string;
    logger.info(`Socket connected: ${socket.id} userId=${userId} type=${userType}`);

    // Join personal room
    socket.join(`user:${userId}`);

    setupPresenceHandlers(io, socket);
    setupCallHandlers(io, socket);

    socket.on('disconnect', () => {
      logger.info(`Socket disconnected: ${socket.id} userId=${userId}`);
    });
  });
};
