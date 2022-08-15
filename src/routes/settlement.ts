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
  checkContributorExists,
  addTaxApplicationPaymentAgreement,
  getSettlementsReport,
  getAgreements,
  contributorSearch,
  getAgreementsForContributor,
  internalContributorSignUp,
  internalLicenseApproval,
  internalUserLinking,
  internalUserImport,
  createSpecialSettlement,
  patchSettlement,
  addRebateForDeclaration,
  deleteSettlement,
  getIUSettlementsForContributor,
  getIvaReport,
  getCertificatesForSettlement,
} from '@helpers/settlement';
import { Usuario } from '@root/interfaces/sigt';
import { generateReceipt, generateReceiptAgreement } from '@helpers/receipt';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', authenticate('jwt'), checkContributorExists(), async (req, res) => {
  const { doc, ref, pref } = req.query;
  mainLogger.info(doc, ref);
  const [err, data] = await fulfill(getSettlements({ document: doc, reference: ref ? ref : null, type: pref, user: req.user as Usuario }));
  mainLogger.error(err);
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/iu/declaration', authenticate('jwt'), async (req, res) => {
  const { doc, ref, pref, amount } = req.query;
  const [err, data] = await fulfill(getIUSettlementsForContributor({ document: doc, reference: ref ? ref : null, type: pref, declaration: amount }));
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
  const { tipoContribuyente, referencia, idCargo } = req.query;
  const [error, data] = await fulfill(createAccountStatement({ contributor, reference: referencia || null, typeUser: tipoContribuyente, idCargo: idCargo }));
  if (error) res.status(500).json(error);
  if (data)
    data.toBuffer(async (err, buffer) => {
      if (err) res.status(500).json({ status: 500, message: 'Error al procesar el pdf' });
      res.contentType('application/pdf').send(buffer);
    });
});

router.get('/import', authenticate('jwt'), async (req: any, res) => {
  const { user } = req;
  const { documento, referencia, tipoDocumento, tipoContribuyente } = req.query;
  const [err, data] = await fulfill(internalUserImport({ document: documento, reference: referencia, docType: tipoDocumento, typeUser: tipoContribuyente, user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/instances', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getApplicationsAndSettlements({ user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/search/taxPayer', authenticate('jwt'), async (req: any, res) => {
  const { doc, pref, name } = req.query;
  const [err, data] = await fulfill(contributorSearch({ document: doc || null, docType: pref, name: name || null }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/agreements', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getAgreements({ user: req.user }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/agreements/:tipoContribuyente', authenticate('jwt'), async (req: any, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const { tipoContribuyente } = req.params;
  const [err, data] = await fulfill(getAgreementsForContributor({ reference: referencia, docType: tipoDocumento, document: documento, typeUser: tipoContribuyente }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

//TODO: incluir validacion de que sea funcionario, informacion del contribuyente
router.get('/instances/:tipoContribuyente', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento, referencia } = req.query;
  const { tipoContribuyente } = req.params;
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

router.get('/vehiculoCert/:idLiquidacion', authenticate('jwt'), async (req, res) => {
  const {idLiquidacion} = req.params;
  const [err, data] = await fulfill(getCertificatesForSettlement(idLiquidacion));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
}) 

router.post('/report', authenticate('jwt'), async (req, res) => {
  const { from, to, ramo } = req.body;
  const [error, data] = await fulfill(getSettlementsReport(req.user, { from, to, ramo }));
  mainLogger.info(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/report/iva', authenticate('jwt'), async (req, res) => {
  const { from, to } = req.body;
  const [error, data] = await fulfill(getIvaReport(req.user, { from, to }));
  mainLogger.info(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
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
      idLiquidacion: id,
      media: certificate,
      user: req.user,
    })
  );
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/receipt/:id/application', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [error, data] = await fulfill(generateReceipt({ application: id }));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json({ url: data, message: 'Recibo generado', status: 200 });
});

router.post('/receipt/:id/agreement', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [error, data] = await fulfill(generateReceiptAgreement({ agreement: id }));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json({ url: data, message: 'Recibo generado', status: 200 });
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

// router.post('/benefits', authenticate('jwt'), async (req, res) => {
//   const { contribuyente } = req.body;
//   const [error, data] = await fulfill(createUserBenefits(contribuyente));
//   if (error) res.status(500).json(error);
//   if (data) res.status(data.status).json(data);
// });

router.post('/linking', authenticate('jwt'), async (req, res) => {
  const { datosEnlace } = req.body;
  const [error, data] = await fulfill(internalUserLinking(datosEnlace));
  mainLogger.info(error);
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/taxPayer', authenticate('jwt'), async (req, res) => {
  const { datosEnlace } = req.body;
  const [error, data] = await fulfill(initialUserLinking(datosEnlace, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/license', authenticate('jwt'), async (req: any, res) => {
  const [error, data] = await fulfill(internalLicenseApproval(req.body, req.user));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/internal', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(internalContributorSignUp(req.body));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/special', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createSpecialSettlement({ process: req.body, user: req.user }));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/taxPayer/verify', authenticate('jwt'), async (req, res) => {
  const { codigo } = req.body;
  const [error, data] = await fulfill(verifyUserLinking({ code: codigo, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/taxPayer/resend', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(resendUserCode({ user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/:id/payment', authenticate('jwt'), async (req: any, res) => {
  const { procedimiento } = req.body;
  const { id } = req.params;
  const [error, data] = await fulfill(addTaxApplicationPayment({ payment: procedimiento.pagos, interest: procedimiento.interesMoratorio, application: id, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.put('/:id/payment/:fragment', authenticate('jwt'), async (req: any, res) => {
  const { procedimiento } = req.body;
  const { id, fragment } = req.params;
  const [error, data] = await fulfill(addTaxApplicationPaymentAgreement({ payment: procedimiento.pagos, agreement: id, fragment, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/:id', authenticate('jwt'), async (req, res) => {
  const { liquidacion } = req.body;
  const { id } = req.params;
  const [error, data] = await fulfill(patchSettlement({ id, settlement: liquidacion }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/rebate/:id', authenticate('jwt'), async (req, res) => {
  const { solicitud: process } = req.body;
  const { id } = req.params;
  process.id = id;
  const [error, data] = await fulfill(addRebateForDeclaration({ process, user: req.user }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/delete/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const {observaciones: observations} = req.body;
  const [error, data] = await fulfill(deleteSettlement(+id, observations, req.user));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
