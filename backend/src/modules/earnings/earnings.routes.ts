import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as earningsController from './earnings.controller';

const router = Router();
router.use(authenticate);
router.get('/summary', earningsController.getEarningsSummary);
router.get('/history', earningsController.getEarningsHistory);

export default router;
