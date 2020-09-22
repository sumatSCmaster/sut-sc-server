import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getActivityDiscounts, createActivityDiscount, updateEndTimeDiscount } from '@helpers/discounts';

const router = Router();

router.get('/activities', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivityDiscounts());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/activity', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createActivityDiscount(req.body));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.patch('/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(updateEndTimeDiscount(req.params['id'], req.body.to));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
