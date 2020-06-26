import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getActivities } from '@helpers/activities';
import { authenticate } from 'passport';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivities());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});


export default router;
