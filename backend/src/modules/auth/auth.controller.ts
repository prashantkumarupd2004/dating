import { Request, Response, NextFunction } from 'express';
import { AuthRequest } from '../../middleware/auth';
import { sendSuccess, sendCreated } from '../../utils/response';
import * as authService from './auth.service';
import {
  googleLoginSchema,
  registerSchema,
  refreshTokenSchema,
} from './auth.schema';

export const googleLogin = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { firebaseToken } = googleLoginSchema.parse(req.body);
    const result = await authService.loginWithGoogle(firebaseToken);
    res.status(result.isNew ? 201 : 200).json({
      success: true,
      message: 'Login successful',
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

export const register = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  try {
    const data = registerSchema.parse(req.body);
    const profile = await authService.completeRegistration(req.userId!, data);
    sendCreated(res, profile, 'Registration completed');
  } catch (err) {
    next(err);
  }
};

export const refreshToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { refreshToken: token } = refreshTokenSchema.parse(req.body);
    const tokens = await authService.refreshTokens(token);
    sendSuccess(res, tokens, 'Tokens refreshed');
  } catch (err) {
    next(err);
  }
};

export const logout = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { refreshToken: token } = refreshTokenSchema.parse(req.body);
    await authService.logout(token);
    sendSuccess(res, null, 'Logged out successfully');
  } catch (err) {
    next(err);
  }
};
