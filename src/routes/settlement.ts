import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getSettlements, insertSettlements } from '@helpers/settlement';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, rim } = req.query;
  const [err, data] = await fulfill(getSettlements({ document: doc, reference: rim }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/init', authenticate('jwt'), async (req: any, res) => {
  const {} = req.body;
  const [error, data] = await fulfill(insertSettlements());
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
