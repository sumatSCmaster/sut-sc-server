import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getContributorExonerations, getActivityExonerations, getBranchExonerations } from '@helpers/exonerations';
import { authenticate } from 'passport';

const router = Router();

router.get('/contributor/:id', async (req, res) => {
  const [error, data] = await fulfill(getContributorExonerations({ contributorId: req.params['id'] }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/activities', async (req, res) => {
  const [error, data] = await fulfill(getActivityExonerations());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/branches', async (req, res) => {
    const [error, data] = await fulfill(getBranchExonerations());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
  });


export default router;
