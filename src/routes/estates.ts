import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import {
  getEstatesInfo,
  getEstateInfoByCod,
  createPersonalEstate,
  taxPayerEstatesByRIM,
  createBareEstate,
  linkCommercial,
  updateEstate,
  getEstateByCod,
  taxPayerEstatesByNaturalCont,
  linkNatural,
  updateEstateDate,
  unlinkCommercial,
  unlinkNatural,
  generateCodCat,
} from '@helpers/estate';
import { authenticate } from 'passport';
import { mainLogger } from '@utils/logger';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getEstatesInfo());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/sedemat/', async (req, res) => {
  const [error, data] = await fulfill(getEstateByCod(req.query));
  mainLogger.info(error);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/:cod', async (req, res) => {
  const [error, data] = await fulfill(getEstateInfoByCod(req.params['cod']));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.post('/', authenticate('jwt'), async (req, res) => {
  const { tramite } = req.body;
  const [error, data] = await fulfill(createPersonalEstate(tramite));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/generateCodCat', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(generateCodCat(req.body))
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
})

router.get('/sedemat/natural', async (req, res) => {
  const [error, data] = await fulfill(taxPayerEstatesByNaturalCont(req.query));
  mainLogger.info(error);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/sedemat/contributor/rim/', async (req, res) => {
  const [error, data] = await fulfill(taxPayerEstatesByRIM(req.query));
  mainLogger.info(error);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/sedemat/', async (req, res) => {
  const [error, data] = await fulfill(createBareEstate(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/sedemat/natural/link/', async (req, res) => {
  const [error, data] = await fulfill(linkNatural(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/sedemat/rim/link/', async (req, res) => {
  const [error, data] = await fulfill(linkCommercial(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/sedemat/natural/unlink/', async (req, res) => {
  const [error, data] = await fulfill(unlinkNatural(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.post('/sedemat/rim/unlink/', async (req, res) => {
  const [error, data] = await fulfill(unlinkCommercial(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/sedemat/estate', async (req, res) => {
  const [error, data] = await fulfill(updateEstate(req.body));
  mainLogger.info(error);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.patch('/sedemat/estate/date', async (req, res) => {
  const [error, data] = await fulfill(updateEstateDate(req.body));
  mainLogger.info(error);
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});
export default router;
