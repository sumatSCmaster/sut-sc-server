import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { createRRICertificate } from '@utils/forms';

const router = Router();

router.get('/', async (req: any, res) => {
  const { id, areaTerreno, areaConstruccion, codigoRRI, ubicadoEn, parroquiaEdificio } = req.query;
  console.log(req.query, 'PABLITO');
  const [error, data] = await fulfill(createRRICertificate(id, areaTerreno, areaConstruccion, codigoRRI, ubicadoEn, parroquiaEdificio));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

export default router;
