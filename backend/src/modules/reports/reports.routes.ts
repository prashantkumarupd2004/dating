import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as reportsController from './reports.controller';

const router = Router();
router.use(authenticate);
router.post('/', reportsController.createReport);
router.get('/mine', reportsController.getMyReports);

export default router;
