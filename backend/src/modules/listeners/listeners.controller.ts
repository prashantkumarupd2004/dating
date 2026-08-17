import { Response, NextFunction } from 'express';
import path from 'path';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import * as listenersService from './listeners.service';

export const registerAsListener = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await listenersService.registerAsListener(req.userId!, req.body);
    sendCreated(res, listener, 'Listener registration submitted');
  } catch (err) {
    next(err);
  }
};

export const getMyListener = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await listenersService.getMyListenerAccount(req.userId!);
    sendSuccess(res, listener, 'Listener profile fetched');
  } catch (err) {
    next(err);
  }
};

export const updateMyListener = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await listenersService.getMyListenerAccount(req.userId!);
    const updated = await listenersService.updateListenerProfile(listener.id, req.body);
    sendSuccess(res, updated, 'Profile updated');
  } catch (err) {
    next(err);
  }
};

export const updateStatus = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await listenersService.getMyListenerAccount(req.userId!);
    const { status } = req.body;
    const updated = await listenersService.toggleOnlineStatus(listener.id, status);
    sendSuccess(res, updated, 'Status updated');
  } catch (err) {
    next(err);
  }
};

export const uploadVoiceSample = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.file) {
      res.status(400).json({ success: false, message: 'No audio file provided' });
      return;
    }
    const relativePath = path.join('uploads', 'voice-samples', req.file.filename).replace(/\\/g, '/');
    const doc = await listenersService.saveVoiceSample(req.userId!, relativePath);
    sendCreated(res, doc, 'Voice sample uploaded successfully');
  } catch (err) {
    next(err);
  }
};
