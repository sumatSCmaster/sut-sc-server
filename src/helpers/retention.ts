import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { Usuario, Liquidacion } from '@root/interfaces/sigt';
import { finingPercentage, fixatedAmount, getApplicationsAndSettlementsById, getApplicationsAndSettlementsByIdNots, isExonerated } from './settlement';
import { getUsersByContributor } from './user';
import { generateReceipt } from './receipt';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

const codigosRamo = {
  AE: 112,
  SM: 122,
  MUL: 501,
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
    const RD0ApplicationExists = (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.RD0, branch.id_registro_municipal])).rows[0];
    if (!!RD0ApplicationExists) throw { status: 409, message: 'Ya existe una declaración de retenciones para este mes' };
    const now = moment(new Date());

    let lastRD = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.RD0, branch.id_registro_municipal])).rows[0];
    const lastRDPayment = (lastRD && moment(lastRD.fecha_liquidacion)) || moment().startOf('year').subtract(1, 'M');
    console.log('🚀 ~ file: retention.ts ~ line 47 ~ getRetentionMonths ~ lastRDPayment', lastRDPayment);
    const RDDate = moment([lastRDPayment.year(), lastRDPayment.month(), 1]);
    console.log('🚀 ~ file: retention.ts ~ line 49 ~ getRetentionMonths ~ RDDate', RDDate);
    const dateInterpolation = Math.floor(now.diff(RDDate, 'M'));
    console.log('🚀 ~ file: retention.ts ~ line 51 ~ getRetentionMonths ~ dateInterpolation', dateInterpolation);

    if (dateInterpolation > 0) {
      debtRD = await Promise.all(
        new Array(dateInterpolation).fill({ month: null, year: null }).map(async (value, index) => {
          const date = addMonths(new Date(lastRDPayment.toDate()), index);
          const momentDate = moment(date);
          const exonerado = await isExonerated({ branch: codigosRamo.RD0, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') }, client);
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
        usuarios: await getUsersByContributor(contributor.id_contribuyente),
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

export const getRetentionChargingsForDocumentAndReference = async ({ document, reference }) => {
  const client = await pool.connect();
  try {
    const retenciones = {
      cobros: (await client.query(queries.GET_RETENTION_CHARGINGS_FOR_CONTRIBUTOR, [document, reference])).rows,
      balanceTotal: (await client.query(queries.GET_RETENTION_FISCAL_CREDIT_FOR_CONTRIBUTOR, [document, reference])).rows[0].credito,
    };
    return { status: 200, message: 'Cobros de retenciones obtenidos', retenciones };
  } catch (error) {
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener cobros de retenciones',
    };
  } finally {
    client.release();
  }
};

//TODO: hacer el desglose de retencion y apuntar al ramo de retencion
export const insertRetentions = async ({ process, user }) => {
  const client = await pool.connect();
  const { retenciones } = process;
  //Esto hay que sacarlo de db
  const finingAmount = 10;
  const FINING_THRESHOLD_DATE = 15;
  let finingMonths: any;
  try {
    client.query('BEGIN');
    const userContributor = user.tipoUsuario === 4 ? (await client.query(queries.GET_CONTRIBUTOR_BY_USER, [user.id])).rows : (await client.query(queries.TAX_PAYER_EXISTS, [process.tipoDocumento, process.documento])).rows;
    const userHasContributor = userContributor.length > 0;
    if (!userHasContributor) throw { status: 404, message: 'El usuario no esta asociado con ningun contribuyente' };
    const contributorReference = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [process.rim, process.contribuyente])).rows[0];
    if (!contributorReference) throw { status: 404, message: 'El agente de retención proporcionado no existe' };
    const benefittedUser = (await client.query(queries.GET_USER_IN_CHARGE_OF_BRANCH_BY_ID, [contributorReference.id_registro_municipal])).rows[0];
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.tipoUsuario !== 4 ? process.usuario || null : user.id, process.contribuyente])).rows[0];
    await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['RETENCION', application.id_solicitud]);

    // ! Esto hay que descomentarlo el otro mes
    if (retenciones.length > 0) {
      const now = moment().utcOffset(-4).locale('ES');
      const pivot = moment().utcOffset(-4).locale('ES');
      const onlyRD = retenciones.sort((a, b) =>
        pivot.month(a.fechaCancelada.month).toDate() === pivot.month(b.fechaCancelada.month).toDate() ? 0 : pivot.month(a.fechaCancelada.month).toDate() > pivot.month(b.fechaCancelada.month).toDate() ? 1 : -1
      );
      //   const lastSavedFine = (await client.query(queries.GET_LAST_FINE_FOR_LATE_RETENTION, [contributorReference.id_registro_municipal])).rows[0];
      //   if (lastSavedFine && moment(lastSavedFine.fecha_liquidacion).year() === now.year() && moment(lastSavedFine.fecha_liquidacion).month() < now.month()) {
      //     const proposedFiningDate = moment().locale('ES').month(onlyRD[0].fechaCancelada.month).month();
      //     const finingDate = moment(lastSavedFine.fecha_liquidacion).month() < proposedFiningDate ? moment(lastSavedFine.fecha_liquidacion).month() : proposedFiningDate;
      //     finingMonths = new Array(now.month() - 1 - finingDate).fill({});
      //     if (finingMonths.length > 0) {
      //       let counter = finingDate;
      //       finingMonths = await Promise.all(
      //         finingMonths.map((el, i) => {
      //           const multa = Promise.resolve(
      //             client.query(queries.CREATE_FINING_FOR_LATE_RETENTION, [
      //               application.id_solicitud,
      //               fixatedAmount(finingAmount * PETRO),
      //               {
      //                 fecha: {
      //                   month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
      //                   year: now.year(),
      //                 },
      //                 descripcion: 'Multa por Declaracion Fuera de Plazo (AR)',
      //                 monto: finingAmount,
      //               },
      //               moment().month(counter).endOf('month').format('MM-DD-YYYY'),
      //               (contributorReference && contributorReference.id_registro_municipal) || null,
      //             ])
      //           )
      //             .then((el) => el.rows[0])
      //             .then((data) => {
      //               return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto, descripcion: data.datos.descripcion };
      //             });
      //           counter++;
      //           return multa;
      //         })
      //       );
      //     }
      //     if (now.date() > 10) {
      //       const rightfulMonth = now.month() - 1;
      //       const multa = (
      //         await client.query(queries.CREATE_FINING_FOR_LATE_RETENTION, [
      //           application.id_solicitud,
      //           fixatedAmount(finingAmount * PETRO),
      //           {
      //             fecha: {
      //               month: moment().month(rightfulMonth).toDate().toLocaleDateString('ES', { month: 'long' }),
      //               year: now.year(),
      //             },
      //             descripcion: 'Multa por Declaracion Fuera de Plazo (AR)',
      //             monto: finingAmount,
      //           },
      //           moment().locale('ES').endOf('month').format('MM-DD-YYYY'),
      //           (contributorReference && contributorReference.id_registro_municipal) || null,
      //         ])
      //       ).rows[0];
      //       const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };
      //       finingMonths.push(fine);
      //     }
      //   } else {
      //     const finingDate = moment().locale('ES').month(onlyRD[0].fechaCancelada.month).month() + 1;
      //     finingMonths = new Array(now.month() - finingDate).fill({});
      //     if (finingMonths.length > 0) {
      //       let counter = finingDate - 1;
      //       finingMonths = await Promise.all(
      //         finingMonths.map((el, i) => {
      //           const multa = Promise.resolve(
      //             client.query(queries.CREATE_FINING_FOR_LATE_RETENTION, [
      //               application.id_solicitud,
      //               fixatedAmount(finingAmount * PETRO),
      //               {
      //                 fecha: {
      //                   month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
      //                   year: now.year(),
      //                 },
      //                 descripcion: 'Multa por Declaracion Fuera de Plazo (AR)',
      //                 monto: finingAmount,
      //               },
      //               moment().month(counter).endOf('month').format('MM-DD-YYYY'),
      //               (contributorReference && contributorReference.id_registro_municipal) || null,
      //             ])
      //           )
      //             .then((el) => el.rows[0])
      //             .then((data) => {
      //               return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto, descripcion: data.datos.descripcion };
      //             });
      //           counter++;
      //           return multa;
      //         })
      //       );
      //     }
      //     if (now.date() > 10) {
      //       const rightfulMonth = moment().month(now.month()).month() - 1;
      //       const multa = (
      //         await client.query(queries.CREATE_FINING_FOR_LATE_RETENTION, [
      //           application.id_solicitud,
      //           fixatedAmount(finingAmount * PETRO),
      //           {
      //             fecha: {
      //               month: moment().month(rightfulMonth).toDate().toLocaleDateString('ES', { month: 'long' }),
      //               year: now.year(),
      //             },
      //             descripcion: 'Multa por Declaracion Fuera de Plazo (AR)',
      //             monto: finingAmount,
      //           },
      //           moment().endOf('month').format('MM-DD-YYYY'),
      //           (contributorReference && contributorReference.id_registro_municipal) || null,
      //         ])
      //       ).rows[0];
      //       const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };
      //       finingMonths.push(fine);
      //     }
      //   }
      const finingDate = moment().locale('ES').month(onlyRD[0].fechaCancelada.month).year(onlyRD[0].fechaCancelada.year).startOf('month');
      const comparingDate = now.clone().startOf('month');
      finingMonths = new Array(comparingDate.diff(finingDate, 'M')).fill({});
      if (finingMonths.length > 0) {
        // let counter = finingDate - 1;
        finingMonths = await Promise.all(
          onlyRD.map(async (el, i) => {
            if (i === 0) return;
            const exonerado = await isExonerated(
              { branch: codigosRamo.MUL, contributor: contributorReference?.id_registro_municipal, activity: el.id_actividad_economica, startingDate: moment().locale('ES').month(el.fechaCancelada.month).startOf('month') },
              client
            );
            if (exonerado) return;
            const currentMonth = now.clone().subtract(1, 'M');
            const comparedMonth = moment().locale('ES').month(el.fechaCancelada.month).year(el.fechaCancelada.year);
            const percentage = await finingPercentage({ currentMonth, comparedMonth, branch: 'RD0', client });
            const multa = Promise.resolve(
              client.query(queries.CREATE_FINING_FOR_LATE_RETENTION_PETRO, [
                application.id_solicitud,
                (+el.monto * percentage).toFixed(8),
                {
                  fecha: {
                    month: moment().locale('ES').month(el.fechaCancelada.month).toDate().toLocaleDateString('ES', { month: 'long' }),
                    year: moment().locale('ES').year(el.fechaCancelada.year).format('YYYY'),
                  },
                  descripcion: 'Multa por Declaracion Fuera de Plazo',
                  monto: percentage,
                },
                moment().locale('ES').month(el.fechaCancelada.month).endOf('month').format('MM-DD-YYYY'),
                (contributorReference && contributorReference.id_registro_municipal) || null,
              ])
            )
              .then((el) => el.rows[0])
              .then((data) => {
                return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto_petro, descripcion: data.datos.descripcion };
              });
            return multa;
          })
        );
      }
      const exonerado = await isExonerated({ branch: codigosRamo.MUL, contributor: contributorReference?.id_registro_municipal, activity: null, startingDate: moment().startOf('month') }, client);
      if (now.date() > FINING_THRESHOLD_DATE && !exonerado) {
        const basePercentage = +(await client.query(queries.GET_SCALE_FOR_RETENTION_FINING_STARTING_AMOUNT)).rows[0].indicador;
        const multa = (
          await client.query(queries.CREATE_FINING_FOR_LATE_RETENTION_PETRO, [
            application.id_solicitud,
            (+onlyRD[0].monto * basePercentage).toFixed(8),
            {
              fecha: {
                month: moment().subtract(1, 'M').toDate().toLocaleDateString('ES', { month: 'long' }),
                year: moment().subtract(1, 'M').format('YYYY'),
              },
              descripcion: 'Multa por Declaracion Fuera de Plazo',
              monto: basePercentage,
            },
            moment().subtract(1, 'M').endOf('month').format('MM-DD-YYYY'),
            (contributorReference && contributorReference.id_registro_municipal) || null,
          ])
        ).rows[0];
        const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };

        // finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
        finingMonths.push(fine);
      }
    }
    // ! Esto hay que descomentarlo el otro mes

    const settlement: Liquidacion[] = await Promise.all(
      retenciones.map(async (el) => {
        const datos = {
          //   desglose: el.desglose ? el.desglose.map((al) => breakdownCaseHandler(el.ramo, al)) : undefined,
          fecha: { month: el.fechaCancelada.month, year: el.fechaCancelada.year },
          valorPetro: PETRO,
          fechaLiquidacion: moment().format('MM-DD-YYYY'),
          // desglose: el.items,
        };
        // console.log(el.ramo);
        const liquidacion = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            application.id_solicitud,
            +el.monto,
            'RD0',
            el.descripcion || 'Pago ordinario',
            datos,
            moment().locale('ES').month(el.fechaCancelada.month).endOf('month').format('MM-DD-YYYY'),
            (contributorReference && contributorReference.id_registro_municipal) || null,
          ])
        ).rows[0];

        await Promise.all(
          el.items.map(async (x, i) => {
            try {
              await client.query(queries.CREATE_RETENTION_DETAIL, [liquidacion.id_liquidacion, x.rif, x.rim, x.razonSocial, x.tipoServicio, x.fecha, x.baseImponible, x.montoRetenido, x.porcentaje, x.codActividad, x.numeroFactura]);
            } catch (e) {
              throw { status: 403, message: `Verifique el rif: ${x.rif} dentro de su declaracion de ${el.fechaCancelada.month} ${el.fechaCancelada.year}, pues este posee un RIM asociado.`, rif: x.rif, fechaCancelada: el.fechaCancelada, index: i };
            }
          })
        );

        return {
          id: liquidacion.id_liquidacion,
          ramo: branchNames[el.ramo],
          fecha: datos.fecha,
          monto: liquidacion.monto,
          montoPetro: liquidacion.monto_petro,
          certificado: liquidacion.certificado,
          recibo: liquidacion.recibo,
          // desglose: datos.desglose,
        };
      })
    );
    await client.query(queries.SET_AMOUNT_IN_BS_BASED_ON_PETRO, [application.id_solicitud]);
    await client.query(queries.FINISH_ROUNDING, [application.id_solicitud]);
    let state = (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS])).rows[0].state;
    if (settlement.reduce((x, y) => x + +y.montoPetro!, 0) === 0) {
      // (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.VALIDAR])).rows[0].state;
      state = await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
    }
    const solicitud = await getApplicationsAndSettlementsByIdNots({ id: application.id_solicitud, user }, client);
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [application.id_contribuyente]);
    // solicitud.recibo = await generateReceipt({ application: solicitud.id }, client);
    await client.query('COMMIT');
    // await sendNotification(
    //   user,
    //   `Se ha iniciado una solicitud para el contribuyente con el documento de identidad: ${solicitud.tipoDocumento}-${solicitud.documento}`,
    //   'CREATE_APPLICATION',
    //   'IMPUESTO',
    //   { ...solicitud, estado: state, nombreCorto: 'SEDEMAT' },
    //   client
    // );
    return { status: 201, message: 'Declaracion de retencion creada satisfactoriamente', solicitud };
  } catch (error) {
    console.log(error);
    client.query('ROLLBACK');
    throw {
      ...error,
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear solicitud de retenciones',
    };
  } finally {
    client.release();
  }
};

export const createRetentionAgent = async ({ docType, document }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente ingresado no existe' };
    if (!!contributor.es_agente_retencion) throw { status: 403, message: 'El contribuyente ingresado ya es un agente de retención' };
    const agent = (await client.query(queries.CREATE_NEW_RETENTION_AGENT_RIM, [docType, document])).rows[0];
    const agenteRetencion = {
      id: agent.id_contribuyente,
      tipoDocumento: agent.tipo_documento,
      tipoContribuyente: agent.tipo_contribuyente,
      documento: agent.documento,
      razonSocial: agent.razon_social,
      denomComercial: agent.denominacion_comercial || undefined,
      siglas: agent.siglas || undefined,
      parroquia: agent.id_parroquia,
      sector: agent.sector,
      direccion: agent.direccion,
      puntoReferencia: agent.punto_referencia,
      verificado: agent.verificado,
      esAgenteRetencion: agent.es_agente_retencion,
      referenciaMunicipal: agent.referencia_municipal,
    };
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [agent.id_contribuyente]);
    await client.query('COMMIT');
    return { status: 201, message: 'Agente de retencion creado', agenteRetencion };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear nuevo agente de retencion',
    };
  } finally {
    client.release();
  }
};

export const updateRetentionAgentStatus = async ({ id, status }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(queries.SET_RETENTION_AGENT_STATE, [status, id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Estado de agente de retencion actualizado' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar estado de agente de retencion',
    };
  } finally {
    client.release();
  }
};

export const updateRetentionAgentRIM = async ({ id, reference }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE impuesto.registro_municipal SET referencia_municipal = $1 WHERE id_registro_municipal = $2', [reference, id]);
    await client.query('COMMIT');
    return { status: 200, message: 'RIM de Agente de Retencion actualizado' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar RIM de agente de retencion',
    };
  } finally {
    client.release();
  }
};

export const getRetentionAgents = async () => {
  const client = await pool.connect();
  try {
    const retentionAgents = (await client.query(queries.GET_RETENTION_AGENTS)).rows.map((contributor) => ({
      id: contributor.id_contribuyente,
      idRim: contributor.id_registro_municipal,
      tipoDocumento: contributor.tipo_documento,
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      razonSocial: contributor.razon_social,
      denomComercial: contributor.denominacion_comercial || undefined,
      siglas: contributor.siglas || undefined,
      parroquia: contributor.id_parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      puntoReferencia: contributor.punto_referencia,
      verificado: contributor.verificado,
      esAgenteRetencion: contributor.es_agente_retencion,
      referenciaMunicipal: contributor.referencia_municipal,
    }));
    return { status: 200, message: 'Agentes de retencion obtenidos', agentesRetencion: retentionAgents };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener agentes de retencion',
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

// const isExonerated = async ({ branch, contributor, activity, startingDate }, client): Promise<boolean> => {
//   try {
//     if (branch === codigosRamo.AE) {
//       const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
//       if (branchIsExonerated) return !!branchIsExonerated;
//       const activityIsExonerated = (await client.query(queries.ECONOMIC_ACTIVITY_IS_EXONERATED, [activity, startingDate])).rows[0];
//       if (activityIsExonerated) return !!activityIsExonerated;
//       const contributorIsExonerated = (await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
//       if (contributorIsExonerated) return !!contributorIsExonerated;
//       return !!(await client.query(queries.CONTRIBUTOR_ECONOMIC_ACTIVIES_IS_EXONERATED, [contributor, activity, startingDate])).rows[0];
//     } else {
//       const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
//       if (branchIsExonerated) return !!branchIsExonerated;
//       return !!(await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
//     }
//     return false;
//   } catch (e) {
//     throw e;
//   }
// };

const branchNames = {
  AE: 'ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES',
  SM: 'SERVICIOS MUNICIPALES',
  IU: 'PROPIEDAD INMOBILIARIA',
  PP: 'PROPAGANDAS Y AVISOS COMERCIALES',
  SAE: 'TASA ADMINISTRATIVA DE SOLVENCIA DE AE',
  RD0: 'RETENCIONES DECRETO 048',
};

const applicationStateEvents = {
  INGRESARDATOS: 'ingresardatos_pi',
  APROBARCAJERO: 'aprobacioncajero_pi',
  VALIDAR: 'validar_pi',
  FINALIZAR: 'finalizar_pi',
  REBOTAR: 'rebotado_pi',
};
