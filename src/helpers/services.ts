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
    return { status: 200, message: '' };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getMunicipalServicesByContributor = async ({ reference, document, docType }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en HACIENDA' };
    if (!reference) throw { status: 404, message: 'Debe proporcionar el RIM del contribuyente' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'La sucursal solicitada no existe' };
    const estates = (await client.query(queries.GET_ESTATES_DATA_FOR_CONTRIBUTOR, [branch.id_registro_municipal])).rows.filter((el) => el.metros_construccion && el.metros_terreno);
    if (!(estates.length > 0)) throw { status: 404, message: 'El contribuyente no tiene inmuebles asociados' };
    const res = await Promise.all(
      estates.map(async (estate) => {
        return {
          id: estate.id_inmueble,
          codCat: estate.cod_catastral,
          direccion: estate.direccion,
          parroquia: estate.id_parroquia,
          metrosConstruccion: estate.metros_construccion,
          metrosTerreno: estate.metros_terreno,
          tipoInmueble: estate.tipo_inmueble,
          poseeGas: estate.posee_gas,
          fechaCreacion: estate.fecha_creacion,
          fechaActualizacion: estate.fecha_actualizacion,
          tarifaGas: await getGasTariffForEstate({ estate, branchId: branch.id_registro_municipal, client }),
          tarifaAseo: await getCleaningTariffForEstate({ estate, branchId: branch.id_registro_municipal, client }),
        };
      })
    );
    return { status: 200, message: 'ASEO DOMICILIARIO obtenidos por contribuyente', inmuebles: res };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los ASEO DOMICILIARIO del contribuyente',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getCleaningTariffForEstate = async ({ estate, branchId, client }) => {
  try {
    // if (!estate && !branchId) return (await client.query(queries.GET_AE_CLEANING_TARIFF, [branchId])).rows[0].monto;
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    if (!estate && !!branchId) return (await client.query(queries.GET_AE_CLEANING_TARIFF, [branchId])).rows[0]?.tarifa || 0;
    // const USD = (await client.query(queries.GET_USD_VALUE)).rows[0].valor_en_bs;
    // const costoMtsCom = +(await client.query(queries.GET_SCALE_FOR_COMMERCIAL_ESTATE_MTS_COST)).rows[0].indicador;
    // const limiteAseoCom = +(await client.query(queries.GET_SCALE_FOR_COMMERCIAL_ESTATE_PETRO_LIMIT)).rows[0].indicador;
    // const costoMtsInd = +(await client.query(queries.GET_SCALE_FOR_INDUSTRIAL_ESTATE_MTS_COST)).rows[0].indicador;
    // const limiteAseoInd = +(await client.query(queries.GET_SCALE_FOR_INDUSTRIAL_ESTATE_PETRO_LIMIT)).rows[0].indicador;
    // const costoMts = estate.tipo_inmueble === 'INDUSTRIAL' ? costoMtsInd : costoMtsCom;
    // const limiteAseo = estate.tipo_inmueble === 'INDUSTRIAL' ? limiteAseoInd : limiteAseoCom;
    const calculoAseo = !!['COMERCIAL', 'INDUSTRIAL'].find((type) => type === estate.tipo_inmueble)
      ? /*estate.metros_construccion && +estate.metros_construccion !== 0
        ? costoMts * PETRO * estate.metros_construccion
        :*/ +(await client.query(queries.GET_AE_CLEANING_TARIFF, [branchId])).rows[0]?.tarifa || +(await client.query(`SELECT indicador FROM impuesto.baremo WHERE descripcion = 'Tarifa por Inmueble Desocupado'`)).rows[0]?.indicador
      : +(await client.query(queries.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0]?.monto;
    // const tarifaAseo = calculoAseo / PETRO > limiteAseo ? PETRO * limiteAseo : calculoAseo;
    return +calculoAseo;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener la tarifa de aseo',
    };
  }
};

/**
 *
 * @param param0
 */
export const getGasTariffForEstate = async ({ estate, branchId, client }) => {
  try {
    const PETRO = +(await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    if (!estate && !!branchId) return +(await client.query(queries.GET_AE_GAS_TARIFF, [branchId])).rows[0].monto * PETRO;
    if (!estate.posee_gas) return 0;
    const tarifaGas = !!['COMERCIAL', 'INDUSTRIAL'].find((type) => type === estate.tipo_inmueble) ? (await client.query(queries.GET_AE_GAS_TARIFF, [branchId])).rows[0].monto : (await client.query(queries.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].monto;
    return +tarifaGas * PETRO;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener la tarifa de gas',
    };
  }
};

/**
 *
 * @param param0
 */
export const updateGasStateForEstate = async ({ estates }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const inmuebles = await Promise.all(
      estates.map(async (el) => {
        await client.query('UPDATE inmueble_urbano SET posee_gas = $1 WHERE id_inmueble = $2', [el.estado, el.id]);
        const estate = (await client.query(queries.GET_ESTATE_BY_ID, [el.id])).rows[0];
        const inmueble = {
          id: estate.id_inmueble,
          codCat: estate.cod_catastral,
          direccion: estate.direccion,
          parroquia: estate.id_parroquia,
          metrosConstruccion: estate.metros_construccion,
          metrosTerreno: estate.metros_terreno,
          tipoInmueble: estate.tipo_inmueble,
          poseeGas: estate.posee_gas,
          fechaCreacion: estate.fecha_creacion,
          fechaActualizacion: estate.fecha_actualizacion,
          tarifaGas: await getGasTariffForEstate({ estate, branchId: estate.id_registro_municipal, client }),
          tarifaAseo: await getCleaningTariffForEstate({ estate, branchId: estate.id_registro_municipal, client }),
        };
        return inmueble;
      })
    );
    await client.query('COMMIT');
    return { status: 200, message: 'Estado del gas actualizado', inmuebles };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar el estado del gas de los inmuebles',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getServicesTariffScales = async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const scales = (await client.query('SELECT id_baremo as id, descripcion, indicador FROM impuesto.baremo')).rows;
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
 * @param type
 * @param date
 */
export const getSettlementsByDepartment = async (type, date) => {
  const client = await pool.connect();
  try {
    const departamento = {
      SAGAS: [107],
      IMAU: [108],
      CPU: [9, 70, 71],
    };
    if (!departamento[type]) throw { status: 404, message: 'El departamento solicitado no est?? disponible' };
    const queriedDate = !!date ? moment(date) : moment();
    const liquidaciones = await Promise.all(
      (await client.query(queries.GET_SETTLEMENTS_BY_MONTH_IN_GROUPED_BRANCH, [departamento[type], queriedDate])).rows.map(async (el) => ({
        id: el.id_liquidacion,
        ramo: el.descripcionRamo,
        descripcion: el.descripcionSubramo,
        estado: el.state || 'finalizado',
        fechaLiquidacion: el.fecha_liquidacion,
        fechaSolicitud: el.fecha || 'N/A',
        monto: el.monto,
        certificado: el.certificado,
        recibo: el.recibo,
        contribuyente: (await client.query('SELECT id_contribuyente AS id, razon_social AS "razonSocial", documento, tipo_documento AS "tipoDocumento" FROM impuesto.contribuyente WHERE id_contribuyente = $1', [el.id_contribuyente])).rows[0],
      }))
    );
    return { status: 200, message: `Liquidaciones de ${type} obtenidas satisfactoriamente`, liquidaciones };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las liquidaciones de servicios por departamento',
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
export const updateGasTariffScales = async (id, tariff) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE impuesto.baremo_servicio_municipal SET indicador = $1 WHERE id_baremo = $2', [tariff, id]);
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
export const createMunicipalServicesScale = async ({ description, tariff }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const scale = (await client.query('INSERT INTO impuesto.baremo_servicio_municipal (descripcion, indicador) VALUES ($1, $2) RETURNING *', [description, tariff])).rows[0];
    await client.query('COMMIT');
    return { status: 200, message: 'Nuevo valor del baremo de ASEO DOMICILIARIO agregado', baremo: { id: scale.id_baremo, descripcion: scale.descripcion, indicador: scale.indicador } };
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
