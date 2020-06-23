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
  getApplicationsAndSettlementsForContributor,
  logInExternalLinking,
  verifyUserLinking,
  initialUserLinking,
  getEntireDebtsForContributor,
  resendUserCode,
} from '@helpers/settlement';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref } = req.query;
  console.log(doc, ref);
  const [err, data] = await fulfill(getSettlements({ document: doc, reference: ref ? ref : null, type: pref, user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

// router.get('/taxPayer', authenticate('jwt'), async (req, res) => {
//   const { tipoDocumento, documento, tipoContribuyente } = req.query;
//   const [err, data] = await fulfill(getTaxPayerInfo({ docType: tipoDocumento, document: documento, type: tipoContribuyente }));
//   if (err) res.status(err.status).json(err);
//   if (data) res.status(data.status).json(data);
// });

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

router.get('/instances', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getApplicationsAndSettlements({ user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

//TODO: incluir validacion de que sea funcionario, informacion del contribuyente
router.get('/instances/:referencia', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, tipoContribuyente } = req.query;
  const { referencia } = req.params;
  const [err, data] = await fulfill(getApplicationsAndSettlementsForContributor({ referencia, docType: tipoDocumento, document: documento, typeUser: tipoContribuyente }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/debts/:tipoContribuyente', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const { tipoContribuyente } = req.params;
  const [err, data] = await fulfill(getEntireDebtsForContributor({ reference: referencia, docType: tipoDocumento, document: documento, typeUser: tipoContribuyente }));
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

router.post(
  '/login',
  /*authenticate('jwt'), */ async (req, res) => {
    const { usuario } = req.body;
    const [error, data] = await fulfill(logInExternalLinking({ credentials: usuario }));
    if (error) res.status(500).json(error);
    if (data) res.status(data.status).json(data);
  }
);

router.post('/taxPayer', authenticate('jwt'), async (req, res) => {
  const { datosEnlace } = req.body;
  const [error, data] = await fulfill(initialUserLinking(datosEnlace, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/taxPayer/verify', authenticate('jwt'), async (req, res) => {
  const { codigo, rims } = req.body;
  const [error, data] = await fulfill(verifyUserLinking({ rims, code: codigo, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

//TODO: TERMINAR y crear el helper
router.put('/taxPayer/resend', authenticate('jwt'), async (req, res) => {
  const { rims } = req.body;
  const [error, data] = await fulfill(resendUserCode({ rims, user: req.user }));
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

export default router;
