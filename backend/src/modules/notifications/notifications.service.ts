import { prisma } from '../../config/database';
import { getPagination, buildMeta } from '../../utils/pagination';

export const getNotifications = async (
  userId: string,
  listenerId: string | undefined,
  filters: { page?: number; limit?: number }
) => {
  const { page, limit, skip } = getPagination(filters);
  const where: any = { OR: [{ userId }] };
  if (listenerId) where.OR.push({ listenerId });

  const [notifications, total] = await Promise.all([
    prisma.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.notification.count({ where }),
  ]);
  return { data: notifications, meta: buildMeta(total, page, limit) };
};

export const markAsRead = async (notificationId: string, userId: string) => {
  return prisma.notification.updateMany({
    where: { id: notificationId, userId },
    data: { isRead: true },
  });
};

export const markAllRead = async (userId: string) => {
  return prisma.notification.updateMany({
    where: { userId, isRead: false },
    data: { isRead: true },
  });
};
