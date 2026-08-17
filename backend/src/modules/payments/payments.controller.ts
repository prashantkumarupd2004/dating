import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import * as paymentsService from './payments.service';

export const createOrder = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { coinPackageId } = req.body;
    const order = await paymentsService.createOrder(req.userId!, coinPackageId);
    sendCreated(res, order, 'Order created');
  } catch (err) { next(err); }
};

export const verifyPayment = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { orderId, paymentId, signature } = req.body;
    const result = await paymentsService.verifyPayment(req.userId!, orderId, paymentId, signature);
    sendSuccess(res, result, 'Payment verified');
  } catch (err) { next(err); }
};
