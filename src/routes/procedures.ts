import { Router } from 'express';
import { getAvailableProcedures, procedureInit, getAvailableProceduresOfInstitution, updateProcedureCost, updateProcedure } from '@helpers/procedures';
import { validate, isOfficial } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';

import instances from './procedureInstances';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getAvailableProcedures());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

router.get('/:id', isOfficial, authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getAvailableProceduresOfInstitution(req.params['id']));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

router.patch('/:id', isOfficial, authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(updateProcedureCost(req.params['id'], req.body.costo));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

router.post('/init', validate(), checkResult, authenticate('jwt'), async (req: any, res) => {
  const { id } = req.user;
  const { tramite } = req.body;
  const [error, data] = await fulfill(procedureInit(tramite, id));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.use('/instances', instances);

//TODO: refactorizar en la medida de lo posible.
router.put('/update', isOfficial, validate(), checkResult, authenticate('jwt'), async (req: any, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(updateProcedure(tramite));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
