import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import { AppError } from '../../middleware/errorHandler';
import { prisma } from '../../config/database';
import * as payoutsService from './payouts.service';

export const requestPayout = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const listener = await prisma.listener.findUnique({ where: { userId: req.userId! } });
    if (!listener) throw new AppError(404, 'Listener account not found');
    const { amount, method, accountDetails } = req.body;
    const payout = await payoutsService.requestPayout(listener.id, amount, method, accountDetails);
    sendCreated(res, payout, 'Payout request submitted');
  } catch (err) { next(err); }
};

export const getPayouts = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const listener = await prisma.listener.findUnique({ where: { userId: req.userId! } });
    if (!listener) throw new AppError(404, 'Listener account not found');
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 20,
    };
    const result = await payoutsService.getPayouts(listener.id, filters);
    sendSuccess(res, result.data, 'Payouts fetched', 200, result.meta);
  } catch (err) { next(err); }
};
