import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const editCondominiumType = async (id: number, type: number) => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.EDIT_CONDO_TYPE_BY_ID, [id, type])).rows[0];
    return { status: 200, message: 'condominio actualizado exitosamente', nuevoTipo: response };
  } catch (e: any) {
    throw { status: 500, message: errorMessageGenerator(e) || errorMessageExtractor(e) || e.message };
  }
};

export const getCondominiumType = async (id: number) => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_CONDOMINIUM_TYPE_BY_ID, [id])).rows[0];
    const response2 = (await client.query(queries.GET_ALL_CONDO_TYPES)).rows;
    const condoTypes = {
      tipoA: { ...response2.filter((elem) => elem.tipo_condominio === 'TIPO A') },
      tipoB: { ...response2.filter((elem) => elem.tipo_condominio === 'TIPO B') },
      tipoC: { ...response2.filter((elem) => elem.tipo_condominio === 'TIPO C') },
    };
    return { status: 200, message: 'tipo de condominio obtenido', tipoCondominio: response || 'no asignado', infoCondominios: condoTypes };
  } catch (e: any) {
    throw {
      status: 500,
      message: errorMessageGenerator(e) || errorMessageExtractor(e) || e.message,
    };
  }
};
