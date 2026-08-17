import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';
import { sendPushNotification } from '../../services/firebase.service';
import { Decimal } from '@prisma/client/runtime/library';

export const listPayouts = async (query: any) => {
  const { page, limit, skip } = getPagination(query);
  const where: any = {};
  if (query.status) where.status = query.status;

  const [payouts, total] = await Promise.all([
    prisma.payout.findMany({
      where, skip, take: limit, orderBy: { createdAt: 'desc' },
      include: { listener: { include: { profile: { select: { displayName: true } } } } },
    }),
    prisma.payout.count({ where }),
  ]);
  return { payouts, meta: buildMeta(total, page, limit) };
};

export const approvePayout = async (adminId: string, payoutId: string, notes?: string) => {
  const payout = await prisma.payout.findUnique({
    where: { id: payoutId },
    include: { listener: { include: { user: { include: { devices: true } } } } },
  });
  if (!payout) throw new AppError(404, 'Payout not found');
  if (payout.status !== 'REQUESTED' && payout.status !== 'UNDER_REVIEW')
    throw new AppError(400, 'Payout cannot be approved in current status');

  await prisma.$transaction([
    prisma.payout.update({
      where: { id: payoutId },
      data: { status: 'APPROVED', adminId, adminNotes: notes, processedAt: new Date() },
    }),
    prisma.payoutTransaction.create({ data: { payoutId, status: 'APPROVED', notes } }),
    prisma.listenerWallet.update({
      where: { listenerId: payout.listenerId },
      data: {
        totalWithdrawn: { increment: payout.amount },
        pendingBalance: { decrement: payout.amount },
      },
    }),
  ]);

  await prisma.adminLog.create({
    data: { adminId, action: 'APPROVE_PAYOUT', targetType: 'Payout', targetId: payoutId, newValue: { amount: payout.amount.toString(), notes } },
  });

  for (const device of payout.listener.user.devices) {
    await sendPushNotification(device.fcmToken, 'Payout Approved', `Your payout of ₹${payout.amount} has been approved.`).catch(() => {});
  }
};

export const rejectPayout = async (adminId: string, payoutId: string, reason: string) => {
  const payout = await prisma.payout.findUnique({
    where: { id: payoutId },
    include: { listener: { include: { user: { include: { devices: true } } } } },
  });
  if (!payout) throw new AppError(404, 'Payout not found');

  await prisma.$transaction([
    prisma.payout.update({ where: { id: payoutId }, data: { status: 'REJECTED', adminId, adminNotes: reason } }),
    prisma.payoutTransaction.create({ data: { payoutId, status: 'REJECTED', notes: reason } }),
    prisma.listenerWallet.update({
      where: { listenerId: payout.listenerId },
      data: { pendingBalance: { decrement: payout.amount }, availableBalance: { increment: payout.amount } },
    }),
  ]);

  await prisma.adminLog.create({
    data: { adminId, action: 'REJECT_PAYOUT', targetType: 'Payout', targetId: payoutId, newValue: { reason } },
  });

  for (const device of payout.listener.user.devices) {
    await sendPushNotification(device.fcmToken, 'Payout Rejected', `Your payout request was rejected: ${reason}`).catch(() => {});
  }
};
