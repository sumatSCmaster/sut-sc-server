import { check } from 'express-validator';

export const createProject = [
  check('nombre').exists().withMessage('Debe incluir el nombre del proyecto').isString().withMessage('Nombre invalido'),
  check('direccion').exists().withMessage('Debe incluir la direccion del proyecto').isString().withMessage('Direccion invalida'),
  check('parroquia').exists().withMessage('Debe incluir la parroquia en donde sera el proyecto').isNumeric().withMessage('Parroquia invalida'),
  check('longitud').exists().withMessage('Debe incluir la longitud del proyecto').isNumeric().withMessage('Longitud invalida'),
  check('latitud').exists().withMessage('Debe incluir la latitud del proyecto').isNumeric().withMessage('Latitud invalida'),
  check('duracionEstimada').exists().withMessage('Debe incluir la duracion estimada del proyecto').isNumeric().withMessage('Duracion invalida'),
  check('fechaInicio').exists().withMessage('Debe incluir la fecha de inicio del proyecto'),
  check('descripcion').exists().withMessage('Debe incluir la descripcion del proyecto').isString().withMessage('Descripcion invalida'),
  check('costoDolares').exists().withMessage('Debe incluir el costo en dolares del proyecto').isNumeric().withMessage('Costo en $ invalido'),
  check('costoBs').exists().withMessage('Debe incluir el costo en bolivares del proyecto').isNumeric().withMessage('Costo en Bs invalido'),
  check('poblacion').exists().withMessage('Debe incluir la poblacion del proyecto').isString().withMessage('Poblacion invalida'),
  check('cantidad').exists().withMessage('Debe incluir la cantidad de poblacion del proyecto').isNumeric().withMessage('Cantidad invalida'),
  check('archivos').exists().withMessage('Debe incluir los archivos del proyecto').isArray({ min: 1 }).withMessage('Archivos invalidos'),
  check('actividades').exists().withMessage('Debe incluir las actividades del proyecto').isArray({ min: 1 }).withMessage('Actividades invalidas')
];