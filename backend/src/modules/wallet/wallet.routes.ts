import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as walletController from './wallet.controller';

const router = Router();
router.use(authenticate);
router.get('/', walletController.getWallet);
router.get('/transactions', walletController.getTransactions);
router.get('/packages', walletController.getCoinPackages);

export default router;
