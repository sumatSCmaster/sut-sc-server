import { check, param } from 'express-validator';

export const createInstitution = [
  check('nombre').exists().withMessage('Debe incluir el nombre de la institucion').isString().withMessage('Nombre de institucion invalido')
];

export const idExists = [
  param('id').isNumeric().withMessage('ID invalido en ruta')
];

export const editInstitution = [
  ...idExists,
  check('nombre').exists().withMessage('Debe incluir el nuevo nombre de la institucion').isString().withMessage('Nombre de institucion invalido')
];
