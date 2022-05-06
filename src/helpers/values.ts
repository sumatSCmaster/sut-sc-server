import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import Redis from '@utils/redis';
import { mainLogger } from '@utils/logger';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

/**
 *
 * @param value
 */
export const updatePetroValue = async (value) => {
  const client = await pool.connect();
  const REDIS_KEY = 'petro';
  const redisClient = Redis.getInstance();
  try {
    await client.query('BEGIN');
    const result = (await client.query(queries.UPDATE_PETRO_VALUE, [value])).rows[0].valor_en_bs;
    await client.query('COMMIT');
    await redisClient.setAsync(REDIS_KEY, result);
    await redisClient.expireAsync(REDIS_KEY, 1800);
    return {
      status: 200,
      message: 'Se ha actualizado el valor del PETRO',
      petro: result,
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

export const updatePesoValue = async (value) => {
  const client = await pool.connect();
  const REDIS_KEY = 'peso';
  const redisClient = Redis.getInstance();
  try {
    await client.query('BEGIN');
    const result = (await client.query(queries.UPDATE_PESO_VALUE, [value])).rows[0].valor_en_bs;
    await client.query('COMMIT');
    await redisClient.setAsync(REDIS_KEY, result);
    await redisClient.expireAsync(REDIS_KEY, 1800);
    return {
      status: 200,
      message: 'Se ha actualizado el valor del PETRO',
      peso: result,
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
  try {
    const result = await getPetro();
    return {
      status: 200,
      message: 'Se ha obtenido el valor de la PETRO',
      petro: result,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en obtencion del valor de la PETRO',
    };
  } finally {
  }
};

export const getPesoValue = async () => {
  try {
    const result = await getPeso();
    return {
      status: 200,
      message: 'Se ha obtenido el valor de la PETRO',
      peso: result,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error en obtencion del valor de la PETRO',
    };
  } finally {
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

export const getPetro = async () => {
  const REDIS_KEY = 'petro';
  let client: PoolClient | undefined;
  const redisClient = Redis.getInstance();
  let petro;
  try {
    const cachedPetro = await redisClient.getAsync(REDIS_KEY);
    if (cachedPetro !== null) {
      petro = cachedPetro;
    } else {
      client = await pool.connect();
      petro = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
      await redisClient.setAsync(REDIS_KEY, petro);
      await redisClient.expireAsync(REDIS_KEY, 1800);
    }
    return petro;
  } catch (e) {
    mainLogger.error(`getPetro - ERROR ${e.message}`);
    throw e;
  } finally {
    if (client) client.release();
  }
};

export const getPeso = async () => {
  const REDIS_KEY = 'peso';
  let client: PoolClient | undefined;
  const redisClient = Redis.getInstance();
  let peso;
  try {
    const cachedPeso = await redisClient.getAsync(REDIS_KEY);
    if (cachedPeso !== null) {
      peso = cachedPeso;
    } else {
      client = await pool.connect();
      peso = (await client.query(queries.GET_PESO_VALUE)).rows[0].valor_en_bs;
      await redisClient.setAsync(REDIS_KEY, peso);
      await redisClient.expireAsync(REDIS_KEY, 1800);
    }
    return peso;
  } catch (e) {
    mainLogger.error(`getPetro - ERROR ${e.message}`);
    throw e;
  } finally {
    if (client) client.release();
  }
};