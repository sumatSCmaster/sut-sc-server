import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getTimeFunctionary } from '@helpers/reportCPU';

const router = Router();

router.post('/timeFunctionary', authenticate('jwt'), async (req, res) => {
  const {from, to} = req.body;
  const [error, data] = await fulfill(getTimeFunctionary(from, to));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;