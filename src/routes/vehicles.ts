import { Router } from 'express';
import { authenticate } from 'passport';
import { getIdByRif } from '@utils/user';
import { fulfill } from '@utils/resolver';
import { getVehiclesByContributor, getBrands, getVehicleTypes, createVehicle, updateVehicle, deleteVehicle, checkVehicleExists } from '@helpers/vehicles';

const router = Router();

router.get('/getByRif/:rif', authenticate('jwt'), async (req, res) => {
  const { rif } = req.params;
  const { id_contribuyente } = await getIdByRif(rif);
  const [err, data] = await fulfill(getVehiclesByContributor(id_contribuyente));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/brands', authenticate('jwt'), async (_, res) => {
  const [err, data] = await fulfill(getBrands());
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/types', authenticate('jwt'), async (_, res) => {
  const [err, data] = await fulfill(getVehicleTypes());
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.user;
  const [err, data] = await fulfill(getVehiclesByContributor(id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/', authenticate('jwt'), checkVehicleExists(), async (req: any, res) => {
  const { vehiculo: vehicle } = req.body;
  const [err, data] = await fulfill(createVehicle(vehicle, req.user));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.put('/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const { vehiculo: vehicle } = req.body;
  const [err, data] = await fulfill(updateVehicle(vehicle, id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.delete('/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(deleteVehicle(id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

export default router;
