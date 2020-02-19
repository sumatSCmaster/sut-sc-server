import { Router } from 'express';
import office from './office';
import { authenticate } from 'passport';
import { getInstitutions, removeInstitution, getInstitution, createInstitution, editInstitution } from '@helpers/institution';
import { isAdmin } from '@middlewares/auth';
import * as instValidations from '@validations/institution';
import { checkResult }from '@validations/index';

const router = Router();

router.use('/', office);

router.get('/', authenticate('jwt'), async (req, res) => {
  try {
    const institutions = await getInstitutions();
    res.status(200).json({
      status: 200,
      message: 'Institucion retornadas de manera exitosa.',
      institutions
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/', authenticate('jwt'), instValidations.createInstitution, checkResult, isAdmin, async (req, res) => {
  try {
    const institution = await createInstitution(req.body.nombre);
    res.status(200).json({
      status: 200,
      message: 'Institucion creada de manera exitosa.',
      institution
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/:id', authenticate('jwt'), instValidations.idExists, checkResult, async (req, res) => {
  try {
    const institution = await getInstitution(parseInt(req.params.id));
    if(institution) {
      res.status(200).json({
        status: 200,
        message: 'Institucion retornada de manera exitosa.',
        institution
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Institucion con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:id', authenticate('jwt'), instValidations.idExists, checkResult, isAdmin, async (req, res) => {
  try {
    const institution = await removeInstitution(parseInt(req.params.id));
    if(institution) {
      res.status(200).json({
        status: 200,
        message: 'Institucion eliminada de manera exitosa.',
        institution
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Institucion con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id', authenticate('jwt'), instValidations.editInstitution, checkResult, isAdmin, async (req: any, res) => {
  try {
    const institution = await editInstitution(parseInt(req.params.id), req.body.nombre);
    if(institution) {
      res.status(200).json({
        status: 200,
        message: 'Institucion editada de manera exitosa.',
        institution
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Institucion con id ${req.params.id} no encontrada.`
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