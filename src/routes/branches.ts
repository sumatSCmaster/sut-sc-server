import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateBranchesReport, getBranches, getTransfersReport, getCondoReport } from '@helpers/branches';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getBranches());
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

router.post('/', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getCondoReport({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
