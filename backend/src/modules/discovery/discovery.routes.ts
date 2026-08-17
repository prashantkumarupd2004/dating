import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as discoveryController from './discovery.controller';

const router = Router();

router.use(authenticate);

router.get('/', discoveryController.listListeners);
router.get('/:listenerId', discoveryController.getListenerDetail);

export default router;
