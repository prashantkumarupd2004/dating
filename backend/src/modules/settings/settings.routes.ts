import { Router } from 'express';
import { getAppSettings } from './settings.controller';

const router = Router();
router.get('/', getAppSettings);
export default router;
