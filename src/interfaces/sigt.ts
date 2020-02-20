
export enum Nacionalidad {
  V = "Venezolano",
  E = "Extranjero"
}

export enum DescripcionesTipoUsuario {
  Superuser = "Superuser",
  Administrador = "Administrador",
  Funcionario = "Funcionario",
  UsuarioExterno = "Usuario externo",
}

export enum IDsTipoUsuario {
  Superuser = 1,
  Administrador,
  Funcionario,
  UsuarioExterno
}

export interface Usuario {
  id_usuario: number
  nombre_completo: string
  nombre_de_usuario: string
  direccion: string
  cedula: string
  telefonos: string[]
  nacionalidad: Nacionalidad
  rif?: string
  tipo_usuario: TipoUsuario
  datos_google?: DatosGoogle
  cuenta_funcionario?: CuentaFuncionario 
}

export interface DatosGoogle {
  id_usuario: number,
  id_google: string
}

export interface CuentaFuncionario {
  id_usuario: number,
  password: string
}

export interface TipoUsuario{
  id_tipo_usuario: number
  descripcion: DescripcionesTipoUsuario
}

export namespace Payloads {
  export type CrearSuperuser = Partial<Usuario>
}
