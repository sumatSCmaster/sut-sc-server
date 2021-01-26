import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Parroquia } from '@interfaces/sigt';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import Redis from '@utils/redis';
import { mainLogger } from '@utils/logger';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

/**
 *
 */
export const getAllParishes = async (): Promise<{
  parroquias: Parroquia[];
  status: number;
  message: string;
}> => {
  const REDIS_KEY = 'parishes';
  const redisClient = Redis.getInstance();
  let client: PoolClient | undefined;
  let parroquias: Parroquia[];
  try {
    mainLogger.info('getAllParishes - try');
    let cachedParishes = await redisClient.getAsync(REDIS_KEY);
    if (cachedParishes !== null) {
      mainLogger.info('getAllParishes - getting cached parishes');
      parroquias = JSON.parse(cachedParishes);
    } else {
      client = await pool.connect();
      const response = await client.query(queries.GET_PARISHES);
      parroquias = response.rows;
      await redisClient.setAsync(REDIS_KEY, JSON.stringify(parroquias));
      await redisClient.expireAsync(REDIS_KEY, 36000);
    }

    return { parroquias, status: 200, message: 'Parroquias obtenidas' };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las parroquias',
    };
  } finally {
    if (client) client.release();
  }
};

/**
 *
 * @param parish
 */
export const getSectorByParish = async (parish) => {
  const client = await pool.connect();
  try {
    const sectores = (await client.query(queries.GET_SECTOR_BY_PARISH, [parish])).rows;
    return { status: 200, message: 'Sectores obtenidos satisfactoriamente', sectores };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};
