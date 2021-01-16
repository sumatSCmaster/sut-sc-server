import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import { mainLogger } from '@utils/logger';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const updateContributor = async ({ id, tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(queries.UPDATE_TAXPAYER, [id, tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia]);
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Contribuyente actualizado' };
  } catch (e) {
    await client.query('ROLLBACK');
    mainLogger.error(e);
    throw e;
  } finally {
    client.release();
  }
};

export const updateRIM = async ({ id, telefono, email, denomComercial, nombreRepresentante, capitalSuscrito, tipoSociedad, parroquia, direccion, esMonotributo }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const parish = (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [parroquia])).rows[0]?.id;
    await client.query(queries.UPDATE_RIM, [id, telefono, email, denomComercial, nombreRepresentante, capitalSuscrito, tipoSociedad, telefono, parish, direccion, esMonotributo]);
    await client.query('COMMIT');
    return { status: 200, message: 'RIM actualizado' };
  } catch (e) {
    await client.query('ROLLBACK');
    mainLogger.error(e);
    throw e;
  } finally {
    client.release();
  }
};
