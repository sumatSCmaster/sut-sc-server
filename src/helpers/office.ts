import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Oficina } from 'sge';

const pool = Pool.getInstance();

export const getOffices = async (id: number): Promise<Oficina[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_INSTITUTION_OFFICES, [id]);
    return result.rows.map((o) => ({
      id: o.id as number,
      descripcion: o.descripcion as string
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createOffice = async (idInst: number, name: string): Promise<Oficina> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CREATE_OFFICE, [name, idInst]);
    return {
      id: result.rows[0].id as number,
      descripcion: result.rows[0].descripcion as string
    };
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const editOffice = async (idInst: number, idOffice: number, name: string, institucion: number): Promise<Oficina | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.EDIT_OFFICE, [name, idOffice, idInst, institucion]);
    return result.rowCount > 0 ? ({
      id: result.rows[0].id as number,
      descripcion: result.rows[0].descripcion as string
    }) : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const removeOffice = async (idInst: number, idOffice: number): Promise<Oficina | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.DELETE_OFFICE, [idOffice, idInst]);
    return result.rowCount > 0 ? ({
      id: result.rows[0].id as number,
      descripcion: result.rows[0].descripcion as string
    }) : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};