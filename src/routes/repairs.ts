import { Router } from 'express';

import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { insertRepairs, getRepairYears } from '@helpers/repairs';
import { Usuario } from '@root/interfaces/sigt';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref } = req.query;
  const [err, data] = await fulfill(getRepairYears({ document: doc, reference: ref ? ref : null, docType: pref, user: req.user as Usuario }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/init', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(insertRepairs({ process: req.body, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
