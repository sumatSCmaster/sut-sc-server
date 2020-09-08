import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getEstatesInfo, getEstateInfoByCod, createPersonalEstate, taxPayerEstatesByRIM, createBareEstate, linkCommercial, updateEstate, getEstateByCod, taxPayerEstatesByNaturalCont, linkNatural } from '@helpers/estate';
import { authenticate } from 'passport';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getEstatesInfo());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, ...data });
});

router.get('/sedemat/', async (req, res) => {
  const [error, data] = await fulfill(getEstateByCod(req.query));
  console.log(error)
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
})

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

router.get('/sedemat/natural', async(req, res) => {
  const [error, data] = await fulfill(taxPayerEstatesByNaturalCont(req.query));
  console.log(error)
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});


router.get('/sedemat/contributor/rim/', async(req, res) => {
  const [error, data] = await fulfill(taxPayerEstatesByRIM(req.query));
  console.log(error)
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
})


router.post('/sedemat/rim/link/', async (req, res) => {
  const [error, data] = await fulfill(linkCommercial(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
})

router.patch('/sedemat/estate', async (req, res) => {
  const [error, data] = await fulfill(updateEstate(req.body));
  console.log(error)
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
})

router.patch('/sedemat/estate/date', async (req, res) => {
  const [error, data] = await fulfill(updateEstateDate(req.body));
  console.log(error)
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
})
export default router;
