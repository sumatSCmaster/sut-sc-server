import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { createRepotRMP, createReportRID } from '@helpers/report';

const router = Router();

router.post('/methodPay', authenticate('jwt'), async (req, res) => {
  const {fecha} = req.body;
  const [error, data] = await fulfill(createRepotRMP(fecha));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  res.status(200).json({data, status: 200});
});

router.get('/ingresadoDetallado', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createReportRID());
  if (error) res.status(500).json({ message: error.message, status: 500 });
  res.status(200).json({data, status: 200});
});


export default router;