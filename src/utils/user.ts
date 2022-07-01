import Pool from './Pool';
import queries from './queries';
import { errorMessageExtractor } from '@helpers/errors';

const pool = Pool.getInstance();

export const getIdByRif = async (rif: string, pref:string) => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_USER_ID_BY_RIF, [rif, pref])).rows[0];
    return response;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const getIdByRim = async (rim:string) => {
  const client = await pool.connect();
  try {
    const response = (await client.query(`SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $1`, [rim])).rows[0];
    return response;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const checkIfOfficial = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_OFFICIAL, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const checkIfDirector = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_DIRECTOR, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const checkIfAdmin = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_ADMIN, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const checkIfChief = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_CHIEF, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const checkIfSuperuser = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_SUPERUSER, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};
