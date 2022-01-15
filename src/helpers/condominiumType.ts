import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const getCondominiumType = async (id: number) => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_CONDOMINIUM_TYPE_BY_ID, [id])).rows[0];
    const response2 = await client.query(queries.GET_ALL_CONDO_TYPES);
    return { status: 200, message: 'tipo de condominio obtenido', tipoCondominio: response || 'no asignado', infoCondominios: response2 };
  } catch (e: any) {
    throw {
      status: 500,
      message: errorMessageGenerator(e) || errorMessageExtractor(e) || e.message,
    };
  }
};
