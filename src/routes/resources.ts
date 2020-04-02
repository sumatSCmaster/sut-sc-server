import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';
import { authenticate } from 'passport';
import { getAllInstitutions } from '@helpers/institutions';
import { getAllParishes, getSectorByParish } from '@helpers/parish';
import { isSuperuser } from '@validations/auth';

const router = Router();

router.get('/institutions', authenticate('jwt'), isSuperuser, async (req: any, res) => {
  const [err, data] = await fulfill(getAllInstitutions());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/parishes', async (req: any, res) => {
  const [err, data] = await fulfill(getAllParishes());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sector/:parish', async (req: any, res) => {
  const { parish } = req.params;
  const [err, data] = await fulfill(getSectorByParish(parish));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
