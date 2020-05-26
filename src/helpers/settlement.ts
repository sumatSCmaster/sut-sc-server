import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import { insertPaymentReference } from './banks';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { Liquidacion, Solicitud, Usuario } from '@root/interfaces/sigt';
import { resolve } from 'path';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
const gticPool = GticPool.getInstance();
const pool = Pool.getInstance();

const dev = process.env.NODE_ENV !== 'production';

export const getSettlements = async ({ document, reference, type, user }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  const montoAcarreado: any = {};
  let AE, SM, IU, PP;
  try {
    const currentApplicationExists = (await client.query(queries.CURRENT_APPLICATION_EXISTS, [document, reference, type])).rows;
    if (currentApplicationExists.length > 0) return { status: 409, message: 'Ya existe una declaracion de impuestos para este mes' };
    const contributor = (reference
      ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference, type])
      : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document, type])
    ).rows[0];
    if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    console.log(contributor);
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
            el.tx_tp_inmueble === 'COMERCIAL'
              ? el.nu_metro_cuadrado && el.nu_metro_cuadrado !== 0
                ? 0.15 * el.nu_metro_cuadrado
                : (await gtic.query(queries.gtic.GET_MAX_CLEANING_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa
              : (await gtic.query(queries.gtic.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].nu_tarifa;
          const tarifaGas =
            el.tx_tp_inmueble === 'COMERCIAL'
              ? (await gtic.query(queries.gtic.GET_MAX_GAS_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa
              : (await gtic.query(queries.gtic.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].nu_tarifa;
          return { tipoInmueble: el.tx_tp_inmueble, direccionInmueble: el.tx_direccion, tarifaAseo, tarifaGas, deuda: debtSM };
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
          return { direccionInmueble: el.tx_direccion, ultimoAvaluo: el.nu_monto, impuestoInmueble: (el.nu_monto * 0.01) / 12, deuda: debtIU };
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
        return { month: date.toLocaleString('ES', { month: 'long' }), year: date.getFullYear() };
      });
    }
    if (debtPP) {
      const publicityArticles = (await gtic.query(queries.gtic.GET_PUBLICITY_ARTICLES)).rows;
      const publicitySubarticles = (await gtic.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
      PP = {
        deuda: debtPP,
        articulos: publicityArticles.map((el) => {
          return {
            id: +el.co_articulo,
            nombreArticulo: el.tx_articulo,
            subarticulos: publicitySubarticles
              .filter((al) => +el.co_articulo === al.co_articulo)
              .map((el) => {
                return {
                  id: +el.co_medio,
                  nombreSubarticulo: el.tx_medio,
                  parametro: el.parametro,
                  costo: +el.ut_medio * UTMM,
                  costoAlto: el.parametro === 'BANDA' ? (+el.ut_medio + 2) * UTMM : undefined,
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
        montoAcarreado: addMissingCarriedAmounts(montoAcarreado),
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
  const { impuestos } = process;
  try {
    client.query('BEGIN');
    const application = (
      await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, process.documento, process.rim, process.nacionalidad, process.totalPagoImpuestos])
    ).rows[0];
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
          tipoProcedimiento: el.tipoImpuesto,
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
    if (!payment.costo) return { status: 403, message: 'Debe incluir el monto a ser pagado' };
    const solicitud = (await client.query('SELECT * FROM impuesto.solicitud WHERE id_solicitud = $1', [application])).rows[0];
    const pagoSum = payment.map((e) => e.costo).reduce((e, i) => e + i);
    if (pagoSum < solicitud.monto_total) return { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
    payment.map(async (el) => {
      const nearbyHolidays = (
        await client.query("SELECT * FROM impuesto.dias_feriados WHERE dia BETWEEN $1::date AND ($1::date + interval '7 days');", [el.fecha])
      ).rows;
      const paymentDate = checkIfWeekend(moment(el.fecha));
      if (nearbyHolidays.length > 0) {
        while (nearbyHolidays.find((el) => el.dia === paymentDate.format('YYYY-MM-DD'))) paymentDate.add({ days: 1 });
      }
      el.fecha = paymentDate;
      el.concepto = 'IMPUESTO';
      await insertPaymentReference(el, application, client);
    });
    await client.query(queries.UPDATE_PAID_STATE_FOR_TAX_PAYMENT_APPLICATION, [application]);
    client.query('COMMIT');
    return { status: 200, message: 'Pago añadido para la solicitud declarada' };
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

export const createCertificateForApplication = async ({ settlement, media, user }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    client.query('BEGIN');
    const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_SETTLEMENT, [settlement])).rows[0];
    if (applicationView[media]) return { status: 200, message: 'Certificado generado satisfactoriamente', media: applicationView[media] };
    const dir = await certificateCreationHandler(applicationView.tipoLiquidacion, media, {
      gticPool: gtic,
      pool: client,
      user,
      application: applicationView,
    });
    client.query('COMMIT');
    return { status: 200, message: 'Certificado generado satisfactoriamente', media: dir };
  } catch (error) {
    client.query('ROLLBACK');
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
const mesesCardinal = {
  Enero: 'Primer',
  Febrero: 'Segundo',
  Marzo: 'Tercer',
  Abril: 'Cuarto',
  Mayo: 'Quinto',
  Junio: 'Sexto',
  Julio: 'Séptimo',
  Agosto: 'Octavo',
  Septiembre: 'Noveno',
  Octubre: 'Décimo',
  Noviembre: 'Undécimo',
  Diciembre: 'Duodécimo',
};
const createSolvencyForApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical
      ? [application.documento, application.rim, application.nacionalidad]
      : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-solvencia-AE.pug`), {
        moment: require('moment'),
        tramite: 'PAGO DE IMPUESTOS',
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          contribuyente: isJuridical ? datosContribuyente.tx_razon_social : datosContribuyente.nb_contribuyente + datosContribuyente.ap_contribuyente,
          rim: application.rim,
          cedulaORif: application.nacionalidad + '-' + application.documento,
          direccion: datosContribuyente.tx_direccion,
          representanteLegal: datosContribuyente.nb_representante_legal,
          periodo: mesesCardinal[application.mes],
          anio: application.anio,
          fecha: moment().format('DD-MM-YYYY'),
          fechaLetra: `${moment().date()} de ${application.mes} de ${application.anio}`,
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/solvencia.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/solvencia.pdf`;
      if (dev) {
        pdf
          .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
          .toFile(pdfDir, async () => {
            await pool.query(queries.UPDATE_CERTIFICATE_SETTLEMENT, [dir, application.idLiquidacion]);
            res(dir);
          });
      } else {
        // try {
        //   pdf
        //     .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        //     .toBuffer(async (err, buffer) => {
        //       if (err) {
        //         rej(err);
        //       } else {
        //         const bucketParams = {
        //           Bucket: 'sut-maracaibo',
        //           Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
        //         };
        //         await S3Client.putObject({
        //           ...bucketParams,
        //           Body: buffer,
        //           ACL: 'public-read',
        //           ContentType: 'application/pdf',
        //         }).promise();
        //         res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
        //       }
        //     });
        // } catch (e) {
        //   throw e;
        // } finally {
        // }
      }
    });
  } catch (error) {
    throw error;
  }
};

const createReceiptForSMOrIUApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical
      ? [application.documento, application.rim, application.nacionalidad]
      : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    if (application.tipoLiquidacion === 'SM') {
    } else if (application.tipoLiquidacion === 'IU') {
    }
  } catch (error) {
    throw error;
  }
};

const createReceiptForAEApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical
      ? [application.documento, application.rim, application.nacionalidad]
      : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const economicActivities = (await gticPool.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [datosContribuyente.co_contribuyente])).rows[0];
    const applicationInfo = (await gticPool.query(queries.gtic.GET_INFO_FOR_AE_CERTIFICATE)).rows[0];
    const UTMM = (await pool.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const impuesto = UTMM * 2;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    moment.locale('es');

    const certAE = {
      fecha: moment().format('YYYY-MM-DD'),
      tramite: 'PAGO DE IMPUESTOS',
      moment: require('moment'),
      QR: linkQr,
      datos: {
        nroSolicitud: application.id,
        nroPlanilla: new Date().getTime().toString().slice(7),
        motivo: `D${application.mes.substr(0, 3).toUpperCase()}${application.anio}`,
        porcion: '1/1',
        categoria: applicationInfo.tx_ramo,
        rif: `${application.nacionalidad}-${application.documento}`,
        ref: application.rim,
        razonSocial: isJuridical ? datosContribuyente.tx_razon_social : datosContribuyente.nb_contribuyente + datosContribuyente.ap_contribuyente,
        direccion: datosContribuyente.tx_direccion,
        fechaCre: moment(application.fechaCreacion).format('YYYY-MM-DD'),
        fechaLiq: moment().format('YYYY-MM-DD'),
        fechaVenc: moment().date(31).format('YYYY-MM-DD'),
        codigo: economicActivities.nu_ref_actividad,
        descripcion: economicActivities.tx_actividad,
        montoDeclarado: (application.montoLiquidacion / (economicActivities.nu_porc_alicuota / 100)).toFixed(2),
        alicuota: economicActivities.nu_porc_alicuota / 100,
        minTrib: Math.floor(economicActivities.nu_ut),
        impuesto: application.montoLiquidacion,
        totalImpuestoDet: application.montoLiquidacion,
        tramitesInternos: impuesto,
        totalTasaRev: 0.0,
        anticipoYRetenciones: 0.0,
        interesMora: 0.0,
        montoTotal: application.montoLiquidacion + impuesto,
        observacion: 'Pago por Impuesto de Actividad Economica - VIA WEB',
        estatus: 'PAGADO',
        totalLiq: application.montoLiquidacion + impuesto,
        totalRecaudado: 0.0,
        totalCred: 0.0,
      },
    };
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-AE.pug`), certAE);
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
      const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });
      if (dev) {
        pdf
          .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
          .toFile(pdfDir, async () => {
            await pool.query(queries.UPDATE_RECEIPT_FOR_SETTLEMENTS, [dir, application.idProcedimiento, application.id]);
            res(dir);
          });
      } else {
        // try {
        //   pdf
        //     .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        //     .toBuffer(async (err, buffer) => {
        //       if (err) {
        //         rej(err);
        //       } else {
        //         const bucketParams = {
        //           Bucket: 'sut-maracaibo',
        //           Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
        //         };
        //         await S3Client.putObject({
        //           ...bucketParams,
        //           Body: buffer,
        //           ACL: 'public-read',
        //           ContentType: 'application/pdf',
        //         }).promise();
        //         res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
        //       }
        //     });
        // } catch (e) {
        //   throw e;
        // } finally {
        // }
      }
    });
  } catch (error) {
    throw error;
  }
};

const createReceiptForPPApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
  } catch (error) {
    throw error;
  }
};

const certificateCreationSnippet = () => {
  // const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${id}`, { errorCorrectionLevel: 'H' });
  // return new Promise(async (res, rej) => {
  //   const html = renderFile(resolve(__dirname, `../views/planillas/${planilla}.pug`), {
  //     fecha,
  //     codigo,
  //     formato,
  //     tramite,
  //     institucion,
  //     datos,
  //     id,
  //     cache: false,
  //     moment: require('moment'),
  //     QR: linkQr,
  //     costoFormateado,
  //     UTMM,
  //     costo,
  //     written,
  //   });
  //   const pdfDir = resolve(__dirname, `../../archivos/tramites/${codigo}/${dir.split('/').pop()}`);
  //   if (dev) {
  //     pdf
  //       .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
  //       .toFile(pdfDir, () => {
  //         res(dir);
  //       });
  //   } else {
  //     try {
  //       pdf
  //         .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
  //         .toBuffer(async (err, buffer) => {
  //           if (err) {
  //             rej(err);
  //           } else {
  //             const bucketParams = {
  //               Bucket: 'sut-maracaibo',
  //               Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
  //             };
  //             await S3Client.putObject({
  //               ...bucketParams,
  //               Body: buffer,
  //               ACL: 'public-read',
  //               ContentType: 'application/pdf',
  //             }).promise();
  //             res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
  //           }
  //         });
  //     } catch (e) {
  //       throw e;
  //     } finally {
  //     }
  //   }
  // });
};

const checkIfWeekend = (date: Moment) => {
  if (date.isoWeekday() === 6) date.add({ days: 2 });
  if (date.isoWeekday() === 7) date.add({ days: 1 });
  return date;
};

const addMissingCarriedAmounts = (amountObject) => {
  if (!amountObject.hasOwnProperty('AE')) amountObject.AE = { monto: 0 };
  if (!amountObject.hasOwnProperty('SM')) amountObject.SM = { monto: 0 };
  if (!amountObject.hasOwnProperty('IU')) amountObject.IU = { monto: 0 };
  if (!amountObject.hasOwnProperty('PP')) amountObject.PP = { monto: 0 };
  return amountObject;
};

const certificateCases = switchcase({
  AE: { recibo: createReceiptForAEApplication, solvencia: createSolvencyForApplication },
  SM: { recibo: createReceiptForSMOrIUApplication },
  IU: { recibo: createReceiptForSMOrIUApplication },
  PP: { recibo: createReceiptForPPApplication },
})(null);

const certificateCreationHandler = async (process, media, payload: CertificatePayload) => {
  try {
    const result = certificateCases(process)[media];
    if (result) return await result(payload);
    throw new Error('No se encontró el tipo de certificado seleccionado');
  } catch (e) {
    throw e;
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

interface CertificatePayload {
  gticPool: PoolClient;
  pool: PoolClient;
  user: Usuario;
  application: any;
}
