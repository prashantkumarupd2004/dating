import { Request, Response } from 'express';
import * as settingsService from './settings.service';
import { sendSuccess } from '../../utils/response';

export const getAppSettings = async (_req: Request, res: Response): Promise<void> => {
  const data = await settingsService.getAppSettings();
  sendSuccess(res, data);
};
