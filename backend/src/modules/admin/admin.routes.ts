import { Router } from 'express';
import { authenticateAdmin } from '../../middleware/auth';
import { login } from './admin.auth.controller';
import * as usersCtrl from './admin.users.controller';
import * as listenersCtrl from './admin.listeners.controller';
import * as callsCtrl from './admin.calls.controller';
import * as payoutsCtrl from './admin.payouts.controller';
import * as analyticsCtrl from './admin.analytics.controller';
import * as settingsCtrl from './admin.settings.controller';
import * as reportsCtrl from './admin.reports.controller';
import * as packagesCtrl from './admin.coin-packages.controller';
import * as notifCtrl from './admin.notifications.controller';
import * as supportCtrl from './admin.support.controller';

const router = Router();

// Auth — public
router.post('/login', login);

// All routes below require admin JWT
router.use(authenticateAdmin);

// Dashboard & analytics
router.get('/dashboard', analyticsCtrl.getDashboardStats);
router.get('/analytics/revenue', analyticsCtrl.getRevenueChart);
router.get('/analytics/calls', analyticsCtrl.getCallStats);
router.get('/audit-logs', analyticsCtrl.getAuditLogs);

// Users
router.get('/users', usersCtrl.listUsers);
router.get('/users/:id', usersCtrl.getUserDetail);
router.post('/users/:id/suspend', usersCtrl.suspendUser);
router.post('/users/:id/ban', usersCtrl.banUser);
router.post('/users/:id/unban', usersCtrl.unbanUser);
router.post('/users/:id/wallet/adjust', usersCtrl.adjustCoins);

// Listeners
router.get('/listeners', listenersCtrl.listListeners);
router.post('/listeners/:id/approve', listenersCtrl.approveListener);
router.post('/listeners/:id/reject', listenersCtrl.rejectListener);
router.post('/listeners/:id/suspend', listenersCtrl.suspendListener);
router.post('/listeners/:id/reactivate', listenersCtrl.reactivateListener);

// Calls
router.get('/calls', callsCtrl.listCalls);

// Payouts
router.get('/payouts', payoutsCtrl.listPayouts);
router.post('/payouts/:id/approve', payoutsCtrl.approvePayout);
router.post('/payouts/:id/reject', payoutsCtrl.rejectPayout);

// Settings
router.get('/settings', settingsCtrl.getAllSettings);
router.patch('/settings/:key', settingsCtrl.updateSetting);

// Reports
router.get('/reports', reportsCtrl.listReports);
router.patch('/reports/:id', reportsCtrl.updateReport);

// Coin packages
router.get('/coin-packages', packagesCtrl.listPackages);
router.post('/coin-packages', packagesCtrl.createPackage);
router.patch('/coin-packages/:id', packagesCtrl.updatePackage);
router.delete('/coin-packages/:id', packagesCtrl.deletePackage);

// Notifications
router.post('/notifications/broadcast', notifCtrl.sendBroadcast);

// Payments
router.get('/payments', async (req, res) => {
  const { prisma } = await import('../../config/database');
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = 20;
  const [payments, total] = await Promise.all([
    prisma.payment.findMany({
      skip: (page - 1) * limit, take: limit,
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { name: true, phone: true, email: true } }, coinPackage: { select: { name: true } } },
    }),
    prisma.payment.count(),
  ]);
  res.json({ success: true, data: { payments, total, page, totalPages: Math.ceil(total / limit) } });
});

// Support
router.get('/support/tickets', supportCtrl.listTickets);
router.post('/support/tickets/:id/reply', supportCtrl.replyToTicket);
router.patch('/support/tickets/:id/status', supportCtrl.updateTicketStatus);

export default router;
