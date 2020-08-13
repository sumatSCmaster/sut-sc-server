import { Router } from 'express';
import { authenticate } from 'passport';

import { fulfill } from '@utils/resolver';
import { getVehiclesByContributor } from '@helpers/vehicles';

const router = Router();

router.get('/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(getVehiclesByContributor(id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

export default router;
