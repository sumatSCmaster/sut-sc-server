import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

/**
 *
 * @param value
 */
export const updatePetroValue = async (value) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = (await client.query(queries.UPDATE_PETRO_VALUE, [value])).rows[0];
    await client.query('COMMIT');
    return {
      status: 200,
      message: 'Se ha actualizado el valor del PETRO',
      petro: result.valor_en_bs,
    };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en actualizacion del valor de la PETRO',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getPetroValue = async () => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.GET_PETRO_VALUE)).rows[0];
    return {
      status: 200,
      message: 'Se ha obtenido el valor de la PETRO',
      petro: result.valor_en_bs,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en obtencion del valor de la PETRO',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param value
 */
export const updateUsdValue = async (value) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = (await client.query(queries.UPDATE_USD_VALUE, [value])).rows[0];
    await client.query('COMMIT');
    return {
      status: 200,
      message: 'Se ha actualizado el valor del USD',
      usd: result.valor_en_bs,
    };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en actualizacion del valor del USD',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getUsdValue = async () => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.GET_USD_VALUE)).rows[0];
    return {
      status: 200,
      message: 'Se ha obtenido el valor del USD',
      usd: result.valor_en_bs,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en obtencion del valor del USD',
    };
  } finally {
    client.release();
  }
};
