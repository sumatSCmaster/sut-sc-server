import { check, param } from "express-validator";

export const idExists = [
  param('id').isNumeric().withMessage('ID de tarea en ruta invalido')
];

export const createTask = [
  check('tarea.responsable').exists().withMessage('Debe incluir el responsable de la tarea').isString().withMessage('Cedula invalida'),
  check('tarea.fechaEntrega').exists().withMessage('Debe incluir la fecha de entrega').isNumeric().withMessage('Fecha invalida'),
  check('tarea.titulo').exists().withMessage('Debe incluir el titulo de la tarea').isString().withMessage('Titulo invalido'),
  check('tarea.descripcion').exists().withMessage('Debe incluir la descripcion de la tarea').isString().withMessage('Descripcion invalida')
];

export const editTask = [
  ...idExists,
  check('titulo').exists().withMessage('Debe incluir el titulo de la tarea').isString().withMessage('Titulo invalido'),
  check('descripcion').exists().withMessage('Debee incluir la descripcion de la tarea').isString().withMessage('Descripcion invalida')
]

export const editStatus = [
  ...idExists,
  check('status').exists().withMessage('Debe incluir el nuevo estado de la tarea').isNumeric().withMessage('Status invalido')
];

export const rateTask = [
  ...idExists,
  check('rating').exists().withMessage('Debe incluir el rating de la tarea').isNumeric().withMessage('Rating invalido')
];

export const createComment = [
  ...idExists,
  check('comentario.descripcion').exists().withMessage('Debe incluir la descripcion del comentario').isString().withMessage('Descripcion invalida')
];

export const editComment = [
  ...idExists,
  param('idComment').isNumeric().withMessage('ID de comentario en ruta invalido'),
  check('descripcion').exists().withMessage('Debe incluir la descripcion del comentario').isString().withMessage('Descripcion invalida')
];

export const deleteComment = [
  ...idExists,
  param('idComment').isNumeric().withMessage('ID de comentario en ruta invalido'),
];