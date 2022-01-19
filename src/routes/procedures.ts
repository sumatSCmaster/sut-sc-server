import { Router } from 'express';
import { getAvailableProcedures, procedureInit, getAvailableProceduresOfInstitution, updateProcedureCost, updateProcedureHandler, getProcedureCosts, approveAllLicenses, generateCertificate } from '@helpers/procedures';
import { validate, isOfficial, isExternalUser, isLogged, isAuth } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';

import { fulfill } from '@utils/resolver';

import instances from './procedureInstances';
import { createMockCertificate } from '@utils/forms';
import { setTracingTag, getUserIdFromReq } from '@utils/tracing';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  setTracingTag(`user.id`, getUserIdFromReq(req));
  const [error, data] = await fulfill(getAvailableProcedures(req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/sedemat/costs', async (req, res) => {
  const [error, data] = await fulfill(getProcedureCosts());
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
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

router.post('/init', validate(), checkResult, authenticate('jwt'), async (req: any, res) => {
  const { tramite } = req.body;
  mainLogger.error(`procedure/init start`);
  const [error, data] = await fulfill(procedureInit(tramite, req.user));
  mainLogger.error(`procedure/init error ${error?.message}`);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/license/approve', authenticate('jwt'), async (req: any, res) => {
  const { tramites } = req.body;
  const [error, data] = await fulfill(approveAllLicenses(tramites, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/certificate/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [error, data] = await fulfill(generateCertificate(id));
  if (error) res.status(500).json({ status: 500, error, message: 'Error al generar certificado' });
  if (data) res.status(data.status).json(data);
});

router.put('/update', validate(), checkResult, authenticate('jwt'), isAuth, async (req: any, res) => {
  const { tramite, idUsuario } = req.body;
  console.log(tramite, "tramite");
  const [error, data] = await fulfill(updateProcedureHandler(tramite, req.user, idUsuario));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/mockCertificate/:id', async (req: any, res) => {
  const { id } = req.params;
  const [error, data] = await fulfill(createMockCertificate(id));
  if (error) res.status(500).json(error);
  if (data)
    data.toBuffer(async (err, buffer) => {
      if (err) res.status(500).json({ status: 500, message: 'Error al procesar el pdf' });
      res.contentType('application/pdf').send(buffer);
    });
});

router.use('/instances', instances);

export default router;
