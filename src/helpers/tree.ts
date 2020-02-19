import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Payloads, Cargo, Usuario } from 'sge';

const pool = Pool.getInstance();

export const getTree = async (): Promise<string> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_TREE);
    return result.rows[0].arbol_jerarquico as string;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const updateTree = async (flat: Payloads.DatosCargo[], tree: string): Promise<string> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    client.query(queries.CLEAR_INDEXES);
    Promise.all(flat.filter((f) => f.title !== 'Administrador' ? client.query(queries.INSERT_POSITION, [f.left, f.right, f.title]) : null));
    client.query(queries.SET_TREE, [tree]);
    client.query('COMMIT');
    return tree as string;
  } catch(e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const getChildren = async (left: number, right: number): Promise<Cargo[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_CHILDREN, [left, right]);
    return result.rows.map((r) => ({
      id: r.id as number,
      nombre: r.nombre as string
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getChildrenUsers = async (left: number, right: number): Promise<Usuario[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_CHILDREN_USERS, [left, right]);
    return result.rows.map((res) => ({
      cedula: res.cedula,
      nombre: res.nombre_completo,
      correo: res.correo_electronico,
      telefono: res.telefono,
      institucion: {
        id: res.id_institucion,
        descripcion: res.institucion_descripcion,
        oficinas: [{ id: res.id_oficina, descripcion: res.oficina_descripcion }]
      },
      oficina: {
        id: res.id_oficina,
        descripcion: res.oficina_descripcion
      },
      indexDer: res.index_izq,
      indexIzq: res.index_der,
      cargo: res.cargo,
      username: res.username,
      tareasCalificadas: res.tareas_calificadas,
      rating: res.rating,
      urlAvatar: res.url_avatar
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};