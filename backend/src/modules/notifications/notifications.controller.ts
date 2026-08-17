import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess } from '../../utils/response';
import { prisma } from '../../config/database';
import * as notificationsService from './notifications.service';

export const getNotifications = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const listener = await prisma.listener.findUnique({ where: { userId: req.userId! } });
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 20,
    };
    const result = await notificationsService.getNotifications(req.userId!, listener?.id, filters);
    sendSuccess(res, result.data, 'Notifications fetched', 200, result.meta);
  } catch (err) { next(err); }
};

export const markAsRead = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    await notificationsService.markAsRead(req.params.id, req.userId!);
    sendSuccess(res, null, 'Marked as read');
  } catch (err) { next(err); }
};

export const markAllRead = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    await notificationsService.markAllRead(req.userId!);
    sendSuccess(res, null, 'All notifications marked as read');
  } catch (err) { next(err); }
};
