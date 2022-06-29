import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { createRepotRMP } from '@helpers/report';

const router = Router();

router.get('/methodPay', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createRepotRMP());
  if (error) res.status(500).json({ message: error.message, status: 500 });
  res.status(200).json({data, status: 200});
});

export default router;