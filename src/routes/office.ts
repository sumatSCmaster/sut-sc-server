import { Router } from 'express';
import { authenticate } from 'passport';
import { getOffices, createOffice, editOffice, removeOffice } from '@helpers/office';
import { isAdmin } from '@middlewares/auth';
import * as officeValidations from '@validations/office';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/:idInst/office', authenticate('jwt'), officeValidations.idExists, checkResult, async (req, res) => {
  try {
    const offices = await getOffices(parseInt(req.params.idInst));
    res.status(200).json({
      status: 200,
      message: 'Oficinas retornadas de manera exitosa.',
      offices
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/:idInst/office', authenticate('jwt'), officeValidations.createOffice, checkResult, isAdmin, async (req: any, res) => {
  try {
    const office = await createOffice(parseInt(req.params.idInst), req.body.nombre);
    res.status(200).json({
      status: 200,
      message: 'Oficina creada de manera exitosa.',
      office
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:idInst/office/:idOffice', authenticate('jwt'), officeValidations.editOficina, checkResult, isAdmin, async (req: any, res) => {
  try {
    const office = await editOffice(parseInt(req.params.idInst), parseInt(req.params.idOffice), req.body.nombre, req.body.institucion);
    if(office) {
      res.status(200).json({
        status: 200,
        message: 'Oficina editada de manera exitosa.',
        office
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Oficina con id ${req.params.idOffice} no encontrada dentro de la institucion con id ${req.params.idInst}.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:idInst/office/:idOffice', authenticate('jwt'), officeValidations.deleteOffice, checkResult, isAdmin, async (req, res) => {
  try {
    const office = await removeOffice(parseInt(req.params.idInst), parseInt(req.params.idOffice));
    if(office) {
      res.status(200).json({
        status: 200,
        message: 'Oficina eliminada de manera exitosa.',
        office
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Oficina con id ${req.params.idOffice} no encontrada dentro de la institucion con id ${req.params.idInst}.`
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