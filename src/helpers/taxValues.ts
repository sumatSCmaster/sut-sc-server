import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Parroquia } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const getDataForTaxValues = async () => {
  const client = await pool.connect();
  try {
    const parroquias = (await client.query(queries.GET_PARISHES)).rows;
    const anos = (await client.query(queries.GET_YEARS)).rows;
    const tiposConstruccion = (await client.query(queries.GET_CONSTRUCTION_TYPES)).rows;
    return { status: 200, message: 'Informacion inicial de valores fiscales obtenida', datos: { parroquias, anos, tiposConstruccion } };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};

export const updateTaxValues = async taxes => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};

export const getTotalTaxForEstate = async tramite => {
  const { datos } = tramite;
  const client = await pool.connect();
  try {
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};

export const getSectorByParish = async parish => {
  const client = await pool.connect();
  try {
    const sectores = (await client.query(queries.GET_SECTOR_BY_PARISH, [parish])).rows;
    return { status: 200, message: 'Sectores obtenidos satisfactoriamente', sectores };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};
