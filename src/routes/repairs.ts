import { Router } from 'express';

import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { insertRepairs } from '@helpers/repairs';

const router = Router();

router.post('/init', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(insertRepairs({ process: req.body, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
