import { check, param } from 'express-validator';
import e = require('express');

export const idExists = [
  param('idInst').isNumeric().withMessage('ID de institucion invalido en ruta')
];

export const createOffice = [
  ...idExists,
  check('nombre').exists().withMessage('Debe incluir el nombre de la oficina').isString().withMessage('Nombre de oficina invalido')
];

export const editOficina = [
  ...idExists,
  param('idOffice').isNumeric().withMessage('ID de oficina invalido en ruta'),
  check('nombre').exists().withMessage('Debe incluir el nuevo nombre de la oficina').isString().withMessage('Nombre de oficina invalido'),
  check('institucion').exists().withMessage('Debe incluir el id de la institucion').isNumeric().withMessage('ID institucion invalido')
];

export const deleteOffice = [
  ...idExists, 
  param('idOffice').isNumeric().withMessage('ID de oficina invalido en ruta'),
];