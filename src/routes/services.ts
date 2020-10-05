import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getMunicipalServicesByContributor, updateGasStateForEstate, updateGasTariffScales, getServicesTariffScales, createMunicipalServicesScale, getSettlementsByDepartment } from '@helpers/services';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const [error, data] = await fulfill(getMunicipalServicesByContributor({ reference: referencia, document: documento, docType: tipoDocumento }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/gas', authenticate('jwt'), async (req, res) => {
  const { inmuebles } = req.body;
  const [error, data] = await fulfill(updateGasStateForEstate({ estates: inmuebles }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/scales', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getServicesTariffScales());
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/settlements/:type', authenticate('jwt'), async (req, res) => {
  const { type } = req.params;
  const { date } = req.query;
  const [error, data] = await fulfill(getSettlementsByDepartment(type, date));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/scales/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { indicador } = req.body;
  const [error, data] = await fulfill(updateGasTariffScales(id, indicador));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

// router.post('/scales', authenticate('jwt'), async (req, res) => {
//   const { descripcion, indicador } = req.body;
//   const [error, data] = await fulfill(createMunicipalServicesScale({ description: descripcion, tariff: indicador }));
//   if (error) res.status(500).json(error);
//   if (data) res.status(data.status).json(data);
// });

export default router;
