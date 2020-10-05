import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getAllChargings, updateOneCharging, getAllWallets, linkWallet, getChargingsByWallet, createChargings, createAllChargings } from '@helpers/chargings';
import { authenticate } from 'passport';

const router = Router();

router.post('/charging', async (req, res) => {
  const [error, data] = await fulfill(createAllChargings());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/charging', async (req, res) => {
  const [error, data] = await fulfill(getAllChargings());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.patch('/charging/:id',  async (req, res) => {
  const [error, data] = await fulfill(updateOneCharging(req.user , {idCobranza: req.params['id'], ...req.body}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/',  async (req, res) => {
    const [error, data] = await fulfill(getAllWallets());
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

router.get('/:id',  async (req, res) => {
    const [error, data] = await fulfill(getChargingsByWallet(req.params['id']));
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

router.patch('/:id',  async (req, res) => {
    const [error, data] = await fulfill(linkWallet(req.params['id'], req.body.idUser));
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
});

export default router;
