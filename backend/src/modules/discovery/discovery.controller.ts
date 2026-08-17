import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess } from '../../utils/response';
import * as discoveryService from './discovery.service';

export const listListeners = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const filters = {
      onlineOnly: req.query.onlineOnly === 'true',
      language: req.query.language as string | undefined,
      city: req.query.city as string | undefined,
      minAge: req.query.minAge ? parseInt(req.query.minAge as string, 10) : undefined,
      maxAge: req.query.maxAge ? parseInt(req.query.maxAge as string, 10) : undefined,
      callType: req.query.callType as 'AUDIO' | 'VIDEO' | undefined,
      page: req.query.page ? parseInt(req.query.page as string, 10) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 20,
    };
    const result = await discoveryService.getListeners(req.userId!, filters);
    sendSuccess(res, result.data, 'Listeners fetched', 200, result.meta);
  } catch (err) {
    next(err);
  }
};

export const getListenerDetail = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await discoveryService.getListenerDetail(
      req.params.listenerId,
      req.userId!
    );
    sendSuccess(res, listener, 'Listener fetched');
  } catch (err) {
    next(err);
  }
};
