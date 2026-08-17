import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import path from 'path';
import { config } from './config';
import { errorHandler } from './middleware/errorHandler';
import { defaultLimiter } from './middleware/rateLimiter';

import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/users/users.routes';
import listenerRoutes from './modules/listeners/listeners.routes';
import callRoutes from './modules/calls/calls.routes';
import walletRoutes from './modules/wallet/wallet.routes';
import paymentRoutes from './modules/payments/payments.routes';
import earningRoutes from './modules/earnings/earnings.routes';
import payoutRoutes from './modules/payouts/payouts.routes';
import discoveryRoutes from './modules/discovery/discovery.routes';
import reportRoutes from './modules/reports/reports.routes';
import notificationRoutes from './modules/notifications/notifications.routes';
import supportRoutes from './modules/support/support.routes';
import adminRoutes from './modules/admin/admin.routes';
import settingsRoutes from './modules/settings/settings.routes';

const app = express();

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' }, // allow audio/media cross-origin
}));
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);
    // Allow configured origins
    if (config.allowedOrigins.includes(origin)) return callback(null, true);
    // Allow any origin in development
    if (config.env !== 'production') return callback(null, true);
    callback(null, true); // Allow all for now — tighten in production
  },
  credentials: true,
}));
app.use(morgan(config.env === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
// Serve uploads with cross-origin headers so admin browser can play audio
app.use('/uploads', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(path.join(process.cwd(), 'uploads')));
app.use(defaultLimiter);

app.get('/health', (_req, res) => res.json({ status: 'ok', env: config.env }));

app.get('/', (_req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Milan API</title>
      <style>
        body { font-family: sans-serif; background: #0f0f1a; color: #e0e0e0; padding: 40px; }
        h1 { color: #ff6b9d; } h2 { color: #a78bfa; border-bottom: 1px solid #333; padding-bottom: 6px; }
        .badge { background: #1e1e2e; border: 1px solid #333; border-radius: 6px; padding: 4px 10px; font-size: 13px; }
        .ok { color: #4ade80; } .route { color: #60a5fa; font-family: monospace; }
        ul { line-height: 2; } a { color: #f472b6; }
      </style>
    </head>
    <body>
      <h1>💕 Milan API Server</h1>
      <p class="badge">Status: <span class="ok">● Running</span> &nbsp;|&nbsp; Env: <b>${config.env}</b> &nbsp;|&nbsp; Port: <b>${config.port}</b></p>
      <h2>Available Routes</h2>
      <ul>
        <li><span class="route">GET  /health</span> — Health check</li>
        <li><span class="route">POST /api/auth/google</span> — Google Sign-In</li>
        <li><span class="route">GET  /api/listeners</span> — Browse listeners</li>
        <li><span class="route">POST /api/calls/initiate</span> — Start a call</li>
        <li><span class="route">GET  /api/wallet/balance</span> — Wallet balance</li>
        <li><span class="route">POST /api/payments/create-order</span> — Recharge</li>
        <li><span class="route">GET  /api/admin/*</span> — Admin panel APIs</li>
      </ul>
      <p><a href="/health">/health</a> endpoint check karo server status ke liye.</p>
    </body>
    </html>
  `);
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/listeners', listenerRoutes);
app.use('/api/calls', callRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/earnings', earningRoutes);
app.use('/api/payouts', payoutRoutes);
app.use('/api/discovery', discoveryRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/settings', settingsRoutes);

app.use(errorHandler);

export default app;
