import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { DiaFeriado } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

/**
 *
 */
export const getHolidays = async (): Promise<DiaFeriado[]> => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.GET_HOLIDAYS)).rows as DiaFeriado[];
    return result;
  } catch (e) {
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al obtener dias feriados',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param data
 */
export const createHolidays = async (data: DiaFeriado[]): Promise<DiaFeriado[]> => {
  const client = await pool.connect();
  try {
    const queryResult = await Promise.all(data.map((diaFeriado) => client.query(queries.CREATE_HOLIDAY, [diaFeriado.dia, diaFeriado.descripcion])));
    const result = queryResult.map((q) => q.rows[0]) as DiaFeriado[];
    return result;
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al crear dias feriados',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 */
export const deleteHoliday = async (id): Promise<DiaFeriado> => {
  const client = await pool.connect();
  try {
    const result = (await client.query(queries.DELETE_HOLIDAY, [id])).rows[0] as DiaFeriado;
    return result;
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al eliminar dias feriados',
    };
  } finally {
    client.release();
  }
};
