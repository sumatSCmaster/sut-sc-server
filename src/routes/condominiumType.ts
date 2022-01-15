import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getCondominiumType } from '@helpers/condominiumType';

const router = Router();

router.get('/search/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(getCondominiumType(id));
  if (err) res.status(500).json({ err, status: 500 });
  if (data) res.status(200).json(data);
});

router.put('/edit', authenticate('jwt'), async (req: any, res) => {});

export default router;
