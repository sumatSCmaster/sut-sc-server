import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getStats } from '@helpers/statistics';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getStats(req.user));
  if(err) res.status(500).json(err);
  if(data) res.status(200).json(data);
});

export default router;
