import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';

export const listReports = async (req: AdminRequest, res: Response): Promise<void> => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = 20;
  const where: any = {};
  if (req.query.status) where.status = req.query.status;
  if (req.query.category) where.category = req.query.category;

  const [reports, total] = await Promise.all([
    prisma.report.findMany({
      where, skip: (page - 1) * limit, take: limit, orderBy: { createdAt: 'desc' },
      include: { reporter: { select: { name: true } }, reportedUser: { select: { name: true } }, reportedListener: { include: { profile: { select: { displayName: true } } } } },
    }),
    prisma.report.count({ where }),
  ]);
  sendSuccess(res, { reports, total, page, totalPages: Math.ceil(total / limit) });
};

export const updateReport = async (req: AdminRequest, res: Response): Promise<void> => {
  const report = await prisma.report.update({
    where: { id: req.params.id },
    data: { status: req.body.status, adminNotes: req.body.notes, adminId: req.adminId, resolvedAt: req.body.status === 'RESOLVED' ? new Date() : undefined },
  });
  await prisma.adminLog.create({
    data: { adminId: req.adminId!, action: 'UPDATE_REPORT', targetType: 'Report', targetId: req.params.id, newValue: { status: req.body.status } },
  });
  sendSuccess(res, report, 'Report updated');
};
