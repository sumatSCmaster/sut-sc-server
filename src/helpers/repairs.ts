import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { Usuario, Liquidacion } from '@root/interfaces/sigt';
import { fixatedAmount, getApplicationsAndSettlementsById } from './settlement';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

const codigosRamo = {
  AE: 112,
  SM: 122,
  PP: 114,
  IU: 111,
  RD0: 915,
};

export const processRetentionFile = async (file) => {
  return {};
};

export const getRetentionMonths = async ({ document, reference, docType, user }: { document: string; reference: string; docType: string; user: Usuario }) => {
  const client = await pool.connect();
  let debtRD;
  try {
    if (!reference) throw { status: 403, message: 'Debe incluir un RIM de Agente de Retención' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'No existe el RIM de Agente de Retención proporcionado' };
    const RD0ApplicationExists = (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.RD0, reference])).rows[0];
    if (!!RD0ApplicationExists) throw { status: 409, message: 'Ya existe una declaración de retenciones para este mes' };
    const now = moment(new Date());

    let lastRD = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM, [codigosRamo.RD0, branch.referencia_municipal])).rows[0];
    const lastRDPayment = (lastRD && moment(lastRD.fecha_liquidacion)) || moment().month(0);
    const RDDate = moment([lastRDPayment.year(), lastRDPayment.month(), 1]);
    const dateInterpolation = Math.floor(now.diff(RDDate, 'M'));
    if (dateInterpolation > 0) {
      debtRD = await Promise.all(
        new Array(dateInterpolation).fill({ month: null, year: null }).map(async (value, index) => {
          const date = addMonths(new Date(lastRDPayment.toDate()), index);
          const momentDate = moment(date);
          const exonerado = await isExonerated({ branch: codigosRamo.RD0, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
        })
      );
    }
    return {
      status: 200,
      message: 'Deuda de retención obtenida satisfactoriamente',
      retenciones: {
        RD: debtRD,
        contribuyente: contributor.id_contribuyente,
        razonSocial: contributor.razon_social,
        siglas: contributor.siglas,
        rim: reference,
        documento: contributor.documento,
        tipoDocumento: contributor.tipo_documento,
        // creditoFiscal: fiscalCredit,
      },
    };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener deuda de retención',
    };
  } finally {
    client.release();
  }
};

// ! TODO: hacer el desglose de retencion y apuntar al ramo de retencion
export const insertRepairs = async ({ process, user }) => {
  const client = await pool.connect();
  const { reparo } = process;
  //Esto hay que sacarlo de db
  const finingAmount = 10;
  let finingMonths: any;
  try {
    client.query('BEGIN');
    const userContributor = user.tipoUsuario === 4 ? (await client.query(queries.GET_CONTRIBUTOR_BY_USER, [user.id])).rows : (await client.query(queries.TAX_PAYER_EXISTS, [process.tipoDocumento, process.documento])).rows;
    const userHasContributor = userContributor.length > 0;
    if (!userHasContributor) throw { status: 404, message: 'El usuario no esta asociado con ningun contribuyente' };
    const contributorReference = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [process.rim, userContributor[0].id_contribuyente])).rows[0];
    if (!!process.rim && !contributorReference) throw { status: 404, message: 'El rim proporcionado no existe' };
    const benefittedUser = (await client.query(queries.GET_USER_IN_CHARGE_OF_BRANCH_BY_ID, [contributorReference.id_registro_municipal])).rows[0];
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(user.tipoUsuario !== 4 && benefittedUser?.id) || user.id, userContributor[0].id_contribuyente])).rows[0];

    // const settlement: Liquidacion[] = await Promise.all(
    //   reparo.map(async (el) => {
    let settlements: any[] = [];
    for (let year in reparo) {
      const settlement: Liquidacion[] = await Promise.all(
        reparo[year].map(async (el) => {
          const month = el[0].mes;
          const datos = {
            fecha: { month, year },
            desglose: el,
          };
          // console.log(el.ramo);
          const liquidacion = (
            await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
              application.id_solicitud,
              fixatedAmount(+el.reduce((i, j) => i + j.monto, 0) * 1.3),
              'REP',
              datos,
              moment().month(month).endOf('month').format('MM-DD-YYYY'),
              (contributorReference && contributorReference.id_registro_municipal) || null,
            ])
          ).rows[0];

          return {
            id: liquidacion.id_liquidacion,
            ramo: branchNames['REP'],
            fecha: datos.fecha,
            monto: liquidacion.monto,
            certificado: liquidacion.certificado,
            recibo: liquidacion.recibo,
            desglose: datos.desglose,
          };
          //   })
          // );
        })
      );
      settlements.push(settlement);
    }
    let state = (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS])).rows[0].state;
    if (settlements.flat().reduce((x, y) => x + +y.monto, 0) === 0) {
      (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.VALIDAR])).rows[0].state;
      state = await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
    }
    await client.query('COMMIT');
    const solicitud = await getApplicationsAndSettlementsById({ id: application.id_solicitud, user });
    // await sendNotification(
    //   user,
    //   `Se ha iniciado una solicitud para el contribuyente con el documento de identidad: ${solicitud.tipoDocumento}-${solicitud.documento}`,
    //   'CREATE_APPLICATION',
    //   'IMPUESTO',
    //   { ...solicitud, estado: state, nombreCorto: 'SEDEMAT' },
    //   client
    // );
    return { status: 201, message: 'Reparo fiscal iniciado', solicitud };
  } catch (error) {
    console.log(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al iniciar un reparo fiscal',
    };
  } finally {
    client.release();
  }
};

const addMonths = (date: Date, months): Date => {
  const d = date.getDate();
  date.setMonth(date.getMonth() + +months);
  if (date.getDate() != d) {
    date.setDate(0);
  }
  return date;
};

const isExonerated = async ({ branch, contributor, activity, startingDate }): Promise<boolean> => {
  const client = await pool.connect();
  try {
    if (branch === codigosRamo.AE) {
      const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
      if (branchIsExonerated) return !!branchIsExonerated;
      const activityIsExonerated = (await client.query(queries.ECONOMIC_ACTIVITY_IS_EXONERATED, [activity, startingDate])).rows[0];
      if (activityIsExonerated) return !!activityIsExonerated;
      const contributorIsExonerated = (await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
      if (contributorIsExonerated) return !!contributorIsExonerated;
      return !!(await client.query(queries.CONTRIBUTOR_ECONOMIC_ACTIVIES_IS_EXONERATED, [contributor, activity, startingDate])).rows[0];
    } else {
      const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
      if (branchIsExonerated) return !!branchIsExonerated;
      return !!(await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
    }
    return false;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

const branchNames = {
  AE: 'ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES',
  SM: 'SERVICIOS MUNICIPALES',
  IU: 'PROPIEDAD INMOBILIARIA',
  PP: 'PROPAGANDAS Y AVISOS COMERCIALES',
  SAE: 'TASA ADMINISTRATIVA DE SOLVENCIA DE AE',
  RD0: 'RETENCIONES DECRETO 048',
  REP: 'REPAROS FISCALES',
};

const applicationStateEvents = {
  INGRESARDATOS: 'ingresardatos_pi',
  APROBARCAJERO: 'aprobacioncajero_pi',
  VALIDAR: 'validar_pi',
  FINALIZAR: 'finalizar_pi',
  REBOTAR: 'rebotado_pi',
};
