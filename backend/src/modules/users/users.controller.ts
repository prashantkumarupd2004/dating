import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import * as usersService from './users.service';

export const getMe = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const profile = await usersService.getProfile(req.userId!);
    sendSuccess(res, profile, 'Profile fetched');
  } catch (err) {
    next(err);
  }
};

export const updateMe = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const updated = await usersService.updateProfile(req.userId!, req.body);
    sendSuccess(res, updated, 'Profile updated');
  } catch (err) {
    next(err);
  }
};

export const getWallet = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const wallet = await usersService.getWalletBalance(req.userId!);
    sendSuccess(res, wallet, 'Wallet fetched');
  } catch (err) {
    next(err);
  }
};

export const addDevice = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { fcmToken, platform } = req.body;
    const device = await usersService.addDeviceToken(req.userId!, fcmToken, platform);
    sendCreated(res, device, 'Device registered');
  } catch (err) {
    next(err);
  }
};

export const deleteAccount = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    await usersService.deleteAccount(req.userId!);
    sendSuccess(res, null, 'Account deleted');
  } catch (err) {
    next(err);
  }
};
