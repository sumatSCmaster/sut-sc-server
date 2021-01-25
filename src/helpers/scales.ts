import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor } from './settlement';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

const template = async (props) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getScales = async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const scales = (await client.query('SELECT id_baremo as id, descripcion, indicador FROM impuesto.baremo ORDER BY id_baremo')).rows;
    await client.query('COMMIT');
    return { status: 200, message: 'Baremo de tarifas de servicio municipal obtenido', scales };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener baremos de tarifas de servicio municipal',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 * @param tariff
 */
export const updateScale = async (id, tariff) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE impuesto.baremo SET indicador = $1 WHERE id_baremo = $2', [tariff, id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Valor del baremo seleccionado actualizado satisfactoriamente' };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar el valor seleccionado',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const createScale = async ({ description, tariff }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const scale = (await client.query('INSERT INTO impuesto.baremo (descripcion, indicador) VALUES ($1, $2) RETURNING *', [description, tariff])).rows[0];
    await client.query('COMMIT');
    return { status: 200, message: 'Nuevo valor del baremo de servicios municipales agregado', baremo: { id: scale.id_baremo, descripcion: scale.descripcion, indicador: scale.indicador } };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear nuevo valor en el baremo de servicios',
    };
  } finally {
    client.release();
  }
};
