import { check } from 'express-validator';

export const createAdmin = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isString().withMessage('Cedula invalida'),
  check('usuario.nombre').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.correo').exists().withMessage('Debe incluir el correo del usuario').isEmail().withMessage('Correo electronico invalido'),
  check('usuario.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  check('usuario.institucion').exists().withMessage('Debe incluir la institucion del usuario').isString().withMessage('Institucion invalida'),
  check('usuario.oficina').exists().withMessage('Debe incluir la oficina del usuario').isString().withMessage('Oficina invalida'),
  check('usuario.cargo').exists().withMessage('Debe incluir el cargo del usuario').isString().withMessage('Cargo invalido'),
  check('password').exists().withMessage('Debe incluir clave de administrador')
];

export const login = [
  check('username').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('password').exists().withMessage('Debe incluir la contraseña').isString().withMessage('Contraseña invalida')
];