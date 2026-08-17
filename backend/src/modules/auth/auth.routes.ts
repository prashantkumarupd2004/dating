import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as authController from './auth.controller';

const router = Router();

router.post('/google', authController.googleLogin);
router.post('/register', authenticate, authController.register);
router.post('/refresh', authController.refreshToken);
router.post('/logout', authController.logout);

export default router;
