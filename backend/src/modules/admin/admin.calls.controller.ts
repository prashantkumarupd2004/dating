import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';
import { getPagination, buildMeta } from '../../utils/pagination';

export const listCalls = async (req: AdminRequest, res: Response): Promise<void> => {
  const { page, limit, skip } = getPagination(req.query as any);
  const where: any = {};
  if (req.query.type) where.type = req.query.type;
  if (req.query.status) where.status = req.query.status;
  if (req.query.userId) where.userId = req.query.userId;
  if (req.query.listenerId) where.listenerId = req.query.listenerId;
  if (req.query.from || req.query.to) {
    where.createdAt = {};
    if (req.query.from) where.createdAt.gte = new Date(req.query.from as string);
    if (req.query.to) where.createdAt.lte = new Date(req.query.to as string);
  }
  const [calls, total] = await Promise.all([
    prisma.call.findMany({
      where, skip, take: limit, orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { name: true } },
        listener: { include: { profile: { select: { displayName: true } } } },
        billing: true,
        earning: true,
      },
    }),
    prisma.call.count({ where }),
  ]);
  sendSuccess(res, { calls, meta: buildMeta(total, page, limit) });
};
