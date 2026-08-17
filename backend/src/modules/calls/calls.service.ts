import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { generateRtcToken, generateChannelId } from '../../services/agora.service';
import { checkSufficientBalance, processCallBilling } from '../../services/billing.service';
import { sendMulticastNotification } from '../../services/firebase.service';
import { getIO } from '../../sockets/registry';
import { config } from '../../config';
import { logger } from '../../utils/logger';
import { getPagination, buildMeta } from '../../utils/pagination';
import { v4 as uuidv4 } from 'uuid';

const RING_TIMEOUT_MS = 45_000;

export const initiateCall = async (
  userId: string,
  listenerId: string,
  callType: 'AUDIO' | 'VIDEO'
) => {
  // 1. Check feature flag
  const featureKey = callType === 'AUDIO' ? 'audio_calls_enabled' : 'video_calls_enabled';
  const featureSetting = await prisma.setting.findUnique({ where: { key: featureKey } });
  if (featureSetting?.value === 'false') {
    throw new AppError(403, `${callType} calls are currently disabled`);
  }

  // 2. Check listener status
  const listener = await prisma.listener.findUnique({
    where: { id: listenerId },
    select: {
      id: true,
      status: true,
      onlineStatus: true,
      isAudioEnabled: true,
      isVideoEnabled: true,
      user: {
        select: {
          id: true,
          devices: { select: { fcmToken: true } },
        },
      },
    },
  });
  if (!listener || listener.status !== 'APPROVED') throw new AppError(404, 'Listener not available');
  if (listener.onlineStatus !== 'ONLINE') throw new AppError(409, 'Listener is not online');
  if (callType === 'AUDIO' && !listener.isAudioEnabled)
    throw new AppError(409, 'Listener does not accept audio calls');
  if (callType === 'VIDEO' && !listener.isVideoEnabled)
    throw new AppError(409, 'Listener does not accept video calls');

  // 3. Check user balance
  const { sufficient, ratePerMinute, estimatedMinutes } = await checkSufficientBalance(userId, callType);
  if (!sufficient) throw new AppError(402, 'Insufficient balance');

  const caller = await prisma.user.findUnique({ where: { id: userId }, select: { name: true } });

  // 4. Check blocks
  const block = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: userId, blockedListenerId: listenerId },
        { blockedListenerId: listenerId, blockerId: userId },
      ],
    },
  });
  if (block) throw new AppError(403, 'Cannot call this listener');

  // 5. Generate Agora channel and tokens
  // UIDs are deterministic per-call: user gets range 1–99999, listener gets 100001–199999.
  // We store both in the Call row so acceptCall can reuse them (same UID → same token works).
  const channelId = generateChannelId();
  const userUid = Math.floor(Math.random() * 99999) + 1;
  const listenerUid = Math.floor(Math.random() * 99999) + 100001;

  const [userToken] = await Promise.all([
    generateRtcToken(channelId, userUid),
    generateRtcToken(channelId, listenerUid), // pre-generate; stored UIDs allow acceptCall to regenerate
  ]);

  // 6. Create call record — persist UIDs so acceptCall issues a consistent token
  const ringExpiresAt = new Date(Date.now() + RING_TIMEOUT_MS);
  const call = await prisma.call.create({
    data: {
      userId,
      listenerId,
      type: callType,
      status: 'RINGING',
      agoraChannelId: channelId,
      userUid,
      listenerUid,
      ringExpiresAt,
      idempotencyKey: uuidv4(),
      billing: {
        create: { ratePerMinute, coinsDeducted: 0 },
      },
    },
  });

  // 7. Set listener to BUSY
  await prisma.listener.update({
    where: { id: listenerId },
    data: { onlineStatus: 'BUSY' },
  });

  // 8. Notify the listener in realtime, with an FCM push as a background/killed-app fallback
  const callerName = caller?.name ?? 'Someone';
  getIO().to(`listener:${listenerId}`).emit('call:incoming', {
    callId: call.id,
    callType,
    userId,
    callerName,
  });

  const fcmTokens = listener.user.devices.map((d) => d.fcmToken);
  if (fcmTokens.length) {
    sendMulticastNotification(
      fcmTokens,
      'Incoming Call',
      `${callerName} is calling you`,
      { type: 'incoming_call', callId: call.id, callType }
    ).catch(() => {});
  }

  logger.info(`Call initiated: callId=${call.id} userId=${userId} listenerId=${listenerId} type=${callType}`);

  // 9. Auto-miss the call if the listener never responds
  setTimeout(async () => {
    try {
      const current = await prisma.call.findUnique({ where: { id: call.id } });
      if (current?.status !== 'RINGING') return;
      await prisma.call.update({
        where: { id: call.id },
        data: { status: 'MISSED', endedAt: new Date() },
      });
      await prisma.listener.update({
        where: { id: listenerId },
        data: { onlineStatus: 'ONLINE' },
      });
      getIO().to(`user:${userId}`).emit('call:ended', { callId: call.id, reason: 'missed' });
      getIO().to(`listener:${listenerId}`).emit('call:ended', { callId: call.id, reason: 'missed' });
      logger.info(`Call auto-missed: callId=${call.id}`);
    } catch (err) {
      logger.error('Ring timeout handling failed', err);
    }
  }, RING_TIMEOUT_MS);

  return {
    callId: call.id,
    channelId,
    agoraToken: userToken,
    agoraAppId: config.agora.appId,
    userUid,
    ratePerMinute,
    estimatedMinutes,
  };
};

export const acceptCall = async (callId: string, listenerId: string) => {
  const call = await prisma.call.findFirst({ where: { id: callId, listenerId } });
  if (!call) throw new AppError(404, 'Call not found');
  if (call.status !== 'RINGING') throw new AppError(409, 'Call is not in ringing state');

  const updated = await prisma.call.update({
    where: { id: callId },
    data: { status: 'IN_PROGRESS', startedAt: new Date() },
  });

  // Reuse the listenerUid stored at initiation — this ensures the Agora token
  // is issued for the same UID the listener will actually join with.
  const listenerUid = call.listenerUid ?? (Math.floor(Math.random() * 99999) + 100001);
  const agoraToken = await generateRtcToken(call.agoraChannelId!, listenerUid);

  getIO().to(`user:${call.userId}`).emit('call:accepted', { callId });

  logger.info(`Call accepted: callId=${callId} listenerId=${listenerId}`);

  return {
    ...updated,
    channelId: call.agoraChannelId,
    agoraToken,
    agoraAppId: config.agora.appId,
    listenerUid,
  };
};

export const endCall = async (callId: string, endedBy: string) => {
  const call = await prisma.call.findUnique({ where: { id: callId } });
  if (!call) throw new AppError(404, 'Call not found');
  if (call.userId !== endedBy && call.listenerId !== endedBy) {
    throw new AppError(403, 'Not authorized to end this call');
  }
  if (!['RINGING', 'ACCEPTED', 'IN_PROGRESS'].includes(call.status)) {
    throw new AppError(409, 'Call cannot be ended in its current state');
  }

  const endedAt = new Date();
  const startedAt = call.startedAt || new Date();
  const durationSeconds = Math.max(
    0,
    Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000)
  );

  const status = durationSeconds > 0 ? 'COMPLETED' : 'CANCELLED';

  const updated = await prisma.call.update({
    where: { id: callId },
    data: { status, endedAt, durationSeconds },
  });

  // Reset listener to ONLINE
  await prisma.listener.update({
    where: { id: call.listenerId },
    data: { onlineStatus: 'ONLINE' },
  });

  // Process billing for completed calls
  if (status === 'COMPLETED' && durationSeconds > 0) {
    try {
      await processCallBilling(callId);
    } catch (err) {
      logger.error(`Billing failed for call ${callId}`, err);
    }
  }

  getIO().to(`user:${call.userId}`).emit('call:ended', { callId, reason: status.toLowerCase() });
  getIO().to(`listener:${call.listenerId}`).emit('call:ended', { callId, reason: status.toLowerCase() });

  logger.info(`Call ended: callId=${callId} endedBy=${endedBy} status=${status} duration=${durationSeconds}s`);

  return updated;
};

export const rejectCall = async (callId: string, listenerId: string) => {
  const call = await prisma.call.findFirst({ where: { id: callId, listenerId } });
  if (!call) throw new AppError(404, 'Call not found');

  await prisma.listener.update({
    where: { id: listenerId },
    data: { onlineStatus: 'ONLINE' },
  });

  logger.info(`Call rejected: callId=${callId} listenerId=${listenerId}`);

  const updated = await prisma.call.update({
    where: { id: callId },
    data: { status: 'REJECTED', endedAt: new Date() },
  });

  getIO().to(`user:${call.userId}`).emit('call:ended', { callId, reason: 'rejected' });

  return updated;
};

export const getCallHistory = async (
  userId: string,
  filters: { page?: number; limit?: number; type?: string }
) => {
  const { page, limit, skip } = getPagination(filters);

  const where: any = {
    OR: [{ userId }, { listener: { userId } }],
  };
  if (filters.type) where.type = filters.type;

  const [calls, total] = await Promise.all([
    prisma.call.findMany({
      where,
      include: {
        user: { select: { name: true } },
        listener: {
          include: {
            profile: { select: { displayName: true, photoUrl: true } },
          },
        },
        earning: { select: { listenerAmount: true } },
        billing: { select: { coinsDeducted: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.call.count({ where }),
  ]);

  return { data: calls, meta: buildMeta(total, page, limit) };
};

export const rateCall = async (
  callId: string,
  userId: string,
  rating: number,
  comment?: string
) => {
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new AppError(400, 'Rating must be an integer between 1 and 5');
  }

  const call = await prisma.call.findUnique({ where: { id: callId } });
  if (!call) throw new AppError(404, 'Call not found');
  if (call.userId !== userId) throw new AppError(403, 'Not authorized to rate this call');
  if (call.status !== 'COMPLETED') throw new AppError(400, 'Only completed calls can be rated');

  const existing = await prisma.callRating.findUnique({ where: { callId } });
  if (existing) throw new AppError(409, 'This call has already been rated');

  const callRating = await prisma.callRating.create({
    data: { callId, userId, listenerId: call.listenerId, rating, comment },
  });

  // Recompute listener's average rating and total count
  const agg = await prisma.callRating.aggregate({
    where: { listenerId: call.listenerId },
    _avg: { rating: true },
    _count: { rating: true },
  });

  await prisma.listenerProfile.update({
    where: { listenerId: call.listenerId },
    data: {
      rating: Math.round((agg._avg.rating ?? 0) * 10) / 10,
      totalRatings: agg._count.rating,
    },
  });

  logger.info(`Call rated: callId=${callId} userId=${userId} rating=${rating}`);

  return callRating;
};

export const cleanupExpiredRingingCalls = async (): Promise<void> => {
  // Find all RINGING calls that have expired
  const expiredCalls = await prisma.call.findMany({
    where: {
      status: 'RINGING',
      ringExpiresAt: { lte: new Date() },
    },
    select: { id: true, userId: true, listenerId: true },
  });

  if (expiredCalls.length === 0) return;

  logger.info(`Cleaning up ${expiredCalls.length} expired ringing calls`);

  for (const call of expiredCalls) {
    try {
      await prisma.call.update({
        where: { id: call.id },
        data: { status: 'MISSED', endedAt: new Date() },
      });

      await prisma.listener.update({
        where: { id: call.listenerId },
        data: { onlineStatus: 'ONLINE' },
      });

      getIO().to(`user:${call.userId}`).emit('call:ended', { callId: call.id, reason: 'missed' });
      getIO().to(`listener:${call.listenerId}`).emit('call:ended', { callId: call.id, reason: 'missed' });

      logger.info(`Expired call cleaned up: callId=${call.id}`);
    } catch (err) {
      logger.error(`Failed to cleanup expired call ${call.id}`, err);
    }
  }
};
