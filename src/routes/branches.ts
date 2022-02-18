import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateBranchesReport, generateBranchesReportById, getBranches, getTransfersReport, getCondoReport, getTransfersReportBank, getCondoReportDisclosed } from '@helpers/branches';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getBranches());
  mainLogger.info(`${error?.message} ${error?.stack}`);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;

  const [error, data] = await fulfill(generateBranchesReportById(id));
  mainLogger.info(`${error?.message} ${error?.stack}`);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/', authenticate('jwt'), async (req, res) => {
  const { from, to, alcaldia } = req.body;
  const [error, data] = await fulfill(generateBranchesReport(req.user, { from, to, alcaldia }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/reportTransf', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getTransfersReport({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/reportTransfBank/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { day } = req.body;
  const [error, data] = await fulfill(getTransfersReportBank({ day, id }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/condoReport', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  mainLogger.info('AAAAAAAAAAAAAAAAAAAAA');
  const [error, data] = await fulfill(getCondoReport({ from, to }));
  mainLogger.info(`AAAAAAAAAAAAAAAAAAAAA ${error?.message}`);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/condoReportDisclosed', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  mainLogger.info('AAAAAAAAAAAAAAAAAAAAA');
  const [error, data] = await fulfill(getCondoReportDisclosed({ from, to }));
  mainLogger.info(`AAAAAAAAAAAAAAAAAAAAA ${error?.message}`);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
