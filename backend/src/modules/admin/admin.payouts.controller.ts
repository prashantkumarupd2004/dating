import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import * as svc from './admin.payouts.service';
import { sendSuccess } from '../../utils/response';

export const listPayouts = async (req: AdminRequest, res: Response): Promise<void> => {
  const data = await svc.listPayouts(req.query);
  sendSuccess(res, data);
};

export const approvePayout = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.approvePayout(req.adminId!, req.params.id, req.body.notes);
  sendSuccess(res, null, 'Payout approved');
};

export const rejectPayout = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.rejectPayout(req.adminId!, req.params.id, req.body.reason ?? 'Rejected by admin');
  sendSuccess(res, null, 'Payout rejected');
};
