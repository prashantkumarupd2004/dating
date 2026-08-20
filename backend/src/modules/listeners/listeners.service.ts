import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { redis } from '../../config/redis';
import { logger } from '../../utils/logger';

const PRESENCE_TTL = 35;

export const registerAsListener = async (
  userId: string,
  data: {
    displayName: string;
    dateOfBirth: string;
    city?: string;
    state?: string;
    bio?: string;
    languages?: string[];
    relationshipStatus?: string;
    isAudioAvailable?: boolean;
    isVideoAvailable?: boolean;
  }
) => {
  // ── Gender enforcement: only FEMALE users can become listeners ────────────
  const userProfile = await prisma.userProfile.findUnique({
    where: { userId },
    select: { gender: true },
  });

  // If profile exists, enforce female-only rule
  if (userProfile && userProfile.gender !== 'FEMALE') {
    throw new AppError(403, 'Only female users can register as listeners');
  }

  const existing = await prisma.listener.findUnique({ where: { userId } });
  if (existing) throw new AppError(409, 'Already registered as a listener');

  const listener = await prisma.listener.create({
    data: {
      userId,
      status: 'PENDING',
      isAudioEnabled: data.isAudioAvailable ?? true,
      isVideoEnabled: data.isVideoAvailable ?? false,
      profile: {
        create: {
          displayName: data.displayName,
          dateOfBirth: new Date(data.dateOfBirth),
          city: data.city,
          state: data.state,
          bio: data.bio,
          languages: data.languages || [],
          relationshipStatus: data.relationshipStatus,
        },
      },
      wallet: { create: {} },
    },
    include: { profile: true },
  });

  logger.info(`New listener registration submitted for user ${userId}`);
  return listener;
};

export const getListenerProfile = async (listenerId: string) => {
  const listener = await prisma.listener.findUnique({
    where: { id: listenerId },
    include: {
      profile: true,
      wallet: true,
      user: { select: { name: true, email: true } },
    },
  });
  if (!listener) throw new AppError(404, 'Listener not found');
  return listener;
};

export const updateListenerProfile = async (
  listenerId: string,
  data: {
    displayName?: string;
    city?: string;
    bio?: string;
    languages?: string[];
    isAudioEnabled?: boolean;
    isVideoEnabled?: boolean;
  }
) => {
  const { isAudioEnabled, isVideoEnabled, ...profileData } = data;

  const [listener] = await prisma.$transaction([
    prisma.listener.update({
      where: { id: listenerId },
      data: { isAudioEnabled, isVideoEnabled },
    }),
    prisma.listenerProfile.update({
      where: { listenerId },
      data: profileData,
    }),
  ]);

  return listener;
};

export const toggleOnlineStatus = async (
  listenerId: string,
  status: 'ONLINE' | 'OFFLINE' | 'BUSY'
) => {
  const listener = await prisma.listener.update({
    where: { id: listenerId },
    data: { onlineStatus: status },
  });

  try {
    if (status === 'ONLINE') {
      await redis.setex(`presence:${listenerId}`, PRESENCE_TTL, listenerId);
    } else {
      await redis.del(`presence:${listenerId}`);
    }
  } catch {
    // Redis unavailable, DB status is source of truth
  }

  logger.info(`Listener ${listenerId} status changed to ${status}`);
  return listener;
};

export const getMyListenerAccount = async (userId: string) => {
  const listener = await prisma.listener.findUnique({
    where: { userId },
    include: { profile: true, wallet: true },
  });
  if (!listener) throw new AppError(404, 'Listener account not found');
  return listener;
};

export const saveVoiceSample = async (userId: string, fileUrl: string) => {
  const listener = await prisma.listener.findUnique({ where: { userId } });
  if (!listener) throw new AppError(404, 'Listener account not found. Register as listener first.');

  const doc = await prisma.listenerDocument.create({
    data: {
      listenerId: listener.id,
      type: 'VOICE_SAMPLE',
      fileUrl,
      status: 'PENDING',
    },
  });

  logger.info(`Voice sample uploaded for listener ${listener.id}`);
  return doc;
};
