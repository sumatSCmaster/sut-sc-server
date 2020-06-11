import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import {
  getSettlements,
  insertSettlements,
  getApplicationsAndSettlements,
  addTaxApplicationPayment,
  createCertificateForApplication,
  createAccountStatement,
  getTaxPayerInfo,
} from '@helpers/settlement';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref } = req.query;
  console.log(doc, ref);
  const [err, data] = await fulfill(getSettlements({ document: doc, reference: ref ? ref : null, type: pref, user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/', authenticate('jwt'), async (req, res) => {});

router.get('/taxPayer', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, tipoContribuyente } = req.query;
  const [err, data] = await fulfill(getTaxPayerInfo({ docType: tipoDocumento, document: documento, type: tipoContribuyente }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/instances', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getApplicationsAndSettlements({ user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/init', authenticate('jwt'), async (req: any, res) => {
  const { procedimiento } = req.body;
  const [error, data] = await fulfill(insertSettlements({ process: procedimiento, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/:id/:certificate', authenticate('jwt'), async (req: any, res) => {
  const { id, certificate } = req.params;
  const [error, data] = await fulfill(
    createCertificateForApplication({
      settlement: id,
      media: certificate,
      user: req.user,
    })
  );
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/:id/payment', authenticate('jwt'), async (req: any, res) => {
  const { procedimiento } = req.body;
  const { id } = req.params;
  const [error, data] = await fulfill(addTaxApplicationPayment({ payment: procedimiento.pagos, application: id, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/accountStatement/:contributor', async (req: any, res) => {
  const { contributor } = req.params;
  const [error, data] = await fulfill(createAccountStatement(contributor));
  if (error) res.status(500).json(error);
  if (data)
    data.toBuffer(async (err, buffer) => {
      if (err) res.status(500).json({ status: 500, message: 'Error al procesar el pdf' });
      res.contentType('application/pdf').send(buffer);
    });
});

export default router;
