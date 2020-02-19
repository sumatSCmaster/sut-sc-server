import { Router } from 'express';
import { authenticate } from 'passport';
import { getRoles, removeRole, editRole, createRole } from '@helpers/role';
import { isAdmin } from '@middlewares/auth';
import * as roleValidations from '@validations/role';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  try {
    const roles = await getRoles();
    res.status(200).json({
      status: 200,
      message: 'Roles retornados exitosamente.',
      roles
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/', authenticate('jwt'), roleValidations.createRole, checkResult, isAdmin, async (req, res) => {
  try {
    const role = await createRole(req.body.permisos, req.body.nombre);
    res.status(200).json({
      status: 200,
      message: 'Rol creado de manera exitosa.',
      role
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:id', authenticate('jwt'), roleValidations.idExists, checkResult, isAdmin, async (req, res) => {
  try {
    const role = await removeRole(parseInt(req.params.id));
    if(role) {
      res.status(200).json({
        status: 200,
        message: 'Rol eliminado exitosamente.',
        role
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Rol con id ${req.params.id} no encontrado.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id', authenticate('jwt'), roleValidations.editRole, checkResult, isAdmin, async (req: any, res) => {
  try {
    const role = await editRole(parseInt(req.params.id), req.body.nombre, req.body.permisos || []);
    if(role) {
      res.status(200).json({
        status: 200,
        message: 'Rol editado de manera exitosa.',
        role
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Rol con id ${req.params.id} no encontrado.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

export default router;