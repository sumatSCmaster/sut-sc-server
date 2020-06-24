import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateBranchesReport } from '@helpers/branches';
import { authenticate } from 'passport';

const router = Router();

router.get('/', async (req, res) => {
  console.log('a')
  const { from, to } = req.body;
  const [error, data] = await fulfill(generateBranchesReport(req.user ,{from, to}));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});


export default router;
