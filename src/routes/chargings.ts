import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getAllChargings, updateOneCharging, getAllWallets, linkWallet, getChargingsByWallet, createChargings, createAllChargings, getChargingsByWalletExcel } from '@helpers/chargings';
import { authenticate } from 'passport';

const router = Router();

router.post('/charging', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createAllChargings(req.body.cant_top, req.body.cant_ar, req.body.cant_per_wallet));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/charging', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getAllChargings());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.patch('/charging/:id', authenticate('jwt'),  async (req, res) => {
  const [error, data] = await fulfill(updateOneCharging(req.user , {idCobranza: req.params['id'], ...req.body}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/',  authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(getAllWallets());
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

router.get('/:id',  authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(getChargingsByWallet(req.params['id']));
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

router.get('/report/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getChargingsByWalletExcel(req.params['id']));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.patch('/:id',  authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(linkWallet(req.params['id'], req.body.idUser));
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

export default router;
