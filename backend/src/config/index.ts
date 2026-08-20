import dotenv from 'dotenv';
dotenv.config();

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '5000', 10),
  databaseUrl: process.env.DATABASE_URL!,
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET!,
    refreshSecret: process.env.JWT_REFRESH_SECRET!,
    adminSecret: process.env.JWT_ADMIN_SECRET || process.env.JWT_ACCESS_SECRET!,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '2h',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID!,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL!,
    privateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  },
  agora: {
    appId: process.env.AGORA_APP_ID!,
    appCertificate: process.env.AGORA_APP_CERTIFICATE!,
  },
  razorpay: {
    keyId: process.env.RAZORPAY_KEY_ID!,
    keySecret: process.env.RAZORPAY_KEY_SECRET!,
  },
  coinToInrRate: (() => {
    const v = parseFloat(process.env.COIN_TO_INR_RATE || '0.10');
    if (isNaN(v)) throw new Error('COIN_TO_INR_RATE must be a valid number');
    return v;
  })(),
  allowedOrigins: (process.env.ALLOWED_ORIGINS || 'http://localhost:3000').split(','),
  uploadBaseUrl: process.env.UPLOAD_BASE_URL || 'http://localhost:5000/uploads',
  call: {
    // How often (ms) Flutter clients POST a heartbeat while call is active.
    // Flutter sends every 12s; backend expects a beat within participantTimeoutMs.
    heartbeatIntervalMs: parseInt(process.env.CALL_HEARTBEAT_INTERVAL_MS || '12000', 10),
    // Grace period after last heartbeat before backend treats participant as gone.
    // Must be > heartbeatIntervalMs to tolerate brief network blips.
    participantTimeoutMs: parseInt(process.env.CALL_PARTICIPANT_TIMEOUT_MS || '45000', 10),
    // How often the server-side watchdog scans for orphaned IN_PROGRESS calls.
    watchdogIntervalMs: parseInt(process.env.CALL_WATCHDOG_INTERVAL_MS || '15000', 10),
  },
};
