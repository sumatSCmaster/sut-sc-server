declare namespace sigt {

  enum Nacionalidad {
    V = "Venezolano",
    E = "Extranjero"
  }

  enum DescripcionesTipoUsuario {
    Superuser = "Superuser",
    Administrador = "Administrador",
    Funcionario = "Funcionario",
    UsuarioExterno = "Usuario externo",
  }

  enum IDsTipoUsuario {
    Superuser = 1,
    Administrador,
    Funcionario,
    UsuarioExterno
  }

  interface Usuario {
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

  interface DatosGoogle {
    id_usuario: number,
    id_google: string
  }

  interface CuentaFuncionario {
    id_usuario: number,
    password: string
  }

  interface TipoUsuario{
    id_tipo_usuario: number
    descripcion: DescripcionesTipoUsuario
  }

  namespace Payloads {
    type CrearSuperuser = Partial<Usuario>
  }
}

declare module 'sigt' {
  export = sigt;
}