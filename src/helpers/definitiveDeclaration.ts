import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import { fixatedAmount, isExonerated } from './settlement';
import { uniqBy } from 'lodash';

const pool = Pool.getInstance();

const template = async (props) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return { status: 200, message: '' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};

export const getDataForDefinitiveDeclaration = async ({ document, reference, docType }) => {
  const client = await pool.connect();
  try {
    const now = moment(new Date());
    const proposedYear = now.clone().subtract(1, 'year');
    if (!reference) throw { status: 403, message: 'Debe incluir un RIM' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'No existe el RIM proporcionado' };
    const lastYearDeclaration = (await client.query(queries.ALL_YEAR_SETTLEMENTS_EXISTS_FOR_LAST_YEAR_AE_DECLARATION, [codigosRamo.AE, branch.id_registro_municipal, proposedYear.year()])).rows;
    const definitiveDeclaration = uniqBy(lastYearDeclaration, (settlement) => settlement.datos.fecha.month).filter((el) => !!el.datos.desglose);
    if (definitiveDeclaration.length < 12) throw { status: 409, message: 'Debe realizar todas las declaraciones de AE correspondientes al año previo' };
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    const solvencyCost = branch?.estado_licencia === 'PERMANENTE' ? +(await client.query(queries.GET_SCALE_FOR_PERMANENT_AE_SOLVENCY)).rows[0].indicador : +(await client.query(queries.GET_SCALE_FOR_TEMPORAL_AE_SOLVENCY)).rows[0].indicador;
    const liquidaciones = await Promise.all(
      definitiveDeclaration.map(async (el) => {
        const startingDate = moment().locale('ES').month(el.datos.fecha.month).year(el.datos.fecha.year).startOf('month');
        el.datos.desglose = await Promise.all(
          el.datos.desglose.map(async (d) => {
            const aforo = (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_ID, [d.aforo])).rows[0];
            const exonerado = await isExonerated({ branch: 112, contributor: branch?.id_registro_municipal, activity: aforo.id_actividad_economica, startingDate }, client);
            return {
              id: aforo.id_actividad_economica,
              minimoTributable: Math.round(aforo.minimo_tributable) * PETRO,
              nombreActividad: aforo.descripcion,
              // idContribuyente: +branch.id_registro_municipal,
              alicuota: aforo.alicuota / 100,
              exonerado,
              montoDeclarado: fixatedAmount(d.montoDeclarado),
              montoCobrado: d.montoCobrado,
              costoSolvencia: PETRO * solvencyCost,
            };
          })
        );
        return {
          id: el.id_liquidacion,
          monto: fixatedAmount(el.monto),
          montoPetro: +el.monto_petro,
          datos: el.datos,
          estado: el.estado,
          fecha: el.datos.fecha,
        };
      })
    );
    return { status: 200, message: 'Declaraciones previas obtenidas', liquidaciones };
  } catch (error) {
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener declaraciones previas',
    };
  } finally {
    client.release();
  }
};

export const insertDefinitiveYearlyDeclaration = async ({ process, user }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return { status: 200, message: 'Declaracion anual creada' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al insertar declaracion definitiva anual',
    };
  } finally {
    client.release();
  }
};

const codigosRamo = {
  AE: 112,
  SM: 122,
  MUL: 501,
  PP: 114,
  IU: 111,
  RD0: 915,
};
