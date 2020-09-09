import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getAEDeclarationsForAlteration } from '@helpers/alterations';

const router = Router();

router.get('/ae', async (req: any, res) => {
  const { tipoDocumento: docType, documento: document, referencia: reference } = req.query;
  const [error, data] = await fulfill(getAEDeclarationsForAlteration({ docType, document, reference, user: req?.user }));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
