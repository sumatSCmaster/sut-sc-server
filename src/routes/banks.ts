import { Router } from 'express';
import { getAllBanks, validatePayments, listTaxPayments, updatePayment, addPayment, paymentReferenceSearch, reversePaymentForProcess, approveSinglePayment, listProcedurePayments, setAccountState } from '@helpers/banks';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

//TODO: realizar estructura correcta en el helper, y tipificar
router.get('/', async (req, res) => {
  const [err, data] = await fulfill(getAllBanks());
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/accountState', async (req, res) => {
  const {data} = req.body;
  const [err, dataa] = await fulfill(setAccountState(data));
  if (err) res.status(err.status).json(err);
  if (dataa) res.status(dataa.status).json(dataa); 
})

router.get('/reference/search', async (req, res) => {
  const { referencia: reference, banco: bank } = req.query;
  const [err, data] = await fulfill(paymentReferenceSearch({ reference, bank }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.put('/validatePayments', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(validatePayments(req.body, req.user));
  mainLogger.error(err);
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.put('/validateSinglePayment', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(approveSinglePayment(req.body.id, req.user));
  mainLogger.error(err);
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.get('/payment/', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(listTaxPayments());
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.get('/procedurePayments/', async (req, res) => {
  const [err, data] = await fulfill(listProcedurePayments(req.query.type_doc, req.query.doc));
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.post('/payment/', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(addPayment(req.body));
  if (err) res.status(500).json({ status: 500, message: errorMessageGenerator(err) });
  if (data) res.status(data.status).json(data);
});

router.patch('/payment/:id/', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(updatePayment({ id: req.params['id'], ...req.body }));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

router.delete('/payment/:id/:concept', authenticate('jwt'), async (req, res) => {
  const { id, concept } = req.params;
  const [err, data] = await fulfill(reversePaymentForProcess({ id: +id, concept }));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

export default router;
