import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';

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

export const getMunicipalServicesByContributor = async ({ reference, document, docType }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
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
    return res;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los servicios municipales del contribuyente',
    };
  } finally {
    client.release();
  }
};

export const getCleaningTariffForEstate = async ({ estate, branchId, client }) => {
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const USD = (await client.query(queries.GET_USD_VALUE)).rows[0].valor_en_bs;
    const calculoAseo =
      estate.tipo_inmueble === 'COMERCIAL'
        ? estate.metros_construccion && estate.metros_construccion !== 0
          ? 0.1 * USD * estate.metros_construccion
          : (await client.query(queries.GET_AE_CLEANING_TARIFF, [branchId])).rows[0].monto
        : (await client.query(queries.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].monto;
    const tarifaAseo = calculoAseo / UTMM > 150 ? UTMM * 150 : calculoAseo;
    return tarifaAseo;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener la tarifa de aseo',
    };
  }
};

export const getGasTariffForEstate = async ({ estate, branchId, client }) => {
  try {
    if (!estate.posee_gas) return undefined;
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const calculoGas = estate.tipo_inmueble === 'COMERCIAL' ? (await client.query(queries.GET_AE_GAS_TARIFF, [branchId])).rows[0].monto : (await client.query(queries.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].monto;
    const tarifaGas = calculoGas / UTMM > 300 ? UTMM * 300 : calculoGas;
    return tarifaGas;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener la tarifa de aseo',
    };
  }
};

export const updateGasStateForEstate = async ({ estateId, gasState }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE inmueble_urbano SET posee_gas = $1 WHERE id_inmueble = $2', [gasState, estateId]);
    await client.query('COMMIT');
    const estate = (await client.query(queries.GET_ESTATE_BY_ID, [estateId])).rows[0];
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
