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

  // ── Smart BUSY check ──────────────────────────────────────────────────────
  // If the listener is marked BUSY, verify there is a genuinely active call
  // backing that status. If no active call exists the BUSY flag is stale
  // (server crash / ungraceful shutdown) — auto-heal it so the new call can proceed.
  if (listener.onlineStatus === 'BUSY') {
    const backingCall = await prisma.call.findFirst({
      where: {
        listenerId,
        status: { in: ['RINGING', 'ACCEPTED', 'IN_PROGRESS'] },
      },
      select: { id: true, status: true, ringExpiresAt: true },
    });

    if (!backingCall) {
      // BUSY with no live call → stale state, auto-heal
      await prisma.listener.update({ where: { id: listenerId }, data: { onlineStatus: 'ONLINE' } });
      logger.warn(`[CALL_HEAL] Listener ${listenerId} was BUSY with no active call — auto-reset to ONLINE`);
      // Fall through: onlineStatus is now effectively ONLINE
    } else if (
      backingCall.status === 'RINGING' &&
      backingCall.ringExpiresAt &&
      backingCall.ringExpiresAt < new Date()
    ) {
      // Expired RINGING call not yet cleaned up → clean it now and allow new call
      await prisma.call.update({ where: { id: backingCall.id }, data: { status: 'MISSED', endedAt: new Date() } });
      await prisma.listener.update({ where: { id: listenerId }, data: { onlineStatus: 'ONLINE' } });
      getIO().emit('listener:status', { listenerId, status: 'ONLINE' });
      logger.warn(`[CALL_HEAL] Cleaned expired RINGING call ${backingCall.id}, reset listener ${listenerId} to ONLINE`);
      // Fall through: onlineStatus is now effectively ONLINE
    } else {
      // Genuine active call — listener really is busy
      throw new AppError(409, 'Listener is busy');
    }
  } else if (listener.onlineStatus !== 'ONLINE') {
    throw new AppError(409, 'Listener is not online');
  }

  if (callType === 'AUDIO' && !listener.isAudioEnabled)
    throw new AppError(409, 'Listener does not accept audio calls');
  if (callType === 'VIDEO' && !listener.isVideoEnabled)
    throw new AppError(409, 'Listener does not accept video calls');

  // 3. Check user balance
  const { sufficient, ratePerMinute, estimatedMinutes } = await checkSufficientBalance(userId, callType);
  if (!sufficient) throw new AppError(402, 'Insufficient balance');

  const caller = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      name: true,
      profile: { select: { nickname: true, photoUrl: true } },
    },
  });

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

  // 5. Generate Agora channel and tokens BEFORE the transaction
  //    (token generation is async/external — keep outside the short DB lock)
  const channelId  = generateChannelId();
  const userUid    = Math.floor(Math.random() * 99999) + 1;
  const listenerUid = Math.floor(Math.random() * 99999) + 100001;
  const [userToken] = await Promise.all([
    generateRtcToken(channelId, userUid),
    generateRtcToken(channelId, listenerUid),
  ]);

  // 6. ATOMIC: re-check availability, set BUSY, create call inside a transaction.
  //    Prisma transactions are serialized at the DB level — the tx.listener.update
  //    below acts as the atomic guard (no raw SQL lock needed).
  const ringExpiresAt = new Date(Date.now() + RING_TIMEOUT_MS);
  let call: any;
  try {
    call = await prisma.$transaction(async (tx) => {
      // Re-fetch status inside the transaction — the earlier fetch (step 2) may be stale.
      const fresh = await tx.listener.findUnique({
        where: { id: listenerId },
        select: { onlineStatus: true },
      });
      // Smart inner check: if BUSY, verify there's actually an active call.
      // The outer layer already healed obvious stale cases; this catches any
      // race window between the outer check and acquiring the lock.
      if (fresh?.onlineStatus === 'BUSY') {
        const liveCall = await tx.call.findFirst({
          where: { listenerId, status: { in: ['RINGING', 'ACCEPTED', 'IN_PROGRESS'] } },
          select: { id: true },
        });
        if (liveCall) {
          throw new AppError(409, 'Listener is busy');
        }
        // Stale BUSY inside transaction — proceed to set BUSY for the new call
        logger.warn(`[CALL_HEAL_TX] Stale BUSY in transaction for listener ${listenerId} — proceeding with new call`);
      } else if (fresh?.onlineStatus !== 'ONLINE') {
        throw new AppError(409, 'Listener is not online');
      }

      // Mark BUSY atomically — visible to any other transaction only after commit.
      await tx.listener.update({
        where: { id: listenerId },
        data: { onlineStatus: 'BUSY' },
      });

      // Create the call record inside the same transaction.
      return tx.call.create({
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
    });
  } catch (err: any) {
    // Re-throw AppErrors as-is (they already have a meaningful message).
    // For unexpected transaction errors (DB connection, constraint, timeout),
    // do NOT say "Listener is busy" — that is misleading. Use a generic message.
    if (err instanceof AppError) throw err;
    logger.error('[INITIATE_CALL] Transaction failed', err);
    throw new AppError(503, 'Call could not be started. Please try again.');
  }

  // 7. Broadcast BUSY status to all connected clients so home screens update immediately.
  getIO().emit('listener:status', { listenerId, status: 'BUSY' });

  // 8. Notify the listener in realtime, with an FCM push as background/killed-app fallback
  // Use nickname as display name (falls back to user.name if not set)
  const callerName  = caller?.profile?.nickname || caller?.name || 'Someone';
  const callerPhoto = caller?.profile?.photoUrl ?? null;
  getIO().to(`listener:${listenerId}`).emit('call:incoming', {
    callId: call.id,
    callType,
    userId,
    callerName,
    callerPhoto,
  });

  const fcmTokens = listener.user.devices.map((d) => d.fcmToken);
  if (fcmTokens.length) {
    sendMulticastNotification(
      fcmTokens,
      'Incoming Call',
      `${callerName} is calling you`,
      { type: 'INCOMING_CALL', callId: call.id, callType }
    ).catch(() => {});
  }

  logger.info(`Call initiated: callId=${call.id} userId=${userId} listenerId=${listenerId} type=${callType}`);

  // 9. Auto-miss the call if the listener never responds within the ring timeout.
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
      // Broadcast ONLINE so all home screens update
      getIO().emit('listener:status', { listenerId, status: 'ONLINE' });
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

export const endCall = async (
  callId: string,
  endedBy: string,
  terminationReason?: string
) => {
  const call = await prisma.call.findUnique({ where: { id: callId } });
  if (!call) throw new AppError(404, 'Call not found');

  // Allow system watchdog to end any call; normal users may only end their own.
  // IMPORTANT: Listeners authenticate with their USER jwt, so req.userId = the listener's
  // userId, NOT the Listener-table id (call.listenerId). We resolve this here.
  const isSystem = endedBy === 'system_watchdog';
  if (!isSystem) {
    const isCallerUser = call.userId === endedBy;
    if (!isCallerUser) {
      // Check if endedBy is the userId of the listener on this call
      const listenerRecord = await prisma.listener.findUnique({
        where: { id: call.listenerId },
        select: { userId: true },
      });
      const isListenerUser = listenerRecord?.userId === endedBy;
      if (!isListenerUser) {
        throw new AppError(403, 'Not authorized to end this call');
      }
    }
  }
  if (!['RINGING', 'ACCEPTED', 'IN_PROGRESS'].includes(call.status)) {
    // Already ended — idempotent, no error.
    logger.info(`[CALL_END] callId=${callId} already ended (status=${call.status}) — skipping`);
    return await prisma.call.findUnique({ where: { id: callId } });
  }

  const endedAt  = new Date();
  const startedAt = call.startedAt || endedAt;
  const durationSeconds = Math.max(
    0,
    Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000)
  );

  const status = durationSeconds > 0 ? 'COMPLETED' : 'CANCELLED';
  const reason = terminationReason ?? 'normal';

  const updated = await prisma.call.update({
    where: { id: callId },
    data: { status, endedAt, durationSeconds, terminationReason: reason },
  });

  // Reset listener to ONLINE and broadcast to all clients
  await prisma.listener.update({
    where: { id: call.listenerId },
    data: { onlineStatus: 'ONLINE' },
  });
  getIO().emit('listener:status', { listenerId: call.listenerId, status: 'ONLINE' });

  // Process billing for completed calls
  if (status === 'COMPLETED' && durationSeconds > 0) {
    try {
      await processCallBilling(callId);
      logger.info(`[CALL_BILLING_FINALIZED] callId=${callId} duration=${durationSeconds}s reason=${reason}`);
    } catch (err) {
      logger.error(`Billing failed for call ${callId}`, err);
    }
  }

  getIO().to(`user:${call.userId}`).emit('call:ended', { callId, reason });
  getIO().to(`listener:${call.listenerId}`).emit('call:ended', { callId, reason });

  logger.info(`[CALL_END] callId=${callId} endedBy=${endedBy} status=${status} duration=${durationSeconds}s reason=${reason}`);

  return updated;
};

export const rejectCall = async (callId: string, listenerId: string) => {
  const call = await prisma.call.findFirst({ where: { id: callId, listenerId } });
  if (!call) throw new AppError(404, 'Call not found');

  // Idempotency: if already rejected, return without re-emitting events.
  if (call.status === 'REJECTED') {
    logger.info(`rejectCall: callId=${callId} already REJECTED — idempotent no-op`);
    return call;
  }

  // Only a RINGING call can be rejected by the listener.
  if (call.status !== 'RINGING') {
    throw new AppError(409, `Cannot reject call in status: ${call.status}`);
  }

  // Restore listener to ONLINE and broadcast immediately so other users' screens update.
  await prisma.listener.update({
    where: { id: listenerId },
    data: { onlineStatus: 'ONLINE' },
  });
  getIO().emit('listener:status', { listenerId, status: 'ONLINE' });

  const updated = await prisma.call.update({
    where: { id: callId },
    data: { status: 'REJECTED', endedAt: new Date() },
  });

  // Notify caller immediately — this is the fix for the "stuck on Connecting" bug.
  getIO().to(`user:${call.userId}`).emit('call:ended', { callId, reason: 'rejected' });

  logger.info(`Call rejected: callId=${callId} listenerId=${listenerId}`);
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
      // Broadcast ONLINE so all home screens update immediately
      getIO().emit('listener:status', { listenerId: call.listenerId, status: 'ONLINE' });

      getIO().to(`user:${call.userId}`).emit('call:ended', { callId: call.id, reason: 'missed' });
      getIO().to(`listener:${call.listenerId}`).emit('call:ended', { callId: call.id, reason: 'missed' });

      logger.info(`Expired call cleaned up: callId=${call.id}`);
    } catch (err) {
      logger.error(`Failed to cleanup expired call ${call.id}`, err);
    }
  }
};

/**
 * Returns the status of a call for a given user/listener.
 * Used by Flutter to validate stored active-call state on app restore.
 */
export const getCallStatus = async (callId: string, userId: string) => {
  const call = await prisma.call.findFirst({
    where: {
      id: callId,
      OR: [
        { userId },
        { listener: { userId } },
      ],
    },
    select: { id: true, status: true, type: true },
  });

  if (!call) throw new AppError(404, 'Call not found');

  const isActive = ['RINGING', 'IN_PROGRESS'].includes(call.status);
  logger.info(`[BACKEND_CALL_STATUS] callId=${callId} status=${call.status} isActive=${isActive}`);

  return {
    callId:   call.id,
    status:   call.status,
    type:     call.type,
    isActive,
  };
};

// ─────────────────────────────────────────────────────────────────────────────
// HEARTBEAT — called by Flutter every ~12s while call is active
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Records a liveness heartbeat from a call participant.
 * Updates callerLastSeen or listenerLastSeen depending on role.
 *
 * @param callId  - The active call id
 * @param userId  - The authenticated user's id (may be caller or listener's user)
 * @param role    - 'user' (caller) | 'listener'
 */
export const callHeartbeat = async (
  callId: string,
  userId: string,
  role: 'user' | 'listener'
) => {
  const call = await prisma.call.findFirst({
    where: {
      id: callId,
      status: 'IN_PROGRESS',
      OR: [
        { userId },
        { listener: { userId } },
      ],
    },
    select: { id: true, userId: true, listenerId: true },
  });

  if (!call) {
    // Call may have just ended — return gracefully so the client can detect this
    // on the next getCallStatus check rather than crashing.
    logger.warn(`[CALL_HEARTBEAT] callId=${callId} not found / not IN_PROGRESS (userId=${userId})`);
    return { ok: false, reason: 'call_not_active' };
  }

  const now = new Date();
  if (role === 'listener') {
    await prisma.call.update({
      where: { id: callId },
      data: { listenerLastSeen: now },
    });
  } else {
    await prisma.call.update({
      where: { id: callId },
      data: { callerLastSeen: now },
    });
  }

  logger.debug(`[CALL_HEARTBEAT] callId=${callId} role=${role} userId=${userId} ts=${now.toISOString()}`);
  return { ok: true };
};

// ─────────────────────────────────────────────────────────────────────────────
// SERVER-SIDE WATCHDOG — called every watchdogIntervalMs from server.ts
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Scans all IN_PROGRESS calls and terminates any where a participant's
 * heartbeat has been silent for longer than participantTimeoutMs.
 *
 * This is the authoritative mechanism that protects billing when a
 * participant's app is force-killed without a clean call-end signal.
 *
 * Behaviour:
 *  - Both participants must have sent at least one heartbeat before timeout
 *    is enforced (callerLastSeen / listenerLastSeen null = call just started,
 *    give it a full grace period from startedAt).
 *  - Termination is idempotent — endCall() safely handles already-ended calls.
 */
export const watchdogActiveCalls = async (): Promise<void> => {
  const timeoutMs   = config.call.participantTimeoutMs;
  const cutoffTime  = new Date(Date.now() - timeoutMs);

  // Find all calls that have been IN_PROGRESS long enough to have heartbeats,
  // but where at least one participant heartbeat is missing or too old.
  const activeCalls = await prisma.call.findMany({
    where: {
      status: 'IN_PROGRESS',
      startedAt: { not: null },
    },
    select: {
      id: true,
      userId: true,
      listenerId: true,
      startedAt: true,
      callerLastSeen: true,
      listenerLastSeen: true,
    },
  });

  if (activeCalls.length === 0) return;

  for (const call of activeCalls) {
    const startedAt   = call.startedAt!;
    const callAgeMs   = Date.now() - startedAt.getTime();

    // Do not fire watchdog on calls younger than participantTimeoutMs.
    // This gives both clients time to send their first heartbeat after joining.
    if (callAgeMs < timeoutMs) continue;

    // Determine timeout conditions
    const callerDead = call.callerLastSeen === null
      ? callAgeMs > timeoutMs * 2   // never sent heartbeat → double timeout
      : call.callerLastSeen < cutoffTime;

    const listenerDead = call.listenerLastSeen === null
      ? callAgeMs > timeoutMs * 2
      : call.listenerLastSeen < cutoffTime;

    if (!callerDead && !listenerDead) continue;

    const reason = callerDead && listenerDead
      ? 'both_participants_timeout'
      : callerDead
        ? 'caller_timeout'
        : 'listener_timeout';

    logger.warn(
      `[CALL_TIMEOUT] callId=${call.id} reason=${reason}` +
      ` callerLastSeen=${call.callerLastSeen?.toISOString() ?? 'never'}` +
      ` listenerLastSeen=${call.listenerLastSeen?.toISOString() ?? 'never'}`
    );

    try {
      await endCall(call.id, 'system_watchdog', reason);
      logger.info(`[CALL_TIMEOUT] Successfully terminated orphan call: callId=${call.id} reason=${reason}`);
    } catch (err) {
      logger.error(`[CALL_TIMEOUT] Failed to terminate call ${call.id}:`, err);
    }
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// STARTUP HEAL — call once on server start
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Resets all listeners stuck in BUSY state without a live call backing them.
 * This recovers from server crashes / PM2 restarts where cleanup jobs were
 * interrupted mid-flight, leaving onlineStatus = 'BUSY' permanently.
 *
 * Also marks any RINGING/IN_PROGRESS calls older than 24 hours as MISSED/ENDED.
 */
export const resetStaleListenerStatuses = async (): Promise<void> => {
  try {
    // ── 1. Heal stale BUSY listeners ────────────────────────────────────────
    const busyListeners = await prisma.listener.findMany({
      where: { onlineStatus: 'BUSY' },
      select: { id: true },
    });

    let resetCount = 0;
    for (const l of busyListeners) {
      const activeCall = await prisma.call.findFirst({
        where: { listenerId: l.id, status: { in: ['RINGING', 'ACCEPTED', 'IN_PROGRESS'] } },
        select: { id: true },
      });
      if (!activeCall) {
        await prisma.listener.update({ where: { id: l.id }, data: { onlineStatus: 'ONLINE' } });
        resetCount++;
      }
    }
    if (resetCount > 0) {
      logger.info(`[STARTUP_HEAL] Reset ${resetCount} stale BUSY listeners to ONLINE`);
    }

    // ── 2. Force-end zombie calls older than 24 hours ───────────────────────
    const zombieCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const zombieCalls = await prisma.call.findMany({
      where: {
        status: { in: ['RINGING', 'ACCEPTED', 'IN_PROGRESS'] },
        createdAt: { lte: zombieCutoff },
      },
      select: { id: true, listenerId: true, status: true },
    });
    for (const call of zombieCalls) {
      try {
        await endCall(call.id, 'system_watchdog', 'startup_zombie_cleanup');
        logger.info(`[STARTUP_HEAL] Ended zombie call ${call.id} (status=${call.status})`);
      } catch (err) {
        logger.error(`[STARTUP_HEAL] Failed to end zombie call ${call.id}`, err);
      }
    }
    if (zombieCalls.length > 0) {
      logger.info(`[STARTUP_HEAL] Cleaned ${zombieCalls.length} zombie calls`);
    }
  } catch (err) {
    logger.error('[STARTUP_HEAL] Startup heal failed', err);
  }
};
