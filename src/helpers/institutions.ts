import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const getAllInstitutions = async (): Promise<{
  instituciones: Institucion[];
  status: number;
  message: string;
}> => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_INSTITUTION);
    const instituciones: Institucion[] = response.rows.map((el) => {
      return {
        id: el.id_institucion,
        nombreCompleto: el.nombre_completo,
        nombreCorto: el.nombre_corto,
      };
    });
    return { instituciones, status: 200, message: 'Instituciones obtenidas' };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las instituciones',
    };
  } finally {
    client.release();
  }
};
