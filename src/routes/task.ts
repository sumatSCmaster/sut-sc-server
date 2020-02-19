import { Router } from 'express';
import { authenticate } from 'passport';
import { getUserTasks, createTask, getSentTasks, deleteTask, createTaskComment, changeTaskStatus, editTask, getRatePendingTasks, 
  rateTask, editComment, deleteComment } from '@helpers/task';
import { hasTaskPermission, isUnderInTree, isTaskSender, canComment, isCommentOwner, isTaskReceiverOrSender } from '@middlewares/task';
import * as taskValidations from '@validations/task';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  try {
    const tasks = await getUserTasks(req.user.id);
    res.status(200).json({
      status: 200,
      message: 'Tareas retornadas de manera exitosa.',
      tasks
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/', authenticate('jwt'), taskValidations.createTask, checkResult, hasTaskPermission, isUnderInTree, async (req: any, res) => {
  try {
    req.body.tarea.emisor = req.user.id;
    const task = await createTask(req.body.tarea);
    res.status(200).json({
      status: 200,
      message: 'Tarea creada exitosamente.',
      task
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/sent', authenticate('jwt'), async (req: any, res) => {
  try {
    const tasks = await getSentTasks(req.user.id);
    res.status(200).json({
      status: 200,
      message: 'Tareas retornadas de manera exitosa.',
      tasks
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:id', authenticate('jwt'), taskValidations.idExists, checkResult, isTaskSender, async (req, res) => {
  try {
    const id = await deleteTask(parseInt(req.params.id));
    res.status(200).json({
      status: 200,
      message: 'Tarea eliminada exitosamente',
      id
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id', authenticate('jwt'), taskValidations.editTask, checkResult, isTaskSender, async (req, res) => {
  try {
    const task = await editTask(parseInt(req.params.id), req.body.titulo, req.body.descripcion);
    if(task) {
      res.status(200).json({
        status: 200,
        message: 'Tarea editada exitosamente',
        task
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Tarea con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id/status', authenticate('jwt'), taskValidations.editStatus, checkResult, isTaskReceiverOrSender, async (req, res) => {
  try {
    const id = await changeTaskStatus(parseInt(req.params.id), req.body.status);
    if(id) {
      res.status(200).json({
        status: 200,
        message: 'Status editado de manera exitosa',
        id
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Tarea con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/toRate', authenticate('jwt'), async (req: any, res) => {
  try {
    const tasks = await getRatePendingTasks(req.user.id);
    res.status(200).json({
      status: 200,
      message: 'Tareas pendientes por calificar retornadas de manera exitosa.',
      tasks
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id/rate', authenticate('jwt'), taskValidations.rateTask, checkResult, isTaskSender, async (req, res) => {
  try {
    const rate = await rateTask(parseInt(req.params.id), parseFloat(req.body.rating));
    if(rate) {
      res.status(200).json({
        status: 200,
        message: 'Tarea calificada de manera exitosa.',
        rate
      });
    } else {
      res.status(409).json({
        status: 409,
        message: 'La tarea ya ha sido calificada.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/:id/comment', authenticate('jwt'), taskValidations.createComment, checkResult, canComment, async (req: any, res) => {
  try {
    req.body.comentario.emisor = req.user.id;
    req.body.comentario.target = parseInt(req.params.id);
    const comment = await createTaskComment(req.body.comentario);
    if(comment) {
      res.status(200).json({
        status: 200,
        message: 'Comentario creado exitosamente',
        comment
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Tarea con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/:id/comment/:idComment', authenticate('jwt'), taskValidations.editComment, checkResult, isCommentOwner, async (req, res) => {
  try {
    const comment = await editComment(parseInt(req.params.idComment), req.body.descripcion);
    if(comment) {
      res.status(200).json({
        status: 200,
        message: 'Comentario editado exitosamente',
        comment
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Comentario con id ${req.params.idComment} no encontrado.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:id/comment/:idComment', authenticate('jwt'), taskValidations.deleteComment, checkResult, isCommentOwner, async (req, res) => {
  try {
    const comment = await deleteComment(parseInt(req.params.idComment));
    if(comment) {
      res.status(200).json({
        status: 200,
        message: 'Comentario eliminado de manera exitosa.',
        comment
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Comentario con id ${req.params.idComment} no encontrado.`
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