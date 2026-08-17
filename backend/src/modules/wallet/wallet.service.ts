import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';

export const getWallet = async (userId: string) => {
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
    include: {
      transactions: {
        orderBy: { createdAt: 'desc' },
        take: 10,
      },
    },
  });
  if (!wallet) throw new AppError(404, 'Wallet not found');

  // Convert Prisma Decimal to number so Flutter gets numeric value (not string)
  return {
    ...wallet,
    balance: parseFloat(wallet.balance.toString()),
    transactions: wallet.transactions.map((tx) => ({
      ...tx,
      amount: parseFloat(tx.amount.toString()),
    })),
  };
};


export const getTransactions = async (
  userId: string,
  filters: { page?: number; limit?: number; type?: string }
) => {
  const { page, limit, skip } = getPagination(filters);
  const wallet = await prisma.wallet.findUnique({ where: { userId } });
  if (!wallet) throw new AppError(404, 'Wallet not found');

  const where: any = { walletId: wallet.id };
  if (filters.type) where.type = filters.type;

  const [transactions, total] = await Promise.all([
    prisma.walletTransaction.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.walletTransaction.count({ where }),
  ]);

  return { data: transactions, meta: buildMeta(total, page, limit) };
};

export const getCoinPackages = async () => {
  const packages = await prisma.coinPackage.findMany({
    where: { isActive: true },
    orderBy: { sortOrder: 'asc' },
  });
  return packages.map((p) => ({
    ...p,
    priceInr: parseFloat(p.priceInr.toString()),
    originalPriceInr: p.originalPriceInr ? parseFloat(p.originalPriceInr.toString()) : null,
  }));
};
