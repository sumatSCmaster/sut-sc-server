import { QueryResult } from 'pg';

export enum Nacionalidad {
  V = 'V',
  E = 'E',
}

export enum DescripcionesTipoUsuario {
  Superuser = 'Superuser',
  Administrador = 'Administrador',
  Funcionario = 'Funcionario',
  UsuarioExterno = 'Usuario Externo',
}

export enum IDsTipoUsuario {
  Superuser = 1,
  Administrador = 2,
  Funcionario = 3,
  UsuarioExterno = 4,
  Director = 5,
}

export interface Seccion {
  id: number;
  nombre: string;
  campos?: Campo[];
}

export interface Usuario {
  id: number;
  password?: string;
  nombreCompleto: string;
  nombreUsuario: string;
  direccion: string;
  cedula: string;
  telefono?: string;
  nacionalidad: Nacionalidad;
  rif?: string;
  tipoUsuario: TipoUsuario | number;
  datosGoogle?: DatosGoogle;
  cuentaFuncionario?: CuentaFuncionario;
  datosFacebook?: DatosFacebook;
  institucion?: Institucion;
}

export interface DatosFacebook {
  usuario: number;
  id: string;
}

export interface DatosGoogle {
  usuario: number;
  id: string;
}

export interface CuentaFuncionario {
  id: number;
  institucion: number;
}

export interface TipoUsuario {
  id: number;
  descripcion: DescripcionesTipoUsuario;
}

export interface Institucion {
  id: number;
  nombreCompleto: string;
  nombreCorto: string;
  tramitesDisponibles?: TipoTramite[];
}

export interface TipoTramite {
  id: number;
  titulo: string;
  costo: number;
  recaudos: Recaudo[] | null;
  pagoPrevio: boolean;
  secciones?: Seccion[];
  sufijo?: string;
  necesitaCodCat: boolean;
  utmm?: number;
}

export interface Parroquia {
  id: number;
  nombre: string;
}

export interface Tramite {
  id: number;
  estado: string;
  datos: object;
  costo: number;
  fechaCreacion: Date;
  codigoTramite: string;
  usuario: Usuario;
  tipoTramite: number;
  consecutivo?: number;
  nombreLargo: string;
  nombreCorto: string;
  nombreTramiteLargo: string;
  nombreTramiteCorto: string;
  fechaCulminacion: Date;
  recaudos: string[];
  planilla: string;
  certificado: string | null;
  aprobado: boolean;
  bill: any;
}

export interface Multa {
  id: number;
  estado: string;
  datos: object;
  costo: number;
  fechaCreacion: Date;
  codigoMulta: string;
  usuario: Usuario;
  tipoTramite: number;
  consecutivo?: number;
  nombreLargo: string;
  nombreCorto: string;
  nombreTramiteLargo: string;
  nombreTramiteCorto: string;
  fechaCulminacion: Date;
  boleta: string;
  certificado: string | null;
  aprobado: boolean;
  cedula: string;
  nacionalidad: string;
}

export interface Inmueble {
  id: number;
  codCatastral: string;
  direccion: string;
  parroquia: string;
  metrosConstruccion: number;
  metrosTerreno: number;
  fechaCreacion: Date;
  fechaActualizacion: Date;
  fechaUltimoAvaluo: Date;
  tipoInmueble: string;
}

export interface Recaudo {
  id: number;
  nombreCompleto: string;
  nombreCorto: string;
}

export interface ActividadEconomica {
  id: string;
  nombreActividad: string;
  idContribuyente: number;
  alicuota: number;
  costoSolvencia: number;
  deuda: Fecha[];
}

export interface Solicitud {
  id: number;
  usuario: Usuario;
  documento: string;
  rim?: string;
  nacionalidad: string;
  aprobado: boolean;
  fecha: Date;
  monto: number;
  pagado: boolean;
  liquidaciones: Liquidacion[];
}

export interface Liquidacion {
  id: number;
  tipoProcedimiento: string;
  fecha: Fecha;
  monto: number;
  certificado?: string;
  recibo?: string;
  multas?: any;
}

export interface Publicidad {
  articulos: {
    id: number;
    nombreArticulo: string;
    subarticulos: {
      id: number;
      nombreSubarticulo: string;
      parametro: string;
      costo: number;
    };
  };
  deuda: Fecha[];
}

export interface ServicioMunicipal {
  direccionInmueble: string;
  tarifaAseo: string;
  tarifaGas: string;
  deuda: Fecha[];
}

export interface InmuebleUrbano {
  direccionInmueble: string;
  ultimoAvaluo: string;
  impuestoInmueble: number;
  deuda: Fecha[];
}

export interface Fecha {
  month: string;
  year: number;
}

export interface Impuesto {
  tipoImpuesto: string;
  fechaCancelada: Date;
  monto: number;
}

export interface Campo {
  id: number;
  orden: number;
  status: string;
  nombre: string;
  tipo: string;
}

export interface Notificacion {
  id: number;
  tramite: Partial<Tramite>;
  emisor: string;
  receptor: string | null;
  descripcion: string;
  status: boolean;
  fechaCreacion: Date;
  concepto: string;
}

export interface ErrorEstandar {
  message: string;
  error: QueryResult<any>;
  status: number;
}

export namespace Payloads {
  export type CrearSuperuser = Partial<Usuario> & {
    institucion: number;
  };
  export type CrearAdmin = CrearSuperuser;

  export type ProcedureItems = {
    nombre: string;
    costo: number;
  };

  export type UpdateProcedureInstanceCost = {
    id: number;
    costo: number;
    items: ProcedureItems[];
  };
}
