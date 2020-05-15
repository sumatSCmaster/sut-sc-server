import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import switchcase from '@utils/switch';
const gticPool = GticPool.getInstance();
const pool = Pool.getInstance();

export const getSettlements = async ({ document, reference }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const contributor = (reference
      ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference])
      : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document])
    ).rows[0];
    if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    return {};
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener los impuestos',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

export const insertSettlements = async () => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones',
    };
  } finally {
    client.release();
    gtic.release();
  }
};
