import { Router } from 'express';

import { fulfill } from '@utils/resolver';
import { processRetentionFile, getRetentionMonths, insertRetentions, getRetentionAgents, updateRetentionAgentStatus } from '@helpers/retention';
import { authenticate } from 'passport';
import { Usuario } from '@root/interfaces/sigt';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref } = req.query;
  const [err, data] = await fulfill(getRetentionMonths({ document: doc, reference: ref ? ref : null, docType: pref, user: req.user as Usuario }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/agents', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getRetentionAgents());
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/init', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(insertRetentions({ process: req.body, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/agent', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(insertRetentions({ process: req.body, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/agent/:id', authenticate('jwt'), async (req, res) => {
  const { status } = req.body;
  const { id } = req.params;
  const [error, data] = await fulfill(updateRetentionAgentStatus({ id, status }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/report/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(processRetentionFile(req.file));
  console.log(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
