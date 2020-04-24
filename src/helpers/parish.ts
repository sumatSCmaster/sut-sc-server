import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Parroquia } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const getAllParishes = async (): Promise<{
  parroquias: Parroquia[];
  status: number;
  message: string;
}> => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_PARISHES);
    const parroquias: Parroquia[] = response.rows;
    return { parroquias, status: 200, message: 'Parroquias obtenidas' };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las parroquias',
    };
  } finally {
    client.release();
  }
};

export const getSectorByParish = async (parish) => {
  const client = await pool.connect();
  try {
    const sectores = (await client.query(queries.GET_SECTOR_BY_PARISH, [parish])).rows;
    return { status: 200, message: 'Sectores obtenidos satisfactoriamente', sectores };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};
