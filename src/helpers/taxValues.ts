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
    const parroquias = (await client.query(queries.GET_PARISHES)).rows;
    const tiposConstruccion = (await client.query(queries.GET_CONSTRUCTION_TYPES)).rows;
    await Promise.all(
      data.map(async el => {
        const year = el.descripcion;
        anos[year] = {
          id: el.id,
          parroquias: await getGroundsByYear(el.id, client),
          construcciones: await getConstructionsByYear(el.id, client),
        };
      })
    );
    return { status: 200, message: 'Informacion inicial de valores fiscales obtenida', datos: { parroquias, tiposConstruccion, anos } };
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
  const parroquias = (await client.query(queries.GET_PARISHES)).rows;
  return Promise.all(
    parroquias.map(async parish => {
      const sectores = (await client.query(queries.GET_SECTOR_BY_PARISH, [parish.nombre])).rows;
      return {
        id: +parish.id,
        descripcion: parish.nombre,
        sectores: sectores
          .map(sector => {
            const terreno = res.find(el => +el.idSector == +sector.id && +el.idParroquia == +parish.id);
            if (!terreno) return null;
            return {
              id: +sector.id,
              descripcion: sector.descripcion,
              terreno: {
                id: +terreno.id,
                valorFiscal: terreno.valorFiscal,
              },
            };
          })
          .filter(el => el !== null),
      };
    })
  );
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
