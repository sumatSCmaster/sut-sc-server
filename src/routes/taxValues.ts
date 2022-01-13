import { Router } from 'express';
import { fulfill } from '@utils/resolver';
// import { authenticate } from 'passport';
import { getDataForTaxValues, getTaxValuesToDate, updateConstructionValuesByFactor, updateConstructionValuesByModel, updateGroundValuesByFactor, updateGroundValuesBySector } from '@helpers/taxValues';

const router = Router();

router.get('/resources', async (req: any, res) => {
  const [err, data] = await fulfill(getDataForTaxValues());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/present', async (req: any, res) => {
  const [err, data] = await fulfill(getTaxValuesToDate());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.patch('/constructions', async (req: any, res) => {
  const { activo } = req.body;
  const [err, data] = await fulfill(updateConstructionValuesByFactor(activo));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.patch('/constructions/:model', async (req: any, res) => {
  const { activo } = req.body;
  const { model } = req.params;
  const [err, data] = await fulfill(updateConstructionValuesByModel(activo, model));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.patch('/grounds', async (req: any, res) => {
  const { activo } = req.body;
  const [err, data] = await fulfill(updateGroundValuesByFactor(activo));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.patch('/grounds/:sector', async (req: any, res) => {
  const { activo } = req.body;
  const { sector } = req.params;
  const { year } = req.query;
  const [err, data] = await fulfill(updateGroundValuesBySector(activo, sector, year));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
