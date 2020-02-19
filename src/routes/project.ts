import { Router } from 'express';
import { authenticate } from 'passport';
import { isAdmin } from '@middlewares/auth';
import { getProjects, createProject } from '@helpers/project';
import { hasProjectPermission } from '@middlewares/project';
import * as projectValidations from '@validations/project';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/', authenticate('jwt'), isAdmin, async (req, res) => {
  try {
    const projects = await getProjects();
    res.status(200).json({
      status: 200,
      message: 'Proyectos retornados de manera exitosa',
      projects
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/', authenticate('jwt'), hasProjectPermission, projectValidations.createProject, checkResult, async (req: any, res) => {
  try {
    req.body.responsable = req.user.id;
    req.body.institucion = req.user.user.institucion.id;
    const project = await createProject(req.body);
    res.status(200).json({
      status: 200,
      message: 'Proyecto creado de manera exitosa',
      project
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

export default router;