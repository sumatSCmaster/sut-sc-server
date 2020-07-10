import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateReceipt } from '@helpers/receipt';
import { authenticate } from 'passport';

const router = Router();

router.post('/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(generateReceipt({ application: +req.params['id'] }));
  console.log(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
