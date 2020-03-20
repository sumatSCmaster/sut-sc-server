import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getEstatesInfo, getEstateInfoByCod, createPersonalEstate } from '@helpers/estate';
import { authenticate } from 'passport';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getEstatesInfo());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/:cod', async (req, res) => {
  const [error, data] = await fulfill(getEstateInfoByCod(req.params['cod']));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.post('/', authenticate('jwt'), async (req, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(createPersonalEstate(tramite));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
