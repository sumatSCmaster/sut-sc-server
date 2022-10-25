import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor, errorMessageGenerator } from './errors';

const pool = Pool.getInstance();

export const getRRICertificates = async (ids: []) => {
  const client = await pool.connect();
  try {
  const response = (await client.query(queries.GET_RRI_CERTIFICATES_BY_IDS, [ids])).rows;
  return { certificates: response };
  }
  catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener informacion de validacion',
    };
  }
};
