import Pool from '@utils/Pool';
import queries from '@utils/queries';

const pool = Pool.getInstance();

export const getObservations = async (idTramite: number): Promise<any> => {
  const client: any = await pool.connect();
  try {
    const response = await client.query(queries.GET_OBSERVATIONS, [idTramite]);
    return response.rows[0];
  } catch (error) {
    throw new Error('Error al obtener observaciones');
  }
};
