import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Parroquia } from '@interfaces/sigt';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
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
      data.map(async (el) => {
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
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};

export const getTaxValuesToDate = async () => {
  const client = await pool.connect();
  const anos = {};
  try {
    const data = (await client.query(queries.GET_LAST_YEAR)).rows;
    const parroquias = (await client.query(queries.GET_PARISHES)).rows;
    const tiposConstruccion = (await client.query(queries.GET_CONSTRUCTION_TYPES)).rows;
    await Promise.all(
      data.map(async (el) => {
        const year = el.descripcion;
        anos[year] = {
          id: el.id,
          parroquias: await getGroundsByYear(el.id, client),
          construcciones: await getConstructionsByYear(el.id, client),
        };
      })
    );
    return { status: 200, message: 'Valores fiscales obtenidos', datos: { parroquias, tiposConstruccion, anos } };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los valores fiscales actualizados',
    };
  } finally {
    client.release();
  }
};

const getConstructionsByYear = async (year: number, client: PoolClient) => {
  const res = (
    await client.query(queries.GET_CONSTRUCTION_BY_YEAR, [year]).catch((e) => {
      throw new Error(e);
    })
  ).rows;
  return res.map((el) => {
    return { id: +el.id, valorFiscal: el.valorFiscal, tipoConstruccion: { id: +el.idTipoConstruccion, modeloConstruccion: el.tipoConstruccion } };
  });
};

const getGroundsByYear = async (year: number, client: PoolClient) => {
  const res = (
    await client.query(queries.GET_GROUNDS_BY_YEAR, [year]).catch((e) => {
      throw new Error(e);
    })
  ).rows;
  const parroquias = (await client.query(queries.GET_PARISHES)).rows;
  return Promise.all(
    parroquias.map(async (parish) => {
      const sectores = (await client.query(queries.GET_SECTOR_BY_PARISH, [parish.nombre])).rows;
      return {
        id: +parish.id,
        descripcion: parish.nombre,
        sectores: sectores
          .map((sector) => {
            const terreno = res.find((el) => +el.idSector == +sector.id && +el.idParroquia == +parish.id);
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
          .filter((el) => el !== null),
      };
    })
  );
};

export const updateGroundValuesByFactor = async (ground) => {
  const client = await pool.connect();
  const year = new Date().getFullYear();
  const { factor } = ground;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_GROUND_VALUES_BY_FACTOR, [factor, year])).rows[0];
    const anos = {
      [year]: {
        id: response.ano_id,
        parroquias: await getGroundsByYear(response.ano_id, client),
      },
    };
    client.query('COMMIT');
    return { status: 200, message: 'Valor fiscal de los terrenos actualizado!', anos };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al actualizar el valor fiscal de los terrenos',
    };
  } finally {
    client.release();
  }
};

export const updateConstructionValuesByFactor = async (construction) => {
  const client = await pool.connect();
  const year = new Date().getFullYear();
  const { factor } = construction;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_CONSTRUCTION_VALUES_BY_FACTOR, [factor, year])).rows[0];
    const anos = {
      [year]: {
        id: response.ano_id,
        construcciones: await getConstructionsByYear(response.ano_id, client),
      },
    };
    client.query('COMMIT');
    return { status: 200, message: 'Valor fiscal de las construcciones actualizado!', anos };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al actualizar el valor fiscal de las construcciones',
    };
  } finally {
    client.release();
  }
};

export const updateGroundValuesBySector = async (ground, sector) => {
  const client = await pool.connect();
  const year = new Date().getFullYear();
  const { valorFiscal } = ground;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_GROUND_VALUES_BY_SECTOR, [valorFiscal, year, sector])).rows[0];
    const ground = (await client.query(queries.GET_GROUND_BY_ID, [response.id])).rows[0];
    const sectores = {
      id: +ground.idSector,
      descripcion: ground.sector,
      terreno: {
        id: +ground.id,
        valorFiscal: ground.valorFiscal,
      },
    };
    const parroquia = {
      id: ground.idParroquia,
      descripcion: ground.parroquia,
      sectores: [sectores],
    };
    const anos = {
      [year]: {
        id: response.ano_id,
        parroquia,
      },
    };
    client.query('COMMIT');
    return { status: 200, message: 'Valor fiscal del terreno actualizado!', anos };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al actualizar el valor fiscal del terreno',
    };
  } finally {
    client.release();
  }
};

export const updateConstructionValuesByModel = async (construction, model) => {
  const client = await pool.connect();
  const year = new Date().getFullYear();
  const { valorFiscal } = construction;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_CONSTRUCTION_VALUES_BY_MODEL, [valorFiscal, year, model])).rows[0];
    const construct = (await client.query(queries.GET_CONSTRUCTION_BY_ID, [response.id])).rows[0];
    const anos = {
      [year]: {
        id: response.ano_id,
        construccion: {
          id: +construct.id,
          valorFiscal: construct.valorFiscal,
          tipoConstruccion: { id: +construct.idTipoConstruccion, modeloConstruccion: construct.tipoConstruccion },
        },
      },
    };
    client.query('COMMIT');
    return { status: 200, message: 'Valor fiscal de la construccion actualizado!', anos };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al actualizar el valor fiscal de la construccion',
    };
  } finally {
    client.release();
  }
};
