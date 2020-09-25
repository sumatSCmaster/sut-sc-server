import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getActivityBranchDiscounts, createActivityDiscount, updateEndTimeDiscount, createContributorDiscount, getContributorDiscounts } from '@helpers/discounts';

const router = Router();

router.get('/activities', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivityBranchDiscounts());
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/contributor/:typedoc/:doc/:ref', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getContributorDiscounts({ typeDoc: req.params['typedoc'], doc: req.params['doc'], ref: req.params['ref'] }));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/contributor', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createContributorDiscount(req.body));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/activity', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createActivityDiscount(req.body));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(updateEndTimeDiscount(req.params['id'], req.body.to));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
