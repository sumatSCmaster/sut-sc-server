import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { updatePetroValue, getPetroValue, getUsdValue, updateUsdValue } from '@helpers/values';
import { isSuperuser, isSuperuserOrDaniel } from '@validations/auth';
import { authenticate } from 'passport';

const router = Router();

router.patch('/petro', authenticate('jwt'), isSuperuserOrDaniel, async (req, res) => {
  const [error, data] = await fulfill(updatePetroValue(req.body.value));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

router.get('/petro', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getPetroValue());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

router.get('/peso', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getPesoValue());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

router.patch('/peso', authenticate('jwt'), isSuperuserOrDaniel, async (req, res) => {
  const [error, data] = await fulfill(updatePesoValue(req.body.value));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

router.patch('/usd', authenticate('jwt'), isSuperuserOrDaniel, async (req, res) => {
  const [error, data] = await fulfill(updateUsdValue(req.body.value));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

router.get('/usd', authenticate('jwt'), isSuperuserOrDaniel, async (req, res) => {
  const [error, data] = await fulfill(getUsdValue());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ ...data });
});

export default router;
