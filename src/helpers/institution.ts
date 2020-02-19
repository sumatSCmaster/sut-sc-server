import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion } from 'sge';

const pool = Pool.getInstance();

export const getInstitutions = async (): Promise<Institucion[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_ALL_INSTITUTIONS);
    return await Promise.all(result.rows.map(async (r) => {
      const offices = await client.query(queries.GET_INSTITUTION_OFFICES, [r.id])
      return {
        id: r.id as number,
        descripcion: r.descripcion as string,
        oficinas: offices.rows.map((o) => ({
          id: o.id as number,
          descripcion: o.descripcion as string
        }))
      }
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getInstitution = async (id: number): Promise<Institucion | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_INSTITUTION, [id]);
    const offices = await client.query(queries.GET_INSTITUTION_OFFICES, [id])
    return result.rowCount > 0 ? ({
      id: result.rows[0].id as number,
      descripcion: result.rows[0].descripcion as string,
      oficinas: offices.rows.map((o) => ({
        id: o.id as number,
        descripcion: o.descripcion as string
      }))
    }) : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const removeInstitution = async (id: number): Promise<Institucion | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.DELETE_INSTITUTION, [id]);
    return result.rowCount > 0 ? ({
      id: result.rows[0].id as number,
      descripcion: result.rows[0].descripcion as string,
      oficinas: []
    }) : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createInstitution = async (name: string): Promise<Institucion> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CREATE_INSTITUTION, [name]);
    return {
      id: result.rows[0].id as number,
      descripcion: name,
      oficinas: []
    };
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const editInstitution = async (id: number, name: string): Promise<Institucion | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.EDIT_INSTITUTION, [name, id]);
    const offices = await client.query(queries.GET_INSTITUTION_OFFICES, [id])
    if(result.rowCount > 0) {
      return {
        id,
        descripcion: name,
        oficinas: offices.rows.map((o) => ({
          id: o.id as number,
          descripcion: o.descripcion as string
        }))
      };
    }
    return null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};