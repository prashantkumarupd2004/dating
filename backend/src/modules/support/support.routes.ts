import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as ctrl from './support.controller';

const router = Router();

router.use(authenticate);
router.post('/', ctrl.createTicket);
router.get('/', ctrl.getTickets);
router.get('/:id', ctrl.getTicket);
router.post('/:id/reply', ctrl.replyToTicket);

export default router;
