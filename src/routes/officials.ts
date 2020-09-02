import { Router } from 'express';
import { getOfficialsByInstitution, createOfficial, updateOfficial, deleteOfficial, getAllOfficials, deleteOfficialSuperuser, blockOfficial } from '@helpers/officials';
import * as validators from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { isSuperuser } from '@middlewares/auth';

const router = Router();

//TODO: añadir validacion de tipo de usuario
router.get('/', authenticate('jwt'), validators.isOfficial, async (req: any, res) => {
  const { institucion, id } = req.user;
  const [err, data] = await fulfill(getOfficialsByInstitution(institucion.id, id));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/all', authenticate('jwt'), isSuperuser, async (req: any, res) => {
  const [err, data] = await fulfill(getAllOfficials());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.post('/', authenticate('jwt'), validators.createOfficial, checkResult, validators.isOfficialAdmin, async (req: any, res) => {
  const { usuario } = req.body;
  const [err, data] = await fulfill(createOfficial(usuario));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

router.put('/:id', authenticate('jwt'), validators.updateOfficial, checkResult, validators.isOfficialAdmin, async (req, res) => {
  const { usuario } = req.body;
  const { id } = req.params;
  const [err, data] = await fulfill(updateOfficial(usuario, id));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

router.delete('/:id', authenticate('jwt'), validators.isOfficialAdmin, async (req: any, res) => {
  const { institucion } = req.user;
  const { id } = req.params;
  let err, data;
  if (req.user.tipoUsuario !== 1) {
    [err, data] = await fulfill(deleteOfficial(id, institucion.id));
  } else {
    [err, data] = await fulfill(deleteOfficialSuperuser(id));
  }
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

router.patch('/:id', authenticate('jwt'), validators.isOfficialAdmin, async (req: any, res) => {
  const { institucion } = req.user;
  const { id } = req.params;
  const [err, data] = await fulfill(blockOfficial(id, req.body.bloqueado));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

export default router;
