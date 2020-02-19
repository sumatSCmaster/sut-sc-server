import Pool from '@utils/Pool';
import { Tarea, Payloads, Comentario, Rol } from 'sge';
import queries from '@utils/queries';
import { sendNotification } from './notification';
import { getUsers } from '@config/socket';

const pool = Pool.getInstance();
const users = getUsers();

export const getUserTasks = async (id: string): Promise<Tarea[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_TASKS, [id]);
    return await Promise.all(result.rows.map(async (r) => {
      const comments = await client.query(queries.GET_TASK_COMMENTS, [r.id]);
      return formatTask(r, comments.rows);
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createTask = async (task: Payloads.CrearTarea): Promise<Tarea> => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.CREATE_TASK, [task.emisor, task.responsable, new Date(task.fechaEntrega), task.descripcion, task.titulo])).rows[0];
    const _task = (await client.query(queries.GET_TASK_BY_ID, [result.id])).rows[0];
    const taskObj = formatTask(_task, []);
    sendNotification(task.emisor, task.responsable, `${taskObj.emisor.nombre} te ha asignado una tarea.`, taskObj, 1);
    users.get(task.responsable)?.emit('SEND_TASK', task);
    return taskObj;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getSentTasks = async (id: string): Promise<Tarea[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_SENT_TASKS, [id]);
    return await Promise.all(result.rows.map(async (r) => {
      const tasks = await client.query(queries.GET_TASK_COMMENTS, [r.id]);
      return formatTask(r, tasks.rows);
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getRatePendingTasks = async (id: string): Promise<Tarea[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_RATE_PENDING, [id]);
    return await Promise.all(result.rows.map(async (r) => {
      const comments = await client.query(queries.GET_TASK_COMMENTS, [r.id]);
      return formatTask(r, comments.rows);
    }))
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const rateTask = async (id: number, rating: number): Promise<number | null> => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.RATE_TASK, [id, rating])).rows[0];
    const _task = (await client.query(queries.GET_TASK_BY_ID, [id])).rows[0];
    const task = formatTask(_task, []);
    sendNotification(task.emisor.cedula, task.responsable.cedula, `${task.emisor.nombre} te ha calificado una tarea con ${rating} puntos.`,
      task, 1);
    users.get(task.responsable.cedula)?.emit('RATE_TASK', task);
    return result.calificar_tarea >= 0 ? rating : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
}

export const deleteTask = async (id: number): Promise<Tarea> => {
  const client = await pool.connect();
  try {
    const _task = (await client.query(queries.GET_TASK_BY_ID, [id])).rows[0];
    client.query(queries.DELETE_TASK, [id]);
    const task = formatTask(_task, []);
    sendNotification(task.emisor.cedula, task.responsable.cedula, `${task.emisor.nombre} ha eliminado una tarea a la que fuiste asignado.`,
      task, 1);
    users.get(task.responsable.cedula)?.emit('DELETE_TASK', task);
    return task;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const editTask = async (id: number, title: string, description: string): Promise<Tarea | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.UPDATE_TASK_INFO, [title, description, id]);
    const comments = await client.query(queries.GET_TASK_COMMENTS, [id]);
    if(result.rowCount > 0) {
      result.rows[0].titulo = title;
      result.rows[0].descripcion = description;
      const task = formatTask(result.rows[0], comments.rows);
      sendNotification(task.emisor.cedula, task.responsable.cedula, `${task.emisor} ha editado una tarea a la que fuiste asignado.`, task, 1);
      users.get(task.responsable.cedula)?.emit('UPDATE_TASK', task);
      return task;
    }
    return null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createTaskComment = async (comment: Payloads.CrearComentario): Promise<Comentario | null> => {
  const client = await pool.connect();
  try {
    const _task = await client.query(queries.CHECK_TASK, [comment.target]);
    if(_task.rowCount === 0) return null;
    const result = (await client.query(queries.CREATE_COMMENT, [comment.emisor, comment.target, comment.descripcion, comment.urlArchivo || null])).rows[0];
    const emisor = (await client.query(queries.GET_USER_BY_ID, [comment.emisor])).rows[0];
    const _comment = formatNewComment(result, emisor);
    const task = formatTask(_task.rows[0], [_comment]);
    sendNotification(comment.emisor, task.responsable.cedula, `${comment.emisor} agrego un comentario a una tarea a la que te fue asignado.`,
      task, 1);
    users.get(task.responsable.cedula)?.emit('SEND_TASK_COMMENT', {
      id: task.id,
      comentario: _comment
    });
    return formatNewComment(result, emisor);
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const changeTaskStatus = async (id: number, status: number): Promise<number | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.UPDATE_TASK_STATUS, [status, id]);
    const _task = (await client.query(queries.GET_TASK_BY_ID, [id])).rows[0];
    const task = formatTask(_task, []);
    sendNotification(task.responsable.cedula, task.responsable.cedula, `${task.responsable.nombre} ha cambiado el status de una tarea.`, task, 1);
    users.get(task.responsable.cedula)?.emit('UPDATE_TASK_STATUS', task);
    return result.rowCount > 0 ? id : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const editComment = async (id: number, description: string): Promise<Comentario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.EDIT_COMMENT, [description, id]);
    if(result.rowCount > 0) {
      const emisor = (await client.query(queries.GET_USER_BY_ID, [result.rows[0].emisor])).rows[0];
      return formatNewComment(result.rows[0], emisor);
    }
    return null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const deleteComment = async (id: number): Promise<number | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.DELETE_COMMENT, [id]);
    return result.rowCount > 0 ? result.rows[0].id : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const formatTask = (_task: any, comments: any[]): Tarea => ({
  id: _task.id as number,
  titulo: _task.titulo as string,
  rating: _task.rating,
  emisor: {
    cedula: _task.cedula_emisor as string,
    nombre: _task.nombre_emisor as string,
    correo: _task.correo_emisor as string,
    telefono: _task.telefono_emisor as string,
    institucion: {
      id: _task.id_inst_emisor,
      descripcion: _task.inst_desc_emisor as string
    },
    oficina: {
      id: _task.id_oficina_emisor as number,
      descripcion: _task.oficina_desc_emisor as string
    },
    cargo: _task.cargo_emisor,
    indexIzq: _task.index_izq_emisor as number,
    indexDer: _task.index_der_emisor as number,
    username: _task.username_emisor as string,
    tareasCalificadas: _task.tareas_calif_emisor as number,
    rating: _task.rating_emisor as number,
    urlAvatar: _task.url_avatar_emisor as string
  },
  responsable: {
    cedula: _task.cedula_responsable as string,
    nombre: _task.nombre_responsable as string,
    correo: _task.correo_responsable as string,
    telefono: _task.telefono_responsable as string,
    institucion: {
      id: _task.id_inst_responsable,
      descripcion: _task.inst_desc_responsable as string
    },
    oficina: {
      id: _task.id_oficina_responsable as number,
      descripcion: _task.oficina_desc_responsable as string
    },
    cargo: _task.cargo_responsable,
    indexIzq: _task.index_izq_responsable as number,
    indexDer: _task.index_der_responsable as number,
    username: _task.username_responsable as string,
    tareasCalificadas: _task.tareas_calif_responsable as number,
    rating: _task.rating_responsable as number,
    urlAvatar: _task.url_avatar_responsable as string
  },
  status: _task.status as number,
  fechaAsignacion: _task.fecha_asignacion as Date,
  fechaEntrega: _task.fecha_entrega as Date,
  fechaCulminacion: _task.fecha_culminacion as Date,
  descripcion: _task.descripcion as string,
  comentarios: comments.map((c) => formatComment(c))
});

const formatComment = (c: any): Comentario => ({
  id: c.id as number,
  emisor: {
    cedula: c.cedula as string,
    nombre: c.nombre_completo as string,
    correo: c.correo_electronico as string,
    telefono: c.telefono as string,
    institucion: {
      id: c.id_institucion,
      descripcion: c.institucion_descripcion as string
    },
    oficina: {
      id: c.id_oficina as number,
      descripcion: c.oficina_descripcion as string
    },
    cargo: c.cargo,
    indexIzq: c.index_izq as number,
    indexDer: c.index_der as number,
    username: c.username as string,
    tareasCalificadas: c.tareas_calificadas as number,
    rating: c.rating as number,
    urlAvatar: c.url_avatar
  },
  target: c.target as number,
  descripcion: c.descripcion as string,
  tipo: c.tipo === 1 ? 'Tarea' : 'Proyecto',
  urlArchivo: c.url_archivo as string
});

const formatNewComment = (c: any, sender: any): Comentario => ({
  id: c.id as number,
  emisor: {
    cedula: sender.cedula as string,
    correo: sender.correo_electronico as string,
    nombre: sender.nombre_completo,
    telefono: sender.telefono as string,
    institucion: {
      id: sender.id_institucion as number,
      descripcion: sender.institucion_descripcion as string
    },
    oficina: {
      id: sender.id_oficina as number,
      descripcion: sender.oficina_descripcion as string
    },
    indexIzq: sender.index_izq as number,
    indexDer: sender.index_der as number,
    cargo: sender.cargo as string,
    username: sender.username as string,
    tareasCalificadas: sender.tareas_calificadas as number,
    rating: sender.rating as number,
    urlAvatar: sender.url_avatar
  },
  tipo: 'Tarea',
  urlArchivo: c.url_archivo as string,
  descripcion: c.descripcion as string,
  target: c.target as number
});