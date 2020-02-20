import { check } from 'express-validator';

export const createSuperuser = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isString().withMessage('Cedula invalida'),
  check('usuario.nombre_completo').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombre_de_usuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.rif').exists().withMessage('Debe incluir el rif del usuario').isString().withMessage('RIF invalido'),
  check('password').exists().withMessage('Debe incluir clave de administrador')
];

export const createAdmin = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isString().withMessage('Cedula invalida'),
  check('usuario.nombre_completo').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombre_de_usuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.rif').exists().withMessage('Debe incluir el rif del usuario').isString().withMessage('RIF invalido'),
  check('usuario.telefonos').exists().withMessage('Debe incluir los telefonos del usuario').isArray().withMessage('Telefonos invalidos'),
  check('password').exists().withMessage('Debe incluir clave de administrador')
];

export const createOfficial = createAdmin;

export const login = [
  check('username').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('password').exists().withMessage('Debe incluir la contraseña').isString().withMessage('Contraseña invalida')
];

