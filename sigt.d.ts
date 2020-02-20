declare namespace sigt {

  enum Nacionalidad {
    Venezolano = "V"
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
    descripcion: string
  }

  namespace Payloads {
    
  }
}

declare module 'sigt' {
  export = sigt;
}