import { Decimal } from '@prisma/client/runtime/library';
import { prisma } from '../config/database';
import { config } from '../config';
import { logger } from '../utils/logger';

export const processCallBilling = async (callId: string): Promise<void> => {
  await prisma.$transaction(
    async (tx) => {
      // 1. Fetch call with billing and user wallet
      const call = await tx.call.findUnique({
        where: { id: callId },
        include: {
          billing: true,
          user: { include: { wallet: true } },
        },
      });

      if (!call) throw new Error(`Call ${callId} not found`);
      if (!call.user.wallet) throw new Error(`Wallet not found for user ${call.userId}`);

      // 2. Idempotency guard
      if (call.billing?.isProcessed) {
        logger.info(`Billing already processed for call ${callId}`);
        return;
      }

      // 3. Lock the wallet row to prevent concurrent billing race conditions
      // Prisma doesn't support SELECT FOR UPDATE, so we use a raw query
      await tx.$executeRaw`SELECT * FROM "Wallet" WHERE "id" = ${call.user.wallet.id} FOR UPDATE`;

      // Re-fetch wallet after locking to get the latest balance
      const lockedWallet = await tx.wallet.findUnique({ where: { id: call.user.wallet.id } });
      if (!lockedWallet) throw new Error(`Wallet not found after lock`);

      const durationSeconds = call.durationSeconds ?? 0;
      const ratePerMinute = call.billing?.ratePerMinute ?? 0;

      // 4. Calculate coins deducted (Decimal, 4dp)
      const rawCoins = new Decimal(durationSeconds)
        .mul(new Decimal(ratePerMinute))
        .div(new Decimal(60));

      const walletBalance = lockedWallet.balance;

      // 5. Clamp to wallet balance
      const coinsDeducted = rawCoins.greaterThan(walletBalance) ? walletBalance : rawCoins;
      const coinsDecimal = coinsDeducted.toDecimalPlaces(4);

      const balanceBefore = walletBalance;
      const balanceAfter = walletBalance.minus(coinsDecimal);

      // 5. Update wallet balance
      await tx.wallet.update({
        where: { id: call.user.wallet.id },
        data: { balance: balanceAfter },
      });

      // 6. Create WalletTransaction (CALL_DEDUCTION)
      await tx.walletTransaction.create({
        data: {
          walletId: call.user.wallet.id,
          type: 'CALL_DEDUCTION',
          amount: coinsDecimal,
          balanceBefore,
          balanceAfter,
          description: `Call deduction for call ${callId}`,
          refId: callId,
        },
      });

      // 7. Upsert CallBilling
      if (call.billing) {
        await tx.callBilling.update({
          where: { callId },
          data: {
            coinsDeducted: coinsDecimal,
            isProcessed: true,
            processedAt: new Date(),
          },
        });
      } else {
        await tx.callBilling.create({
          data: {
            callId,
            ratePerMinute,
            coinsDeducted: coinsDecimal,
            isProcessed: true,
            processedAt: new Date(),
          },
        });
      }

      // 8. Fetch platform_commission_rate from Setting table
      const commissionSetting = await tx.setting.findUnique({
        where: { key: 'platform_commission_rate' },
      });
      const commissionRate = new Decimal(commissionSetting?.value ?? '30');

      // 9. Platform cut and listener share
      const platformCut = coinsDecimal.mul(commissionRate).div(100).toDecimalPlaces(4);
      const listenerShare = coinsDecimal.minus(platformCut);

      // 10. Listener amount in INR
      const coinToInrRate = new Decimal(config.coinToInrRate);
      const listenerAmountInr = listenerShare.mul(coinToInrRate).toDecimalPlaces(2);

      // 11. Upsert Earning record
      const existingEarning = await tx.earning.findUnique({ where: { callId } });
      if (existingEarning) {
        await tx.earning.update({
          where: { callId },
          data: {
            grossCoins: coinsDecimal,
            commissionRate,
            platformCut,
            listenerAmount: listenerAmountInr,
            coinToInrRate,
            status: 'AVAILABLE',
          },
        });
      } else {
        await tx.earning.create({
          data: {
            listenerId: call.listenerId,
            callId,
            grossCoins: coinsDecimal,
            commissionRate,
            platformCut,
            listenerAmount: listenerAmountInr,
            coinToInrRate,
            status: 'AVAILABLE',
          },
        });
      }

      // 12. Increment ListenerWallet
      await tx.listenerWallet.upsert({
        where: { listenerId: call.listenerId },
        update: {
          availableBalance: { increment: listenerAmountInr },
          totalEarned: { increment: listenerAmountInr },
        },
        create: {
          listenerId: call.listenerId,
          availableBalance: listenerAmountInr,
          totalEarned: listenerAmountInr,
        },
      });

      logger.info(`Billing processed for call ${callId}: ${coinsDecimal} coins deducted`);
    },
    { isolationLevel: 'Serializable' }
  );
};

export const checkSufficientBalance = async (
  userId: string,
  callType: 'AUDIO' | 'VIDEO'
): Promise<{
  sufficient: boolean;
  balance: Decimal;
  ratePerMinute: number;
  estimatedMinutes: number;
}> => {
  const rateKey = callType === 'AUDIO' ? 'audio_rate' : 'video_rate';

  const [wallet, rateSetting] = await Promise.all([
    prisma.wallet.findUnique({ where: { userId } }),
    prisma.setting.findUnique({ where: { key: rateKey } }),
  ]);

  const balance = wallet?.balance ?? new Decimal(0);

  // Read rate from settings table; fall back to hardcoded defaults if not configured
  const defaultRate = callType === 'AUDIO' ? 10 : 60;
  const ratePerMinute = rateSetting?.value
    ? parseInt(rateSetting.value, 10) || defaultRate
    : defaultRate;

  // User needs coins for at least 1 minute to start a call
  const sufficient = balance.greaterThanOrEqualTo(new Decimal(ratePerMinute));
  const estimatedMinutes = ratePerMinute > 0
    ? Math.floor(balance.div(new Decimal(ratePerMinute)).toNumber())
    : 0;

  return { sufficient, balance, ratePerMinute, estimatedMinutes };
};
