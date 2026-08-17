import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import * as svc from './admin.users.service';
import { sendSuccess } from '../../utils/response';

export const listUsers = async (req: AdminRequest, res: Response): Promise<void> => {
  const data = await svc.listUsers(req.query);
  sendSuccess(res, data);
};

export const getUserDetail = async (req: AdminRequest, res: Response): Promise<void> => {
  const data = await svc.getUserDetail(req.params.id);
  sendSuccess(res, data);
};

export const suspendUser = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.suspendUser(req.adminId!, req.params.id, req.body.reason ?? '');
  sendSuccess(res, null, 'User suspended');
};

export const banUser = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.banUser(req.adminId!, req.params.id, req.body.reason ?? '');
  sendSuccess(res, null, 'User banned');
};

export const unbanUser = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.unbanUser(req.adminId!, req.params.id);
  sendSuccess(res, null, 'User unbanned');
};

export const adjustCoins = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.adjustCoins(req.adminId!, req.params.id, req.body.coins, req.body.reason ?? '');
  sendSuccess(res, null, 'Wallet adjusted');
};
