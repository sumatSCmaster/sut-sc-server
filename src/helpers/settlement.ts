import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import moment from 'moment';
import switchcase from '@utils/switch';
const gticPool = GticPool.getInstance();
const pool = Pool.getInstance();

export const getSettlements = async ({ document, reference }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  let AE, SM, IU, PP;
  try {
    const contributor = (reference
      ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference])
      : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document])
    ).rows[0];
    if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const now = moment(new Date());
    if (contributor.nu_referencia) {
      const economicActivities = (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [contributor.co_contribuyente])).rows;
      if (economicActivities.length === 0) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      let lastEA = (await gtic.query(queries.gtic.GET_ACTIVE_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastEA) lastEA = (await gtic.query(queries.gtic.GET_PAID_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastEA) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      const lastEAPayment = moment(lastEA.fe_liquidacion);
      const dateInterpolation = Math.floor(now.diff(lastEAPayment, 'M'));
      if (dateInterpolation !== 0) {
        AE = economicActivities.map((el) => {
          return {
            nombreActividad: el.tx_actividad,
            idContribuyente: el.co_contribuyente,
            alicuota: el.nu_porc_alicuota / 100,
            deuda: new Array(dateInterpolation).fill({ month: null, year: null }).map((value, index) => {
              const date = addMonths(new Date(lastEAPayment.toDate()), index);
              return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
            }),
          };
        });
      }
    }
    const estates = (await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows;
    if (estates.length > 0) {
      let lastSM = (await gtic.query(queries.gtic.GET_ACTIVE_MUNICIPAL_SERVICES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastSM) lastSM = (await gtic.query(queries.gtic.GET_PAID_MUNICIPAL_SERVICES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastSM) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      const lastSMPayment = moment(lastSM.fe_liquidacion);
      const dateInterpolationSM = Math.floor(now.diff(lastSMPayment, 'M'));
      const debtSM = new Array(dateInterpolationSM).fill({ month: null, year: null }).map((value, index) => {
        const date = addMonths(new Date(lastSMPayment.toDate()), index);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
      SM = Promise.all(
        estates.map(async (el) => {
          const tarifaAseo =
            el.tx_tipo_inmueble === 'COMERCIAL'
              ? el.nu_metro_cuadrado && el.nu_metro_cuadrado !== 0
                ? 0.15 * el.nu_metro_cuadrado
                : (await gtic.query(queries.gtic.GET_MAX_CLEANING_TARIFF_BY_CONTRIBUTOR)).rows[0].nu_tarifa
              : (await gtic.query(queries.gtic.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].nu_tarifa;
          const tarifaGas =
            el.tx_tipo_inmueble === 'COMERCIAL'
              ? (await gtic.query(queries.gtic.GET_MAX_GAS_TARIFF_BY_CONTRIBUTOR)).rows[0].nu_tarifa
              : (await gtic.query(queries.gtic.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].nu_tarifa;
          return { direccionInmueble: el.tx_direccion_inmueble, tarifaAseo, tarifaGas, deuda: debtSM };
        })
      );

      let lastIU = (await gtic.query(queries.gtic.GET_ACTIVE_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastIU) lastIU = (await gtic.query(queries.gtic.GET_PAID_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastIU) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      const lastIUPayment = moment(lastIU.fe_liquidacion);
      const dateInterpolationIU = Math.floor(now.diff(lastIUPayment, 'M'));
      const debtIU = new Array(dateInterpolationIU).fill({ month: null, year: null }).map((value, index) => {
        const date = addMonths(new Date(lastIUPayment.toDate()), index);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
      IU = estates.map((el) => {
        return { direccionInmueble: el.tx_direccion_inmueble, ultimoAvaluo: el.nu_monto, impuestoInmueble: (el.nu_monto * 0.01) / 12, deuda: debtIU };
      });
    }

    let debtPP;
    let lastPP = (await gtic.query(queries.gtic.GET_ACTIVE_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
    if (!lastPP) lastPP = (await gtic.query(queries.gtic.GET_PAID_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
    if (lastPP) {
      const lastPPPayment = moment(lastPP.fe_liquidacion);
      const dateInterpolationPP = Math.floor(now.diff(lastPPPayment, 'M'));
      debtPP = new Array(dateInterpolationPP).fill({ month: null, year: null }).map((value, index) => {
        const date = addMonths(new Date(lastPPPayment.toDate()), index);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
    } else {
      debtPP = new Array(1).fill({ month: null, year: null }).map((value) => {
        const date = addMonths(new Date(), -1);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
    }
    const publicityArticles = (await gtic.query(queries.gtic.GET_PUBLICITY_ARTICLES)).rows;
    const publicitySubarticles = (await gtic.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
    PP = {
      deuda: debtPP,
      articulos: publicityArticles.map((el) => {
        return {
          id: el.co_articulo,
          nombreArticulo: el.tx_articulo,
          subarticulos: Promise.all(
            publicitySubarticles
              .filter((al) => el.co_articulo === al.co_articulo)
              .map(async (el) => {
                const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
                return {
                  id: el.co_medio,
                  nombreSubarticulo: el.tx_medio,
                  parametro: el.parametro,
                  costo: el.ut_medio * UTMM,
                };
              })
          ),
        };
      }),
    };
    //buscar las cuestiones de publicidad e indexarlas correctamente
    //patras
    return {
      status: 200,
      message: 'Impuestos obtenidos satisfactoriamente',
      impuesto: {
        razonSocial: contributor.tx_razon_social || `${contributor.nb_contribuyente} ${contributor.ap_contribuyente}`,
        siglas: contributor.tx_siglas,
        rim: contributor.nu_referencia,
        documento: contributor.tx_rif || contributor.nu_cedula,
        AE,
        SM,
        IU,
        PP,
      },
    };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener los impuestos',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

export const insertSettlements = async () => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

function addMonths(date, months): Date {
  const d = date.getDate();
  date.setMonth(date.getMonth() + +months);
  if (date.getDate() != d) {
    date.setDate(0);
  }
  return date;
}
