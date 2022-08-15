import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateBranchesReport, generateBranchesReportById, getBranches, getTransfersReport, getCondoReport, getTransfersReportBank, getCondoReportDisclosed, getTransfersExternalReport } from '@helpers/branches';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const {all} = req.query;
  const {id} = req.user;
  const [error, data] = await fulfill(getBranches(all, id));
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

// router.post('/:type', authenticate('jwt'), async (req, res) => {
//   const { from, to, alcaldia } = req.body;
//   const {type} = req.params;
//   const [error, data] = await fulfill(generateBranchesReport(req.user, { from, to, alcaldia }, type));
//   if (error) res.status(500).json({ error, status: 500 });
//   if (data) res.status(200).json({ status: 200, data });
// });

router.post('/reportTransf', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getTransfersReport({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/reportTransfBank/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { from, to } = req.body;
  const [error, data] = await fulfill(getTransfersReportBank({ from, to, id }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/reportTransfExternal', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getTransfersExternalReport({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.post('/condoReport', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getCondoReport({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/condoReportDisclosed', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getCondoReportDisclosed({ from, to }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
