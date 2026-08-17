import { Response } from 'express';
import { AdminRequest } from '../../middleware/auth';
import { prisma } from '../../config/database';
import { sendSuccess } from '../../utils/response';
import { sendMulticastNotification, sendPushNotification } from '../../services/firebase.service';

export const sendBroadcast = async (req: AdminRequest, res: Response): Promise<void> => {
  const { title, body, target, targetId, data } = req.body;

  let tokens: string[] = [];

  if (target === 'all_users') {
    const devices = await prisma.device.findMany({ where: { userId: { not: null } }, select: { fcmToken: true } });
    tokens = devices.map((d) => d.fcmToken);
  } else if (target === 'all_listeners') {
    const devices = await prisma.device.findMany({ where: { listenerId: { not: null } }, select: { fcmToken: true } });
    tokens = devices.map((d) => d.fcmToken);
  } else if (target === 'user' && targetId) {
    const devices = await prisma.device.findMany({ where: { userId: targetId }, select: { fcmToken: true } });
    tokens = devices.map((d) => d.fcmToken);
  } else if (target === 'listener' && targetId) {
    const devices = await prisma.device.findMany({ where: { listenerId: targetId }, select: { fcmToken: true } });
    tokens = devices.map((d) => d.fcmToken);
  }

  if (tokens.length === 0) { sendSuccess(res, { sent: 0 }, 'No devices found'); return; }

  if (tokens.length === 1) {
    await sendPushNotification(tokens[0], title, body, data);
  } else {
    await sendMulticastNotification(tokens, title, body, data);
  }

  await prisma.adminLog.create({
    data: { adminId: req.adminId!, action: 'SEND_NOTIFICATION', targetType: target, targetId: targetId ?? null, newValue: { title, body, recipients: tokens.length } },
  });

  sendSuccess(res, { sent: tokens.length }, 'Notifications sent');
};
