import { Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import { getMyListenerAccount } from '../listeners/listeners.service';
import * as callsService from './calls.service';

export const initiateCall = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { listenerId, callType } = req.body;
    const result = await callsService.initiateCall(req.userId!, listenerId, callType);
    sendCreated(res, result, 'Call initiated');
  } catch (err) {
    next(err);
  }
};

export const acceptCall = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await getMyListenerAccount(req.userId!);
    const call = await callsService.acceptCall(req.params.callId, listener.id);
    sendSuccess(res, call, 'Call accepted');
  } catch (err) {
    next(err);
  }
};

export const endCall = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const call = await callsService.endCall(req.params.callId, req.userId!);
    sendSuccess(res, call, 'Call ended');
  } catch (err) {
    next(err);
  }
};

export const rejectCall = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const listener = await getMyListenerAccount(req.userId!);
    const call = await callsService.rejectCall(req.params.callId, listener.id);
    sendSuccess(res, call, 'Call rejected');
  } catch (err) {
    next(err);
  }
};

export const rateCall = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { rating, comment } = req.body;
    const result = await callsService.rateCall(req.params.callId, req.userId!, rating, comment);
    sendCreated(res, result, 'Rating submitted');
  } catch (err) {
    next(err);
  }
};

export const getCallHistory = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const filters = {
      page: req.query.page ? parseInt(req.query.page as string, 10) : 1,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 20,
      type: req.query.type as string | undefined,
    };
    const result = await callsService.getCallHistory(req.userId!, filters);
    sendSuccess(res, result.data, 'Call history fetched', 200, result.meta);
  } catch (err) {
    next(err);
  }
};
