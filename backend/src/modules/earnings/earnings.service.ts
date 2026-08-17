import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';

export const getEarningsSummary = async (listenerId: string) => {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfWeek = new Date(startOfDay);
  startOfWeek.setDate(startOfDay.getDate() - startOfDay.getDay());
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const [todayTotal, weekTotal, monthTotal, wallet, todayCalls, totalCalls, recentCalls] = await Promise.all([
    prisma.earning.aggregate({
      where: { listenerId, createdAt: { gte: startOfDay } },
      _sum: { listenerAmount: true },
    }),
    prisma.earning.aggregate({
      where: { listenerId, createdAt: { gte: startOfWeek } },
      _sum: { listenerAmount: true },
    }),
    prisma.earning.aggregate({
      where: { listenerId, createdAt: { gte: startOfMonth } },
      _sum: { listenerAmount: true },
    }),
    prisma.listenerWallet.findUnique({ where: { listenerId } }),
    // Today's completed calls
    prisma.call.count({
      where: { listenerId, status: 'COMPLETED', createdAt: { gte: startOfDay } },
    }),
    // All-time completed calls
    prisma.call.count({
      where: { listenerId, status: 'COMPLETED' },
    }),
    // Recent 5 calls
    prisma.call.findMany({
      where: { listenerId, status: 'COMPLETED' },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: {
        id: true,
        type: true,
        durationSeconds: true,
        startedAt: true,
        endedAt: true,
        createdAt: true,
        user: { select: { name: true } },
      },
    }),
  ]);

  return {
    todayEarnings: Number(todayTotal._sum.listenerAmount ?? 0),
    weekEarnings: Number(weekTotal._sum.listenerAmount ?? 0),
    monthEarnings: Number(monthTotal._sum.listenerAmount ?? 0),
    todayCalls,
    totalCalls,
    recentCalls,
    availableBalance: Number(wallet?.availableBalance ?? 0),
    pendingBalance: Number(wallet?.pendingBalance ?? 0),
    totalEarnings: Number(wallet?.totalEarned ?? 0),
    totalWithdrawn: Number(wallet?.totalWithdrawn ?? 0),
  };
};


export const getEarningsHistory = async (
  listenerId: string,
  filters: { page?: number; limit?: number; status?: string }
) => {
  const { page, limit, skip } = getPagination(filters);
  const where: any = { listenerId };
  if (filters.status) where.status = filters.status;

  const [earnings, total] = await Promise.all([
    prisma.earning.findMany({
      where,
      include: {
        call: {
          select: { type: true, durationSeconds: true, startedAt: true, endedAt: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.earning.count({ where }),
  ]);

  return { data: earnings, meta: buildMeta(total, page, limit) };
};
