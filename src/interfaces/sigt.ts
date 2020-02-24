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
  id_usuario: number;
  nombre_completo: string;
  nombre_de_usuario: string;
  direccion: string;
  cedula: string;
  telefonos: string[];
  nacionalidad: Nacionalidad;
  rif?: string;
  tipo_usuario: TipoUsuario;
  datos_google?: DatosGoogle;
  cuenta_funcionario?: CuentaFuncionario;
}

export interface DatosGoogle {
  id_usuario: number;
  id_google: string;
}

export interface CuentaFuncionario {
  id_usuario: number,
  password: string,
  id_institucion: number
}

export interface TipoUsuario {
  id_tipo_usuario: number;
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
  export type CrearSuperuser = Partial<Usuario> & {telefonos: number[], id_institucion: number} 
  export type CrearAdmin = CrearSuperuser 
}
