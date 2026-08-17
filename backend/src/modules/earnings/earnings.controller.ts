import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../middleware/errorHandler';
import { prisma } from '../../config/database';
import * as earningsService from './earnings.service';

export const getEarningsSummary = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const listener = await prisma.listener.findUnique({ where: { userId: req.userId! } });
    if (!listener) throw new AppError(404, 'Listener account not found');
    const summary = await earningsService.getEarningsSummary(listener.id);
    sendSuccess(res, summary, 'Earnings summary fetched');
  } catch (err) { next(err); }
};

export const getEarningsHistory = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const listener = await prisma.listener.findUnique({ where: { userId: req.userId! } });
    if (!listener) throw new AppError(404, 'Listener account not found');
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 20,
      status: req.query.status as string | undefined,
    };
    const result = await earningsService.getEarningsHistory(listener.id, filters);
    sendSuccess(res, result.data, 'Earnings fetched', 200, result.meta);
  } catch (err) { next(err); }
};
