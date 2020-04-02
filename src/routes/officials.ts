import { Router } from 'express';
import { getOfficialsByInstitution, createOfficial, updateOfficial, deleteOfficial, getAllOfficials, deleteOfficialSuperuser } from '@helpers/officials';
import * as validators from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { isSuperuser } from '@middlewares/auth';

const router = Router();

//TODO: añadir validacion de tipo de usuario
router.get('/', authenticate('jwt'), async (req: any, res) => {
  console.log(req.user);
  const { cuentaFuncionario, id } = req.user;
  if (cuentaFuncionario.id_institucion) {
    const [err, data] = await fulfill(getOfficialsByInstitution(cuentaFuncionario.id_institucion, id));
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
  } else {
    res.status(401).json({
      message: 'No tiene permisos para obtener los funcionarios.',
      status: 401,
    });
  }
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

router.delete('/:id', authenticate('jwt'), async (req: any, res) => {
  const { id_institucion } = req.user.cuentaFuncionario;
  if (id_institucion) {
    const { id } = req.params;
    let err, data;
    if (req.user.tipoUsuario !== 1) {
      [err, data] = await fulfill(deleteOfficial(id, id_institucion));
    } else {
      [err, data] = await fulfill(deleteOfficialSuperuser(id));
    }
    if (err) res.status(500).json(err);
    if (data) res.status(data.status).json(data);
  } else {
    res.status(401).json({
      message: 'No tiene permisos para editar funcionarios.',
      status: 401,
    });
  }
});

export default router;
