import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { generateCashierReport, generateAllCashiersReport, getCashierReceipts } from '@helpers/cashier';
import { authenticate } from 'passport';

const router = Router();


router.get('/:id/receipts', authenticate('jwt'), async (req, res) => {
  const { id } = req.params
  const [error, data] = await fulfill(getCashierReceipts({id}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.post('/', authenticate('jwt'), async (req, res) => {
  const { day } = req.body;
  const [error, data] = await fulfill(generateCashierReport(req.user ,{day}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});


router.post('/all', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(generateAllCashiersReport(req.user ,{from, to}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});



export default router;
