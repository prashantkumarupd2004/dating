import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as notificationsController from './notifications.controller';

const router = Router();
router.use(authenticate);
router.get('/', notificationsController.getNotifications);
router.patch('/:id/read', notificationsController.markAsRead);
router.patch('/read-all', notificationsController.markAllRead);

export default router;
