import { prisma } from '../../config/database';
import { getPagination, buildMeta } from '../../utils/pagination';

export const createReport = async (
  reporterId: string,
  data: {
    reportedUserId?: string;
    reportedListenerId?: string;
    category: string;
    description?: string;
  }
) => {
  return prisma.report.create({
    data: {
      reporterId,
      reportedUserId: data.reportedUserId,
      reportedListenerId: data.reportedListenerId,
      category: data.category as any,
      description: data.description,
      status: 'OPEN',
    },
  });
};

export const getUserReports = async (userId: string, filters: { page?: number; limit?: number }) => {
  const { page, limit, skip } = getPagination(filters);
  const [reports, total] = await Promise.all([
    prisma.report.findMany({
      where: { reporterId: userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.report.count({ where: { reporterId: userId } }),
  ]);
  return { data: reports, meta: buildMeta(total, page, limit) };
};
