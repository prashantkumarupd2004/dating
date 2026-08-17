import * as admin from 'firebase-admin';
import { config } from '../config';
import { logger } from '../utils/logger';

let app: admin.app.App;

const getApp = (): admin.app.App => {
  if (!app) {
    app = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: config.firebase.projectId,
        clientEmail: config.firebase.clientEmail,
        privateKey: config.firebase.privateKey,
      }),
    });
  }
  return app;
};

export const verifyFirebaseToken = async (
  idToken: string
): Promise<{ uid: string; phone?: string; email?: string }> => {
  try {
    const decoded = await getApp().auth().verifyIdToken(idToken);
    return {
      uid: decoded.uid,
      phone: decoded.phone_number,
      email: decoded.email,
    };
  } catch (err) {
    logger.error('Firebase token verification failed', err);
    throw new Error('Invalid Firebase token');
  }
};

export const sendPushNotification = async (
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> => {
  try {
    await getApp().messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
  } catch (err) {
    logger.error(`Failed to send push to ${fcmToken}`, err);
  }
};

export const sendMulticastNotification = async (
  fcmTokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> => {
  if (!fcmTokens.length) return;
  try {
    const chunks: string[][] = [];
    for (let i = 0; i < fcmTokens.length; i += 500) {
      chunks.push(fcmTokens.slice(i, i + 500));
    }
    await Promise.all(
      chunks.map((tokens) =>
        getApp().messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: data || {},
          android: {
            priority: 'high',
            notification: { sound: 'default', channelId: 'default' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        })
      )
    );
  } catch (err) {
    logger.error('Multicast notification failed', err);
  }
};
