import { QueryResult } from "pg";

export enum Nacionalidad {
  V = "Venezolano",
  E = "Extranjero"
}

export enum DescripcionesTipoUsuario {
  Superuser = "Superuser",
  Administrador = "Administrador",
  Funcionario = "Funcionario",
  UsuarioExterno = "Usuario externo"
}

export enum IDsTipoUsuario {
  Superuser = 1,
  Administrador,
  Funcionario,
  UsuarioExterno
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
}
