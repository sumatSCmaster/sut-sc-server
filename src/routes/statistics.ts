import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getStats, getStatsSedematWithDate, bsByBranchInterval, getStatsSedematTotal, getStatsSedematSettlements, getStatsSedematTop, getStatsSedematGraphs, getStatsSedemat, getContributorsStatistics } from '@helpers/statistics';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getStats(req.user));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/top', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedematTop({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/total', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedematTotal({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/graphs', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedematGraphs({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/settlements', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedematSettlements({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat', async (req: any, res) => {
  const [err, data] = await fulfill(getStatsSedemat({ institution: req.user?.institucion?.id }));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sedemat/contributors', async (req, res) => {
  const { date } = req.query;
  mainLogger.info(date, req.query, "req.query");
  console.log(req.params, "params");
  const [err, data] = await fulfill(getContributorsStatistics(date));
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
