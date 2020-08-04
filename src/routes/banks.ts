import { Router } from 'express';
import { getAllBanks, validatePayments, listTaxPayments, updatePayment } from '@helpers/banks';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';
import { authenticate } from 'passport';

const router = Router();

//TODO: realizar estructura correcta en el helper, y tipificar
router.get('/', async (req, res) => {
  const [err, data] = await fulfill(getAllBanks());
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.put('/validatePayments', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(validatePayments(req.body, req.user));
  console.log(err)
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.get('/payment/', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(listTaxPayments());
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.patch('/payment/:id', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(updatePayment({ id: req.params['id'], ...req.body}));
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
})
export default router;
