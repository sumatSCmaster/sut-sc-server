import { Router } from 'express';
import { authenticate } from 'passport';
import { getIdByRif, getIdByRim } from '@utils/user';
import { fulfill } from '@utils/resolver';
import { getVehiclesByContributor, getBrands, getVehicleTypes, createVehicle, updateVehicle, deleteVehicle, checkVehicleExists, createVehicleForRim, linkVehicle, unlinkVehicle, updateVehicleDate } from '@helpers/vehicles';

const router = Router();
 
router.get('/getByRif/:rif/:pref', authenticate('jwt'), async (req, res) => {
  const { rif, pref } = req.params;
  const { id_contribuyente } = await getIdByRif(rif, pref);
  const [err, data] = await fulfill(getVehiclesByContributor(id_contribuyente));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/getByRim/:rim', authenticate('jwt'), async (req, res) => {
  const { rim } = req.params;
  const { id_registro_municipal } = await getIdByRim(rim);
  const [err, data] = await fulfill(getVehiclesByContributor(0, id_registro_municipal));
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

router.post('/internal', authenticate('jwt'), async (req: any, res) => {
  const { vehiculo: vehicle, id } = req.body;
  req.user.id = id;
  const [err, data] = await fulfill(createVehicle(vehicle, req.user));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/internal/rim', authenticate('jwt'), async (req: any, res) => {
  const { vehiculo: vehicle, id } = req.body;
  req.user.id = id;
  const [err, data] = await fulfill(createVehicleForRim(vehicle, req.user));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/link', authenticate('jwt'), async (req: any, res) => {
  const { placa, id, isRim } = req.body;
  req.user.id = id;
  const [err, data] = await fulfill(linkVehicle(placa, id, isRim));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/unlink', authenticate('jwt'), async (req: any, res) => {
  const { idVehiculo } = req.body;
  const [err, data] = await fulfill(unlinkVehicle(idVehiculo));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post('/', authenticate('jwt'), async (req: any, res) => {
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

router.patch('/date', authenticate('jwt'), async (req: any, res) => {
  const [error, data] = await fulfill(updateVehicleDate(req.body));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
})

export default router;
