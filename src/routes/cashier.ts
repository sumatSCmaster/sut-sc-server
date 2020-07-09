import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateCashierReport, generateAllCashiersReport } from '@helpers/cashier';
import { authenticate } from 'passport';

const router = Router();


router.post('/', authenticate('jwt'), async (req, res) => {
  const { day } = req.body;
  const [error, data] = await fulfill(generateCashierReport(req.user ,{day}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});


router.post('/all', authenticate('jwt'), async (req, res) => {
  const { day } = req.body;
  const [error, data] = await fulfill(generateAllCashiersReport(req.user ,{day}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});



export default router;
