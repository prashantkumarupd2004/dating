import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';

interface DiscoveryFilters {
  onlineOnly?: boolean;
  language?: string;
  city?: string;
  minAge?: number;
  maxAge?: number;
  callType?: 'AUDIO' | 'VIDEO';
  page?: number;
  limit?: number;
}

export const getListeners = async (userId: string, filters: DiscoveryFilters) => {
  const { page, limit, skip } = getPagination(filters);

  // Get blocked listener IDs for this user
  const blocks = await prisma.block.findMany({
    where: { blockerId: userId },
    select: { blockedListenerId: true },
  });
  const blockedIds = blocks.map((b) => b.blockedListenerId).filter(Boolean) as string[];

  // Build where clause
  const where: any = {
    status: 'APPROVED',
    id: { notIn: blockedIds },
  };

  if (filters.onlineOnly) {
    where.onlineStatus = 'ONLINE';
  }

  if (filters.callType === 'AUDIO') where.isAudioEnabled = true;
  if (filters.callType === 'VIDEO') where.isVideoEnabled = true;

  if (filters.language || filters.city || filters.minAge || filters.maxAge) {
    where.profile = {};
    if (filters.language) {
      where.profile.languages = { has: filters.language };
    }
    if (filters.city) {
      where.profile.city = { contains: filters.city, mode: 'insensitive' };
    }
    if (filters.minAge || filters.maxAge) {
      const now = new Date();
      where.profile.dateOfBirth = {};
      if (filters.maxAge) {
        where.profile.dateOfBirth.gte = new Date(
          now.getFullYear() - filters.maxAge,
          now.getMonth(),
          now.getDate()
        );
      }
      if (filters.minAge) {
        where.profile.dateOfBirth.lte = new Date(
          now.getFullYear() - filters.minAge,
          now.getMonth(),
          now.getDate()
        );
      }
    }
  }

  const [listeners, total] = await Promise.all([
    prisma.listener.findMany({
      where,
      include: {
        profile: {
          select: {
            displayName: true,
            photoUrl: true,
            dateOfBirth: true,
            city: true,
            state: true,
            relationshipStatus: true,
            languages: true,
            rating: true,
            totalCalls: true,
            bio: true,
          },
        },
      },
      orderBy: [
        { onlineStatus: 'asc' },
        { profile: { rating: 'desc' } },
      ],
      skip,
      take: limit,
    }),
    prisma.listener.count({ where }),
  ]);

  // Fetch favorite status
  const favorites = await prisma.favorite.findMany({
    where: { userId, listenerId: { in: listeners.map((l) => l.id) } },
    select: { listenerId: true },
  });
  const favoriteIds = new Set(favorites.map((f) => f.listenerId));

  const enriched = listeners.map((l) => ({ ...l, isFavorite: favoriteIds.has(l.id) }));

  return { data: enriched, meta: buildMeta(total, page, limit) };
};

export const getListenerDetail = async (listenerId: string, userId: string) => {
  const listener = await prisma.listener.findUnique({
    where: { id: listenerId, status: 'APPROVED' },
    include: {
      profile: true,
      interests: { include: { interest: true } },
    },
  });
  if (!listener) throw new AppError(404, 'Listener not found');

  const [favorite, block] = await Promise.all([
    prisma.favorite.findUnique({ where: { userId_listenerId: { userId, listenerId } } }),
    prisma.block.findFirst({ where: { blockerId: userId, blockedListenerId: listenerId } }),
  ]);

  return { ...listener, isFavorite: !!favorite, isBlocked: !!block };
};
