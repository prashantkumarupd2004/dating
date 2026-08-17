import { Server, Socket } from 'socket.io';
import { prisma } from '../config/database';
import { logger } from '../utils/logger';

export const setupCallHandlers = (io: Server, socket: Socket): void => {
  const userId = (socket as any).userId as string;

  socket.on(
    'call:ring',
    async (data: { listenerId: string; callId: string; callType: string }) => {
      try {
        io.to(`listener:${data.listenerId}`).emit('call:incoming', {
          callId: data.callId,
          callType: data.callType,
          userId,
        });
      } catch (err) {
        logger.error('call:ring error', err);
      }
    }
  );

  socket.on('call:accept', async (data: { callId: string; callerId: string }) => {
    try {
      io.to(`user:${data.callerId}`).emit('call:accepted', { callId: data.callId });
    } catch (err) {
      logger.error('call:accept error', err);
    }
  });

  socket.on('call:reject', async (data: { callId: string; callerId: string }) => {
    try {
      io.to(`user:${data.callerId}`).emit('call:rejected', { callId: data.callId });
    } catch (err) {
      logger.error('call:reject error', err);
    }
  });

  socket.on(
    'call:end',
    async (data: { callId: string; callerId: string; listenerId: string }) => {
      try {
        io.to(`user:${data.callerId}`).emit('call:ended', { callId: data.callId });
        io.to(`listener:${data.listenerId}`).emit('call:ended', { callId: data.callId });
      } catch (err) {
        logger.error('call:end error', err);
      }
    }
  );

  socket.on('wallet:check_balance', async () => {
    try {
      const wallet = await prisma.wallet.findUnique({
        where: { userId },
        select: { balance: true },
      });
      socket.emit('wallet:balance', { balance: wallet?.balance?.toString() ?? '0' });
    } catch (err) {
      logger.error('wallet:check_balance error', err);
    }
  });
};
