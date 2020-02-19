import { check, param, query } from 'express-validator';

export const createInvitation = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isString().withMessage('Cedula invalida'),
  check('usuario.nombre').exists().withMessage('Debe incluir el nombre del usuario').isString().withMessage('Nombre invalido'),
  check('usuario.correo').exists().withMessage('Debe incluir el correo del usuario').isEmail().withMessage('Correo invalido'),
  check('usuario.institucion').exists().withMessage('Debe incluir la institucion del usuario').isNumeric().withMessage('Institucion invalida'),
  check('usuario.oficina').exists().withMessage('Debe incluir la oficina del usuario').isNumeric().withMessage('Oficina invalida'),
  check('usuario.cargo').exists().withMessage('Debe incluir el cargo del usuario').isNumeric().withMessage('Cargo invalido'),
  check('usuario.rol').exists().withMessage('Debe incluir el rol del usuario').isNumeric().withMessage('Rol invalido')
];

export const idExists = [
  param('id').isNumeric().withMessage('ID de invitacion invalido en ruta')
];

export const acceptInvitation = [
  param('id').isNumeric().withMessage('ID de invitacion invalido en ruta'),
  check('usuario.token').exists().withMessage('Debe incluir el token de autorizacion').isString().withMessage('Token invalido'),
  check('usuario.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  check('usuario.username').exists().withMessage('Debe incluir el username del usuario').isString().withMessage('Username invalido'),
  check('usuario.password').exists().withMessage('Debe incluir el password del usuario').isString().withMessage('Password invalido')
];

export const redirect = [
  param('id').isNumeric().withMessage('ID de invitacion invalido en ruta'),
  query('token').exists().withMessage('Debe incluir el token como parametro query en la ruta').isString().withMessage('Token invalido')
];