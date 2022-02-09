import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { createRRICertificate } from '@utils/forms';

const router = Router();

router.get('/', async (req: any, res) => {
  const { id, areaTerreno, areaConstruccion, codigoRRI } = req.query;
  const [error, data] = await fulfill(createRRICertificate(id, areaTerreno, areaConstruccion, codigoRRI));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

export default router;
