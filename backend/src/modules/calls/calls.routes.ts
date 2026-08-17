import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import * as callsController from './calls.controller';

const router = Router();

router.use(authenticate);

router.post('/initiate', callsController.initiateCall);
router.post('/:callId/accept', callsController.acceptCall);
router.post('/:callId/end', callsController.endCall);
router.post('/:callId/reject', callsController.rejectCall);
router.post('/:callId/rate', callsController.rateCall);
router.get('/history', callsController.getCallHistory);

export default router;
