import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';

export const getDashboardStats = async (_req: AdminRequest, res: Response): Promise<void> => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [
    totalUsers, totalListeners, onlineListeners,
    todayCalls, todayAudio, todayVideo,
    pendingApprovals, openReports, pendingPayouts,
  ] = await Promise.all([
    prisma.user.count({ where: { isActive: true } }),
    prisma.listener.count({ where: { status: 'APPROVED' } }),
    prisma.listener.count({ where: { onlineStatus: 'ONLINE' } }),
    prisma.call.count({ where: { createdAt: { gte: today } } }),
    prisma.call.count({ where: { createdAt: { gte: today }, type: 'AUDIO' } }),
    prisma.call.count({ where: { createdAt: { gte: today }, type: 'VIDEO' } }),
    prisma.listener.count({ where: { status: 'PENDING' } }),
    prisma.report.count({ where: { status: 'OPEN' } }),
    prisma.payout.count({ where: { status: 'REQUESTED' } }),
  ]);

  const todayRevResult = await prisma.earning.aggregate({
    where: { createdAt: { gte: today } },
    _sum: { grossCoins: true, platformCut: true, listenerAmount: true },
  });

  sendSuccess(res, {
    totalUsers, totalListeners, onlineListeners,
    todayCalls, todayAudio, todayVideo,
    pendingApprovals, openReports, pendingPayouts,
    todayRevenue: {
      grossCoins: todayRevResult._sum.grossCoins ?? 0,
      platformCut: todayRevResult._sum.platformCut ?? 0,
      listenerEarnings: todayRevResult._sum.listenerAmount ?? 0,
    },
  });
};

export const getRevenueChart = async (req: AdminRequest, res: Response): Promise<void> => {
  const days = parseInt((req.query.days as string) ?? '30', 10);
  const from = new Date();
  from.setDate(from.getDate() - days);

  const earnings = await prisma.earning.findMany({
    where: { createdAt: { gte: from } },
    select: { createdAt: true, grossCoins: true, platformCut: true, listenerAmount: true },
    orderBy: { createdAt: 'asc' },
  });

  const map: Record<string, { date: string; grossCoins: number; platformCut: number; listenerAmount: number }> = {};
  for (const e of earnings) {
    const d = e.createdAt.toISOString().slice(0, 10);
    if (!map[d]) map[d] = { date: d, grossCoins: 0, platformCut: 0, listenerAmount: 0 };
    map[d].grossCoins += Number(e.grossCoins);
    map[d].platformCut += Number(e.platformCut);
    map[d].listenerAmount += Number(e.listenerAmount);
  }

  sendSuccess(res, Object.values(map));
};

export const getCallStats = async (req: AdminRequest, res: Response): Promise<void> => {
  const days = parseInt((req.query.days as string) ?? '7', 10);
  const from = new Date();
  from.setDate(from.getDate() - days);

  const calls = await prisma.call.groupBy({
    by: ['type', 'status'],
    where: { createdAt: { gte: from } },
    _count: true,
  });

  sendSuccess(res, calls);
};

export const getAuditLogs = async (req: AdminRequest, res: Response): Promise<void> => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = 50;
  const skip = (page - 1) * limit;

  const [logs, total] = await Promise.all([
    prisma.adminLog.findMany({
      skip, take: limit, orderBy: { createdAt: 'desc' },
      include: { admin: { select: { name: true, email: true } } },
    }),
    prisma.adminLog.count(),
  ]);

  sendSuccess(res, { logs, total, page, totalPages: Math.ceil(total / limit) });
};
