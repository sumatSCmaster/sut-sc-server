import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getScales, updateScale } from '@helpers/scales';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getScales());
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { indicador } = req.body;
  const [error, data] = await fulfill(updateScale(id, indicador));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

// router.post('/', authenticate('jwt'), async (req, res) => {
//   const { descripcion, indicador } = req.body;
//   const [error, data] = await fulfill(createScale({ description: descripcion, tariff: indicador }));
//   if (error) res.status(500).json(error);
//   if (data) res.status(data.status).json(data);
// });

export default router;
