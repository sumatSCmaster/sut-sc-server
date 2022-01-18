import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getCondominiumType, editCondominiumType } from '@helpers/condominiumType';

const router = Router();

router.get('/search/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(getCondominiumType(id));
  if (err) res.status(500).json({ err, status: 500 });
  if (data) res.status(200).json(data);
});

router.put('/edit/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const { type } = req.body;
  const [err, data] = await fulfill(editCondominiumType(id, type));
  if (err) res.status(500).json({ err, status: 500 });
  if (data) res.status(200).json(data);
});

export default router;
