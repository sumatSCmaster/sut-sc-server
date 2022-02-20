import { Router } from 'express';
import auth from './auth';
import official from './officials';
import notification from './notification';
import banks from './banks';
import file from './file';
import procedures from './procedures';
import affairs from './affairs';
import resources from './resources';
import validateDoc from './validateDoc';
import estates from './estates';
import taxValues from './taxValues';
import ordinance from './ordinance';
import values from './values';
import fines from './fines';
import settlement from './settlement';
import alteration from './alterations';
import statistics from './statistics';
import user from './user';
import destination from './terminal';
import discount from './discounts';
import holiday from './holidays';
import branches from './branches';
import exonerations from './exonerations';
import options from './options';
import activities from './activities';
import cashier from './cashier';
import receipt from './receipt';
import definitiveDeclaration from './definitiveDeclaration';
import services from './services';
import retention from './retention';
import repairs from './repairs';
import contributor from './contributor';
import scales from './scales';
import vehicles from './vehicles';
import chargings from './chargings';
import fisc from './fiscalization';
import condominium from './condominium';
import condominiumType from './condominiumType';
import survey from './survey';
import external from './external/bankApi';
import observation from './observation';
import reportSolvRRI from './reportSolvRRI';
import RRICertificate from './RRICertificate';
import reportCPU from './reportCPU';

const router = Router();

router.use('/auth', auth);
router.use('/banks', banks);
router.use('/official', official);
router.use('/procedures', procedures);
router.use('/uploads', file);
router.use('/validateDoc', validateDoc);
router.use('/affairs', affairs);
router.use('/estates', estates);
router.use('/ordinance', ordinance);
router.use('/values', values);
router.use('/taxValues', taxValues);
router.use('/user', user);
router.use('/destination', destination);
router.use('/stats', statistics);
router.use('/options', options);
router.use('/fines', fines);
router.use('/notification', notification);
router.use('/settlements', settlement);
router.use('/holiday', holiday);
router.use('/definitive-declaration', definitiveDeclaration);
router.use('/alterations', alteration);
router.use('/branches', branches);
router.use('/discounts', discount);
router.use('/exonerations', exonerations);
router.use('/activities', activities);
router.use('/scales', scales);
router.use('/cashier', cashier);
router.use('/receipt', receipt);
router.use('/services', services);
router.use('/retentions', retention);
router.use('/repairs', repairs);
router.use('/contributor', contributor);
router.use('/vehicles', vehicles);
router.use('/wallet', chargings);
router.use('/fiscalization', fisc);
router.use('/condominium', condominium);
router.use('/condominiumType', condominiumType);
router.use('/survey', survey);
router.use('/api', external);
router.use('/observation', observation);
router.use(resources);
router.use('/reportSolvRRI', reportSolvRRI);
router.use('/RRICertificate', RRICertificate);
router.use('./reportCPU', reportCPU);

router.get('/', (req, res) => {
  res.status(200).json({
    status: 200,
    message: 'Ok',
  });
});

router.post('/twilio/webhook', (req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/xml' });
  res.end('si');
});

export default router;
