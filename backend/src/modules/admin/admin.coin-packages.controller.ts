import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess, sendCreated } from '../../utils/response';

const serializePkg = (p: any) => ({
  ...p,
  priceInr: parseFloat(p.priceInr.toString()),
  originalPriceInr: p.originalPriceInr ? parseFloat(p.originalPriceInr.toString()) : null,
});

export const listPackages = async (_req: AdminRequest, res: Response): Promise<void> => {
  const packages = await prisma.coinPackage.findMany({ orderBy: { sortOrder: 'asc' } });
  sendSuccess(res, packages.map(serializePkg));
};

export const createPackage = async (req: AdminRequest, res: Response): Promise<void> => {
  const pkg = await prisma.coinPackage.create({ data: req.body });
  await prisma.adminLog.create({ data: { adminId: req.adminId!, action: 'CREATE_COIN_PACKAGE', targetType: 'CoinPackage', targetId: pkg.id, newValue: req.body } });
  sendCreated(res, serializePkg(pkg));
};

export const updatePackage = async (req: AdminRequest, res: Response): Promise<void> => {
  const old = await prisma.coinPackage.findUnique({ where: { id: req.params.id } });
  const pkg = await prisma.coinPackage.update({ where: { id: req.params.id }, data: req.body });
  await prisma.adminLog.create({ data: { adminId: req.adminId!, action: 'UPDATE_COIN_PACKAGE', targetType: 'CoinPackage', targetId: pkg.id, oldValue: old as any, newValue: req.body } });
  sendSuccess(res, serializePkg(pkg));
};

export const deletePackage = async (req: AdminRequest, res: Response): Promise<void> => {
  await prisma.coinPackage.update({ where: { id: req.params.id }, data: { isActive: false } });
  sendSuccess(res, null, 'Package deactivated');
};

