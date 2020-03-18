import { Router } from 'express';
import auth from './auth';
import official from './officials';
//import notification from "./notification";
import banks from './banks';
import file from './file';
import procedures from './procedures';
import affairs from './affairs';
import resources from './resources';
import validateDoc from './validateDoc';
import estates from './estates';
import ordinance from './ordinance';

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
router.use(resources);
//router.use("/notification", notification);

router.get('/', (req, res) => {
  res.status(200).json({
    status: 200,
    message: 'Ok',
  });
});

export default router;
