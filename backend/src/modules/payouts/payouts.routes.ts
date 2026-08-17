import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as payoutsController from './payouts.controller';

const router = Router();
router.use(authenticate);
router.post('/request', payoutsController.requestPayout);
router.get('/', payoutsController.getPayouts);

export default router;
