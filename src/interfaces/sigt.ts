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
  tipoUsuario: TipoUsuario;
  datosGoogle?: DatosGoogle;
  cuentaFuncionario?: CuentaFuncionario;
  datosFacebook?: DatosFacebook;
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
  utmm?: number
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
  recaudos: string[];
  planilla: string;
  certificado: string | null;
  aprobado: boolean;
  bill: any;
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

export interface Campo {
  id: number;
  orden: number;
  status: string;
  nombre: string;
  tipo: string;
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
