import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateBranchesReport, getBranches } from '@helpers/branches';
import { authenticate } from 'passport';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getBranches());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/', async (req, res) => {
  const { from, to, alcaldia } = req.body;
  const [error, data] = await fulfill(generateBranchesReport(req.user, { from, to, alcaldia }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
