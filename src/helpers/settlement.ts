import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import { insertPaymentReference } from './banks';
import moment from 'moment';
import switchcase from '@utils/switch';
import { Liquidacion, Solicitud, Usuario } from '@root/interfaces/sigt';
const gticPool = GticPool.getInstance();
const pool = Pool.getInstance();

export const getSettlements = async ({ document, reference, type }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  const montoAcarreado: any = {};
  let AE, SM, IU, PP;
  try {
    const contributor = (reference
      ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference, type])
      : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document, type])
    ).rows[0];
    if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const now = moment(new Date());
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    if (contributor.nu_referencia) {
      const economicActivities = (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [contributor.co_contribuyente])).rows;
      if (economicActivities.length === 0) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      let lastEA = (await gtic.query(queries.gtic.GET_ACTIVE_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastEA) lastEA = (await gtic.query(queries.gtic.GET_PAID_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastEA) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      const lastEAPayment = moment(lastEA.fe_liquidacion);
      const pastMonthEA = moment(lastEA.fe_liquidacion).subtract(1, 'M');
      const EADate = moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
      const dateInterpolation = Math.floor(now.diff(EADate, 'M'));
      montoAcarreado.AE = {
        monto: lastEA.mo_pendiente ? parseFloat(lastEA.mo_pendiente) : 0,
        fecha: { month: pastMonthEA.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthEA.year() },
      };
      if (dateInterpolation !== 0) {
        AE = economicActivities.map((el) => {
          return {
            id: el.nu_ref_actividad,
            nombreActividad: el.tx_actividad,
            idContribuyente: el.co_contribuyente,
            alicuota: el.nu_porc_alicuota / 100,
            costoSolvencia: UTMM * 2,
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
      const pastMonthSM = moment(lastSM.fe_liquidacion).subtract(1, 'M');
      const SMDate = moment([lastSMPayment.year(), lastSMPayment.month(), 1]);
      const dateInterpolationSM = Math.floor(now.diff(SMDate, 'M'));
      montoAcarreado.SM = {
        monto: lastSM.mo_pendiente ? parseFloat(lastSM.mo_pendiente) : 0,
        fecha: { month: pastMonthSM.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthSM.year() },
      };
      const debtSM = new Array(dateInterpolationSM).fill({ month: null, year: null }).map((value, index) => {
        const date = addMonths(new Date(lastSMPayment.toDate()), index);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
      SM = await Promise.all(
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
          return { tipoInmueble: el.tx_tipo_inmueble, direccionInmueble: el.tx_direccion_inmueble, tarifaAseo, tarifaGas, deuda: debtSM };
        })
      );

      let lastIU = (await gtic.query(queries.gtic.GET_ACTIVE_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastIU) lastIU = (await gtic.query(queries.gtic.GET_PAID_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
      if (!lastIU) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      const lastIUPayment = moment(lastIU.fe_liquidacion);
      const pastMonthIU = moment(lastIU.fe_liquidacion).subtract(1, 'M');
      const IUDate = moment([lastIUPayment.year(), lastIUPayment.month(), 1]);
      const dateInterpolationIU = Math.floor(now.diff(IUDate, 'M'));
      montoAcarreado.IU = {
        monto: lastIU.mo_pendiente ? parseFloat(lastIU.mo_pendiente) : 0,
        fecha: { month: pastMonthIU.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthIU.year() },
      };
      if (dateInterpolationIU > 0) {
        const debtIU = new Array(dateInterpolationIU).fill({ month: null, year: null }).map((value, index) => {
          const date = addMonths(new Date(lastIUPayment.toDate()), index);
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
        });
        IU = estates.map((el) => {
          return { direccionInmueble: el.tx_direccion_inmueble, ultimoAvaluo: el.nu_monto, impuestoInmueble: (el.nu_monto * 0.01) / 12, deuda: debtIU };
        });
      }
    }

    let debtPP;
    let lastPP = (await gtic.query(queries.gtic.GET_ACTIVE_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
    if (!lastPP) lastPP = (await gtic.query(queries.gtic.GET_PAID_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
    if (lastPP) {
      const lastPPPayment = moment(lastPP.fe_liquidacion);
      const pastMonthPP = moment(lastPP.fe_liquidacion).subtract(1, 'M');
      const PPDate = moment([lastPPPayment.year(), lastPPPayment.month(), 1]);
      const dateInterpolationPP = Math.floor(now.diff(PPDate, 'M'));
      montoAcarreado.PP = {
        monto: lastPP.mo_pendiente ? parseFloat(lastPP.mo_pendiente) : 0,
        fecha: { month: pastMonthPP.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthPP.year() },
      };
      if (dateInterpolationPP > 0) {
        debtPP = new Array(dateInterpolationPP).fill({ month: null, year: null }).map((value, index) => {
          const date = addMonths(new Date(lastPPPayment.toDate()), index);
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
        });
      }
    } else {
      debtPP = new Array(1).fill({ month: null, year: null }).map((value) => {
        const date = addMonths(new Date(), -1);
        return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
      });
    }
    if (debtPP) {
      console.log(debtPP);
      const publicityArticles = (await gtic.query(queries.gtic.GET_PUBLICITY_ARTICLES)).rows;
      const publicitySubarticles = (await gtic.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
      PP = {
        deuda: debtPP,
        articulos: publicityArticles.map((el) => {
          return {
            id: el.co_articulo,
            nombreArticulo: el.tx_articulo,
            subarticulos: publicitySubarticles
              .filter((al) => el.co_articulo === al.co_articulo)
              .map((el) => {
                return {
                  id: el.co_medio,
                  nombreSubarticulo: el.tx_medio,
                  parametro: el.parametro,
                  costo: el.ut_medio * UTMM,
                };
              }),
          };
        }),
      };
    }
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
        montoAcarreado,
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

export const insertSettlements = async ({ process, user }) => {
  const client = await pool.connect();
  const { pago, impuestos } = process;
  try {
    client.query('BEGIN');
    const application = (
      await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, process.documento, process.rim, process.nacionalidad, process.totalPagoImpuestos])
    ).rows[0];
    if (!pago) return { status: 403, message: 'Debe incluir el pago de la solicitud' };
    const settlement: Liquidacion[] = await Promise.all(
      impuestos.map(async (el) => {
        const liquidacion = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            application.id_solicitud,
            el.tipoImpuesto,
            el.fechaCancelada.month,
            el.fechaCancelada.year,
            el.monto,
          ])
        ).rows[0];
        return {
          id: liquidacion.id,
          tipoProcedimiento: el.tipoProcedimiento,
          fecha: { month: liquidacion.mes, year: liquidacion.anio },
          monto: liquidacion.monto,
          certificado: liquidacion.certificado,
          recibo: liquidacion.recibo,
        };
      })
    );

    const solicitud: Solicitud = {
      id: application.id_solicitud,
      usuario: user,
      documento: application.documento,
      rim: application.rim,
      nacionalidad: application.nacionalidad,
      aprobado: application.aprobado,
      pagado: application.pagado,
      fecha: application.fecha,
      monto: application.monto_total,
      liquidaciones: settlement,
    };

    client.query('COMMIT');
    return { status: 201, message: 'Liquidaciones de impuestos creadas satisfactoriamente', solicitud };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const getApplicationsAndSettlements = async ({ user }: { user: Usuario }) => {
  const client = await pool.connect();
  try {
    const applications: Solicitud[] = await Promise.all(
      (await client.query(queries.GET_APPLICATION_INSTANCES_BY_USER, [user.id])).rows.map(async (el) => {
        return {
          id: el.id_solicitud,
          usuario: user,
          documento: el.documento,
          rim: el.rim,
          nacionalidad: el.nacionalidad,
          aprobado: el.aprobado,
          pagado: el.pagado,
          fecha: el.fecha,
          monto: el.monto_total,
          liquidaciones: await Promise.all(
            (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows.map((el) => {
              return {
                id: el.id,
                tipoProcedimiento: el.tipoProcedimiento,
                fecha: { month: el.mes, year: el.anio },
                monto: el.monto,
                certificado: el.certificado,
                recibo: el.recibo,
              };
            })
          ),
        };
      })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', solicitudes: applications };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const addTaxApplicationPayment = async ({ payment, application }) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    if (!payment.monto) return { status: 403, message: 'Debe incluir el monto a ser pagado' };
    payment.concepto = 'IMPUESTO';
    await insertPaymentReference(payment, application, client);
    await client.query(queries.UPDATE_PAID_STATE_FOR_TAX_PAYMENT_APPLICATION, [application]);
    client.query('COMMIT');
    return { status: 201, message: 'Pago añadido para la solicitud declarada' };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones',
    };
  } finally {
    client.release();
  }
};

const addMonths = (date, months): Date => {
  const d = date.getDate();
  date.setMonth(date.getMonth() + +months);
  if (date.getDate() != d) {
    date.setDate(0);
  }
  return date;
};
