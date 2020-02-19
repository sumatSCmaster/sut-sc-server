import { check, param } from 'express-validator';

export const idExists = [
  param('id').isNumeric().withMessage('ID de rol en ruta invalido')
];

export const createRole = [
  check('permisos').exists().withMessage('Debe incluir los permisos del rol a crear').isArray({ min: 1 })
  .withMessage('Debe ser asignado minimo un permiso en la creacion del rol'),
  check('nombre').exists().withMessage('Debe incluir el nombre del rol').isString().withMessage('Nombre de rol invalido')
];

export const editRole = [
  ...idExists,
  check('nombre').exists().withMessage('Debe incluir el nombre del rol').isString().withMessage('Nombre de rol invalido'),
  check('permisos').isArray({ min: 0 }).withMessage('Permisos invalidos')
];