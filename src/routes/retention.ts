import { Router } from 'express';

import { fulfill } from '@utils/resolver';
import { processRetentionFile } from '@helpers/retention';
import { authenticate } from 'passport';

const router = Router();


router.post('/report/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(processRetentionFile(req.file));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});


export default router;
