import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import * as reportsService from './reports.service';

export const createReport = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const report = await reportsService.createReport(req.userId!, req.body);
    sendCreated(res, report, 'Report submitted');
  } catch (err) { next(err); }
};

export const getMyReports = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 20,
    };
    const result = await reportsService.getUserReports(req.userId!, filters);
    sendSuccess(res, result.data, 'Reports fetched', 200, result.meta);
  } catch (err) { next(err); }
};
