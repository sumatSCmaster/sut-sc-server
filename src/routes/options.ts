import { Router } from 'express';
import { validate, isOfficial, isExternalUser, isLogged, isAuth } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';

import { fulfill } from '@utils/resolver';
import { getMenu } from '@helpers/options';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getMenu(req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json({ status: 200, options: data });
});

export default router;
