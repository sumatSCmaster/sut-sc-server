import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getAllChargings, updateOneCharging } from '@helpers/chargings';
import { authenticate } from 'passport';

const router = Router();

router.get('/charging', authenticate('jwt'), async (req, res) => {
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

router.patch('/',  async (req, res) => {
    const [error, data] = await fulfill(updateOneCharging(req.user , {idCobranza: req.params['id'], ...req.body}));
    console.log(error, data)
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, data });
  });
  

export default router;
