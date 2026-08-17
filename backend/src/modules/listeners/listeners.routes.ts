import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { authenticate } from '../../middleware/auth';
import * as listenersController from './listeners.controller';

const router = Router();

const uploadDir = path.join(process.cwd(), 'uploads', 'voice-samples');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
});
const upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } });

router.use(authenticate);

router.post('/register', listenersController.registerAsListener);
router.get('/me', listenersController.getMyListener);
router.patch('/me', listenersController.updateMyListener);
router.patch('/status', listenersController.updateStatus);
router.post('/voice-verify', upload.single('audio'), listenersController.uploadVoiceSample);

export default router;
