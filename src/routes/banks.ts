import { Router } from 'express';
import { getAllBanks, validatePayments } from '@helpers/banks';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';

const router = Router();

//TODO: realizar estructura correcta en el helper, y tipificar
router.get('/', async (req, res) => {
  const [err, data] = await fulfill(getAllBanks());
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.put('/validatePayments', async (req, res) => {
  const [err, data] = await fulfill(validatePayments(req.body, req.user));
  console.log(err);
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

export default router;
