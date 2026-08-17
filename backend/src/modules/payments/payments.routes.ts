import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as paymentsController from './payments.controller';

const router = Router();
router.use(authenticate);
router.post('/create-order', paymentsController.createOrder);
router.post('/verify', paymentsController.verifyPayment);

export default router;
