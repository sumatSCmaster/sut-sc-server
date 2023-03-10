import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getObservations } from '@helpers/observations';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const { idTramite } = req.query;
  const [error, data] = await fulfill(getObservations(idTramite));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

export default router;
