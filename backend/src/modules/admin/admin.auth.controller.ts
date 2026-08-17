import { Request, Response } from 'express';
import * as authService from './admin.auth.service';
import { sendSuccess, sendError } from '../../utils/response';

export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;
    if (!email || !password) { sendError(res, 'Email and password required'); return; }
    const data = await authService.adminLogin(email, password);
    sendSuccess(res, data, 'Login successful');
  } catch (err: any) {
    sendError(res, err.message, err.statusCode ?? 500);
  }
};
