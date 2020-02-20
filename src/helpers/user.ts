import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { compare } from 'bcryptjs';
import { NestedSetNode } from 'ts-nested-set';
import { stringify } from 'flatted/cjs';
import { Usuario, Payloads } from 'sigt'

const pool = Pool.getInstance();

export const getUserByUsername = async (username: string): Promise<Usuario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_BY_USERNAME, [username]);
    const res = result.rows[0];
    const user: Usuario = {
      cedula: res.cedula,
      nombre: res.nombre_completo,
      correo: res.correo_electronico,
      telefono: res.telefono,
      institucion: {
        id: res.id_institucion,
        descripcion: res.institucion_descripcion,
        oficinas: []
      },
      oficina: {
        id: res.id_oficina, 
        descripcion: res.oficina_descripcion
      },
      indexIzq: res.index_izq,
      indexDer: res.index_der,
      cargo: res.cargo,
      password: res.password,
      rol: {
        id: res.id_rol,
        nombre: res.rol
      },
      tareasCalificadas: res.tareas_calificadas,
      rating: res.rating,
      urlAvatar: res.url_avatar
    };
    return user;
  } catch(e) {
    return null;
  } finally {
    client.release();
  }
};

export const createAdmin = async (user: Payloads.CrearAdmin): Promise<Usuario> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = (await client.query(queries.CREATE_ADMIN, 
      [user.institucion, user.oficina, user.cargo, user.cedula, user.nombre, user.correo, user.telefono])).rows[0];
    client.query(queries.ASSIGN_ALL_PERMISSIONS, [res.id_rol]);
    client.query(queries.ADD_ACCOUNT, [res.cedula, user.username, user.password]);
    client.query(queries.INIT_CONFIG, [stringify(new NestedSetNode(user.cargo))]);
    client.query('COMMIT');
    const usuario: Usuario = {
      cedula: res.cedula,
      nombre: res.nombre_completo,
      correo: res.correo_electronico,
      telefono: res.telefono,
      institucion: {
        id: res.id_institucion,
        descripcion: user.institucion,
        oficinas: [{ id: res.id_oficina, descripcion: user.oficina }]
      },
      oficina: {
        id: res.id_oficina,
        descripcion: user.oficina
      },
      indexDer: res.index_izq,
      indexIzq: res.index_der,
      cargo: res.cargo,
      username: user.username,
      tareasCalificadas: res.tareas_calificadas,
      rating: res.rating,
      urlAvatar: res.url_avatar
    };
    return usuario;
  } catch(e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const endWizard = async (): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.END_WIZARD);
    return result.rowCount > 0;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
}; 

export const comparePassword = (candidate: string, hash: string): Promise<boolean> => {
  return new Promise((res, rej) => {
    compare(candidate, hash, (err, isMatch) => {
      if(err) rej(err);
      res(isMatch);
    });
  });
};

export const hasNotifications = async (id: string): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.HAS_UNREAD_NOTIF, [id]);
    return result.rowCount > 0;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};