import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess } from '../../utils/response';
import * as walletService from './wallet.service';

export const getWallet = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const wallet = await walletService.getWallet(req.userId!);
    sendSuccess(res, wallet, 'Wallet fetched');
  } catch (err) { next(err); }
};

export const getTransactions = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 20,
      type: req.query.type as string | undefined,
    };
    const result = await walletService.getTransactions(req.userId!, filters);
    sendSuccess(res, result.data, 'Transactions fetched', 200, result.meta);
  } catch (err) { next(err); }
};

export const getCoinPackages = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const packages = await walletService.getCoinPackages();
    sendSuccess(res, packages, 'Packages fetched');
  } catch (err) { next(err); }
};
