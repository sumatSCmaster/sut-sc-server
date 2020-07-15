import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getMunicipalServicesByContributor, updateGasStateForEstate } from '@helpers/services';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const [error, data] = await fulfill(getMunicipalServicesByContributor({ reference: referencia, document: documento, docType: tipoDocumento }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/gas/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { estado } = req.body;
  const [error, data] = await fulfill(updateGasStateForEstate({ estateId: id, gasState: estado }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
