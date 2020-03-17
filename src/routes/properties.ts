import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getPropertiesInfo, getPropertyInfoByCod, createPersonalProperty } from '@helpers/property';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getPropertiesInfo());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/:cod', async (req, res) => {
  const [error, data] = await fulfill(getPropertyInfoByCod(req.params['cod']));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.post('/', async (req, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(createPersonalProperty(tramite));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
