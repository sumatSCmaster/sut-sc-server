import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { mainLogger } from '@utils/logger';
import { PoolClient } from 'pg';

const pool = Pool.getInstance();

export const getCondominiums = async () => {
  const client = await pool.connect();
  try {
    const { rows: condos } = await client.query(queries.GET_CONDOMINIUMS);
    return condos;
  } catch (error) {
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    client.release();
  }
};

export const getCondominium = async (condo_id) => {
  const client = await pool.connect();
  try {
    const [condo] = (await client.query(queries.GET_CONDOMINIUM, [condo_id])).rows;
    const { rows: owners } = await client.query(queries.GET_CONDOMINIUM_OWNERS, [condo_id]);
    return { ...condo, owners };
  } catch (error) {
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    client.release();
  }
};

export const deleteCondominium = async (condo_id) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const [condo] = (await client.query(queries.GET_CONDOMINIUM, [condo_id])).rows;
    await client.query(queries.DELETE_CONDOMINIUM, [condo_id]);
    client.query('COMMIT');
    return condo;
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    client.release();
  }
};

export const createCondominium = async ({ type_doc, doc }) => {
  const client = await pool.connect();
  mainLogger.info(`createCondominium - type_doc ${type_doc} doc ${doc}`);
  try {
    await client.query('BEGIN');
    const result = await client.query(queries.CREATE_CONDOMINIUM, [type_doc, doc]);
    const [condo] = (await client.query(queries.GET_CONDOMINIUM, [result.rows[0].id_condominio])).rows;
    await client.query('COMMIT');
    return condo;
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(`createCondominium - ${error.message}`)
    throw {
      error: error.message,
      message: `Error al agregar el condominio`,
    };
  } finally {
    client.release();
  }
};

export const addOwner = async ({ condo_id, type_doc, doc }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(queries.ADD_CONDO_OWNER, [type_doc, doc, condo_id]);

    await client.query('COMMIT');
    return await getCondominium(condo_id);
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(`createCondominium - ${error.message}`);
    let mess = ' ';
    if (error.message.includes('duplicate'))
      mess = 'Este propietario ya es parte del condominio.';
    else if (error.message.includes('null'))
      mess = 'No se encontró un usuario con la documentación ingresada.';
    else
      mess = 'Error al agregar el propietario.'
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    client.release();
  }
};

export const deleteOwner = async (condo_id, owner_id) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');

    await client.query(queries.DELETE_CONDO_OWNER, [condo_id, owner_id]);
    const [condo] = (await client.query(queries.GET_CONDOMINIUM, [condo_id])).rows;
    const { rows: owners } = await client.query(queries.GET_CONDOMINIUM_OWNERS, [condo_id]);
    client.query('COMMIT');
    return { ...condo, owners };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    client.release();
  }
};

export const isCondominium = async (type_doc, doc, conn: PoolClient | null = null) => {
  const client = conn ? conn : await pool.connect();
  try {
    const { rowCount } = await client.query(queries.GET_CONDOMINIUM_BY_DOC, [type_doc, doc]);
    return rowCount > 0;
  } catch (error) {
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    if (!conn) client.release();
  }
};

export const isCondoOwner = async (type_doc, doc, conn: PoolClient | null = null) => {
  const client = conn ? conn : await pool.connect();
  try {
    const { rowCount } = await client.query(queries.GET_CONDOMINIUM_OWNER_BY_DOC, [type_doc, doc]);
    return rowCount > 0;
  } catch (error) {
    throw {
      error: error,
      message: error.message,
    };
  } finally {
    if (!conn) client.release();
  }
};
