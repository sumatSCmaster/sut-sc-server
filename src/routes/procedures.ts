import { Router } from 'express';
import { getAvailableProcedures, procedureInit, getAvailableProceduresOfInstitution, updateProcedureCost, updateProcedureHandler } from '@helpers/procedures';
import { validate, isOfficial, isExternalUser, isLogged, isAuth } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';

import instances from './procedureInstances';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getAvailableProcedures(req.user));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/:id', authenticate('jwt'), isOfficial, async (req: any, res) => {
  const [error, data] = await fulfill(getAvailableProceduresOfInstitution(req));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.patch('/:id', authenticate('jwt'), isOfficial, async (req, res) => {
  const [error, data] = await fulfill(updateProcedureCost(req.params['id'], req.body.costo));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

router.post('/init', validate(), checkResult, authenticate('jwt'), isExternalUser, async (req: any, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(procedureInit(tramite, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/update', validate(), checkResult, authenticate('jwt'), isAuth, async (req: any, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(updateProcedureHandler(tramite));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.use('/instances', instances);

export default router;
