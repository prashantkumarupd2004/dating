import { Decimal } from '@prisma/client/runtime/library';
import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';

export const requestPayout = async (
  listenerId: string,
  amount: number,
  method: string,
  accountDetails: Record<string, unknown>
) => {
  const minPayoutSetting = await prisma.setting.findUnique({ where: { key: 'min_payout_amount' } });
  const minPayout = parseFloat(minPayoutSetting?.value ?? '500');

  if (amount < minPayout) {
    throw new AppError(400, `Minimum payout amount is ₹${minPayout}`);
  }

  const wallet = await prisma.listenerWallet.findUnique({ where: { listenerId } });
  if (!wallet) throw new AppError(404, 'Wallet not found');

  const amountDecimal = new Decimal(amount);
  if (amountDecimal.greaterThan(wallet.availableBalance)) {
    throw new AppError(400, 'Insufficient available balance');
  }

  const payout = await prisma.$transaction(async (tx) => {
    const created = await tx.payout.create({
      data: {
        listenerId,
        amount: amountDecimal,
        status: 'REQUESTED',
        payoutMethod: method,
        accountDetails: accountDetails as any,
      },
    });

    await tx.listenerWallet.update({
      where: { listenerId },
      data: {
        availableBalance: { decrement: amountDecimal },
        pendingBalance: { increment: amountDecimal },
      },
    });

    return created;
  });

  return payout;
};

export const getPayouts = async (listenerId: string, filters: { page?: number; limit?: number }) => {
  const { page, limit, skip } = getPagination(filters);
  const [payouts, total] = await Promise.all([
    prisma.payout.findMany({
      where: { listenerId },
      include: { transactions: { orderBy: { createdAt: 'desc' }, take: 1 } },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.payout.count({ where: { listenerId } }),
  ]);
  return { data: payouts, meta: buildMeta(total, page, limit) };
};
