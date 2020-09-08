import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getStats, getStatsSedemat, getStatsSedematWithDate, bsByBranchInterval } from '@helpers/statistics';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getStats(req.user));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedemat({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/:date', async (req: any, res) => {
  const { date } = req.params;
  const [err, data] = await fulfill(getStatsSedematWithDate({ institution: req.user?.institucion?.id, date }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/branch/bs', async (req: any, res) => {
  const { fechaInicio: startingDate, fechaFin: endingDate } = req.query;
  const [err, data] = await fulfill(bsByBranchInterval({ institution: req.user?.institucion?.id, startingDate, endingDate }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
