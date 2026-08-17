import { Decimal } from '@prisma/client/runtime/library';
import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { createOrder as rzpCreateOrder, verifyPaymentSignature } from '../../services/razorpay.service';
import { v4 as uuid } from 'uuid';

export const createOrder = async (userId: string, coinPackageId: string) => {
  const pkg = await prisma.coinPackage.findUnique({ where: { id: coinPackageId } });
  if (!pkg || !pkg.isActive) throw new AppError(404, 'Coin package not found or inactive');

  const receipt = `rcpt_${uuid().replace(/-/g, '').slice(0, 16)}`;
  const amountInPaise = pkg.priceInr.mul(100).toNumber();

  const order = await rzpCreateOrder(amountInPaise, receipt);

  const payment = await prisma.payment.create({
    data: {
      userId,
      coinPackageId,
      razorpayOrderId: order.id as string,
      amount: pkg.priceInr,
      coins: pkg.coins,
      bonusCoins: pkg.bonusCoins,
      status: 'PENDING',
    },
  });

  return {
    orderId: order.id,
    amount: amountInPaise,
    currency: 'INR',
    paymentId: payment.id,
    coins: pkg.coins,
    bonusCoins: pkg.bonusCoins,
  };
};

export const verifyPayment = async (
  userId: string,
  razorpayOrderId: string,
  razorpayPaymentId: string,
  razorpaySignature: string
) => {
  const payment = await prisma.payment.findUnique({ where: { razorpayOrderId } });
  if (!payment) throw new AppError(404, 'Payment order not found');
  if (payment.userId !== userId) throw new AppError(403, 'Forbidden');
  if (payment.status === 'SUCCESS') return { alreadyProcessed: true };

  const isValid = verifyPaymentSignature(razorpayOrderId, razorpayPaymentId, razorpaySignature);
  if (!isValid) {
    await prisma.payment.update({
      where: { id: payment.id },
      data: { status: 'FAILED', failureReason: 'Invalid signature' },
    });
    throw new AppError(400, 'Payment verification failed');
  }

  const totalCoins = payment.coins + payment.bonusCoins;

  await prisma.$transaction(async (tx) => {
    await tx.payment.update({
      where: { id: payment.id },
      data: { status: 'SUCCESS', razorpayPaymentId, razorpaySignature },
    });

    const wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) throw new AppError(400, 'Wallet not found');

    const balanceBefore = wallet.balance;
    const balanceAfter = balanceBefore.add(new Decimal(totalCoins));

    await tx.wallet.update({ where: { id: wallet.id }, data: { balance: balanceAfter } });

    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        type: 'RECHARGE',
        amount: new Decimal(totalCoins),
        balanceBefore,
        balanceAfter,
        description: `Recharge — ${totalCoins} coins`,
        refId: payment.id,
        metadata: { razorpayPaymentId },
      },
    });
  });

  return { success: true, coinsAdded: totalCoins };
};
