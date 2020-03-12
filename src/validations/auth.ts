import { check, validationResult } from 'express-validator';
import { fulfill } from '@utils/resolver';
import { getFieldsForValidations } from '@helpers/procedures';

const validations = {
  nombre: check('tramite.datos.nombre')
    .exists()
    .withMessage('Debe incluir el nombre del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El nombre no puede ser vacio'),
  cedula: check('tramite.datos.cedula')
    .exists()
    .withMessage('Debe incluir la cedula del usuario')
    .isInt()
    .withMessage('Cedula invalida'),
  direccion: check('tramite.datos.direccion')
    .exists()
    .withMessage('Debe incluir la direccion del usuario')
    .isString()
    .withMessage('Direccion invalida'),
  puntoReferencia: check('tramite.datos.puntoReferencia')
    .exists()
    .withMessage('Debe incluir un punto de referencia para la direccion del usuario')
    .isString()
    .withMessage('Punto de referencia invalido'),
  sector: check('tramite.datos.sector')
    .exists()
    .withMessage('Debe incluir un sector para la direccion del usuario')
    .isString()
    .withMessage('Sector invalido'),
  parroquia: check('tramite.datos.parroquia')
    .exists()
    .withMessage('Debe incluir una parroquia para la direccion del usuario')
    .isString()
    .withMessage('Parroquia invalida'),
  metrosCuadrados: check('tramite.datos.metrosCuadrados')
    .exists()
    .withMessage('Debe incluir los metros cuadrados de la residencia')
    .isInt()
    .withMessage('Metros cuadrados invalidos'),
  correo: check('tramite.datos.correo')
    .exists()
    .withMessage('Debe incluir el correo del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El correo no puede ser vacio'),
  contacto: check('tramite.datos.contacto')
    .exists()
    .withMessage('Debe incluir el contacto del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El contacto no puede ser vacio'),
  horario: check('tramite.datos.horario')
    .exists()
    .withMessage('Debe incluir el horario disponible para la inspeccion')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El horario es invalido'),
  cedulaORif: check('tramite.datos.cedulaORif')
    .exists()
    .withMessage('Debe incluir la cedula o rif del usuario'),
  nombreORazon: check('tramite.datos.nombreORazon')
    .exists()
    .withMessage('Debe incluir el nombre o razon social del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El nombre o razon social no puede ser vacio'),
  telefono: check('tramite.datos.telefono')
    .exists()
    .withMessage('Debe incluir la cedula del usuario')
    .isInt()
    .withMessage('Cedula invalida'),
  recaudos: check('tramite.recaudos')
    .exists()
    .withMessage('Debe incluir los recaudos')
    .isArray()
    .isLength({ min: 1 })
    .withMessage('Debe poseer al menos un archivo de recaudos'),
  ubicadoEn: check('tramite.datos.ubicadoEn')
    .exists()
    .withMessage('Debe incluir la ubicacion')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir una ubicacion valida'),
  rif: check('tramite.datos.rif')
    .exists()
    .withMessage('Debe incluir el rif de la ubicacion')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir un rif valido'),
  razonSocial: check('tramite.datos.rif')
    .exists()
    .withMessage('Debe incluir la razon social')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir una razon social valida'),
  tipoOcupacion: check('tramite.datos.tipoOcupacion')
    .exists()
    .withMessage('Debe incluir el tipo de ocupacion del establecimiento')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir un tipo de ocupacion del establecimiento'),
  areaConstruccion: check('tramite.datos.areaConstruccion')
    .exists()
    .withMessage('Debe incluir el area de construccion')
    .isInt()
    .withMessage('Area de construccion invalida'),
  numeroProyecto: check('tramite.datos.numeroProyecto')
    .exists()
    .withMessage('Debe incluir el numero del proyecto')
    .isInt()
    .withMessage('Debe incluir un numero de proyecto valido'),
  fechaAprobacion: check('tramite.datos.fechaAprobacion')
    .exists()
    .withMessage('Debe incluir la fecha de aprobacion del proyecto')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir una fecha de aprobacion valida'),
  codigoPermisoConstruccion: check('tramite.datos.codigoPermisoConstruccion')
    .exists()
    .withMessage('Debe incluir el codigo de permiso de construccion del proyecto')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir un codigo de permiso de construcion valido'),
  fechaPermisoConstruccion: check('tramite.datos.fechaPermisoConstruccion')
    .exists()
    .withMessage('Debe incluir la fecha del permiso de construccion')
    .isString()
    .isLength({ min: 1 })
    .withMessage('Debe incluir una fecha de permiso de construccion valida'),
};

export const createSuperuser = [
  check('usuario.cedula')
    .exists()
    .withMessage('Debe incluir la cedula del usuario')
    .isInt()
    .withMessage('Cedula invalida'),
  check('usuario.nombreCompleto')
    .exists()
    .withMessage('Debe incluir el nombre del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario')
    .exists()
    .withMessage('Debe incluir el nombre de usuario')
    .isString()
    .withMessage('Nombre de usuario invalido'),
  check('usuario.direccion')
    .exists()
    .withMessage('Debe incluir la direccion del usuario')
    .isString()
    .withMessage('Direccion invalida'),
  check('usuario.nacionalidad')
    .exists()
    .withMessage('Debe incluir la nacionalidad del usuario')
    .isString()
    .withMessage('Nacionalidad invalida'),
  check('usuario.institucion')
    .exists()
    .withMessage('Debe especificar la institucion del usuario')
    .isNumeric()
    .withMessage('ID de institucion invalido'),
  check('usuario.password')
    .exists()
    .withMessage('Debe incluir clave del superusuario a crear'),
  check('password')
    .exists()
    .withMessage('Debe incluir clave de creacion de superuser'),
];

export const createAdmin = [
  check('usuario.cedula')
    .exists()
    .withMessage('Debe incluir la cedula del usuario')
    .isInt()
    .withMessage('Cedula invalida'),
  check('usuario.nombreCompleto')
    .exists()
    .withMessage('Debe incluir el nombre del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario')
    .exists()
    .withMessage('Debe incluir el nombre de usuario')
    .isString()
    .withMessage('Nombre de usuario invalido'),
  check('usuario.direccion')
    .exists()
    .withMessage('Debe incluir la direccion del usuario')
    .isString()
    .withMessage('Direccion invalida'),
  check('usuario.nacionalidad')
    .exists()
    .withMessage('Debe incluir la nacionalidad del usuario')
    .isString()
    .withMessage('Nacionalidad invalida'),
  check('usuario.telefono')
    .exists()
    .withMessage('Debe incluir el telefono del usuario')
    .isString()
    .withMessage('Telefono invalido'),
  check('usuario.institucion')
    .exists()
    .withMessage('Debe especificar la institucion del usuario')
    .isNumeric()
    .withMessage('ID de institucion invalido'),
  check('usuario.password')
    .exists()
    .withMessage('Debe incluir clave de administrador'),
];

export const createOfficial = [
  check('usuario.cedula')
    .exists()
    .withMessage('Debe incluir la cedula del usuario')
    .isInt()
    .withMessage('Cedula invalida'),
  check('usuario.nombreCompleto')
    .exists()
    .withMessage('Debe incluir el nombre del usuario')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario')
    .exists()
    .withMessage('Debe incluir el nombre de usuario')
    .isString()
    .withMessage('Nombre de usuario invalido'),
  check('usuario.direccion')
    .exists()
    .withMessage('Debe incluir la direccion del usuario')
    .isString()
    .withMessage('Direccion invalida'),
  check('usuario.nacionalidad')
    .exists()
    .withMessage('Debe incluir la nacionalidad del usuario')
    .isString()
    .withMessage('Nacionalidad invalida'),
  check('usuario.telefono')
    .exists()
    .withMessage('Debe incluir el telefono del usuario')
    .isString()
    .withMessage('Telefono invalido'),
  check('usuario.password')
    .exists()
    .withMessage('Debe incluir una contraseña para el usuario'),
];

export const updateOfficial = createOfficial.slice(0, createOfficial.length - 1);

export const login = [
  check('nombreUsuario')
    .exists()
    .withMessage('Debe incluir el nombre de usuario')
    .isString()
    .withMessage('Nombre de usuario invalido'),
  check('password')
    .exists()
    .withMessage('Debe incluir la contraseña')
    .isString()
    .withMessage('Contraseña invalida'),
];

export const validate = () => {
  return async (req, res, next) => {
    const validaciones = await isValidProcedure(req, res);
    await Promise.all(validaciones.map(validation => validation.run(req)));
    next();
  };
};
const isValidProcedure = async (req, res) => {
  const [error, data] = await fulfill(getFieldsForValidations(req.body.tramite.tipoTramite, req.body.tramite.estado || 'iniciado'));
  if (error) res.status(error.status).json(error);
  if (data) {
    const arr = data.fields.map(el => validations[el.validacion]);
    if (data.takings > 0) arr.push(validations['recaudos']);
    return arr;
  }
};

export const isLogged = (req, res, next) => {
  if (req.isAuthenticated()) {
    res.send({
      status: 304,
      response: 'Ya existe una sesión',
    });
  } else {
    next();
  }
};

export const isAuth = (req, res, next) => {
  if (req.isAuthenticated()) {
    next();
  } else {
    res.send({
      status: 400,
      response: 'Debe iniciar sesión primero',
    });
  }
};

export const isOfficial = (req, res, next) => {
  if (req.user.tipoUsuario < 4) next();
  else {
    res.send({
      status: 401,
      response: 'No tiene permisos para realizar esta operación',
    });
  }
};

export const isExternalUser = (req, res, next) => {
  if (req.user.tipoUsuario === 4) next();
  else {
    res.send({
      status: 401,
      response: 'Sólo los usuarios externos pueden realizar esta operación',
    });
  }
};
