import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor, createSettlementForProcedure } from './settlement';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

const categoriaLicencia = {
  29: 'EXPENDIO',
  30: 'DISTRIBUCION',
  31: 'EXPENDIO DE CONSUMO',
  32: 'TEMPORAL',
  33: 'EXPENDIO',
  34: 'DISTRIBUCION',
  35: 'EXPENDIO DE CONSUMO',
};

const tipoLicencia = switchcase({ 32: 'TEMPORAL' })('PERMANENTE');

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

export const installLiquorLicense = async (data, client: PoolClient) => {
  try {
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    const { referenciaMunicipal, fechaFin } = data.funcionario;
    const { tipoTramite } = data;
    mainLogger.info(data);
    const license = (
      await client.query(
        'INSERT INTO impuesto.licencia_licores (id_registro_municipal, tipo_licencia, categoria_licencia, fecha_inicio, fecha_fin) VALUES ((SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $1 LIMIT 1), $2, $3, $4, $5) RETURNING *',
        [referenciaMunicipal, tipoLicencia(tipoTramite), categoriaLicencia[tipoTramite], moment().format('MM-DD-YYYY'), (fechaFin && moment(fechaFin).format('MM-DD-YYYY')) || moment().add(2, 'years').format('MM-DD-YYYY')]
      )
    ).rows[0];
    data.funcionario.licencia = {
      id: license.id_licencia_licores,
      numeroLicencia: license.numero_licencia,
      categoriaLicencia: license.categoria_licencia,
      fechaInicio: license.fecha_inicio,
      fechaFin: license.fecha_fin,
      tipoLicencia: license.tipo_licencia,
    };
    // await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    return data;
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear la licencia de licores',
    };
  }
};

export const renewLiquorLicense = async (data, client: PoolClient) => {
  try {
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    const { referenciaMunicipal, fechaFin } = data.funcionario;
    const { tipoTramite } = data;
    const license = (
      await client.query(
        'UPDATE impuesto.licencia_licores SET tipo_licencia =$1, categoria_licencia = $2, fecha_inicio = $3, fecha_fin = $4 WHERE id_registro_municipal = (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $5 LIMIT 1), RETURNING *',
        [tipoLicencia(tipoTramite), categoriaLicencia[tipoTramite], moment().format('MM-DD-YYYY'), (fechaFin && moment(fechaFin).format('MM-DD-YYYY')) || moment().add(2, 'years').format('MM-DD-YYYY'), referenciaMunicipal]
      )
    ).rows[0];

    data.funcionario.licencia = {
      id: license.id_licencia_licores,
      numeroLicencia: license.numero_licencia,
      categoriaLicencia: license.categoria_licencia,
      fechaInicio: license.fecha_inicio,
      fechaFin: license.fecha_fin,
      tipoLicencia: license.tipo_licencia,
    };
    // await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    return data;
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al renovar la licencia de licores',
    };
  }
};
