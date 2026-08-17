import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth';
import * as supportService from './support.service';
import { sendSuccess, sendCreated } from '../../utils/response';

export const createTicket = async (req: AuthRequest, res: Response): Promise<void> => {
  const data = await supportService.createTicket(req.userId!, req.body.subject, req.body.message);
  sendCreated(res, data, 'Ticket created');
};

export const getTickets = async (req: AuthRequest, res: Response): Promise<void> => {
  const data = await supportService.getTickets(req.userId!, { page: Number(req.query.page), limit: Number(req.query.limit) });
  sendSuccess(res, data);
};

export const getTicket = async (req: AuthRequest, res: Response): Promise<void> => {
  const data = await supportService.getTicket(req.params.id, req.userId!);
  sendSuccess(res, data);
};

export const replyToTicket = async (req: AuthRequest, res: Response): Promise<void> => {
  const data = await supportService.replyToTicket(req.params.id, req.userId!, req.body.message);
  sendSuccess(res, data, 'Reply sent');
};
