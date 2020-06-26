import { Router } from 'express';
import auth from './auth';
import official from './officials';
import notification from './notification';
import banks from './banks';
import file from './file';
import procedures from './procedures';
import affairs from './affairs';
import resources from './resources';
import validateDoc from './validateDoc';
import estates from './estates';
import taxValues from './taxValues';
import ordinance from './ordinance';
import values from './values';
import fines from './fines';
import settlement from './settlement';
import statistics from './statistics';
import user from './user';
import destination from './terminal';
import holiday from './holidays';
import branches from './branches';
import exonerations from './exonerations';
import activities from './activities';

const router = Router();

router.use('/auth', auth);
router.use('/banks', banks);
router.use('/official', official);
router.use('/procedures', procedures);
router.use('/uploads', file);
router.use('/validateDoc', validateDoc);
router.use('/affairs', affairs);
router.use('/estates', estates);
router.use('/ordinance', ordinance);
router.use('/values', values);
router.use('/taxValues', taxValues);
router.use('/user', user);
router.use('/destination', destination);
router.use('/stats', statistics);
router.use('/fines', fines);
router.use('/notification', notification);
router.use('/settlements', settlement);
router.use('/holiday', holiday);
router.use('/branches', branches);
router.use('/exonerations', exonerations);
router.use('/activities', activities);
router.use(resources);

router.get('/', (req, res) => {
  res.status(200).json({
    status: 200,
    message: 'Ok',
  });
});

export default router;
