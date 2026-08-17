import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as usersController from './users.controller';

const router = Router();

router.use(authenticate);

router.get('/me', usersController.getMe);
router.patch('/me', usersController.updateMe);
router.get('/wallet', usersController.getWallet);
router.post('/devices', usersController.addDevice);
router.delete('/account', usersController.deleteAccount);

export default router;
