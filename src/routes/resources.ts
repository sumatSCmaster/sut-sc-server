import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';
import { authenticate } from 'passport';
import { getAllInstitutions } from '@helpers/institutions';
import { getAllParishes } from '@helpers/parish';
import { getDataForTaxValues, getSectorByParish, updateTaxValues, getTaxValuesToDate } from '@helpers/taxValues';

const router = Router();

router.get('/institutions', authenticate('jwt'), async (req: any, res) => {
  if (req.user.tipoUsuario === 1) {
    const [err, data] = await fulfill(getAllInstitutions());
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
  } else {
    res.status(401).json({
      message: 'No tiene permisos de superusuario',
      status: 401,
    });
  }
});

router.get('/parishes', async (req: any, res) => {
  const [err, data] = await fulfill(getAllParishes());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/taxValues/resources', async (req: any, res) => {
  const [err, data] = await fulfill(getDataForTaxValues());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/taxValues/present', async (req: any, res) => {
  const [err, data] = await fulfill(getTaxValuesToDate());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/sector/:parish', async (req: any, res) => {
  const { parish } = req.params;
  const [err, data] = await fulfill(getSectorByParish(parish));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.put('/taxValue', async (req: any, res) => {
  const { valorFiscal } = req.body;
  const [err, data] = await fulfill(updateTaxValues(valorFiscal));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
