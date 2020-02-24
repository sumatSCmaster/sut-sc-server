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

export interface Usuario {
  id: number;
  password?: string;
  nombreCompleto: string;
  nombreUsuario: string;
  direccion: string;
  cedula: string;
  telefonos: string[];
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
  tramitesDisponibles?: TramitesDisponibles[];
}

export interface TramitesDisponibles {
  id: number;
  titulo: string;
  costo: number;
  campos?: Campos[];
}

export interface Campos {
  id: number;
  orden: number;
  status: string;
  nombre: string;
  tipo: string;
}

export namespace Payloads {
  export type CrearSuperuser = Partial<Usuario> & {
    telefonos: number[];
    institucion: number;
  };
  export type CrearAdmin = CrearSuperuser;
}
