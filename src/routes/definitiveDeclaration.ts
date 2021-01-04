import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getDataForDefinitiveDeclaration, insertDefinitiveYearlyDeclaration } from '@helpers/definitiveDeclaration';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const [error, data] = await fulfill(getDataForDefinitiveDeclaration({ reference: referencia, document: documento, docType: tipoDocumento }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(insertDefinitiveYearlyDeclaration({ process: req.body, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
