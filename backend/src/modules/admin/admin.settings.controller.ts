import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';

export const getAllSettings = async (_req: AdminRequest, res: Response): Promise<void> => {
  const settings = await prisma.setting.findMany({ orderBy: [{ group: 'asc' }, { key: 'asc' }] });
  const grouped = settings.reduce<Record<string, any[]>>((acc, s) => {
    if (!acc[s.group]) acc[s.group] = [];
    acc[s.group].push(s);
    return acc;
  }, {});
  sendSuccess(res, grouped);
};

export const updateSetting = async (req: AdminRequest, res: Response): Promise<void> => {
  const { key } = req.params;
  const { value } = req.body;
  const old = await prisma.setting.findUnique({ where: { key } });
  const updated = await prisma.setting.update({ where: { key }, data: { value: String(value) } });
  await prisma.adminLog.create({
    data: { adminId: req.adminId!, action: 'UPDATE_SETTING', targetType: 'Setting', targetId: key, oldValue: { value: old?.value }, newValue: { value } },
  });
  sendSuccess(res, updated, 'Setting updated');
};
