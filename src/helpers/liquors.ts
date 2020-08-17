import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor, createSettlementForProcedure } from './settlement';

const pool = Pool.getInstance();

const template = async (props) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};

export const installLiquorLicense = async (data) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear la licencia de licores',
    };
  } finally {
    client.release();
  }
};

export const renewLiquorLicense = async (data) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al renovar la licencia de licores',
    };
  } finally {
    client.release();
  }
};
