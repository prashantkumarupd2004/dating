import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import * as svc from './admin.listeners.service';
import { sendSuccess } from '../../utils/response';

export const listListeners = async (req: AdminRequest, res: Response): Promise<void> => {
  const data = await svc.listListeners(req.query);
  sendSuccess(res, data);
};

export const approveListener = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.approveListener(req.adminId!, req.params.id, req.body.notes);
  sendSuccess(res, null, 'Listener approved');
};

export const rejectListener = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.rejectListener(req.adminId!, req.params.id, req.body.reason ?? 'Does not meet requirements');
  sendSuccess(res, null, 'Listener rejected');
};

export const suspendListener = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.suspendListener(req.adminId!, req.params.id, req.body.reason ?? '');
  sendSuccess(res, null, 'Listener suspended');
};

export const reactivateListener = async (req: AdminRequest, res: Response): Promise<void> => {
  await svc.reactivateListener(req.adminId!, req.params.id);
  sendSuccess(res, null, 'Listener reactivated');
};
