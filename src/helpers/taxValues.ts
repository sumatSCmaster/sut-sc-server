import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Parroquia } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

export const getDataForTaxValues = async () => {
  const client = await pool.connect();
  const anos = {};
  try {
    const data = (await client.query(queries.GET_YEARS)).rows;
    Promise.all(
      data.map(async el => {
        const year = el.descripcion;
        anos[year] = {
          id: el.id,
          terreno: await getGroundsByYear(el.id, client),
          construccion: await getConstructionsByYear(el.id, client),
        };
      })
    );
    const parroquias = (await client.query(queries.GET_PARISHES)).rows;
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

const getConstructionsByYear = async (year: number, client: PoolClient) => {
  const res = (
    await client.query(queries.GET_CONSTRUCTION_BY_YEAR, [year]).catch(e => {
      throw new Error(e);
    })
  ).rows;
  return res.map(el => {
    return { id: +el.id, valorFiscal: el.valorFiscal, tipoConstruccion: { id: +el.idTipoConstruccion, modeloConstruccion: el.tipoConstruccion } };
  });
};

const getGroundsByYear = async (year: number, client: PoolClient) => {
  const res = (
    await client.query(queries.GET_GROUNDS_BY_YEAR, [year]).catch(e => {
      throw new Error(e);
    })
  ).rows;
  return res.map(el => {
    return {
      id: +el.id,
      valorFiscal: el.valorFiscal,
      sector: { id: +el.idSector, descripcion: el.sector, parroquia: { id: +el.idParroquia, descripcion: el.parroquia } },
    };
  });
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
