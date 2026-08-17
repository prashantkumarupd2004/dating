import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';
import { Decimal } from '@prisma/client/runtime/library';

export const listUsers = async (query: any) => {
  const { page, limit, skip } = getPagination(query);
  const where: any = {};
  if (query.search) where.OR = [
    { name: { contains: query.search, mode: 'insensitive' } },
    { email: { contains: query.search, mode: 'insensitive' } },
    { phone: { contains: query.search } },
  ];
  if (query.status === 'banned') where.isBanned = true;
  if (query.status === 'suspended') where.isSuspended = true;
  if (query.status === 'active') { where.isBanned = false; where.isSuspended = false; }

  const [users, total] = await Promise.all([
    prisma.user.findMany({ where, skip, take: limit, orderBy: { createdAt: 'desc' },
      include: { profile: true, wallet: true } }),
    prisma.user.count({ where }),
  ]);
  return { users, meta: buildMeta(total, page, limit) };
};

export const getUserDetail = async (userId: string) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { profile: true, wallet: { include: { transactions: { take: 10, orderBy: { createdAt: 'desc' } } } }, listener: true },
  });
  if (!user) throw new AppError(404, 'User not found');
  return user;
};

export const suspendUser = async (adminId: string, userId: string, reason: string) => {
  const user = await prisma.user.update({
    where: { id: userId }, data: { isSuspended: true },
  });
  await logAdminAction(adminId, 'SUSPEND_USER', 'User', userId, null, { reason });
  return user;
};

export const banUser = async (adminId: string, userId: string, reason: string) => {
  const user = await prisma.user.update({
    where: { id: userId }, data: { isBanned: true },
  });
  await logAdminAction(adminId, 'BAN_USER', 'User', userId, null, { reason });
  return user;
};

export const unbanUser = async (adminId: string, userId: string) => {
  const user = await prisma.user.update({
    where: { id: userId }, data: { isBanned: false, isSuspended: false },
  });
  await logAdminAction(adminId, 'UNBAN_USER', 'User', userId, null, null);
  return user;
};

export const adjustCoins = async (adminId: string, userId: string, coins: number, reason: string) => {
  const wallet = await prisma.wallet.findUnique({ where: { userId } });
  if (!wallet) throw new AppError(404, 'Wallet not found');
  const balanceBefore = wallet.balance;
  const balanceAfter = Decimal.max(new Decimal(0), balanceBefore.add(new Decimal(coins)));
  await prisma.$transaction([
    prisma.wallet.update({ where: { id: wallet.id }, data: { balance: balanceAfter } }),
    prisma.walletTransaction.create({
      data: {
        walletId: wallet.id, type: coins > 0 ? 'BONUS' : 'CALL_DEDUCTION',
        amount: new Decimal(coins), balanceBefore, balanceAfter,
        description: `Admin adjustment: ${reason}`, refId: adminId,
      },
    }),
  ]);
  await logAdminAction(adminId, 'ADJUST_COINS', 'User', userId, { balance: balanceBefore }, { balance: balanceAfter, coins, reason });
};

const logAdminAction = async (adminId: string, action: string, targetType: string, targetId: string, oldVal: any, newVal: any) => {
  await prisma.adminLog.create({ data: { adminId, action, targetType, targetId, oldValue: oldVal, newValue: newVal } });
};
