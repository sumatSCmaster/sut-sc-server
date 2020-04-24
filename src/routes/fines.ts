import { Router } from 'express';
import { validate, isOfficial, isExternalUser, isAuth } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';

import { fulfill } from '@utils/resolver';
import { updateFiningHandler, finingInit } from '@helpers/fines';

const router = Router();

router.post('/init', /*validate(), checkResult, */ authenticate('jwt'), isOfficial, async (req: any, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(finingInit(tramite, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/update', /* validate(), checkResult, */ authenticate('jwt'), isAuth, async (req: any, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(updateFiningHandler(tramite, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
