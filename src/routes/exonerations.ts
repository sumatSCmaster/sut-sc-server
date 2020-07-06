import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getContributorExonerations, getActivityExonerations, getBranchExonerations, createContributorExoneration, createActivityExoneration, createBranchExoneration, updateEndTimeExoneration } from '@helpers/exonerations';
import { authenticate } from 'passport';

const router = Router();

router.get('/contributor/:typedoc/:doc/:ref', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getContributorExonerations({ typeDoc: req.params['typedoc'], doc: req.params['doc'], ref: req.params['ref'] }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/activities', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivityExonerations());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/branches', authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(getBranchExonerations());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
  });

router.post('/contributor', authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(createContributorExoneration(req.body))
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
})

router.post('/activity', authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(createActivityExoneration(req.body))
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
})

router.post('/branch', authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(createBranchExoneration(req.body))
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

router.patch('/:id', authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(updateEndTimeExoneration(req.params['id'], req.body.to))
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
})
export default router;
