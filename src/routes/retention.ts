import { Router } from 'express';

import { fulfill } from '@utils/resolver';
import { processRetentionFile, getRetentionMonths } from '@helpers/retention';
import { authenticate } from 'passport';
import { Usuario } from '@root/interfaces/sigt';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref } = req.query;
  const [err, data] = await fulfill(getRetentionMonths({ document: doc, reference: ref ? ref : null, docType: pref, user: req.user as Usuario }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/report/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(processRetentionFile(req.file));
  console.log(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
