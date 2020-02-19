import Pool from '@utils/Pool';
import { Proyecto, Payloads } from 'sge';
import queries from '@utils/queries';
import { urlencoded } from 'express';

const pool = Pool.getInstance();

export const getProjects = async (): Promise<Proyecto[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_ALL_PROJECTS);
    return await Promise.all(result.rows.map(async (project) => 
      formatProject(
        project,
        (await client.query(queries.GET_PROJECT_FILES, [project.id_proyecto])).rows,
        (await client.query(queries.GET_PROJECT_ACTIVITIES, [project.id_proyecto])).rows
      )
    ));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createProject = async (project: Payloads.CrearProyecto): Promise<Proyecto> => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.CREATE_PROJECT, [project.institucion, project.responsable, project.nombre, project.direccion,
      project.parroquia, project.longitud, project.latitud, project.duracionEstimada, new Date(project.fechaInicio), project.descripcion, project.costoDolares, 
      project.costoBs, project.poblacion, project.cantidad])).rows[0];
    const data = (await client.query(queries.GET_PROJECT_BY_ID, [result.id])).rows[0];
    const activities = await Promise.all(project.actividades.map(async (a) => (await client.query(queries.CREATE_ACTIVITY, [result.id, a.descripcion, 
      a.duracion, new Date(a.fechaInicio), new Date(a.fechaFin)])).rows[0]));
    project.archivos.map(async (f) => await client.query(queries.INSERT_FILE, [result.id, f]));
    client.query('COMMIT');
    return formatProject(data, project.archivos.map((f) => ({ url_archivo: f })), activities);
  } catch(e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

const formatProject = (project: any, files: any[], activities: any[]): Proyecto => ({
  id: project.id_proyecto as number,
  institucion: {
    id: project.id_institucion as number,
    descripcion: project.institucion_descripcion as string
  },
  responsable: {
    cedula: project.cedula as string,
    nombre: project.nombre_completo as string,
    correo: project.correo_electronico as string,
    telefono: project.telefono as string,
    institucion: {
      id: project.id_institucion as number,
      descripcion: project.institucion_descripcion as string
    },
    oficina: {
      id: project.id_oficina as number,
      descripcion: project.oficina_descripcion as string
    },
    indexDer: project.index_der as number,
    indexIzq: project.index_izq as number,
    rating: project.rating as number,
    tareasCalificadas: project.tareas_calificadas as number,
    urlAvatar: project.url_avatar as string
  },
  status: project.status as number,
  nombre: project.nombre as string,
  direccion: project.direccion as string,
  duracionEstimada: project.duracion_estimada as number,
  longitud: project.longitud as number,
  latitud: project.latitud as number,
  fechaCulminacion: project.fechaCulminacion as Date,
  fechaInicio: project.fechaInicio as Date,
  descripcion: project.descripcion as string,
  costoBs: project.costo_bs as number,
  costoDolares: project.costo_dolares as number,
  archivos: files.map((f) => f.url_archivo),
  actividades: activities.map((a) => ({
    id: a.id as number,
    descripcion: a.descripcion as string,
    duracion: a.duracion as number,
    status: a.status as number,
    fechaInicio: a.fecha_inicio as Date,
    fechaFin: a.fecha_fin as Date,
    fechaCulminacion: a.fecha_culminacion as Date
  })),
  poblacion: project.poblacion as string,
  cantidad: project.cantidad as number
});