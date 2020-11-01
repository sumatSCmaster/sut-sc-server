import { check, validationResult } from 'express-validator';
import { fulfill } from '@utils/resolver';
import { getFieldsForValidations } from '@helpers/procedures';
import { IDsTipoUsuario as userTypes } from '@interfaces/sigt';
import { Pool } from 'pg';

const estimacionSimple = [
  check('tramite.datos.estimacionSimple').exists().withMessage('Debe incluir la estimacion simple'),
  check('tramite.datos.estimacionSimple.esTerreno').exists().withMessage('Debe indicar si el inmueble es terreno').isBoolean().withMessage('Indicador de terreno invalido'),
  check('tramite.datos.estimacionSimple.esConstruccion').exists().withMessage('Debe indicar si el inmueble es construccion').isBoolean().withMessage('Indicador de construccion invalido'),
  check('tramite.datos.estimacionSimple.valoresFiscales').exists().withMessage('Debe incluir los valores fiscales del inmueble').isArray().isLength({ min: 1, max: 4 }).withMessage('Debe incluir valores fiscales validos'),
  check('tramite.datos.estimacionSimple.terreno').optional().if(check('tramite.datos.estimacionSimple.esTerreno').exists()).not().isEmpty().withMessage('Debe incluir los datos del terreno'),
  // .contains([
  //   check('area')
  //     .exists()
  //     .withMessage('Debe incluir el area del terreno')
  //     .isString()
  //     .withMessage('Debe incluir un area del terreno valida'),
  //   check('sector')
  //     .exists()
  //     .withMessage('Debe incluir el sector del terreno')
  //     .isInt()
  //     .withMessage('Debe incluir un sector del terreno valida'),
  //   check('valorSector')
  //     .exists()
  //     .withMessage('Debe incluir el valor fiscal del sector')
  //     .isString()
  //     .withMessage('Debe incluir un valor fiscal valido para el sector'),
  // ]),
  check('tramite.datos.estimacionSimple.construccion').optional().if(check('tramite.datos.estimacionSimple.esConstruccion').exists()).not().isEmpty().withMessage('Debe incluir los datos del terreno'),
  // .contains([
  //   check('area')
  //     .exists()
  //     .withMessage('Debe incluir el area de construccion')
  //     .isString()
  //     .withMessage('Debe incluir un area de construccion valida'),
  //   check('sector')
  //     .exists()
  //     .withMessage('Debe incluir el secior del construccion')
  //     .isInt()
  //     .withMessage('Debe incluir un sector del construccion valida'),
  //   check('valorSector')
  //     .exists()
  //     .withMessage('Debe incluir el valor fiscal del sector')
  //     .isString()
  //     .withMessage('Debe incluir un valor fiscal valido para el sector'),
  // ]),
];

const validations = {
  nombre: check('tramite.datos.nombre').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  cedula: check('tramite.datos.cedula').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  direccion: check('tramite.datos.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  puntoReferencia: check('tramite.datos.puntoReferencia').exists().withMessage('Debe incluir un punto de referencia para la direccion del usuario').isString().withMessage('Punto de referencia invalido'),
  sector: check('tramite.datos.sector').exists().withMessage('Debe incluir un sector para la direccion del usuario').isString().withMessage('Sector invalido'),
  parroquia: check('tramite.datos.parroquia').exists().withMessage('Debe incluir una parroquia para la direccion del usuario').isString().withMessage('Parroquia invalida'),
  metrosCuadrados: check('tramite.datos.metrosCuadrados').exists().withMessage('Debe incluir los metros cuadrados de la residencia').isInt().withMessage('Metros cuadrados invalidos'),
  correo: check('tramite.datos.correo').exists().withMessage('Debe incluir el correo del usuario').isString().isLength({ min: 1 }).withMessage('El correo no puede ser vacio'),
  contacto: check('tramite.datos.contacto').exists().withMessage('Debe incluir el contacto del usuario').isString().isLength({ min: 1 }).withMessage('El contacto no puede ser vacio'),
  horario: check('tramite.datos.horario').exists().withMessage('Debe incluir el horario disponible para la inspeccion').isString().isLength({ min: 1 }).withMessage('El horario es invalido'),
  cedulaORif: check('tramite.datos.cedulaORif').exists().withMessage('Debe incluir la cedula o rif del usuario'),
  nombreORazon: check('tramite.datos.nombreORazon').exists().withMessage('Debe incluir el nombre o razon social del usuario').isString().isLength({ min: 1 }).withMessage('El nombre o razon social no puede ser vacio'),
  telefono: check('tramite.datos.telefono').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  recaudos: check('tramite.recaudos').exists().withMessage('Debe incluir los recaudos').isArray().isLength({ min: 1 }).withMessage('Debe poseer al menos un archivo de recaudos'),
  ubicadoEn: check('tramite.datos.ubicadoEn').exists().withMessage('Debe incluir la ubicacion').isString().isLength({ min: 1 }).withMessage('Debe incluir una ubicacion valida'),
  rif: check('tramite.datos.rif').exists().withMessage('Debe incluir el rif de la ubicacion').isString().isLength({ min: 1 }).withMessage('Debe incluir un rif valido'),
  razonSocial: check('tramite.datos.razonSocial').exists().withMessage('Debe incluir la razon social').isString().isLength({ min: 1 }).withMessage('Debe incluir una razon social valida'),
  tipoOcupacion: check('tramite.datos.tipoOcupacion').exists().withMessage('Debe incluir el tipo de ocupacion del establecimiento').isString().isLength({ min: 1 }).withMessage('Debe incluir un tipo de ocupacion del establecimiento'),
  areaConstruccion: check('tramite.datos.areaConstruccion').exists().withMessage('Debe incluir el area de construccion').isInt().withMessage('Area de construccion invalida'),
  numeroProyecto: check('tramite.datos.numeroProyecto').exists().withMessage('Debe incluir el numero del proyecto').isInt().withMessage('Debe incluir un numero de proyecto valido'),
  fechaAprobacion: check('tramite.datos.fechaAprobacion').exists().withMessage('Debe incluir la fecha de aprobacion del proyecto').isString().isLength({ min: 1 }).withMessage('Debe incluir una fecha de aprobacion valida'),
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
  nombreObra: check('tramite.datos.nombreObra').exists().withMessage('Debe incluir el nombre de obra de la construccion').isString().isLength({ min: 1 }).withMessage('Debe incluir un nombre de obra de la construccion valido'),
  aforo: check('tramite.datos.aforo').exists().withMessage('Debe incluir el aforo de la ubicacion').isString().withMessage('Debe incluir un aforo valido'),
  informe: check('tramite.datos.informe').exists().withMessage('Debe incluir el informe de la inspeccion').isString().isLength({ min: 1 }).withMessage('Debe incluir un informe de la inspeccion valido'),
  observaciones: check('tramite.datos.observaciones').optional().isString().withMessage('Debe incluir observaciones validas'),
  parroquiaEdificio: check('tramite.datos.parroquiaEdificio').exists().withMessage('Debe incluir la parroquia del edificio').isString().isLength({ min: 1 }).withMessage('Parroquia del edificio invalida'),
  tipoInmueble: check('tramite.datos.tipoInmueble').exists().withMessage('Debe incluir el tipo del inmueble').isString().isLength({ min: 1 }).withMessage('Tipo del inmueble invalido'),
  propietarios: check('tramite.datos.propietarios').exists().withMessage('Debe incluir los propietarios del inmueble').isArray().isLength({ min: 1 }).withMessage('Debe incluir al menos un propietario de este inmueble'),
  nombreConjunto: check('tramite.datos.nombreConjunto').exists().withMessage('Debe incluir el nombre del conjunto del inmueble').isString().isLength({ min: 1 }).withMessage('El nombre de conjunto no puede ser vacio'),
  cantidadEdificios: check('tramite.datos.cantidadEdificios').exists().withMessage('Debe incluir la cantidad de edificios del conjunto del inmueble').isInt().withMessage('Debe incluir una cantidad de edificios valida'),
  nombreEdificio: check('tramite.datos.nombreEdificio').exists().withMessage('Debe incluir el nombre del edificio al que pertenece el inmueble').isString().isLength({ min: 1 }).withMessage('El nombre del edificio no puede ser vacio'),
  cantidadPisos: check('tramite.datos.cantidadPisos').exists().withMessage('Debe incluir la cantidad de pisos del edificio').isInt().withMessage('Debe incluir una cantidad de pisos valida'),
  pisoApto: check('tramite.datos.pisoApto').exists().withMessage('Debe incluir el piso donde esta ubicado el inmueble').isInt().withMessage('Debe incluir un numero de piso valido para el inmueble'),
  cantidadAptosPiso: check('tramite.datos.cantidadAptosPiso').exists().withMessage('Debe incluir la cantidad de apartamentos por piso del edificio').isInt().withMessage('Debe incluir una cantidad de apartamentos por piso valida'),
  numeroApto: check('tramite.datos.numeroApto').exists().withMessage('Debe incluir el numero de apartamento del inmueble').isString().isLength({ min: 1 }).withMessage('El numero de apartamento no puede ser vacio'),
  nomenclaturaEdificio: check('tramite.datos.nomenclaturaEdificio').exists().withMessage('Debe incluir la nomenclatura del edificio').isString().isLength({ min: 1 }).withMessage('La nomenclatura del edificio no puede ser vacia'),
  ubicacionEdificio: check('tramite.datos.ubicacionEdificio').exists().withMessage('Debe incluir la ubicacion del edificio').isString().isLength({ min: 1 }).withMessage('La ubicacion del edificio no puede ser vacia'),
  datosRegistro: check('tramite.datos.datosRegistro').exists().withMessage('Debe incluir los datos de registro del inmueble').isString().isLength({ min: 1 }).withMessage('Los datos de registro no pueden ser vacios'),
  circuito: check('tramite.datos.circuito').exists().withMessage('Debe incluir el circuito del inmueble').isString().isLength({ min: 1 }).withMessage('El circuito del inmueble no puede ser vacio'),
  areaTerreno: check('tramite.datos.areaTerreno').exists().withMessage('Debe incluir el area del terreno del inmueble').isInt().withMessage('Debe incluir un area del terreno del inmueble valida'),
  plano: check('tramite.datos.plano').exists().withMessage('Debe incluir el plano del inmueble').isString().isLength({ min: 1 }).withMessage('El plano del inmueble no puede ser vacio'),
  codCat: check('tramite.datos.codCat').exists().withMessage('Debe incluir el codigo catastral del inmueble').isString().isLength({ min: 1 }).withMessage('El codigo catastral no puede ser vacio'),
  croquis: check('tramite.datos.croquis').exists().withMessage('Debe incluir el croquis del inmueble').isString().isLength({ min: 1 }).withMessage('El croquis no puede ser vacio'),
  tipoInmuebleSolvencia: check('tramite.datos.tipoInmuebleSolvencia').exists().withMessage('Debe incluir el tipo del inmueble para la solvencia').isString().isLength({ min: 1 }).withMessage('El tipo de inmueble para la solvencia no puede ser vacio'),
  modeloConstruccion: check('tramite.datos.modeloConstruccion')
    .exists()
    .withMessage('Debe incluir el modelo de construccion para la solvencia')
    .isString()
    .isLength({ min: 1 })
    .withMessage('El modelo de construccion para la solvencia no puede ser vacio'),
  valorFiscal: check('tramite.datos.valorFiscal').exists().withMessage('Debe incluir los valores fiscales del terreno para la solvencia').isArray().isLength({ min: 1 }).withMessage('Debe incluir al menos un valor fiscal para este inmueble'),
  estimacionSimple: check('tramite.datos.estimacionSimple').exists().withMessage('Debe incluir la estimacion simple'),
  destino: check('tramite.datos.destino').exists().withMessage('Debe incluir el destino').isString().isLength({ min: 1 }).withMessage('El destino no puede ser vacio'),
  fechaHora: check('tramite.datos.fechaHora').exists().withMessage('Debe incluir la fecha y hora').isString().isLength({ min: 1 }).withMessage('La fecha y hora no puede ser vacia'),
  numeroBohio: check('tramite.datos.numeroBohio').optional().isInt().isLength({ min: 1 }).withMessage('Debe incluir un numero de bohio valido'),
  detallesBohio: check('tramite.datos.detallesBohio').optional().isString().isLength({ min: 1 }).withMessage('Debe incluir un detalle de bohio valido'),
  fechaApartado: check('tramite.datos.fechaApartado').exists().withMessage('Debe incluir la fecha para apartar').isString().isLength({ min: 1 }).withMessage('La fecha para apartar no puede ser vacia'),
  numeroBohioFunc: check('tramite.datos.numeroBohioFunc').exists().withMessage('Debe incluir el numero de bohio').isInt().isLength({ min: 1 }).withMessage('Debe incluir un numero de bohio valido'),
  nombreOrganizacion: check('tramite.datos.nombreOrganizacion').exists().withMessage('Debe incluir el nombre de la organizacion').isString().isLength({ min: 1 }).withMessage('El nombre de la organizacion no puede ser vacio'),
  tipoSociedad: check('tramite.datos.tipoSociedad').exists().withMessage('Debe incluir el tipo de sociedad').isString().isLength({ min: 1 }).withMessage('El tipo de sociedad no puede ser vacio'),
  tipoTransporte: check('tramite.datos.tipoTransporte').exists().withMessage('Debe incluir el tipo de transporte').isString().isLength({ min: 1 }).withMessage('El tipo de transporte no puede ser vacio'),
  nombreRepresentante: check('tramite.datos.nombreRepresentante').exists().withMessage('Debe incluir el nombre del representante').isString().isLength({ min: 1 }).withMessage('El nombre del representante no puede ser vacio'),
  cedulaRepresentante: check('tramite.datos.cedulaRepresentante').exists().withMessage('Debe incluir la cedula del representante').isInt().isLength({ min: 1 }).withMessage('Debe incluir una cedula valida para el representante'),
  telefonoRepresentante: check('tramite.datos.telefonoRepresentante')
    .exists()
    .withMessage('Debe incluir el numero de telefono del representante')
    .isInt()
    .isLength({ min: 1 })
    .withMessage('Debe incluir un numero de telefono valido para el representante'),
  finalidad: check('tramite.datos.finalidad').exists().withMessage('Debe incluir la finalidad').isString().isLength({ min: 1 }).withMessage('La finalidad no puede ser vacia'),
  frente: check('tramite.datos.frente').optional().isString().withMessage('El frente no puede ser vacio'),
  linderoFrente: check('tramite.datos.linderoFrente').exists().withMessage('Debe incluir el lindero del frente').isString().isLength({ min: 1 }).withMessage('El lindero del frente no puede ser vacio'),
  linderoFondo: check('tramite.datos.linderoFondo').exists().withMessage('Debe incluir el lindero del fondo').isString().isLength({ min: 1 }).withMessage('El lindero del fondo no puede ser vacio'),
  linderoDerecha: check('tramite.datos.linderoDerecha').exists().withMessage('Debe incluir el lindero de la derecha').isString().isLength({ min: 1 }).withMessage('El lindero de la derecha no puede ser vacio'),
  linderoIzquierda: check('tramite.datos.linderoIzquierda').exists().withMessage('Debe incluir el lindero de la izquierda').isString().isLength({ min: 1 }).withMessage('El lindero de la izquierda no puede ser vacio'),
  sitio: check('tramite.datos.sitio').exists().withMessage('Debe incluir el sitio').isString().isLength({ min: 1 }).withMessage('El sitio no puede ser vacio'),
  codigoNomenclatura: check('tramite.datos.codigoNomenclatura').exists().withMessage('Debe incluir el codigo de nomenclatura'),
  numeroPlaca: check('tramite.datos.numeroPlaca').exists().withMessage('Debe incluir el numero de la placa').isString().isLength({ min: 1 }).withMessage('El numero de placa no puede ser vacio'),
  denominacion: check('tramite.datos.denominacion').exists().withMessage('Debe incluir la denominacion del inmueble').isString().isLength({ min: 1 }).withMessage('La denominacion no puede ser vacia'),
  actividadComercial: check('tramite.datos.actividadComercial').exists().withMessage('Debe incluir la actividad comercial').isString().isLength({ min: 1 }).withMessage('La actvividad comercial no puede ser vacia'),
  direccionInmueble: check('tramite.datos.direccionInmueble').exists().withMessage('Debe incluir la direccion del inmueble').isString().isLength({ min: 1 }).withMessage('La direccion del inmueble no puede ser vacia'),
  parroquiaInmueble: check('tramite.datos.parroquiaInmueble').exists().withMessage('Debe incluir la parroquia del inmueble').isString().isLength({ min: 1 }).withMessage('La parroquia del inmueble no puede ser vacia'),
  telefonoInmueble: check('tramite.datos.telefonoInmueble').exists().withMessage('Debe incluir el telefono del inmueble').isString().isLength({ min: 1 }).withMessage('El telefono del inmueble no puede ser vacio'),
  correoInmueble: check('tramite.datos.correoInmueble').exists().withMessage('Debe incluir el correo del inmueble').isString().isLength({ min: 1 }).withMessage('El correo del inmueble no puede ser vacio'),
  nombreInstitucion: check('tramite.datos.nombreInstitucion').exists().withMessage('Debe incluir el nombre de la institucion').isString().isLength({ min: 1 }).withMessage('El nombre de la institucion no puede ser vacio'),
  representanteInstitucion: check('tramite.datos.representanteInstitucion').exists().withMessage('Debe incluir el representante de la institucion').isString().isLength({ min: 1 }).withMessage('El representante de la institucion no puede ser vacio'),
  turno: check('tramite.datos.turno').exists().withMessage('Debe incluir el turno').isString().isLength({ min: 1 }).withMessage('El turno no puede ser vacio'),
  nivelEducativo: check('tramite.datos.nivelEducativo').exists().withMessage('Debe incluir el nivel educativo').isString().isLength({ min: 1 }).withMessage('El nivel educativo no puede ser vacio'),
  direccionPlantel: check('tramite.datos.direccionPlantel').exists().withMessage('Debe incluir la direccion del plantel').isString().isLength({ min: 1 }).withMessage('La direccion del plantel no puede ser vacia'),
  direccionEmpresa: check('tramite.datos.direccionEmpresa').exists().withMessage('Debe incluir la direccion de la empresa').isString().isLength({ min: 1 }).withMessage('La direccion de la empresa no puede ser vacia'),
  parroquiaEmpresa: check('tramite.datos.parroquiaEmpresa').exists().withMessage('Debe incluir la parroquia de la empresa').isString().isLength({ min: 1 }).withMessage('La parroquia de la empresa no puede ser vacia'),
  telefonoEmpresa: check('tramite.datos.telefonoEmpresa').exists().withMessage('Debe incluir el telefono de la empresa').isString().isLength({ min: 1 }).withMessage('El telefono de la empresa no puede ser vacio'),
  correoEmpresa: check('tramite.datos.correoEmpresa').exists().withMessage('Debe incluir el correo de la empresa').isString().isLength({ min: 1 }).withMessage('El correo de la empresa no puede ser vacio'),
  nombreEmpresaComercio: check('tramite.datos.nombreEmpresaComercio').exists().withMessage('Debe incluir el nombre de la empresa o comercio').isString().isLength({ min: 1 }).withMessage('El nombre de la empresa o comercio no puede ser vacio'),
  distribucion: check('tramite.datos.distribucion').exists().withMessage('Debe incluir la distribucion').isArray().isLength({ min: 1 }).withMessage('Debe incluir una distribucion valida'),
  planoConstruccion: check('tramite.datos.planoConstruccion').exists().withMessage('Debe incluir el plano de construccion').isString().isLength({ min: 1 }).withMessage('El plano de construccion no puede ser vacio'),
  metrosCuadradosConstruccion: check('tramite.datos.metrosCuadradosConstruccion')
    .exists()
    .withMessage('Debe incluir los metros cuadrados de la construccion')
    .isNumeric()
    .isLength({ min: 1 })
    .withMessage('Debe incluir metros cuadrados validos para la construccion'),
  usoConforme: check('tramite.datos.usoConforme').exists().withMessage('Debe incluir el uso conforme').isString().isLength({ min: 1 }).withMessage('El uso conforme no puede ser vacio'),
  denominacionComercial: check('tramite.datos.denominacionComercial').exists().withMessage('Debe incluir la denominacion comercial').isString().isLength({ min: 1 }).withMessage('La denominacion comercial no puede ser vacia'),
  siglas: check('tramite.datos.siglas').optional(),
  tipoContribuyente: check('tramite.datos.tipoContribuyente').exists().withMessage('Debe incluir el tipo de contribuyente').isString().isLength({ min: 1 }).withMessage('El tipo de contribuyente no puede ser vacio'),
  documentoIdentidad: check('tramite.datos.documentoIdentidad').exists().withMessage('Debe incluir el documento de identidad').isString().isLength({ min: 1 }).withMessage('El documento de identidad no puede ser vacio'),
  actividadesEconomicas: check('tramite.datos.actividadesEconomicas').exists().withMessage('Debe incluir las actividades economicas').isArray().isLength({ min: 1 }).withMessage('Debe poseer al menos una actividad economica'),
  capitalSuscrito: check('tramite.datos.capitalSuscrito').exists().withMessage('Debe incluir el capital suscrito').isInt().isLength({ min: 1 }).withMessage('El capital suscrito no puede ser vacio'),
  tipoSociedadContrib: check('tramite.datos.tipoSociedadContrib').exists().withMessage('Debe incluir el tipo de sociedad del contribuyente').isString().isLength({ min: 1 }).withMessage('El tipo de sociedad del contribuyente no puede ser vacio'),
  estadoLicencia: check('tramite.datos.estadoLicencia').exists().withMessage('Debe incluir el estado de la licencia').isString().isLength({ min: 1 }).withMessage('El estado de la licencia no puede ser vacio'),
};

export const createSuperuser = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  check('usuario.nombreCompleto').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.institucion').exists().withMessage('Debe especificar la institucion del usuario').isNumeric().withMessage('ID de institucion invalido'),
  check('usuario.password').exists().withMessage('Debe incluir clave del superusuario a crear'),
  check('password').exists().withMessage('Debe incluir clave de creacion de superuser'),
];

export const createAdmin = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  check('usuario.nombreCompleto').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  check('usuario.institucion').exists().withMessage('Debe especificar la institucion del usuario').isNumeric().withMessage('ID de institucion invalido'),
  check('usuario.password').exists().withMessage('Debe incluir clave de administrador'),
];

export const createOfficial = [
  check('usuario.cedula').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  check('usuario.nombreCompleto').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  // check('usuario.tipoUsuario')
  //   .exists()
  //   .withMessage('Debe incluir el tipo de usuario')
  //   .isNumeric()
  //   .withMessage('Tipo usuario debe ser un valor numerico'),
  check('usuario.password').exists().withMessage('Debe incluir una contraseña para el usuario'),
];

export const updateUserV = [
  check('usuario.documento').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  check('usuario.nombreCompleto').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('usuario.nombreUsuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('usuario.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('usuario.tipoDocumento').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('usuario.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  // check('usuario.tipoUsuario')
  //   .exists()
  //   .withMessage('Debe incluir el tipo de usuario')
  //   .isNumeric()
  //   .withMessage('Tipo usuario debe ser un valor numerico'),
  // check('usuario.password').exists().withMessage('Debe incluir una contraseña para el usuario'),
];

export const updateRIM = [
  check('capitalSuscrito').exists().withMessage('Debe incluir el capital suscrito').isInt().isLength({ min: 1 }).withMessage('El capital suscrito no puede ser vacio'),
  check('tipoSociedad').exists().withMessage('Debe incluir el tipo de sociedad').isString().isLength({ min: 1 }).withMessage('Tipo de sociedad invalido'),
  check('direccion').exists().withMessage('Debe incluir la direccion del contribuyente').isString().isLength({ min: 1 }).withMessage('Direccion invalida'),
  check('nombreRepresentante').exists().withMessage('Debe incluir el nombre del representante').isString().isLength({ min: 1 }).withMessage('Nombre del representante invalido'),
  check('denomComercial').exists().withMessage('Debe incluir la denominacion comercial de la sucursal').isString().withMessage('Denominacion comercial invalida'),
  check('email').exists().withMessage('Debe incluir el email de la sucursal').isString().isLength({ min: 1 }).withMessage('Email invalido'),
  check('telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  check('parroquia').exists().withMessage('Debe incluir una parroquia para la direccion del usuario').isString().isLength({ min: 1 }).withMessage('Parroquia invalida'),
];

export const updateOfficial = createOfficial.slice(0, createOfficial.length - 1);

export const login = [
  check('nombreUsuario').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('password').exists().withMessage('Debe incluir la contraseña').isString().withMessage('Contraseña invalida'),
];

export const createSocialCase = [
  check('caso.datos.cedula').exists().withMessage('Debe incluir la cedula del usuario').isInt().withMessage('Cedula invalida'),
  check('caso.datos.nombreCompleto').exists().withMessage('Debe incluir el nombre del usuario').isString().isLength({ min: 1 }).withMessage('El nombre no puede ser vacio'),
  check('caso.datos.email').exists().withMessage('Debe incluir el nombre de usuario').isString().withMessage('Nombre de usuario invalido'),
  check('caso.datos.direccion').exists().withMessage('Debe incluir la direccion del usuario').isString().withMessage('Direccion invalida'),
  check('caso.datos.nacionalidad').exists().withMessage('Debe incluir la nacionalidad del usuario').isString().withMessage('Nacionalidad invalida'),
  check('caso.datos.telefono').exists().withMessage('Debe incluir el telefono del usuario').isString().withMessage('Telefono invalido'),
  check('caso.datos.parroquia').exists().withMessage('Debe incluir una parroquia para la direccion del usuario').isString().withMessage('Parroquia invalida'),
  check('caso.datos.edad').exists().withMessage('Debe incluir la edad  del usuario').isInt().withMessage('Edad invalida'),
  check('caso.datos.sexo').exists().withMessage('Debe incluir el sexo del usuario').isBoolean().withMessage('Sexo invalido'),
  check('caso.datos.poblacionIndigena').exists().withMessage('Debe indicar si el usuario pertenece a la poblacion indigena').isBoolean().withMessage('Dato invalido'),
  check('caso.datos.profesion').exists().withMessage('Debe incluir la profesion del usuario').isString().withMessage('Profesion invalida'),
  check('caso.datos.oficio').exists().withMessage('Debe incluir el oficio del usuario').isString().withMessage('Oficio invalido'),
  check('caso.datos.estadoCivil').exists().withMessage('Debe incluir el estado civil del usuario').isString().withMessage('Estado civil invalido'),
  check('caso.datos.nivelInstruccion').exists().withMessage('Debe incluir el nivel de instruccion del usuario').isString().withMessage('Nivel de instruccion invalido'),
  check('caso.datos.empleadoAlcaldia').exists().withMessage('Debe indicar si el usuario es empleado de la alcaldia').isBoolean().withMessage('Dato invalido'),
  check('caso.datos.tipoAyuda').exists().withMessage('Debe incluir el tipo de ayuda que solicita el usuario').isString().withMessage('Tipo de ayuda invalido'),
  check('caso.datos.tipoAyudaDesc').exists().withMessage('Debe incluir la descripción del tipo de ayuda que solicita el usuario').isString().withMessage('Descripción de ayuda inválida'),
  check('caso.datos.condicionLaboral').exists().withMessage('Debe incluir la condicion laboral del usuario').isString().withMessage('Condicion laboral invalida'),
  check('caso.datos.fechaNacimiento').exists().withMessage('Debe incluir la fecha de nacimiento del usuario').isString().withMessage('Fecha de nacimiento invalida'),
  check('caso.datos.razonDeSolicitud').exists().withMessage('Debe incluir la razon de solicitud del usuario').isString().withMessage('Razon de solicitud'),
  check('caso.datos.patologiaActual').exists().withMessage('Debe incluir la patologia actual del usuario').isString().withMessage('Patologia invalida'),
  check('caso.datos.areaDeSalud').exists().withMessage('Debe incluir el area de salud de la patologia del solicitante').isString().withMessage('Area de salud invalida'),
  check('caso.datos.liderDeCalle').exists().withMessage('Debe incluir el lider de calle del solicitante'),
  check('caso.datos.solicitante').exists().withMessage('Debe incluir la firma del solicitante'),
];

export const createPersonalProperty = [];

export const validate = () => {
  return async (req, res, next) => {
    if (req.body.tramite.hasOwnProperty('aprobado') && !req.body.tramite.aprobado) return next();
    const validaciones = await isValidProcedure(req, res);
    await Promise.all(validaciones.map((validation) => validation.run(req)));
    next();
  };
};
const isValidProcedure = async (req, res) => {
  const [error, data] = await fulfill(getFieldsForValidations({ id: req.body.tramite.idTramite, type: req.body.tramite.tipoTramite }));
  if (error) res.status(error.status).json(error);
  if (data) {
    const arr = data.fields.map((el) => validations[el.validacion]);
    // if (data.takings > 0) arr.push(validations['recaudos']);
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
  if (req.user.tipoUsuario !== userTypes.UsuarioExterno) next();
  else {
    res.send({
      status: 401,
      response: 'No tiene permisos para realizar esta operación',
    });
  }
};

export const isExternalUser = (req, res, next) => {
  if (req.user.tipoUsuario === userTypes.UsuarioExterno) next();
  else {
    res.send({
      status: 401,
      response: 'Sólo los usuarios externos pueden realizar esta operación',
    });
  }
};

export const isOfficialAdmin = (req, res, next) => {
  if (req.user.tipoUsuario === userTypes.Administrador || req.user.tipoUsuario === userTypes.Superuser) next();
  else {
    res.send({
      status: 401,
      response: 'Sólo los funcionarios administradores o superior pueden realizar esta operación',
    });
  }
};

export const isSuperuser = (req, res, next) => {
  if (req.user.tipoUsuario === userTypes.Superuser) next();
  else {
    res.send({
      status: 401,
      response: 'Sólo los superusuarios pueden realizar esta operacion',
    });
  }
};

export const isSuperuserOrDaniel = (req, res, next) => {
  if (req.user.tipoUsuario === userTypes.Superuser || req.user?.institucion?.cargo?.id === 24) next();
  else {
    res.send({
      status: 401,
      response: 'Sólo los superusuarios pueden realizar esta operacion',
    });
  }
};
