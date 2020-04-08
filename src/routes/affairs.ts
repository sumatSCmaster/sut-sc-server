import { Router } from 'express';
import { isOfficialAdmin, createSocialCase } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';

import { affairInit, updateAffair } from '@helpers/affairs';

const router = Router();

router.post('/init', createSocialCase, checkResult, authenticate('jwt'), isOfficialAdmin, async (req: any, res) => {
  const { caso } = req.body;
  const [error, data] = await fulfill(affairInit(caso, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/update', authenticate('jwt'), isOfficialAdmin, async (req: any, res) => {
  const { caso } = req.body;
  const [error, data] = await fulfill(updateAffair(caso, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
