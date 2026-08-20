import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../../utils/jwt';
import { verifyFirebaseToken } from '../../services/firebase.service';

const REFRESH_EXPIRES_DAYS = 90;

function getRefreshExpiry(): Date {
  return new Date(Date.now() + REFRESH_EXPIRES_DAYS * 24 * 60 * 60 * 1000);
}

function generateTokens(userId: string) {
  const accessToken = signAccessToken({ userId, type: 'user' });
  const refreshToken = signRefreshToken({ userId });
  return { accessToken, refreshToken };
}

async function findOrCreateUser(googleId: string, email: string | undefined, name?: string) {
  const existing = await prisma.user.findFirst({
    where: { googleId },
    include: { wallet: true, profile: true },
  });
  if (existing) return { user: existing, isNew: false };

  try {
    const newUser = await prisma.user.create({
      data: {
        googleId,
        email,
        name: name || 'User',
        wallet: { create: { balance: 1000 } },
      },
      include: { wallet: true, profile: true },
    });
    return { user: newUser, isNew: true };
  } catch (err: any) {
    // Race condition: another request already created this user
    if (err.code === 'P2002') {
      const user = await prisma.user.findFirst({
        where: { googleId },
        include: { wallet: true, profile: true },
      });
      if (user) return { user, isNew: false };
    }
    throw err;
  }
}

export const loginWithGoogle = async (firebaseToken: string) => {
  const decoded = await verifyFirebaseToken(firebaseToken);
  const { user, isNew } = await findOrCreateUser(
    decoded.uid,
    decoded.email,
    decoded.email?.split('@')[0] || 'User'
  );
  if (!user.isActive || user.isBanned) throw new AppError(403, 'Account is suspended or banned');

  const { accessToken, refreshToken } = generateTokens(user.id);
  await prisma.userSession.create({
    data: { userId: user.id, refreshToken, expiresAt: getRefreshExpiry() },
  });

  const hasProfile = !!user.profile;
  return { accessToken, refreshToken, user, isNew, hasProfile };
};

export const completeRegistration = async (
  userId: string,
  data: {
    name: string;
    nickname?: string;       // Display name shown to listeners during calls
    dateOfBirth: string;
    gender: 'MALE' | 'FEMALE' | 'OTHER';
    city?: string;
    bio?: string;
    language?: string;
    photoUrl?: string;
  }
) => {
  const dob = new Date(data.dateOfBirth);
  const today = new Date();
  const age = today.getFullYear() - dob.getFullYear()
    - (today < new Date(today.getFullYear(), dob.getMonth(), dob.getDate()) ? 1 : 0);

  if (age < 18) throw new AppError(403, 'Must be 18 or older');

  // Use nickname if provided, else derive from name
  const displayNickname = data.nickname?.trim() || data.name;

  await prisma.user.update({ where: { id: userId }, data: { name: data.name } });

  const profile = await prisma.userProfile.upsert({
    where: { userId },
    update: {
      dateOfBirth: dob,
      gender: data.gender,
      nickname: displayNickname,
      city: data.city,
      bio: data.bio,
      language: data.language,
      photoUrl: data.photoUrl,
    },
    create: {
      userId,
      dateOfBirth: dob,
      gender: data.gender,
      nickname: displayNickname,
      city: data.city,
      bio: data.bio,
      language: data.language,
      photoUrl: data.photoUrl,
    },
  });

  return profile;
};

export const refreshTokens = async (refreshToken: string) => {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new AppError(401, 'Invalid refresh token');
  }

  const session = await prisma.userSession.findUnique({ where: { refreshToken } });
  if (!session || session.expiresAt < new Date()) {
    throw new AppError(401, 'Session expired or not found');
  }

  const user = await prisma.user.findUnique({
    where: { id: payload.userId },
    select: { id: true, isActive: true, isBanned: true },
  });
  if (!user || !user.isActive || user.isBanned) throw new AppError(403, 'Account inactive or banned');

  const { accessToken, refreshToken: newRefreshToken } = generateTokens(user.id);

  await prisma.userSession.update({
    where: { id: session.id },
    data: { refreshToken: newRefreshToken, expiresAt: getRefreshExpiry() },
  });

  return { accessToken, refreshToken: newRefreshToken };
};

export const logout = async (refreshToken: string) => {
  await prisma.userSession.deleteMany({ where: { refreshToken } });
};
