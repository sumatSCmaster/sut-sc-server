import Pool from './Pool';
import queries from './queries';
import { errorMessageExtractor } from '@helpers/errors';

const pool = Pool.getInstance();

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
