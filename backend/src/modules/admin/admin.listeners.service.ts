import { prisma } from '../../config/database';
import { AppError } from '../../middleware/errorHandler';
import { getPagination, buildMeta } from '../../utils/pagination';
import { sendPushNotification } from '../../services/firebase.service';

export const listListeners = async (query: any) => {
  const { page, limit, skip } = getPagination(query);
  const where: any = {};
  if (query.status) where.status = query.status;
  if (query.search) where.profile = { displayName: { contains: query.search, mode: 'insensitive' } };

  const [listeners, total] = await Promise.all([
    prisma.listener.findMany({
      where, skip, take: limit, orderBy: { createdAt: 'desc' },
      include: {
        profile: true,
        user: { select: { name: true, email: true, phone: true } },
        wallet: true,
        documents: { where: { type: 'VOICE_SAMPLE' }, orderBy: { createdAt: 'desc' }, take: 1 },
      },
    }),
    prisma.listener.count({ where }),
  ]);
  return { listeners, meta: buildMeta(total, page, limit) };
};


export const approveListener = async (adminId: string, listenerId: string, notes?: string) => {
  const listener = await prisma.listener.findUnique({
    where: { id: listenerId },
    include: { user: { include: { devices: true } } },
  });
  if (!listener) throw new AppError(404, 'Listener not found');

  await prisma.listener.update({
    where: { id: listenerId },
    data: { status: 'APPROVED', adminNotes: notes, approvedAt: new Date() },
  });

  await prisma.adminLog.create({
    data: { adminId, action: 'APPROVE_LISTENER', targetType: 'Listener', targetId: listenerId, newValue: { notes } },
  });

  for (const device of listener.user.devices) {
    await sendPushNotification(device.fcmToken, 'Application Approved!', 'Your listener account has been approved. Go online and start earning!').catch(() => {});
  }
};

export const rejectListener = async (adminId: string, listenerId: string, reason: string) => {
  const listener = await prisma.listener.findUnique({
    where: { id: listenerId },
    include: { user: { include: { devices: true } } },
  });
  if (!listener) throw new AppError(404, 'Listener not found');

  await prisma.listener.update({
    where: { id: listenerId },
    data: { status: 'REJECTED', rejectionReason: reason },
  });

  await prisma.adminLog.create({
    data: { adminId, action: 'REJECT_LISTENER', targetType: 'Listener', targetId: listenerId, newValue: { reason } },
  });

  for (const device of listener.user.devices) {
    await sendPushNotification(device.fcmToken, 'Application Update', `Your application was not approved: ${reason}`).catch(() => {});
  }
};

export const suspendListener = async (adminId: string, listenerId: string, reason: string) => {
  await prisma.listener.update({
    where: { id: listenerId },
    data: { status: 'SUSPENDED', suspendedAt: new Date(), suspendedReason: reason, onlineStatus: 'OFFLINE' },
  });
  await prisma.adminLog.create({
    data: { adminId, action: 'SUSPEND_LISTENER', targetType: 'Listener', targetId: listenerId, newValue: { reason } },
  });
};

export const reactivateListener = async (adminId: string, listenerId: string) => {
  await prisma.listener.update({ where: { id: listenerId }, data: { status: 'APPROVED', suspendedAt: null, suspendedReason: null } });
  await prisma.adminLog.create({ data: { adminId, action: 'REACTIVATE_LISTENER', targetType: 'Listener', targetId: listenerId, newValue: {} } });
};

export const getPendingCount = async () => prisma.listener.count({ where: { status: 'PENDING' } });
