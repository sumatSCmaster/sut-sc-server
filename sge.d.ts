declare namespace sge {
  interface Usuario {
    cedula: string
    nombre: string
    correo: string
    telefono: string
    institucion: Institucion
    oficina: Oficina
    indexIzq: number
    indexDer: number
    cargo?: string
    password?: string
    username?: string
    rol?: Rol
    rating: number
    tareasCalificadas: number
    urlAvatar: string
  }

  interface Institucion {
    id: number
    descripcion: string
    oficinas?: Oficina[]
  }

  interface Oficina {
    id: number
    descripcion: string
  }

  interface Rol {
    id: number
    nombre: string
    permisos?: Permiso[]
  }

  interface Permiso {
    id: number
    descripcion: string
    categoria: string
  }

  interface Cargo {
    id: number
    nombre: string
  }

  interface Invitacion {
    id: number
    correo: string
    nombre: string
    token?: string
  }

  interface Tarea {
    id: number
    titulo: string
    emisor: Usuario
    responsable: Usuario
    status: number
    fechaAsignacion: Date
    fechaEntrega: Date
    fechaCulminacion: Date
    descripcion: string
    comentarios: Comentario[]
    rating: number
  }

  interface Comentario {
    id: number
    emisor: Usuario
    target: number
    tipo: 'Tarea' | 'Proyecto'
    descripcion: string
    urlArchivo?: string
  }

  interface Notificacion {
    id: number
    emisor: Usuario
    receptor: Usuario
    descripcion: string
    target: Tarea | null // TODO: Ampliar cuando aparezcan otros targets (Proyectos...)
    tipo: 'Tarea' | 'Invitacion' | 'Proyecto',
    status: boolean
    fecha: Date
  }

  interface Proyecto {
    id: number
    institucion: Institucion
    responsable: Usuario
    status: number
    nombre: string
    direccion: string
    longitud: number
    latitud: number
    duracionEstimada: number
    fechaInicio: Date
    fechaCulminacion: Date
    descripcion: string
    costoDolares: number
    costoBs: number
    archivos: string[]
    actividades: Actividad[]
    poblacion: string
    cantidad: number
  }

  interface Actividad {
    id: number
    descripcion: string
    duracion: number
    status: number
    fechaInicio: Date
    fechaFin: Date
    fechaCulminacion: Date
  }

  namespace Payloads {
    interface CrearInvitacion {
      cedula: string
      nombre: string
      correo: string
      institucion: number
      oficina: number
      cargo: number
      rol: number
    }
  
    interface AceptarInvitacion {
      token: string
      telefono: string
      username: string
      password: string
    }
  
    interface DatosCargo {
      title: string
      left: number
      right: number
      depth: number
    }

    interface CrearAdmin {
      cedula: string
      nombre: string
      correo: string
      telefono: string
      institucion: string
      oficina: string
      cargo: string,
      username: string,
      password: string
    }

    interface CrearTarea {
      emisor: string
      responsable: string
      fechaEntrega: number
      descripcion: string
      titulo: string
    }

    interface CrearComentario {
      emisor: string
      target: number
      descripcion: string
      urlArchivo?: string
    }

    interface CrearProyecto {
      institucion: number
      responsable: string
      nombre: string
      direccion: string
      parroquia: number
      longitud: number
      latitud: number
      duracionEstimada: number
      fechaInicio: Date
      descripcion: string
      costoDolares: number
      costoBs: number
      poblacion: string
      cantidad: number
      archivos: string[]
      actividades: CrearActividad[]
    }

    interface CrearActividad {
      descripcion: string
      duracion: number
      fechaInicio: Date
      fechaFin: Date
    }
  }
}

declare module 'sge' {
  export = sge;
}