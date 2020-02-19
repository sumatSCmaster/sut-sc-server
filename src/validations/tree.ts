import { check } from 'express-validator';

export const updateTree = [
  check('tree').exists().withMessage('Debe incluir el arbol en string').isString().withMessage('Arbol invalido'),
  check('flat').exists().withMessage('Debe incluir el .flat() del arbol').isArray({ min: 1 }).withMessage('Array de .flat() invalido')
];