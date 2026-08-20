import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { logger } from '../../utils/logger';

export const getProfile = async (userId: string) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,   // includes nickname, photoUrl, gender etc.
      wallet: { select: { balance: true } },
      listener: { select: { id: true, status: true, onlineStatus: true } },
    },
  });
  if (!user) throw new AppError(404, 'User not found');
  return user;
};

export const updateProfile = async (
  userId: string,
  data: { name?: string; nickname?: string; city?: string; bio?: string; language?: string; photoUrl?: string }
) => {
  if (data.name) {
    await prisma.user.update({ where: { id: userId }, data: { name: data.name } });
  }
  const profile = await prisma.userProfile.upsert({
    where: { userId },
    update: {
      nickname: data.nickname,
      city: data.city,
      bio: data.bio,
      language: data.language,
      photoUrl: data.photoUrl,
    },
    create: {
      userId,
      dateOfBirth: new Date('2000-01-01'),
      gender: 'OTHER',
      nickname: data.nickname,
      city: data.city,
      bio: data.bio,
      language: data.language,
      photoUrl: data.photoUrl,
    },
  });
  return profile;
};

export const uploadPhoto = async (userId: string, fileUrl: string) => {
  return prisma.userProfile.upsert({
    where: { userId },
    update: { photoUrl: fileUrl },
    create: {
      userId,
      dateOfBirth: new Date('2000-01-01'),
      gender: 'OTHER',
      photoUrl: fileUrl,
    },
  });
};

export const getWalletBalance = async (userId: string) => {
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
    select: { balance: true, updatedAt: true },
  });
  if (!wallet) throw new AppError(404, 'Wallet not found');
  return wallet;
};

export const addDeviceToken = async (
  userId: string,
  fcmToken: string,
  platform: 'ANDROID' | 'IOS'
) => {
  return prisma.device.upsert({
    where: { fcmToken },
    update: { userId, platform },
    create: { userId, fcmToken, platform },
  });
};

export const deleteAccount = async (userId: string) => {
  logger.info(`Soft-deleting account for user ${userId}`);
  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: {
        isActive: false,
        name: 'Deleted User',
        phone: null,
        email: null,
        googleId: null,
      },
    }),
    prisma.userProfile.updateMany({
      where: { userId },
      data: { bio: null, city: null, photoUrl: null },
    }),
    prisma.userSession.deleteMany({ where: { userId } }),
  ]);
};
