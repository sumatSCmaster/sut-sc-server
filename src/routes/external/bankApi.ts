import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { apiCheckMiddleware } from './middleware/ApiKeyCheck';
import { getSettlementsByRifAndRim, payApplications } from '@helpers/external/bankApi';

const router = Router();

router.get('/', apiCheckMiddleware, async (req, res) => {
  const { rif, rim } = req.query;
  if(rif === undefined || rim === undefined) {
    return res.status(400).json({error: "Error de parámetros"})
  }
  const [error, data] = await fulfill(getSettlementsByRifAndRim(rif, rim, req.headers['x-sut-api-key']))
  if (error) res.status(400).json({ error: error.message, status: 500 });
  if (data) res.status(200).json({ solicitudes: data });
});

router.post('/', apiCheckMiddleware ,async (req, res) => {
  if(req.body === undefined || req.body.pagos === undefined || req.body.pagos === null ) {
    return res.status(400).json({error: "Error de parámetros"})
  }
  const [error, data] = await fulfill(payApplications(req.body.pagos, req.headers['x-sut-api-key'] as string))
  if (error) res.status(400).json({ error: error.message });
  if (data) res.status(200).json({ ...data });
});

export default router;
