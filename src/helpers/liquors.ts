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

export const installLiquorLicense = async (data, client: PoolClient) => {
  try {
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    const { contribuyente, tipoLicencia, fechaInicio, fechaFin } = data.funcionario;
    const license = (
      await client.query('INSERT INTO impuesto.licencia_licores (id_registro_municipal, tipo_licencia, fecha_inicio, fecha_fin) VALUES ($1, $2, $3, $4) RETURNING *', [
        contribuyente.idRim,
        tipoLicencia,
        moment(fechaInicio).format('MM-DD-YYYY'),
        (fechaFin && moment(fechaFin).format('MM-DD-YYYY')) || moment().add(2, 'years').format('MM-DD-YYYY'),
      ])
    ).rows[0];
    data.funcionario.licencia = {
      id: license.id_licencia_licores,
      numeroLicencia: license.numero_licencia,
      fechaInicio: license.fecha_inicio,
      fechaFin: license.fecha_fin,
      tipoLicencia: license.tipo_licencia,
    };
    // await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    return data;
  } catch (error) {
    console.log(error);
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
    const { contribuyente, tipoLicencia, fechaInicio, fechaFin } = data.funcionario;
    const license = (
      await client.query('UPDATE impuesto.licencia_licores SET tipo_licencia =$1, fecha_inicio $2, fecha_fin=$3 WHERE id_registro_municipal = $4 RETURNING *', [
        tipoLicencia,
        moment(fechaInicio).format('MM-DD-YYYY'),
        (fechaFin && moment(fechaFin).format('MM-DD-YYYY')) || moment().add(2, 'years').format('MM-DD-YYYY'),
        contribuyente.idRim,
      ])
    ).rows[0];

    data.funcionario.licencia = {
      id: license.id_licencia_licores,
      numeroLicencia: license.numero_licencia,
      fechaInicio: license.fecha_inicio,
      fechaFin: license.fecha_fin,
      tipoLicencia: license.tipo_licencia,
    };
    // await createSettlementForProcedure({ monto: +costo, referenciaMunicipal: data.id_registro_municipal, ramo: 'LIC' }, client);
    return data;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al renovar la licencia de licores',
    };
  }
};
