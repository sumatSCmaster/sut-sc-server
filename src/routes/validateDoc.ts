import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { validateDocById, validateSedematById, validateVehicle, validatePerson } from '@helpers/validateDocs';

const router = Router();

router.get('/validarVehiculo', async (req, res) => {
  const { tipo_documento,documento, placa } = req.query;
  const [err, data] = await fulfill(validateVehicle(placa));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/validarUsuario', async (req, res) => {
  const { tipo_documento,documento, placa } = req.query;
  const [err, data] = await fulfill(validatePerson(tipo_documento, documento));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
})

router.get('/validarSedemat/:id', async (req, res) => {
  const [err, data] = await fulfill(validateSedematById(req.params['id']));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
})

router.get('/:id(\\d+)', async (req, res) => {
  const [err, data] = await fulfill(validateDocById(req.params['id']));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});



export default router;