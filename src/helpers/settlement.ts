import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import { insertPaymentReference, insertPaymentCashier } from './banks';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { Liquidacion, Solicitud, Usuario, MultaImpuesto, VerificationValue } from '@root/interfaces/sigt';
import { resolve } from 'path';
import { renderFile } from 'pug';
import { writeFile, mkdir } from 'fs';
import { dirname } from 'path';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import * as pdftk from 'node-pdftk';
import bcrypt, { genSaltSync, hashSync } from 'bcryptjs';
import md5 from 'md5';
import { query } from 'express-validator';
import { sendNotification } from './notification';
import { sendRimVerification, verifyCode, resendCode } from './verification';
import { hasLinkedContributor, signUpUser, getUserByUsername, getUsersByContributor } from './user';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import * as fs from 'fs';
import { procedureInit, initProcedureAnalist, processProcedure, processProcedureAnalist } from './procedures';
import { generateReceipt } from './receipt';
import { getCleaningTariffForEstate, getGasTariffForEstate } from './services';
import { uniqBy, chunk } from 'lodash';
const written = require('written-number');
const gticPool = GticPool.getInstance();
const pool = Pool.getInstance();

const dev = process.env.NODE_ENV !== 'production';

const idTiposSolicitud = {
  AE: 87,
  SM: 175,
  IU: 445,
  PP: 97,
};

export const codigosRamo = {
  AE: 112,
  SM: 122,
  PP: 114,
  IU: 111,
  RD0: 915,
};
const formatCurrency = (number: number) => new Intl.NumberFormat('de-DE').format(number);

export const checkContributorExists = () => async (req: any, res, next) => {
  const client = await pool.connect();
  const { user } = req;
  const { doc, ref, pref, contrib } = req.query;
  try {
    console.log('1');
    if (user.tipoUsuario === 4) return next();
    console.log('2');
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [pref, doc])).rows[0];
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [ref, contributor?.id_contribuyente])).rows[0];
    if (!!ref && !branch) res.status(404).send({ status: 404, message: 'No existe la sucursal solicitada' });
    console.log('3');
    const branchIsUpdated = branch?.actualizado;
    if (!contributor || (!!contributor && !!ref && !branchIsUpdated)) {
      console.log('4');
      const x = await externalLinkingForCashier({ document: doc, docType: pref, reference: ref, user, typeUser: contrib });
      res.status(202).json({ status: 202, message: 'Informacion de enlace de cuenta obtenida', datosEnlace: x });
    } else {
      console.log('5');

      return next();
    }
    console.log('6');
    return next();
  } catch (error) {
    console.log(error);
    res.send({
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al obtener la informacion del usuario',
    });
  } finally {
    client.release();
  }
};

const truthyCheck = (x) => {
  if (x) return true;
  return false;
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
      if (branch === codigosRamo.SM) {
        const allActivitiesAreExonerated = (await client.query(queries.MUNICIPAL_SERVICE_BY_ACTIVITIES_IS_EXONERATED, [contributor, startingDate])).rows[0]?.exonerado;
        if (allActivitiesAreExonerated) return allActivitiesAreExonerated;
      }
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

export const getSettlements = async ({ document, reference, type, user }: { document: string; reference: string | null; type: string; user: Usuario }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  const montoAcarreado: any = {};
  let SM, PP;
  let AE: any[] = [];
  let IU: any[] = [];
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [type, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    console.log('branch', branch);
    console.log('contributor', contributor);
    if ((!branch && reference) || (branch && !branch.actualizado)) throw { status: 404, message: 'La sucursal no esta actualizada o no esta registrada en SEDEMAT' };
    const lastSettlementQuery = contributor.tipo_contribuyente === 'JURIDICO' || (!!reference && branch) ? queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM_OPTIMIZED : queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_CONTRIBUTOR;
    const lastSettlementPayload = contributor.tipo_contribuyente === 'JURIDICO' || (!!reference && branch) ? branch.referencia_municipal : contributor.id_contribuyente;
    const fiscalCredit =
      (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [contributor.tipo_contribuyente === 'JURIDICO' ? branch.id_registro_municipal : contributor.id_contribuyente, contributor.tipo_contribuyente])).rows[0]?.credito || 0;
    const AEApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO' || reference ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.AE, reference])).rows.find((el) => !el.datos.hasOwnProperty('descripcion')) : false;
    const SMApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.SM, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.SM, contributor.id_contribuyente])).rows[0];
    const IUApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.IU, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.IU, contributor.id_contribuyente])).rows[0];
    const PPApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED, [codigosRamo.PP, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.PP, contributor.id_contribuyente])).rows[0];

    console.log(lastSettlementPayload);
    console.log(lastSettlementQuery);
    if (AEApplicationExists && SMApplicationExists && IUApplicationExists && PPApplicationExists) return { status: 409, message: 'Ya existe una declaracion de impuestos para este mes' };
    const now = moment(new Date());
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    //AE
    if (branch && branch?.referencia_municipal && !AEApplicationExists) {
      const economicActivities = (await client.query(queries.GET_ECONOMIC_ACTIVITIES_BY_CONTRIBUTOR, [branch.id_registro_municipal])).rows;
      if (economicActivities.length === 0) throw { status: 404, message: 'El contribuyente no posee aforos asociados' };
      let lastEA = (await client.query(lastSettlementQuery, [codigosRamo.AE, lastSettlementPayload])).rows.find((el) => !el.datos.hasOwnProperty('descripcion'));

      const lastEAPayment = (lastEA && moment(lastEA.fecha_liquidacion)) || moment().month(0);
      const pastMonthEA = (lastEA && moment(lastEA.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
      const EADate = moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
      // console.log(EADate);
      const dateInterpolation = Math.floor(now.diff(EADate, 'M'));
      montoAcarreado.AE = {
        monto: lastEA && lastEA.mo_pendiente ? parseFloat(lastEA.mo_pendiente) : 0,
        fecha: { month: pastMonthEA.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthEA.year() },
      };
      if (dateInterpolation !== 0) {
        AE = (
          await Promise.all(
            economicActivities.map(async (el) => {
              const lastMonthPayment = (await client.query(queries.GET_LAST_AE_SETTLEMENT_BY_AE_ID, [el.id_actividad_economica, branch.id_registro_municipal])).rows[0];
              const paymentDate = !!lastMonthPayment ? (moment(lastMonthPayment).startOf('month').isSameOrAfter(EADate) ? moment(lastMonthPayment.fecha_liquidacion).startOf('month') : EADate) : EADate;
              const interpolation = (!!lastMonthPayment && Math.floor(now.diff(paymentDate, 'M'))) || (!lastMonthPayment && dateInterpolation) || 0;
              // paymentDate = paymentDate.isSameOrBefore(lastEAPayment) ? moment([paymentDate.year(), paymentDate.month(), 1]) : moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
              if (interpolation === 0) return null;
              return {
                id: el.id_actividad_economica,
                minimoTributable: Math.round(el.minimo_tributable) * UTMM,
                nombreActividad: el.descripcion,
                idContribuyente: branch.id_registro_municipal,
                alicuota: el.alicuota / 100,
                costoSolvencia: UTMM * 2,
                deuda: await Promise.all(
                  new Array(interpolation).fill({ month: null, year: null }).map(async (value, index) => {
                    const date = addMonths(new Date(paymentDate.toDate()), index);
                    console.log('eri gei', interpolation, paymentDate.format('YYYY-MM-DD'));
                    const momentDate = moment(date);
                    const exonerado = await isExonerated({ branch: codigosRamo.AE, contributor: branch?.id_registro_municipal, activity: el.id_actividad_economica, startingDate: momentDate.startOf('month') });
                    return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
                  })
                ),
              };
            })
          )
        ).filter((el) => el);
      }
    }
    //SM
    const estates = (await client.query(branch ? queries.GET_ESTATES_FOR_JURIDICAL_CONTRIBUTOR : queries.GET_ESTATES_FOR_NATURAL_CONTRIBUTOR, [branch ? branch.id_registro_municipal : contributor.id_contribuyente])).rows;
    if (!SMApplicationExists) {
      let lastSM = (await client.query(lastSettlementQuery, [codigosRamo.SM, lastSettlementPayload])).rows[0];
      const lastSMPayment = (lastSM && moment(lastSM.fecha_liquidacion).add(1, 'M')) || moment().month(0);
      const pastMonthSM = (lastSM && moment(lastSM.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
      const SMDate = moment([lastSMPayment.year(), lastSMPayment.month(), 1]);
      const dateInterpolationSM = Math.floor(now.diff(SMDate, 'M'));
      montoAcarreado.SM = {
        monto: lastSM && lastSM.mo_pendiente ? parseFloat(lastSM.mo_pendiente) : 0,
        fecha: { month: pastMonthSM.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthSM.year() },
      };
      const debtSM = await Promise.all(
        new Array(dateInterpolationSM + 1).fill({ month: null, year: null }).map(async (value, index) => {
          const date = addMonths(new Date(lastSMPayment.toDate()), index);
          const momentDate = moment(date);
          const exonerado = await isExonerated({ branch: codigosRamo.SM, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
        })
      );

      SM =
        estates.length > 0
          ? await Promise.all(
              estates.map(async (el) => {
                const tarifaAseo = await getCleaningTariffForEstate({ estate: el, branchId: branch?.id_registro_municipal, client });
                const tarifaGas = await getGasTariffForEstate({ estate: el, branchId: branch?.id_registro_municipal, client });
                return { id: el.id_inmueble, tipoInmueble: el.tipo_inmueble, codCat: el.cod_catastral, direccionInmueble: el.direccion, tarifaAseo, tarifaGas, deuda: debtSM };
              })
            )
          : !!branch?.id_registro_municipal
          ? [
              {
                id: 0,
                tipoInmueble: null,
                codCat: null,
                direccionInmueble: null,
                tarifaGas: await getGasTariffForEstate({ estate: null, branchId: branch.id_registro_municipal, client }),
                tarifaAseo: await getCleaningTariffForEstate({ estate: null, branchId: branch.id_registro_municipal, client }),
                deuda: debtSM,
              },
            ]
          : undefined;
    }

    //IU
    if (estates.length > 0) {
      if (!IUApplicationExists) {
        let lastIU = (await client.query(lastSettlementQuery, [codigosRamo.IU, lastSettlementPayload])).rows[0];
        const lastIUPayment = (lastIU && moment(lastIU.fecha_liquidacion).add(1, 'M')) || moment().month(0);
        const pastMonthIU = (lastIU && moment(lastIU.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
        const IUDate = moment([lastIUPayment.year(), lastIUPayment.month(), 1]);
        const dateInterpolationIU = Math.floor(now.diff(IUDate, 'M'));
        montoAcarreado.IU = {
          monto: lastIU && lastIU.mo_pendiente ? parseFloat(lastIU.mo_pendiente) : 0,
          fecha: { month: pastMonthIU.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthIU.year() },
        };
        // if (dateInterpolationIU > 0) {
        IU = (
          await Promise.all(
            estates
              .filter((el) => +el.avaluo)
              .map(async (el) => {
                // let paymentDate: Moment = lastIUPayment;
                // let interpolation = dateInterpolationIU;
                const lastMonthPayment =
                  contributor.tipo_contribuyente === 'JURIDICO'
                    ? (await client.query(queries.GET_LAST_IU_SETTLEMENT_BY_ESTATE_ID, [el.id_inmueble, branch?.id_registro_municipal])).rows[0]
                    : (await client.query(queries.GET_LAST_IU_SETTLEMENT_BY_ESTATE_ID_NATURAL, [el.id_inmueble, contributor.id_contribuyente])).rows[0];
                const paymentDate = !!lastMonthPayment ? (moment(lastMonthPayment).startOf('month').isSameOrAfter(IUDate) ? moment(lastMonthPayment.fecha_liquidacion).startOf('month') : IUDate) : IUDate;
                const interpolation = (!!lastMonthPayment && Math.floor(now.diff(paymentDate, 'M'))) || (!lastMonthPayment && dateInterpolationIU) || 1;
                // paymentDate = paymentDate.isSameOrBefore(lastEAPayment) ? moment([paymentDate.year(), paymentDate.month(), 1]) : moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
                if (interpolation === 0) return null;
                // if (lastMonthPayment) {
                //   paymentDate = moment(lastMonthPayment.fecha_liquidacion);
                //   paymentDate = paymentDate.isSameOrBefore(lastIUPayment) ? moment([paymentDate.year(), paymentDate.month(), 1]) : moment([lastIUPayment.year(), lastIUPayment.month(), 1]);
                //   interpolation = Math.floor(now.diff(paymentDate, 'M'));
                // }
                return {
                  id: el.id_inmueble,
                  codCat: el.cod_catastral,
                  direccionInmueble: el.direccion,
                  ultimoAvaluo: el.avaluo,
                  impuestoInmueble: (el.avaluo * 0.01) / 12,
                  deuda: await Promise.all(
                    new Array(interpolation).fill({ month: null, year: null }).map(async (value, index) => {
                      const date = addMonths(new Date(paymentDate.toDate()), index);
                      const momentDate = moment(date);
                      const exonerado = await isExonerated({ branch: codigosRamo.IU, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
                      return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
                    })
                  ),
                };
              })
          )
        ).filter((el) => el);
        // }
      }
    }

    //PP
    if (!PPApplicationExists) {
      let debtPP;
      let lastPP = (await client.query(lastSettlementQuery, [codigosRamo.PP, lastSettlementPayload])).rows[0];
      if (lastPP) {
        const lastPPPayment = moment(lastPP.fecha_liquidacion).add(1, 'M');
        const pastMonthPP = moment(lastPP.fecha_liquidacion).subtract(1, 'M');
        const PPDate = moment([lastPPPayment.year(), lastPPPayment.month(), 1]);
        const dateInterpolationPP = Math.floor(now.diff(PPDate, 'M')); /*now.isSameOrBefore(PPDate) && now.diff(PPDate, 'd') < 0 ? 0 : now.diff(PPDate, 'M') + 1;*/
        montoAcarreado.PP = {
          monto: lastPP && lastPP.mo_pendiente ? parseFloat(lastPP.mo_pendiente) : 0,
          fecha: { month: pastMonthPP.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthPP.year() },
        };
        // if (dateInterpolationPP > 0) {
        debtPP = await Promise.all(
          new Array(dateInterpolationPP + 1).fill({ month: null, year: null }).map(async (value, index) => {
            const date = addMonths(new Date(lastPPPayment.toDate()), index);
            const momentDate = moment(date);
            const exonerado = await isExonerated({ branch: codigosRamo.PP, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
            return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
          })
        );
        // }
      } else {
        debtPP = await Promise.all(
          new Array(now.month() + 1).fill({ month: null, year: null }).map(async (value, index) => {
            const date = addMonths(moment(`${now.year()}-01-01`).toDate(), index);
            const momentDate = moment(date);
            const exonerado = await isExonerated({ branch: codigosRamo.PP, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
            return { month: date.toLocaleString('ES', { month: 'long' }), year: date.getFullYear(), exonerado };
          })
        );
      }
      if (debtPP) {
        const publicityArticles = (await client.query(queries.GET_PUBLICITY_CATEGORIES)).rows;
        const publicitySubarticles = (await client.query(queries.GET_PUBLICITY_SUBCATEGORIES)).rows;
        PP = {
          deuda: debtPP,
          articulos: publicityArticles.map((el) => {
            return {
              id: +el.id_categoria_propaganda,
              nombreArticulo: el.descripcion,
              subarticulos: publicitySubarticles
                .filter((al) => +el.id_categoria_propaganda === al.id_categoria_propaganda)
                .map((el) => {
                  return {
                    id: +el.id_tipo_aviso_propaganda,
                    nombreSubarticulo: el.descripcion,
                    parametro: el.parametro,
                    costo: +el.monto * UTMM,
                    costoAlto: el.parametro === 'BANDA' ? (+el.monto + 2) * UTMM : undefined,
                  };
                }),
            };
          }),
        };
      }
    }
    return {
      status: 200,
      message: 'Impuestos obtenidos satisfactoriamente',
      impuesto: {
        contribuyente: contributor.id_contribuyente,
        razonSocial: contributor.razon_social,
        siglas: contributor.siglas,
        rim: reference,
        esAgenteRetencion: contributor.es_agente_retencion,
        documento: contributor.documento,
        tipoDocumento: contributor.tipo_documento,
        creditoFiscal: fiscalCredit,
        AE: (AE.length > 0 && AE) || undefined,
        SM,
        IU: (IU.length > 0 && IU) || undefined,
        PP,
        usuarios: await getUsersByContributor(contributor.id_contribuyente),
        montoAcarreado: addMissingCarriedAmounts(montoAcarreado),
      },
    };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los impuestos',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

const nullStringCheck = (str: string | null): string => {
  if (!str) return '';
  return str.trim();
};

export const getTaxPayerInfo = async ({ docType, document, type, gtic, client }) => {
  let taxPayer;
  try {
    if (type === 'NATURAL') {
      const naturalContributor = (await gtic.query(queries.gtic.GET_NATURAL_CONTRIBUTOR, [document, docType])).rows[0];
      if (!naturalContributor) return { status: 200, contribuyente: { tipoContribuyente: type }, message: 'No existe un usuario registrado en SEDEMAT' };
      taxPayer = {
        tipoContribuyente: type,
        documento: document,
        tipoDocumento: docType,
        razonSocial: `${naturalContributor.nb_contribuyente} ${naturalContributor.ap_contribuyente}`.replace('null', '').trim(),
        telefonoMovil: nullStringCheck(naturalContributor.nu_telf_movil).trim(),
        telefonoHabitacion: nullStringCheck(naturalContributor.nu_telf_hab).trim(),
        siglas: nullStringCheck(naturalContributor.tx_siglas).trim(),
        denomComercial: nullStringCheck(naturalContributor.tx_denom_comercial).trim(),
        email: nullStringCheck(naturalContributor.tx_email).trim(),
        parroquia: naturalContributor.tx_direccion ? (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [naturalContributor.tx_direccion.split('Parroquia')[1].split('Sector')[0].trim()])).rows[0]?.id || undefined : undefined,
        sector: nullStringCheck(naturalContributor.sector).trim(),
        direccion: naturalContributor.tx_direccion ? 'Avenida ' + naturalContributor.tx_direccion.split('Parroquia')[1].split('Avenida')[1].split('Pto')[0].trim().replace(/.$/, '') : undefined,
        puntoReferencia: nullStringCheck(naturalContributor.tx_punto_referencia).trim(),
      };
    } else {
      const juridicalContributor = (await gtic.query(queries.gtic.GET_JURIDICAL_CONTRIBUTOR, [document, docType])).rows[0];
      if (!juridicalContributor) return { status: 200, contribuyente: { tipoContribuyente: type }, message: 'No existe un usuario registrado en SEDEMAT' };
      taxPayer = {
        tipoContribuyente: type,
        documento: document,
        tipoDocumento: docType,
        razonSocial: nullStringCheck(juridicalContributor.tx_razon_social).trim(),
        siglas: nullStringCheck(juridicalContributor.tx_siglas).trim(),
        denomComercial: nullStringCheck(juridicalContributor.tx_denom_comercial).trim(),
        telefonoMovil: nullStringCheck(juridicalContributor.nu_telf_movil).trim(),
        telefonoHabitacion: nullStringCheck(juridicalContributor.nu_telf_hab).trim(),
        email: nullStringCheck(juridicalContributor.tx_email).trim(),
        parroquia: juridicalContributor.tx_direccion ? (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [juridicalContributor.tx_direccion.split('Parroquia')[1].split('Sector')[0].trim()])).rows[0]?.id || undefined : undefined,
        sector: nullStringCheck(juridicalContributor.sector).trim(),
        direccion: juridicalContributor.tx_direccion ? 'Avenida ' + juridicalContributor.tx_direccion.split('Parroquia')[1].split('Avenida')[1].split('Pto')[0].trim().replace(/.$/, '') : undefined,
        puntoReferencia: nullStringCheck(juridicalContributor.tx_punto_referencia).trim(),
      };
    }
    return taxPayer;
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const structureEstates = (x: any) => {
  return {
    id: nullStringCheck(x.co_inmueble),
    direccion: nullStringCheck(x.tx_direccion),
    email: nullStringCheck(x.tx_email),
    razonSocial: nullStringCheck(x.tx_razon_social),
    tipoInmueble: nullStringCheck(x.tx_tp_inmueble) || 'RESIDENCIAL',
    denomComercial: nullStringCheck(x.tx_denom_comercial),
    metrosCuadrados: +x.nu_metro_cuadrado,
    cuentaContrato: x.cuenta_contrato,
    nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
    ultimoAvaluo: { year: x.nu_anio || moment().year(), monto: x.nu_monto || 0 },
  };
};

const structureSettlements = (x: any) => {
  return {
    id: nullStringCheck(x.co_liquidacion),
    estado: +x.co_estatus === 1 ? 'VIGENTE' : 'PAGADO',
    ramo: x.nb_ramo == 236 ? 'TASA ADMINISTRATIVA DE SOLVENCIA DE AE' : nullStringCheck(x.tx_ramo),
    codigoRamo: nullStringCheck(x.nb_ramo),
    descripcion: 'Liquidacion por enlace de GTIC',
    monto: nullStringCheck(x.nu_monto),
    fechaLiquidacion: x.fe_liquidacion,
    fechaVencimiento: x.fe_vencimiento,
    fecha: { month: moment(x.fe_liquidacion).toDate().toLocaleDateString('ES', { month: 'long' }), year: moment(x.fe_liquidacion).year() },
  };
};

const structureFinings = (x: any) => {
  return {
    id: nullStringCheck(x.co_decl_multa),
    estado: nullStringCheck(x.in_activo ? 'VIGENTE' : 'PAGADO'),
    monto: nullStringCheck(x.nu_monto),
    fechaLiquidacion: x.fecha_liquidacion,
    ramo: 'MULTAS',
    descripcion: 'Liquidacion por enlace de GTIC',
    fecha: { month: moment(x.fecha_liquidacion).toDate().toLocaleDateString('ES', { month: 'long' }), year: moment(x.fecha_liquidacion).year() },
  };
};

const structureContributor = (x: any) => {
  return {
    id: x.id_contribuyente,
    tipoDocumento: x.tipo_documento,
    tipoContribuyente: x.tipo_contribuyente,
    documento: x.documento,
    razonSocial: x.razon_social,
    denomComercial: x.denominacion_comercial || undefined,
    siglas: x.siglas || undefined,
    parroquia: x.parroquia,
    sector: x.sector,
    direccion: x.direccion,
    puntoReferencia: x.punto_referencia,
    verificado: x.verificado,
  };
};

export const externalLinkingForCashier = async ({ document, docType, reference, typeUser, user }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const contributorQuery = typeUser === 'JURIDICO' ? queries.gtic.GET_JURIDICAL_CONTRIBUTOR + ' LIMIT 1' : queries.gtic.GET_NATURAL_CONTRIBUTOR + ' LIMIT 1';
    console.log(contributorQuery);
    const contributorExists = (await gtic.query(contributorQuery, [document, docType])).rowCount > 0;
    if (!contributorExists) throw { status: 404, message: 'Contribuyente no encontrado', linked: false };
    const linkingData = await Promise.all(
      (await gtic.query(contributorQuery, [document, docType])).rows
        .map(async (el) => {
          console.log(el);
          const contributorExists = (await client.query(queries.TAX_PAYER_EXISTS, [el.tx_tp_doc, el.tx_dist_contribuyente === 'J' ? el.tx_rif : el.nu_cedula])).rows;
          if (contributorExists.length > 0) return getLinkedContributorData(contributorExists[0]);
          return {
            datosContribuyente: await getTaxPayerInfo({
              docType: el.tx_tp_doc,
              document: el.tx_dist_contribuyente === 'J' ? el.tx_rif : el.nu_cedula,
              type: el.tx_dist_contribuyente === 'J' ? 'JURIDICO' : 'NATURAL',
              gtic,
              client,
            }),
            sucursales: await Promise.all(
              el.tx_dist_contribuyente === 'J'
                ? (await gtic.query(queries.gtic.GET_JURIDICAL_CONTRIBUTOR, [el.tx_rif, el.tx_tp_doc])).rows.map(async (x) => {
                    let convenios: any;
                    const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                    const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                    const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                    const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
                    const actividadesEconomicas = await Promise.all(
                      (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [x.co_contribuyente])).rows.map((x) => ({ id: x.nu_ref_actividad, descripcion: x.tx_actividad, alicuota: x.nu_porc_alicuota, minimoTributable: x.nu_ut }))
                    );
                    const agreementRegistry = (
                      await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_estatus = 4 AND co_contribuyente = $1 AND anio_liquidacion = EXTRACT("year" FROM CURRENT_DATE)', [x.co_contribuyente])
                    ).rows;
                    const hasAgreements = agreementRegistry.length > 0;
                    if (hasAgreements) {
                      convenios = (
                        await Promise.all(
                          agreementRegistry.map(async (j) => {
                            const solicitudConvenio = +j.tx_observacion1.split(':')[1];
                            if (isNaN(solicitudConvenio)) return;
                            const solicitud = (await gtic.query('SELECT * FROM t15_solicitud WHERE co_solicitud = $1 AND co_estatus != 5', [solicitudConvenio])).rows;
                            const isCurrentAgreement = solicitud.length > 0;
                            if (isCurrentAgreement) {
                              const liquidaciones = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_solicitud = $1', [solicitud[0].co_solicitud])).rows.map((x) => structureSettlements(x));
                              return (
                                (liquidaciones.length > 0 && {
                                  id: +solicitudConvenio,
                                  estado: solicitud[0].co_estatus === 1 ? 'VIGENTE' : 'PAGADO',
                                  cantPorciones: liquidaciones.length,
                                  idRamo: (await client.query('SELECT id_ramo AS id FROM impuesto.ramo WHERE codigo = $1', [j.nb_ramo])).rows[0].id,
                                  porciones: liquidaciones.map((i) => {
                                    i.codigoRamo = j.nb_ramo;
                                    i.ramo = (j.tx_ramo as string).trim();
                                    return i;
                                  }),
                                }) ||
                                null
                              );
                            }
                            return null;
                          })
                        )
                      ).filter((el) => el);
                      convenios = convenios.length > 0 ? uniqBy(convenios, 'id') : undefined;
                    }
                    inmuebles.push({
                      id: x.co_contribuyente,
                      direccion: nullStringCheck(x.tx_direccion),
                      email: nullStringCheck(x.tx_email),
                      razonSocial: nullStringCheck(x.tx_razon_social),
                      denomComercial: nullStringCheck(x.tx_denom_comercial),
                      tipoInmueble: 'COMERCIAL',
                      metrosCuadrados: 0.0,
                      cuentaContrato: 0.0,
                      nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
                      ultimoAvaluo: { year: moment().year(), monto: 0 },
                    });
                    const datosSucursal = {
                      id: nullStringCheck(x.co_contribuyente),
                      direccion: nullStringCheck(x.tx_direccion),
                      email: nullStringCheck(x.tx_email),
                      razonSocial: nullStringCheck(x.tx_razon_social),
                      denomComercial: nullStringCheck(x.tx_denom_comercial),
                      metrosCuadrados: 0.0,
                      cuentaContrato: 0.0,
                      nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                      telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                      registroMunicipal: nullStringCheck(x.nu_referencia),
                      representado: nullStringCheck(x.nu_referencia) === reference,
                      creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                    };
                    return { datosSucursal, inmuebles, liquidaciones, multas, convenios, actividadesEconomicas };
                  })
                : (await gtic.query(queries.gtic.GET_NATURAL_CONTRIBUTOR, [el.nu_cedula, el.tx_tp_doc])).rows.map(async (x) => {
                    let datos;
                    if (x.nu_referencia) {
                      let convenios: any;
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
                      const actividadesEconomicas = await Promise.all(
                        (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [x.co_contribuyente])).rows.map((x) => ({ id: x.nu_ref_actividad, descripcion: x.tx_actividad, alicuota: x.nu_porc_alicuota, minimoTributable: x.nu_ut }))
                      );
                      const agreementRegistry = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_estatus = 4 AND co_contribuyente = $1', [x.co_contribuyente])).rows;
                      const hasAgreements = agreementRegistry.length > 0;
                      if (hasAgreements) {
                        convenios = (
                          await Promise.all(
                            agreementRegistry.map(async (j) => {
                              const solicitudConvenio = +j.tx_observacion1.split(':')[1];
                              if (isNaN(solicitudConvenio)) return;
                              const solicitud = (await gtic.query('SELECT * FROM t15_solicitud WHERE co_solicitud = $1 AND co_estatus != 5', [solicitudConvenio])).rows;
                              const isCurrentAgreement = solicitud.length > 0;
                              if (isCurrentAgreement) {
                                const liquidaciones = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_solicitud = $1', [solicitud[0].co_solicitud])).rows.map((x) => structureSettlements(x));
                                return (
                                  (liquidaciones.length > 0 && {
                                    id: +solicitudConvenio,
                                    estado: solicitud[0].co_estatus === 1 ? 'VIGENTE' : 'PAGADO',
                                    idRamo: (await client.query('SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1', [j.nb_ramo])).rows[0].id,
                                    cantPorciones: liquidaciones.length,
                                    porciones: liquidaciones.map((i) => {
                                      i.codigoRamo = j.nb_ramo;
                                      i.ramo = (j.tx_ramo as string).trim();
                                      return i;
                                    }),
                                  }) ||
                                  null
                                );
                              }
                              return null;
                            })
                          )
                        ).filter((el) => el);
                        convenios = convenios.length > 0 ? uniqBy(convenios, 'id') : undefined;
                      }
                      inmuebles.push({
                        id: x.co_contribuyente,
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        tipoInmueble: 'RESIDENCIAL',
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
                        ultimoAvaluo: { year: moment().year(), monto: 0 },
                      });
                      const datosSucursal = {
                        id: nullStringCheck(x.co_contribuyente),
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                        telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                        registroMunicipal: nullStringCheck(x.nu_referencia),
                        representado: nullStringCheck(x.nu_referencia) === reference,
                        creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                      };
                      datos = {
                        datosSucursal,
                        inmuebles,
                        liquidaciones,
                        multas,
                        convenios,
                        actividadesEconomicas,
                      };
                    } else {
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_CONTRIBUTOR, [x.co_contribuyente])).rows[0];
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureEstates(j)));
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureFinings(j)));
                      const datosSucursal = {
                        id: nullStringCheck(x.co_contribuyente),
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                        telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                        creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                      };
                      datos = {
                        // datosSucursal,
                        inmuebles,
                        liquidaciones,
                        multas,
                      };
                    }
                    return datos;
                  })
            ),
            actividadesEconomicas: el.nu_referencia
              ? await Promise.all(
                  (await gtic.query(typeUser === 'JURIDICO' ? queries.gtic.ECONOMIC_ACTIVITIES_JURIDICAL : queries.gtic.ECONOMIC_ACTIVIES_NATURAL, [docType, document])).rows.map((x) => ({
                    id: x.nu_ref_actividad,
                    descripcion: x.tx_actividad,
                    alicuota: x.nu_porc_alicuota,
                    minimoTributable: x.nu_ut,
                  }))
                )
              : undefined,
            sinSucursales: false,
          };
        })
        .filter((el) => el)
    );
    return linkingData;
    // await client.query('BEGIN');
    // const { datosContribuyente, sucursales, actividadesEconomicas } = linkingData[0];
    // const { tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, tipoContribuyente } = datosContribuyente;
    // const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    // // if (actividadesEconomicas!.length > 0) {
    // //   await Promise.all(
    // //     actividadesEconomicas!.map(async (x) => {
    // //       return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [contributor.id_contribuyente, x.id]);
    // //     })
    // //   );
    // // }
    // if (datosContribuyente.tipoContribuyente === 'JURIDICO') {
    //   const rims: number[] = await Promise.all(
    //     await sucursales.map(async (x) => {
    //       const { inmuebles, liquidaciones, multas, datosSucursal, actividadesEconomicas } = x;
    //       const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
    //       const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
    //       const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
    //       const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
    //       const pagados = liquidacionesPagas.concat(multasPagas);
    //       const vigentes = liquidacionesVigentes.concat(multasVigentes);
    //       const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
    //       const registry = (await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [contributor.id_contribuyente, registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado || false])).rows[0];
    //       if (actividadesEconomicas!.length > 0) {
    //         await Promise.all(
    //           actividadesEconomicas!.map(async (x) => {
    //             return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [registry.id_registro_municipal, x.id]);
    //           })
    //         );
    //       }
    //       const credit = (await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, [registry.id_registro_municipal, 'JURIDICO', datosSucursal.creditoFiscal])).rows[0];
    //       const estates =
    //         inmuebles.length > 0
    //           ? await Promise.all(
    //               inmuebles.map(async (el) => {
    //                 const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble])).rows[0];
    //                 console.log(inmueble);
    //                 await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
    //               })
    //             )
    //           : undefined;
    //       if (pagados.length > 0) {
    //         const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
    //         await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
    //         await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
    //         await Promise.all(
    //           pagados.map(async (el) => {
    //             const settlement = (
    //               await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
    //                 application.id_solicitud,
    //                 fixatedAmount(+el.monto),
    //                 el.ramo,
    //                 { fecha: el.fecha },
    //                 moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
    //                 registry.id_registro_municipal,
    //               ])
    //             ).rows[0];
    //             await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
    //           })
    //         );
    //       }

    //       if (vigentes.length > 0) {
    //         const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
    //         await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
    //         await Promise.all(
    //           vigentes.map(async (el) => {
    //             const settlement = (
    //               await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
    //                 application.id_solicitud,
    //                 fixatedAmount(+el.monto),
    //                 el.ramo,
    //                 { fecha: el.fecha },
    //                 moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
    //                 registry.id_registro_municipal,
    //               ])
    //             ).rows[0];
    //             await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
    //           })
    //         );
    //       }
    //       return representado ? registry.id_registro_municipal : undefined;
    //     })
    //   );
    // } else {
    //   const rims: number[] = await Promise.all(
    //     await sucursales.map(async (x) => {
    //       const { inmuebles, liquidaciones, multas, datosSucursal } = x;
    //       const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
    //       const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
    //       const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
    //       const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
    //       const pagados = liquidacionesPagas.concat(multasPagas);
    //       const vigentes = liquidacionesVigentes.concat(multasVigentes);
    //       const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
    //       let registry;
    //       const credit = (await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, [contributor.id_contribuyente, 'NATURAL', datosSucursal.creditoFiscal])).rows[0];
    //       if (registroMunicipal) {
    //         registry = (await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [contributor.id_contribuyente, registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado || false])).rows[0];
    //         if (x.actividadesEconomicas!.length > 0) {
    //           await Promise.all(
    //             actividadesEconomicas!.map(async (x) => {
    //               return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [registry.id_registro_municipal, x.id]);
    //             })
    //           );
    //         }
    //         const estates =
    //           inmuebles.length > 0
    //             ? await Promise.all(
    //                 inmuebles.map(async (el) => {
    //                   const inmueble = await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble]);
    //                   await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.rows[0].id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
    //                 })
    //               )
    //             : undefined;
    //       } else {
    //         const estates =
    //           inmuebles.length > 0
    //             ? await Promise.all(
    //                 inmuebles.map(async (el) => {
    //                   const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [(registry && registry.id_registro_municipal) || null, el.direccion, el.tipoInmueble])).rows[0];
    //                   await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [inmueble.id_inmueble, contributor.id_contribuyente]);
    //                   await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
    //                   return 0;
    //                 })
    //               )
    //             : undefined;
    //       }
    //       if (pagados.length > 0) {
    //         const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
    //         await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
    //         await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
    //         await Promise.all(
    //           pagados.map(async (el) => {
    //             const settlement = (
    //               await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
    //                 application.id_solicitud,
    //                 fixatedAmount(+el.monto),
    //                 el.ramo,
    //                 { fecha: el.fecha },
    //                 moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
    //                 (registry && registry.id_registro_municipal) || null,
    //               ])
    //             ).rows[0];
    //             await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
    //           })
    //         );
    //       }

    //       if (vigentes.length > 0) {
    //         const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
    //         await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
    //         await Promise.all(
    //           vigentes.map(async (el) => {
    //             const settlement = (
    //               await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
    //                 application.id_solicitud,
    //                 fixatedAmount(+el.monto),
    //                 el.ramo,
    //                 { fecha: el.fecha },
    //                 moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
    //                 (registry && registry.id_registro_municipal) || null,
    //               ])
    //             ).rows[0];
    //             await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
    //           })
    //         );
    //       }
    //       return representado ? registry.id_registro_municipal : undefined;
    //     })
    //   );
    // }
    // await client.query('COMMIT');
    // return { linked: true };
  } catch (error) {
    await client.query('ROLLBACK');
    console.log(error);
    throw {
      linked: false,
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener datos del contribuyente',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

export const logInExternalLinking = async ({ credentials }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const { attemptedUser, canBeLinked } = await externalUserForLinkingExists({ user: credentials.nombreUsuario, password: credentials.password, gtic });
    if (!canBeLinked) return { status: 403, message: 'Credenciales incorrectas' };
    const contributors = await Promise.all(
      (await gtic.query(queries.gtic.GET_CONTRIBUTOR_BY_REPRESENTATIVE_USER_EXTENDED, [attemptedUser.id_tb004_contribuyente])).rows
        .map(async (el) => {
          const contributorExists = (await client.query(queries.TAX_PAYER_EXISTS, [el.tx_tp_doc, el.tx_dist_contribuyente === 'J' ? el.tx_rif : el.nu_cedula])).rows;
          if (contributorExists.length > 0) return getLinkedContributorData(contributorExists[0]);
          return {
            datosContribuyente: await getTaxPayerInfo({
              docType: el.tx_tp_doc,
              document: el.tx_dist_contribuyente === 'J' ? el.tx_rif : el.nu_cedula,
              type: el.tx_dist_contribuyente === 'J' ? 'JURIDICO' : 'NATURAL',
              gtic,
              client,
            }),
            sucursales: await Promise.all(
              el.tx_dist_contribuyente === 'J'
                ? (await gtic.query(queries.gtic.GET_JURIDICAL_CONTRIBUTOR, [el.tx_rif, el.tx_tp_doc])).rows.map(async (x) => {
                    let convenios: any;
                    const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                    const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                    const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                    const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
                    const actividadesEconomicas = await Promise.all(
                      (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [x.co_contribuyente])).rows.map((x) => ({ id: x.nu_ref_actividad, descripcion: x.tx_actividad, alicuota: x.nu_porc_alicuota, minimoTributable: x.nu_ut }))
                    );
                    const agreementRegistry = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_estatus = 4 AND co_contribuyente = $1', [x.co_contribuyente])).rows;
                    const hasAgreements = agreementRegistry.length > 0;
                    if (hasAgreements) {
                      convenios = (
                        await Promise.all(
                          agreementRegistry.map(async (j) => {
                            const solicitudConvenio = +j.tx_observacion1.split(':')[1];
                            if (isNaN(solicitudConvenio)) return;
                            const solicitud = (await gtic.query('SELECT * FROM t15_solicitud WHERE co_solicitud = $1 AND co_estatus != 5', [solicitudConvenio])).rows;
                            const isCurrentAgreement = solicitud.length > 0;
                            if (isCurrentAgreement) {
                              const liquidaciones = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_solicitud = $1', [solicitud[0].co_solicitud])).rows.map((x) => structureSettlements(x));
                              return (
                                (liquidaciones.length > 0 && {
                                  id: +solicitudConvenio,
                                  estado: solicitud[0].co_estatus === 1 ? 'VIGENTE' : 'PAGADO',
                                  idRamo: (await client.query('SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1', [j.nb_ramo])).rows[0].id,
                                  cantPorciones: liquidaciones.length,
                                  porciones: liquidaciones.map((i) => {
                                    i.codigoRamo = j.nb_ramo;
                                    i.ramo = (j.tx_ramo as string).trim();
                                    return i;
                                  }),
                                }) ||
                                null
                              );
                            }
                            return null;
                          })
                        )
                      ).filter((el) => el);
                      convenios = convenios.length > 0 ? uniqBy(convenios, 'id') : undefined;
                    }
                    inmuebles.push({
                      id: x.co_contribuyente,
                      direccion: nullStringCheck(x.tx_direccion),
                      email: nullStringCheck(x.tx_email),
                      razonSocial: nullStringCheck(x.tx_razon_social),
                      denomComercial: nullStringCheck(x.tx_denom_comercial),
                      tipoInmueble: 'COMERCIAL',
                      metrosCuadrados: 0.0,
                      cuentaContrato: 0.0,
                      nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
                      ultimoAvaluo: { year: moment().year(), monto: 0 },
                    });
                    const datosSucursal = {
                      id: nullStringCheck(x.co_contribuyente),
                      direccion: nullStringCheck(x.tx_direccion),
                      email: nullStringCheck(x.tx_email),
                      razonSocial: nullStringCheck(x.tx_razon_social),
                      denomComercial: nullStringCheck(x.tx_denom_comercial),
                      metrosCuadrados: 0.0,
                      cuentaContrato: 0.0,
                      nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                      telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                      registroMunicipal: nullStringCheck(x.nu_referencia),
                      creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                    };
                    return { datosSucursal, inmuebles, liquidaciones, multas, convenios, actividadesEconomicas };
                  })
                : (await gtic.query(queries.gtic.GET_NATURAL_CONTRIBUTOR, [el.nu_cedula, el.tx_tp_doc])).rows.map(async (x) => {
                    let datos;
                    if (x.nu_referencia) {
                      let convenios: any;
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
                      const actividadesEconomicas = await Promise.all(
                        (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [x.co_contribuyente])).rows.map((x) => ({ id: x.nu_ref_actividad, descripcion: x.tx_actividad, alicuota: x.nu_porc_alicuota, minimoTributable: x.nu_ut }))
                      );
                      const agreementRegistry = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_estatus = 4 AND co_contribuyente = $1', [x.co_contribuyente])).rows;
                      const hasAgreements = agreementRegistry.length > 0;
                      if (hasAgreements) {
                        convenios = (
                          await Promise.all(
                            agreementRegistry.map(async (j) => {
                              const solicitudConvenio = +j.tx_observacion1.split(':')[1];
                              if (isNaN(solicitudConvenio)) return;
                              const solicitud = (await gtic.query('SELECT * FROM t15_solicitud WHERE co_solicitud = $1 AND co_estatus != 5', [solicitudConvenio])).rows;
                              const isCurrentAgreement = solicitud.length > 0;
                              if (isCurrentAgreement) {
                                const liquidaciones = (await gtic.query('SELECT * FROM tb079_liquidacion INNER JOIN tb046_ae_ramo USING (co_ramo) WHERE co_solicitud = $1', [solicitud[0].co_solicitud])).rows.map((x) => structureSettlements(x));
                                return (
                                  (liquidaciones.length > 0 && {
                                    id: +solicitudConvenio,
                                    estado: solicitud[0].co_estatus === 1 ? 'VIGENTE' : 'PAGADO',
                                    idRamo: (await client.query('SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1', [j.nb_ramo])).rows[0].id,
                                    cantPorciones: liquidaciones.length,
                                    porciones: liquidaciones.map((i) => {
                                      i.codigoRamo = j.nb_ramo;
                                      i.ramo = (j.tx_ramo as string).trim();
                                      return i;
                                    }),
                                  }) ||
                                  null
                                );
                              }
                              return null;
                            })
                          )
                        ).filter((el) => el);
                        convenios = convenios.length > 0 ? uniqBy(convenios, 'id') : undefined;
                      }
                      inmuebles.push({
                        id: x.co_contribuyente,
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        tipoInmueble: 'RESIDENCIAL',
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
                        ultimoAvaluo: { year: moment().year(), monto: 0 },
                      });
                      const datosSucursal = {
                        id: nullStringCheck(x.co_contribuyente),
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                        telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                        registroMunicipal: nullStringCheck(x.nu_referencia),
                        creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                      };
                      datos = {
                        datosSucursal,
                        inmuebles,
                        liquidaciones,
                        multas,
                        convenios,
                        actividadesEconomicas,
                      };
                    } else {
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_CONTRIBUTOR, [x.co_contribuyente])).rows[0];
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureEstates(j)));
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureFinings(j)));
                      const datosSucursal = {
                        id: nullStringCheck(x.co_contribuyente),
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
                        telefonoMovil: nullStringCheck(x.nu_telf_representante || x.nu_telf_movil),
                        creditoFiscal: creditoFiscal ? creditoFiscal.mo_haber : 0,
                      };
                      datos = {
                        // datosSucursal,
                        inmuebles,
                        liquidaciones,
                        multas,
                      };
                    }
                    return datos;
                  })
            ),
            actividadesEconomicas: await Promise.all(
              (await gtic.query(el.tx_dist_contribuyente === 'J' ? queries.gtic.ECONOMIC_ACTIVITIES_JURIDICAL : queries.gtic.ECONOMIC_ACTIVIES_NATURAL, [el.tx_tp_doc, el.tx_dist_contribuyente === 'J' ? el.tx_rif : el.nu_cedula])).rows.map((x) => ({
                id: x.nu_ref_actividad,
                descripcion: x.tx_actividad,
                alicuota: x.nu_porc_alicuota,
                minimoTributable: x.nu_ut,
              }))
            ),
            sinSucursales: false,
          };
        })
        .filter((el) => el)
    );
    if (contributors.every((el) => el.hasOwnProperty('sinSucursales') && el.sinSucursales)) return { status: 409, message: 'El usuario ya ha importado y actualizado todas sus sucursales' };
    return { status: 200, message: 'Informacion de enlace de cuenta obtenida', datosEnlace: contributors };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener datos del contribuyente',
    };
  } finally {
    client.release();
    gtic.release();
  }
};

const getLinkedContributorData = async (contributor: any) => {
  const client = await pool.connect();
  try {
    const datosContribuyente = {
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      tipoDocumento: contributor.tipo_documento,
      razonSocial: contributor.razon_social,
      siglas: contributor.siglas,
      denomComercial: contributor.denominacion_comercial,
      telefonoMovil: '',
      telefonoHabitacion: '',
      email: '',
      parroquia: contributor.parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      puntoReferencia: contributor.punto_referencia,
    };
    const sucursales = await Promise.all(
      (await client.query('SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = $1', [contributor.id_contribuyente])).rows
        .filter((el) => !el.actualizado)
        .map(async (el) => {
          const inmueble = (await client.query('SELECT * FROM inmueble_urbano WHERE id_registro_municipal = $1 ORDER BY id_inmueble DESC LIMIT 1', [el.id_registro_municipal])).rows[0];

          const payload = {
            datosSucursal: {
              id: el.id_registro_municipal,
              direccion: inmueble ? inmueble.direccion : null,
              email: el.email,
              razonSocial: datosContribuyente.razonSocial,
              denomComercial: el.denominacion_comercial,
              metrosCuadrados: 0.0,
              cuentaContrato: 0.0,
              nombreRepresentante: el.nombre_representante,
              telefonoMovil: el.telefono_celular,
              registroMunicipal: el.referencia_municipal,
            },
            inmuebles: [{ id: inmueble && inmueble.id_inmueble, direccion: inmueble && inmueble.direccion }],
            liquidaciones: [],
            multas: [],
          };
          return { ...payload };
        })
    );
    return { datosContribuyente, sucursales, sinSucursales: !sucursales.length };
  } catch (error) {
    throw error;
  } finally {
    client.release();
  }
};

const externalUserForLinkingExists = async ({ user, password, gtic }: { user: string; password: string; gtic: PoolClient }) => {
  try {
    const gticUser = (await gtic.query(queries.gtic.GET_REPRESENTATIVE_BY_EMAIL, [user])).rows;
    if (!gticUser[0]) return { canBeLinked: false };
    const isAttemptedUser = gticUser
      .map((el) => ({
        loggedIn: el.tx_password.startsWith('$') ? bcrypt.compareSync(password, el.tx_password) : md5(password) === el.tx_password,
        contribuyente: el,
      }))
      .find((x) => x.loggedIn);
    console.log(isAttemptedUser);
    return { attemptedUser: isAttemptedUser?.contribuyente, canBeLinked: isAttemptedUser?.loggedIn };
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

export const createSettlementForProcedure = async (process, client) => {
  const { referenciaMunicipal, monto, ramo, idTramite } = process;
  try {
    const datos = {
      fecha: { month: moment().toDate().toLocaleDateString('ES', { month: 'long' }), year: moment().year() },
      descripcion: 'TRAMITE',
      idTramite,
    };
    console.log('si');
    const liquidacion = (await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [null, fixatedAmount(monto), ramo, 'Pago ordinario', datos, moment().endOf('month').format('MM-DD-YYYY'), referenciaMunicipal])).rows[0];
  } catch (e) {
    throw e;
  }
};

export const patchSettlement = async ({ id, settlement }) => {
  const client = await pool.connect();
  const { fechaLiquidacion, subramo, estado } = settlement;
  let liquidacion;
  try {
    await client.query('BEGIN');
    const prevSettlement = (await client.query(queries.GET_SETTLEMENT_BY_ID, [id])).rows[0];
    const proposedDate = moment(fechaLiquidacion);
    const newData = {
      ...prevSettlement.datos,
      fecha: { month: proposedDate.locale('es').format('MMMM'), year: proposedDate.year() },
    };
    //1000, validando
    const patchApplication = (await client.query(queries.GET_PATCH_APPLICATION_BY_ORIGINAL_ID_AND_STATE, [prevSettlement.id_solicitud, estado])).rows[0];
    if (!patchApplication) {
      const prevApplication = (await client.query(queries.GET_APPLICATION_BY_ID, [prevSettlement.id_solicitud])).rows[0];
      const newApplication = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [prevApplication.id_usuario, prevApplication.id_contribuyente])).rows[0];
      await client.query(queries.ADD_ORIGINAL_APPLICATION_ID_IN_PATCH_APPLICATION, [prevApplication.id_solicitud, newApplication.id_solicitud]);
      // await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['CORRECCION', newApplication.id_solicitud]);
      await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [newApplication.id_solicitud, applicationStateEvents.INGRESARDATOS]);
      await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [fechaLiquidacion, newApplication.id_solicitud]);
      // if (estado === 'validando') {
      //   await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [newApplication.id_solicitud, applicationStateEvents.VALIDAR]);
      // }
      if (estado === 'finalizado') {
        await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [newApplication.id_solicitud, applicationStateEvents.APROBARCAJERO]);
        await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [fechaLiquidacion, newApplication.id_solicitud]);
      }
      liquidacion = (await client.query(queries.UPDATE_SETTLEMENT_CORRECTION, [proposedDate, proposedDate.endOf('month'), newData, subramo, newApplication.id_solicitud, id])).rows.map((el) => ({
        id: el.id_liquidacion,
        fechaLiquidacion: el.fecha_liquidacion,
        fechaVencimiento: el.fecha_vencimiento,
        monto: +el.monto,
        estado,
        certificado: el.certificado,
        recibo: el.recibo,
        ramo: settlement.ramo,
        subramo,
      }))[0];
    } else {
      liquidacion = (await client.query(queries.UPDATE_SETTLEMENT_CORRECTION, [proposedDate, proposedDate.endOf('month'), newData, subramo, patchApplication.id_solicitud, id])).rows.map((el) => ({
        id: el.id_liquidacion,
        fechaLiquidacion: el.fecha_liquidacion,
        fechaVencimiento: el.fecha_vencimiento,
        monto: +el.monto,
        estado,
        certificado: el.certificado,
        recibo: el.recibo,
        ramo: settlement.ramo,
        subramo,
      }))[0];
    }
    // await client.query(queries.UPDATE_LAST_UPDATE_DATE, [prevSettlement.id_solicitud]);
    await client.query('COMMIT');
    return { status: 200, message: 'Correccion administrativa realizada correctamente', liquidacion };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al realizar la correcion de la liquidacion',
    };
  } finally {
    client.release();
  }
};

//TODO: get de fracciones
export const getAgreementFractionById = async ({ id }): Promise<Solicitud & any> => {
  const client = await pool.connect();
  try {
    const application = (await client.query(queries.GET_AGREEMENT_FRACTION_BY_ID, [id])).rows[0];

    const fraction = {
      id: application.id_fraccion,
      idConvenio: application.id_convenio,
      monto: application.monto,
      fecha: application.fecha,
      fechaAprobacion: application.fecha_aprobado,
      aprobado: application.aprobado,
      estado: (await client.query(queries.GET_AGREEMENT_FRACTION_STATE, [application.id_fraccion])).rows[0]?.state,
    };

    console.log(fraction);
    return fraction;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

//TODO: get de convenios
export const getAgreements = async ({ user }: { user: Usuario }) => {
  const client = await pool.connect();
  try {
    const hasApplications = (await client.query(queries.GET_AGREEMENTS_BY_USER, [user.id])).rows.length > 0;
    if (!hasApplications) throw { status: 404, message: 'El usuario no posee convenios' };
    const applications: any[] = await Promise.all(
      (await client.query(queries.GET_AGREEMENTS_BY_USER, [user.id])).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
        return {
          id: el.id_convenio,
          cantPorciones: el.cantidad,
          usuario: user,
          tipo: 'CONVENIO',
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          estado: (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0]?.state,
          referenciaMunicipal: liquidaciones[0]?.id_registro_municipal
            ? (await client.query('SELECT referencia_municipal FROM impuesto.registro_municipal WHERE id_registro_municipal = $1', [liquidaciones[0]?.id_registro_municipal])).rows[0]?.referencia_municipal
            : undefined,
          fecha: el.fecha,
          ramo: (
            await client.query('SELECT r.descripcion FROM impuesto.ramo r INNER JOIN impuesto.subramo s ON r.id_ramo = s.id_ramo INNER JOIN impuesto.liquidacion l ON s.id_subramo = l.id_subramo WHERE id_liquidacion = $1', [
              liquidaciones[0]?.id_liquidacion,
            ])
          ).rows[0]?.descripcion,
          monto: (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [el.id_solicitud])).rows[0]?.monto_total,
          porciones: await Promise.all((await client.query(queries.GET_FRACTIONS_BY_AGREEMENT_ID, [el.id_convenio])).rows.map(async (el) => await getAgreementFractionById({ id: el.id_fraccion }))),
        };
      })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', convenios: applications };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const getAgreementsForContributor = async ({ reference, docType, document, typeUser }) => {
  const client = await pool.connect();
  try {
    const user = (await client.query(queries.GET_USER_IN_CHARGE_OF_BRANCH, [reference, docType, document])).rows[0];
    if (!reference) throw { status: 404, message: 'Debe proporcionar un RIM que posea encargado' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'La sucursal proporcionada no existe' };
    const agreements = (await client.query(queries.GET_AGREEMENTS_BY_RIM, [branch.id_registro_municipal])).rows;
    if (!(agreements.length > 0)) throw { status: 404, message: 'El usuario no posee convenios' };
    const applications: any[] = await Promise.all(
      agreements.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
        return {
          id: el.id_convenio,
          cantPorciones: el.cantidad,
          usuario: user,
          tipo: 'CONVENIO',
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          estado: (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0]?.state,
          referenciaMunicipal: liquidaciones[0]?.id_registro_municipal
            ? (await client.query('SELECT referencia_municipal FROM impuesto.registro_municipal WHERE id_registro_municipal = $1', [liquidaciones[0]?.id_registro_municipal])).rows[0]?.referencia_municipal
            : undefined,
          fecha: el.fecha,
          ramo: (
            await client.query('SELECT r.descripcion FROM impuesto.ramo r INNER JOIN impuesto.subramo s ON r.id_ramo = s.id_ramo INNER JOIN impuesto.liquidacion l ON s.id_subramo = l.id_subramo WHERE id_liquidacion = $1', [
              liquidaciones[0]?.id_liquidacion,
            ])
          ).rows[0]?.descripcion,
          monto: (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [el.id_solicitud])).rows[0]?.monto_total,
          porciones: await Promise.all((await client.query(queries.GET_FRACTIONS_BY_AGREEMENT_ID, [el.id_convenio])).rows.map(async (el) => await getAgreementFractionById({ id: el.id_fraccion }))),
        };
      })
    );
    return { status: 200, message: 'Convenios obtenidos satisfactoriamente', convenios: applications };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener convenios de contribuyente',
    };
  } finally {
    client.release();
  }
};

export const getApplicationsAndSettlementsById = async ({ id, user }): Promise<Solicitud & any> => {
  const client = await pool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = await Promise.all(
      (await client.query(queries.GET_APPLICATION_BY_ID, [id])).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
        const state = (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state;
        return {
          id: el.id_solicitud,
          usuario: typeof user === 'object' ? user : { id: user },
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          tipo: el.tipo_solicitud,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          rebajado: el.rebajado,
          estado: state,
          referenciaMunicipal: liquidaciones[0]?.id_registro_municipal
            ? (await client.query('SELECT referencia_municipal FROM impuesto.registro_municipal WHERE id_registro_municipal = $1', [liquidaciones[0]?.id_registro_municipal])).rows[0]?.referencia_municipal
            : undefined,
          fecha: el.fecha,
          monto: (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [el.id_solicitud])).rows[0].monto_total,
          liquidaciones: liquidaciones
            .filter((el) => el.tipoProcedimiento !== 'MULTAS')
            .map((el) => {
              return {
                id: el.id_liquidacion,
                ramo: el.tipoProcedimiento,
                fecha: el.datos.fecha,
                monto: el.monto,
                certificado: el.certificado,
                recibo: el.recibo,
              };
            }),
          multas: liquidaciones
            .filter((el) => el.tipoProcedimiento === 'MULTAS')
            .map((el) => {
              return {
                id: el.id_liquidacion,
                ramo: el.tipoProcedimiento,
                fecha: el.datos.fecha,
                monto: el.monto,
                descripcion: el.datos.descripcion,
                certificado: el.certificado,
                recibo: el.recibo,
              };
            }),
          interesMoratorio: await getDefaultInterestByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
          rebajaInteresMoratorio: await getDefaultInterestRebateByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
        };
      })
    );
    return application[0];
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const getApplicationsAndSettlements = async ({ user }: { user: Usuario }) => {
  const client = await pool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const applications: Solicitud[] = await Promise.all(
      (await client.query(queries.GET_APPLICATION_INSTANCES_BY_USER, [user.id])).rows
        .filter((el) => el.tipo_solicitud !== 'CONVENIO')
        .map(async (el) => {
          const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
          const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
          const state = (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state;
          return {
            id: el.id_solicitud,
            usuario: user,
            contribuyente: structureContributor(docs),
            aprobado: el.aprobado,
            documento: docs.documento,
            tipoDocumento: docs.tipo_documento,
            tipo: el.tipo_solicitud,
            rebajado: el.rebajado,
            estado: state,
            referenciaMunicipal: liquidaciones[0]?.id_registro_municipal
              ? (await client.query('SELECT referencia_municipal FROM impuesto.registro_municipal WHERE id_registro_municipal = $1', [liquidaciones[0]?.id_registro_municipal])).rows[0]?.referencia_municipal
              : undefined,
            fecha: el.fecha,
            monto: (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [el.id_solicitud])).rows[0].monto_total,
            liquidaciones: liquidaciones
              .filter((el) => el.tipoProcedimiento !== 'MULTAS')
              .map((el) => {
                return {
                  id: el.id_liquidacion,
                  ramo: el.tipoProcedimiento,
                  fecha: el.datos.fecha,
                  monto: +el.monto,
                  certificado: el.certificado,
                  recibo: el.recibo,
                };
              }),
            multas: liquidaciones
              .filter((el) => el.tipoProcedimiento === 'MULTAS')
              .map((el) => {
                return {
                  id: el.id_liquidacion,
                  ramo: el.tipoProcedimiento,
                  fecha: el.datos.fecha,
                  monto: +el.monto,
                  descripcion: el.datos.descripcion,
                  certificado: el.certificado,
                  recibo: el.recibo,
                };
              }),
            interesMoratorio: await getDefaultInterestByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
            rebajaInteresMoratorio: await getDefaultInterestRebateByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
          };
        })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', solicitudes: applications.filter((el) => el.liquidaciones.length > 0 || el.multas!.length > 0) };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const getApplicationsAndSettlementsForContributor = async ({ referencia, docType, document, typeUser }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente no existe' };
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const userApplications = (referencia
      ? await client.query(queries.GET_APPLICATION_INSTANCES_BY_CONTRIBUTOR, [contributor.id_contribuyente, referencia])
      : await client.query(queries.GET_APPLICATION_INSTANCES_FOR_NATURAL_CONTRIBUTOR, [contributor.id_contribuyente])
    ).rows;
    const hasApplications = userApplications.length > 0;
    if (!hasApplications) return { status: 404, message: 'El usuario no tiene solicitudes' };
    const applications: Solicitud[] = await Promise.all(
      userApplications
        .filter((el) => el.tipo_solicitud !== 'CONVENIO')
        .map(async (el) => {
          const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
          const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
          const state = (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state;

          return {
            id: el.id_solicitud,
            usuario: el.usuario,
            contribuyente: structureContributor(docs),
            aprobado: el.aprobado,
            creditoFiscal: (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [typeUser === 'JURIDICO' ? liquidaciones[0]?.id_registro_municipal : el.id_contribuyente, typeUser])).rows[0]?.credito || 0,
            fecha: el.fecha,
            documento: docs.documento,
            tipoDocumento: docs.tipo_documento,
            rebajado: el.rebajado,
            tipo: el.tipo_solicitud,
            estado: state,
            referenciaMunicipal: liquidaciones[0]?.id_registro_municipal
              ? (await client.query('SELECT referencia_municipal FROM impuesto.registro_municipal WHERE id_registro_municipal = $1', [liquidaciones[0]?.id_registro_municipal])).rows[0]?.referencia_municipal
              : undefined,
            monto: (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [el.id_solicitud])).rows[0].monto_total,
            liquidaciones: liquidaciones
              .filter((el) => el.tipoProcedimiento !== 'MULTAS')
              .map((el) => {
                return {
                  id: el.id_liquidacion,
                  ramo: el.tipoProcedimiento,
                  fecha: el.datos.fecha,
                  monto: +el.monto,
                  certificado: el.certificado,
                  recibo: el.recibo,
                };
              }),
            multas: liquidaciones
              .filter((el) => el.tipoProcedimiento === 'MULTAS')
              .map((el) => {
                return {
                  id: el.id_liquidacion,
                  ramo: el.tipoProcedimiento,
                  fecha: el.datos.fecha,
                  monto: +el.monto,
                  descripcion: el.datos.descripcion,
                  certificado: el.certificado,
                  recibo: el.recibo,
                };
              }),
            interesMoratorio: await getDefaultInterestByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
            rebajaInteresMoratorio: await getDefaultInterestRebateByApplication({ id: el.id_solicitud, date: el.fecha, state, client }),
          };
        })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', solicitudes: applications.filter((el) => el.liquidaciones.length > 0 || el.multas!.length > 0) };
  } catch (error) {
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const formatContributor = async (contributor, client: PoolClient) => {
  try {
    const branches = (await client.query(queries.GET_BRANCHES_BY_CONTRIBUTOR_ID, [contributor.id_contribuyente])).rows;
    return {
      id: contributor.id_contribuyente,
      tipoDocumento: contributor.tipo_documento,
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      razonSocial: contributor.razon_social,
      denomComercial: contributor.denominacion_comercial || undefined,
      siglas: contributor.siglas || undefined,
      parroquia: contributor.id_parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      creditoFiscal: (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [contributor.id_contribuyente, 'NATURAL'])).rows[0]?.credito || 0,
      puntoReferencia: contributor.punto_referencia,
      verificado: contributor.verificado,
      esAgenteRetencion: contributor.es_agente_retencion,
      usuarios: await getUsersByContributor(contributor.id_contribuyente),
      sucursales: branches.length > 0 ? await Promise.all(branches.map((el) => formatBranch(el, client))) : undefined,
    };
  } catch (e) {
    throw e;
  }
};

export const formatBranch = async (branch, client) => {
  return {
    id: branch.id_registro_municipal,
    referenciaMunicipal: branch.referencia_municipal,
    fechaAprobacion: branch.fecha_aprobacion,
    direccion: branch.direccion,
    telefono: branch.telefono_celular,
    email: branch.email,
    denomComercial: branch.denominacion_comercial,
    parroquia: branch.id_parroquia,
    nombreRepresentante: branch.nombre_representante,
    capitalSuscrito: branch.capital_suscrito,
    creditoFiscal: (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [branch.id_registro_municipal, 'JURIDICO'])).rows[0]?.credito || 0,
    tipoSociedad: branch.tipo_sociedad,
    actualizado: branch.actualizado,
    estadoLicencia: branch.estado_licencia,
    actividadesEconomicas: (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_RIM, [branch.id_registro_municipal])).rows,
    liquidaciones: (
      await client.query(
        `WITH solicitudcte AS (
          SELECT id_solicitud
          FROM impuesto.solicitud 
          WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1)
      
      )
      
      SELECT *,
              s.descripcion AS "descripcionSubramo",
               r.descripcion AS "descripcionRamo"
      FROM (SELECT s.id_solicitud AS id,
          s.id_tipo_tramite AS tipotramite,
          s.aprobado,
          s.fecha,
          s.fecha_aprobado AS "fechaAprobacion",
          ev.state,
          s.tipo_solicitud AS "tipoSolicitud",
          s.id_contribuyente
         FROM impuesto.solicitud s
           JOIN ( SELECT es.id_solicitud,
                  impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
                 FROM impuesto.evento_solicitud es
                 WHERE id_solicitud IN (SELECT * FROM solicitudcte)
                GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
      ) sl
      INNER JOIN impuesto.liquidacion l
          ON sl.id = l.id_solicitud
      LEFT JOIN impuesto.subramo s
      USING (id_subramo)
      LEFT JOIN impuesto.ramo r
      USING (id_ramo)
      WHERE l.id_registro_municipal= $1
      ORDER BY fecha_liquidacion DESC;
      `,
        [branch.id_registro_municipal]
      )
    ).rows.map((el) => ({
      id: el.id_liquidacion,
      fechaLiquidacion: el.fecha_liquidacion,
      fechaVencimiento: el.fecha_vencimiento,
      monto: +el.monto,
      estado: el.state || 'finalizado',
      certificado: el.certificado,
      recibo: el.recibo,
      ramo: {
        id: el.id_ramo,
        descripcion: el.descripcionRamo,
      },
      subramo: {
        id: el.id_subramo,
        descripcion: el.descripcionSubramo,
      },
    })),
  };
};

export const contributorSearch = async ({ document, docType, name }) => {
  const client = await pool.connect();
  let contribuyentes: any[] = [];
  try {
    console.log(document, name);
    console.log(!document && !name);
    if (!document && !name) throw { status: 406, message: 'Debe aportar algun parametro para la busqueda' };
    if (document && document.length < 6 && name && name.length < 3) throw { status: 406, message: 'Debe aportar mas datos para la busqueda' };
    contribuyentes = document && document.length > 6 ? (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows : (await client.query(queries.SEARCH_CONTRIBUTOR_BY_NAME, [`%${name}%`])).rows;
    const contributorExists = contribuyentes.length > 0;
    if (!contributorExists) return { status: 404, message: 'No existen coincidencias con la razon social o documento proporcionado' };
    contribuyentes = await Promise.all(contribuyentes.map(async (el) => await formatContributor(el, client)));
    return { status: 200, message: 'Contribuyente obtenido', contribuyentes };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener contribuyentes en busqueda',
    };
  } finally {
    client.release();
  }
};

export const getEntireDebtsForContributor = async ({ reference, docType, document, typeUser }) => {
  const client = await pool.connect();
  try {
    console.log(document, typeUser, docType, reference);
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const contribuyente = (await client.query(queries.GET_CONTRIBUTOR_BY_DOCUMENT_AND_DOC_TYPE, [document, docType])).rows[0];
    if (!contribuyente) return { status: 404, message: 'El contribuyente no está registrado en SEDEMAT' };
    const liquidaciones = (typeUser === 'NATURAL'
      ? await client.query(queries.GET_APPLICATION_DEBTS_FOR_NATURAL_CONTRIBUTOR, [contribuyente.id_contribuyente])
      : await client.query(queries.GET_APPLICATION_DEBTS_BY_MUNICIPAL_REGISTRY, [reference, contribuyente.id_contribuyente])
    ).rows;
    const hasSettlements = liquidaciones.length > 0;
    if (!hasSettlements) return { status: 404, message: 'El contribuyente no posee deudas' };
    const payload = {
      contribuyente: {
        id: contribuyente.id_contribuyente,
        tipoDocumento: contribuyente.tipo_documento,
        documento: contribuyente.documento,
        registroMunicipal: reference,
        razonSocial: contribuyente.razon_social,
        denomComercial: contribuyente.denominacion_comercial || undefined,
        siglas: contribuyente.siglas || undefined,
        parroquia: contribuyente.parroquia,
        sector: contribuyente.sector,
        direccion: contribuyente.direccion,
        puntoReferencia: contribuyente.punto_referencia,
        verificado: contribuyente.verificado,
        usuarios: await getUsersByContributor(contribuyente.id_contribuyente),
        liquidaciones: liquidaciones.map((x) => ({ id: x.id_ramo, ramo: x.descripcion, monto: x.monto })),
        totalDeuda: liquidaciones.map((x) => x.monto).reduce((i, j) => +i + +j),
      },
    };
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', ...payload };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener solicitudes y liquidaciones',
    };
  } finally {
    client.release();
  }
};

const getDefaultInterestByApplication = async ({ id, date, state, client }): Promise<number> => {
  try {
    const value =
      (state === 'ingresardatos' &&
        moment().isAfter(moment(date)) &&
        moment().diff(moment(date).startOf('month'), 'month') > 0 &&
        (
          await client.query(
            'SELECT l.*, s.*, r.descripcion_corta as "tipoProcedimiento" FROM impuesto.liquidacion l INNER JOIN  (SELECT id_subramo, MAX(fecha_vencimiento) AS max_fecha FROM impuesto.liquidacion WHERE id_solicitud = $1 GROUP BY id_subramo) s ON s.id_subramo = l.id_subramo AND s.max_fecha = l.fecha_vencimiento INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo r USING (id_ramo) WHERE id_solicitud = $1;',
            [id]
          )
        ).rows
          // .filter((el) => !!['AE', 'SM', 'IU', 'PP'].find((x) => x === el.tipoProcedimiento))
          .map((p) => ((+p.monto * 0.3324) / 365) * (moment().diff(moment(date).endOf('month'), 'days') - 1))
          .reduce((x, j) => x + j, 0)) ||
      undefined;
    console.log('getDefaultInterestByApplication -> value', id, value);
    return +fixatedAmount(+value);
  } catch (e) {
    throw e;
  }
};

const getDefaultInterestRebateByApplication = async ({ id, date, state, client }): Promise<number> => {
  try {
    const value =
      (state === 'ingresardatos' &&
        moment().isAfter(moment(date)) &&
        moment().diff(moment(date).startOf('month'), 'month') > 0 &&
        (
          await client.query(
            'SELECT l.*, s.*, r.descripcion_corta as "tipoProcedimiento" FROM impuesto.liquidacion l INNER JOIN  (SELECT id_subramo, MAX(fecha_vencimiento) AS max_fecha FROM impuesto.liquidacion WHERE id_solicitud = $1 GROUP BY id_subramo) s ON s.id_subramo = l.id_subramo AND s.max_fecha = l.fecha_vencimiento INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo r USING (id_ramo) WHERE id_solicitud = $1;',
            [id]
          )
        ).rows
          // .filter((el) => !!['AE', 'SM', 'IU', 'PP'].find((x) => x === el.tipoProcedimiento))
          .map((p) => (+p.monto * 0.3324) / 365)
          .reduce((x, j) => x + j, 0)) ||
      undefined;
    // console.log('getDefaultInterestByApplication -> value', id, value);
    return +fixatedAmount(+value);
  } catch (e) {
    throw e;
  }
};

export const initialUserLinking = async (linkingData, user) => {
  const client = await pool.connect();
  const { datosContribuyente, sucursales, datosContacto, actividadesEconomicas } = linkingData;
  const { tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, tipoContribuyente } = datosContribuyente;
  let payload;
  try {
    client.query('BEGIN');
    const contributorExists = (await client.query(queries.TAX_PAYER_EXISTS, [tipoDocumento, documento])).rows;
    if (contributorExists.length > 0) {
      if (datosContribuyente.tipoContribuyente === 'JURIDICO') {
        let hasNewCode = false;
        const rims: number[] = await Promise.all(
          await sucursales.map(async (el) => {
            const { datosSucursal } = el;
            const { nombreRepresentante, telefonoMovil, email, denomComercial, representado, registroMunicipal, direccion } = datosSucursal;
            const updatedRegistry = (
              await client.query(queries.UPDATE_BRANCH_INFO, [denomComercial, nombreRepresentante, representado ? datosContacto.telefono : telefonoMovil, representado ? datosContacto.correo : email, representado, direccion, registroMunicipal])
            ).rows[0];
            return representado ? updatedRegistry.id_registro_municipal : undefined;
          })
        );
        user.tipoUsuario === 4 && (await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributorExists[0].id_contribuyente, user.id]));
        await client.query('COMMIT');
        await sendRimVerification(VerificationValue.CellPhone, { idRim: rims.filter((el) => el), content: datosContacto.telefono, user: user.id });
        hasNewCode = true;

        payload = { rims: rims.filter((el) => el) };
        return { status: 200, message: 'Datos actualizados para las sucursales del contribuyente', hasNewCode, payload };
      } else {
      }
    }
    const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    user.tipoUsuario === 4 && (await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributor.id_contribuyente, user.id]));
    // if (actividadesEconomicas && actividadesEconomicas.length > 0) {
    //   await Promise.all(
    //     actividadesEconomicas.map(async (x) => {
    //       return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [contributor.id_contribuyente, x.id]);
    //     })
    //   );
    // }
    if (datosContribuyente.tipoContribuyente === 'JURIDICO') {
      const rims: number[] = await Promise.all(
        await sucursales.map(async (x) => {
          const { inmuebles, liquidaciones, multas, datosSucursal, actividadesEconomicas, convenios } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado, direccion } = datosSucursal;
          const registry = (
            await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [
              contributor.id_contribuyente,
              registroMunicipal,
              nombreRepresentante,
              representado ? datosContacto.telefono : telefonoMovil,
              representado ? datosContacto.correo : email,
              denomComercial,
              representado || false,
              direccion,
            ])
          ).rows[0];
          if (actividadesEconomicas!.length > 0) {
            await Promise.all(
              actividadesEconomicas!.map(async (x) => {
                return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [registry.id_registro_municipal, x.id, moment().startOf('year').format('YYYY-MM-DD')]);
              })
            );
          }
          if (convenios?.length > 0) {
            await Promise.all(
              convenios.map(async (el) => {
                const applicationAG = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [el.porciones[0].fechaLiquidacion, applicationAG.id_solicitud]);
                await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.INGRESARDATOS]);
                el.estado === 'PAGADO' && (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.APROBARCAJERO]));
                el.estado === 'PAGADO' && (await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [el.porciones[0].fechaLiquidacion, applicationAG.id_solicitud]));
                await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['CONVENIO', applicationAG.id_solicitud]);
                const agreement = (await client.query(queries.CREATE_AGREEMENT, [applicationAG.id_solicitud, el.cantPorciones])).rows[0];
                const benefitAgreement = await Promise.all(
                  el.porciones.map(async (el, i) => {
                    const liquidacion = (
                      await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                        applicationAG.id_solicitud,
                        fixatedAmount(+el.monto),
                        el.ramo,
                        el.descripcion,
                        { fecha: el.fecha },
                        moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                        registry.id_registro_municipal,
                      ])
                    ).rows[0];
                    await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, liquidacion.id_liquidacion]);
                    const fraccion = (await client.query(queries.CREATE_AGREEMENT_FRACTION, [agreement.id_convenio, fixatedAmount(+el.monto), i + 1, el.fechaVencimiento])).rows[0];
                    await client.query(queries.UPDATE_FRACTION_STATE, [fraccion.id_fraccion, applicationStateEvents.INGRESARDATOS]);
                    if (el.estado === 'PAGADO') {
                      await client.query(queries.COMPLETE_FRACTION_STATE, [fraccion.id_fraccion, applicationStateEvents.APROBARCAJERO]);
                      await client.query('UPDATE impuesto.fraccion SET fecha_aprobado = $1 WHERE id_fraccion = $2', [moment(el.fechaVencimiento).format('MM-DD-YYYY'), fraccion.id_fraccion]);
                    }
                  })
                );
                await client.query(queries.CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT, [el.idRamo, applicationAG.id_solicitud]);
                return benefitAgreement;
              })
            );
          }
          const credit = (await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, [registry.id_registro_municipal, 'JURIDICO', fixatedAmount(+datosSucursal?.creditoFiscal || 0), true])).rows[0];
          // const estates =
          //   inmuebles.length > 0
          //     ? await Promise.all(
          //         inmuebles.map(async (el) => {
          //           const x = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble])).rows[0];
          //           await client.query(queries.INSERT_ESTATE_VALUE, [x.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
          //         })
          //       )
          //     : undefined;
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    el.descripcion,
                    { fecha: el.fecha },
                    moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS]);
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [vigentes[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    el.descripcion,
                    { fecha: el.fecha },
                    moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }
          return representado ? registry.id_registro_municipal : undefined;
        })
      );
      await client.query('COMMIT');
      await sendRimVerification(VerificationValue.CellPhone, { content: datosContacto.telefono, user: user.id, idRim: rims.filter((el) => el) });
      payload = { rims: rims.filter((el) => el) };
    } else {
      const rims: number[] = await Promise.all(
        await sucursales.map(async (x) => {
          const { inmuebles, liquidaciones, multas, datosSucursal, convenios } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          let registry;
          const credit = (await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, [contributor.id_contribuyente, 'NATURAL', fixatedAmount(+datosSucursal?.creditoFiscal || 0), true])).rows[0];
          if (datosSucursal?.registroMunicipal) {
            const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado, direccion } = datosSucursal;
            registry = (
              await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [
                contributor.id_contribuyente,
                registroMunicipal,
                nombreRepresentante,
                representado ? datosContacto.telefono : telefonoMovil,
                representado ? datosContacto.correo : email,
                denomComercial,
                representado || false,
                direccion,
              ])
            ).rows[0];
            if (x.actividadesEconomicas?.length > 0) {
              await Promise.all(
                x.actividadesEconomicas!.map(async (x) => {
                  return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [registry.id_registro_municipal, x.id, moment().startOf('year').format('YYYY-MM-DD')]);
                })
              );
            }
            if (convenios?.length > 0) {
              await Promise.all(
                convenios.map(async (el) => {
                  const applicationAG = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
                  await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [el.porciones[0].fechaLiquidacion, applicationAG.id_solicitud]);
                  await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.INGRESARDATOS]);
                  el.estado === 'PAGADO' && (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.APROBARCAJERO]));
                  el.estado === 'PAGADO' && (await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [el.porciones[0].fechaLiquidacion, applicationAG.id_solicitud]));
                  await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['CONVENIO', applicationAG.id_solicitud]);
                  const agreement = (await client.query(queries.CREATE_AGREEMENT, [applicationAG.id_solicitud, el.cantPorciones])).rows[0];
                  const benefitAgreement = await Promise.all(
                    el.porciones.map(async (el, i) => {
                      const liquidacion = (
                        await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                          applicationAG.id_solicitud,
                          fixatedAmount(+el.monto),
                          el.ramo,
                          el.descripcion,
                          { fecha: el.fecha },
                          moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                          registry.id_registro_municipal,
                        ])
                      ).rows[0];
                      await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, liquidacion.id_liquidacion]);
                      const fraccion = (await client.query(queries.CREATE_AGREEMENT_FRACTION, [agreement.id_convenio, fixatedAmount(+el.monto), i + 1, el.fechaVencimiento])).rows[0];
                      await client.query(queries.UPDATE_FRACTION_STATE, [fraccion.id_fraccion, applicationStateEvents.INGRESARDATOS]);
                      if (el.estado === 'PAGADO') {
                        await client.query(queries.COMPLETE_FRACTION_STATE, [fraccion.id_fraccion, applicationStateEvents.APROBARCAJERO]);
                        await client.query('UPDATE impuesto.fraccion SET fecha_aprobado = $1 WHERE id_fraccion = $2', [moment(el.fechaVencimiento).format('MM-DD-YYYY'), fraccion.id_fraccion]);
                      }
                    })
                  );
                  await client.query(queries.CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT, [el.idRamo, applicationAG.id_solicitud]);
                  return benefitAgreement;
                })
              );
            }
            // const estates =
            //   inmuebles.length > 0
            //     ? await Promise.all(
            //         inmuebles.map(async (el) => {
            //           const inmueble = await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble]);
            //           await client.query(queries.INSERT_ESTATE_VALUE, [x.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
            //         })
            //       )
            //     : undefined;
          } else {
            // const estates =
            //   inmuebles.length > 0
            //     ? await Promise.all(
            //         inmuebles.map(async (el) => {
            //           const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [(registry && registry.id_registro_municipal) || null, el.direccion, el.tipoInmueble])).rows[0];
            //           await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [inmueble.id_inmueble, contributor.id_contribuyente]);
            //           await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
            //           return 0;
            //         })
            //       )
            //     : undefined;
          }
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    el.descripcion,
                    { fecha: el.fecha },
                    moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS]);
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [vigentes[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    el.descripcion,
                    { fecha: el.fecha },
                    moment().locale('ES').month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }
          return datosSucursal?.representado ? registry && registry.id_registro_municipal : undefined;
        })
      );
      user.tipoUsuario === 4 && (await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [user.id])).rows[0];
      await client.query('COMMIT');
      // (rims.filter((el) => el).length > 0 && (await sendRimVerification(VerificationValue.CellPhone, { content: datosContacto.telefono, user: user.id, idRim: rims.filter((el) => el) }))) ||
      payload = { rims: rims.filter((el) => el) };
    }
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [contributor.id_contribuyente]);
    await client.query('COMMIT');
    return { status: 201, message: 'Enlace inicial completado', rims: payload.rims };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);

    throw {
      status: error.tiempo ? 429 : 500,
      ...error,
      message: errorMessageGenerator(error) || error.error.message || 'Error al iniciar el enlace de usuario de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

export const verifyUserLinking = async ({ code, user }) => {
  const client = await pool.connect();
  try {
    await verifyCode(VerificationValue.CellPhone, { code, user: user.id });
    const contribuyente = await hasLinkedContributor(user.id);
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [contribuyente?.id]);
    return { status: 200, message: 'Usuario enlazado y verificado', contribuyente };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al verificar el codigo del usuario',
    };
  } finally {
    client.release();
  }
};

export const resendUserCode = async ({ user }) => {
  const client = await pool.connect();
  try {
    await resendCode(VerificationValue.CellPhone, { user: user.id });
    return { status: 200, message: 'Codigo reenviado' };
  } catch (error) {
    console.log(error);
    let status = error.tiempo ? 429 : 500;
    throw {
      status: status,
      message: errorMessageGenerator(error) || 'Error al verificar el codigo del usuario',
      ...error,
    };
  } finally {
    client.release();
  }
};

export const insertSettlements = async ({ process, user }) => {
  const client = await pool.connect();
  const { impuestos } = process;
  //Esto hay que sacarlo de db
  const augment = 10;
  const maxFining = 100;
  let finingMonths: MultaImpuesto[] | undefined, finingAmount;
  try {
    client.query('BEGIN');
    const userContributor = user.tipoUsuario === 4 ? (await client.query(queries.GET_CONTRIBUTOR_BY_USER, [user.id])).rows : (await client.query(queries.TAX_PAYER_EXISTS, [process.tipoDocumento, process.documento])).rows;
    const userHasContributor = userContributor.length > 0;
    if (!userHasContributor) throw { status: 404, message: 'El usuario no esta asociado con ningun contribuyente' };
    const contributorReference = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [process.rim, process.contribuyente])).rows[0];
    const benefittedUser = (await client.query(queries.GET_USER_IN_CHARGE_OF_BRANCH_BY_ID, [contributorReference?.id_registro_municipal])).rows[0];
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.tipoUsuario !== 4 ? process.usuario || null : user.id, process.contribuyente])).rows[0];

    // ! Esto hay que descomentarlo el proximo mes
    // const hasAE = impuestos.find((el) => el.ramo === 'AE');
    // if (hasAE) {
    //   const now = moment().locale('ES');
    //   const pivot = moment().locale('ES');
    //   const onlyAE = impuestos
    //     .filter((el) => el.ramo === 'AE')
    //     .sort((a, b) => (pivot.month(a.fechaCancelada.month).toDate() === pivot.month(b.fechaCancelada.month).toDate() ? 0 : pivot.month(a.fechaCancelada.month).toDate() > pivot.month(b.fechaCancelada.month).toDate() ? 1 : -1));
    //   const lastSavedFine = (await client.query(queries.GET_LAST_FINE_FOR_LATE_APPLICATION, [contributorReference.id_registro_municipal])).rows[0];
    //   if (lastSavedFine && moment(lastSavedFine.fecha_liquidacion).year() === now.year() && moment(lastSavedFine.fecha_liquidacion).month() < now.month()) {
    //     finingAmount = lastSavedFine.datos.monto || lastSavedFine.monto;
    //     const proposedFiningDate = moment().locale('ES').month(onlyAE[0].fechaCancelada.month).month();
    //     const finingDate = moment(lastSavedFine.fecha_liquidacion).month() < proposedFiningDate ? moment(lastSavedFine.fecha_liquidacion).month() : proposedFiningDate;
    //     finingMonths = new Array(now.month() - 1 - finingDate).fill({});
    //     if (finingMonths.length > 0) {
    //       let counter = finingDate;
    //       finingMonths = await Promise.all(
    //         finingMonths.map((el, i) => {
    //           const multa = Promise.resolve(
    //             client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
    //               application.id_solicitud,
    //               fixatedAmount(finingAmount * UTMM),
    //               {
    //                 fecha: {
    //                   month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
    //                   year: now.year(),
    //                 },
    //                 descripcion: 'Multa por Declaracion Fuera de Plazo',
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
    //           finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
    //           return multa;
    //         })
    //       );
    //     }
    //     if (now.date() > 10) {
    //       const rightfulMonth = now.month() - 1;
    //       const multa = (
    //         await client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
    //           application.id_solicitud,
    //           fixatedAmount(finingAmount * UTMM),
    //           {
    //             fecha: {
    //               month: moment().month(rightfulMonth).toDate().toLocaleDateString('ES', { month: 'long' }),
    //               year: now.year(),
    //             },
    //             descripcion: 'Multa por Declaracion Fuera de Plazo',
    //             monto: finingAmount,
    //           },
    //           moment().endOf('month').format('MM-DD-YYYY'),
    //           (contributorReference && contributorReference.id_registro_municipal) || null,
    //         ])
    //       ).rows[0];
    //       const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };
    //       finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
    //       finingMonths.push(fine);
    //     }
    //   } else {
    //     finingAmount = 10;
    //     const finingDate = moment().locale('ES').month(onlyAE[0].fechaCancelada.month).month() + 1;
    //     finingMonths = new Array(now.month() - finingDate).fill({});
    //     if (finingMonths.length > 0) {
    //       let counter = finingDate - 1;
    //       finingMonths = await Promise.all(
    //         finingMonths.map((el, i) => {
    //           const multa = Promise.resolve(
    //             client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
    //               application.id_solicitud,
    //               fixatedAmount(finingAmount * UTMM),
    //               {
    //                 fecha: {
    //                   month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
    //                   year: now.year(),
    //                 },
    //                 descripcion: 'Multa por Declaracion Fuera de Plazo',
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
    //           finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
    //           return multa;
    //         })
    //       );
    //     }
    //     if (now.date() > 10) {
    //       const rightfulMonth = moment().month(now.month()).month() - 1;
    //       const multa = (
    //         await client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
    //           application.id_solicitud,
    //           fixatedAmount(finingAmount * UTMM),
    //           {
    //             fecha: {
    //               month: moment().month(rightfulMonth).toDate().toLocaleDateString('ES', { month: 'long' }),
    //               year: now.year(),
    //             },
    //             descripcion: 'Multa por Declaracion Fuera de Plazo',
    //             monto: finingAmount,
    //           },
    //           moment().endOf('month').format('MM-DD-YYYY'),
    //           (contributorReference && contributorReference.id_registro_municipal) || null,
    //         ])
    //       ).rows[0];
    //       const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };

    //       finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
    //       finingMonths.push(fine);
    //     }
    //   }
    // }
    // ! Esto hay que descomentarlo el proximo mes

    const impuestosExt = impuestos.map((x, i, j) => {
      if (x.ramo === 'AE') {
        const costoSolvencia = 2 * UTMM;
        x.monto = +x.monto - costoSolvencia;
        j.push({ monto: costoSolvencia, ramo: 'SAE', fechaCancelada: x.fechaCancelada });
      }
      if (x.ramo === 'SM') {
        const liquidacionGas = {
          ramo: branchNames['SM'],
          fechaCancelada: x.fechaCancelada,
          monto: impuestos.esAgenteRetencion ? +x.desglose[0].montoGas * 1.04 : +x.desglose[0].montoGas * 1.16,
          desglose: x.desglose,
          descripcion: 'Pago del Servicio de Gas',
        };
        const liquidacionAseo = {
          ramo: branchNames['SM'],
          fechaCancelada: x.fechaCancelada,
          monto: impuestos.esAgenteRetencion ? +x.desglose[0].montoGas * 1.04 : +x.desglose[0].montoAseo * 1.16,
          desglose: x.desglose,
          descripcion: 'Pago del Servicio de Aseo',
        };
        j.push(liquidacionAseo);
        j.push(liquidacionGas);
      }
      return x;
    });

    const settlement: Liquidacion[] = await Promise.all(
      impuestos
        .filter((el) => el.ramo !== 'SM')
        .map(async (el) => {
          const datos = {
            desglose: el.desglose ? el.desglose.map((al) => breakdownCaseHandler(el.ramo, al)) : undefined,
            fecha: { month: el.fechaCancelada.month, year: el.fechaCancelada.year },
          };
          const liquidacion = (
            await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
              application.id_solicitud,
              fixatedAmount(+el.monto),
              el.ramo,
              el.descripcion || 'Pago ordinario',
              datos,
              moment().locale('ES').month(el.fechaCancelada.month).endOf('month').format('MM-DD-YYYY'),
              (contributorReference && contributorReference.id_registro_municipal) || null,
            ])
          ).rows[0];

          return {
            id: liquidacion.id_liquidacion,
            ramo: branchNames[el.ramo],
            fecha: datos.fecha,
            monto: liquidacion.monto,
            certificado: liquidacion.certificado,
            recibo: liquidacion.recibo,
            desglose: datos.desglose,
          };
        })
    );

    // const solicitud: Solicitud & { registroMunicipal: string } = {
    //   id: application.id_solicitud,
    //   usuario: user,
    //   contribuyente: application.contribuyente,
    //   aprobado: application.aprobado,
    //   fecha: application.fecha,
    //   monto: finingMonths
    //     ?.concat(settlement)
    //     .map((el) => +el.monto)
    //     .reduce((x, j) => x + j, 0) as number,
    //   liquidaciones: settlement,
    //   multas: finingMonths,
    //   registroMunicipal: process.rim,
    // };
    const state = (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS])).rows[0].state;
    if (settlement.reduce((x, y) => x + +y.monto, 0) === 0) {
      // (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.VALIDAR])).rows[0].state;
      await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
    }
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [application.id_contribuyente]);
    await client.query('COMMIT');
    const solicitud = await getApplicationsAndSettlementsById({ id: application.id_solicitud, user });
    await sendNotification(
      user,
      `Se ha iniciado una solicitud para el contribuyente con el documento de identidad: ${solicitud.tipoDocumento}-${solicitud.documento}`,
      'CREATE_APPLICATION',
      'IMPUESTO',
      { ...solicitud, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );
    return { status: 201, message: 'Liquidaciones de impuestos creadas satisfactoriamente', solicitud };
  } catch (error) {
    console.log(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones',
    };
  } finally {
    client.release();
  }
};

export const addTaxApplicationPayment = async ({ payment, interest, application, user }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (!!interest) {
      const fixatedApplication = await getApplicationsAndSettlementsById({ id: application, user });
      const idReferenciaMunicipal = fixatedApplication.referenciaMunicipal
        ? (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [fixatedApplication.referenciaMunicipal, fixatedApplication.contribuyente.id])).rows[0].id_registro_municipal
        : undefined;
      const datos = {
        fecha: { month: moment().toDate().toLocaleDateString('ES', { month: 'long' }), year: moment().year() },
      };
      console.log('si');
      const liquidacion = (
        await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [application, fixatedAmount(+interest), 'INTERESES', 'Pago ordinario', datos, moment().endOf('month').format('MM-DD-YYYY'), idReferenciaMunicipal || null])
      ).rows[0];
    }
    const solicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [application])).rows[0];
    console.log('addTaxApplicationPayment -> solicitud', solicitud);
    const pagoSum = +payment.map((e) => +fixatedAmount(+e.costo)).reduce((e, i) => e + i, 0);
    console.log('addTaxApplicationPayment -> pagoSum', pagoSum);
    if (pagoSum < +fixatedAmount(+solicitud.monto_total)) throw { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
    const creditoPositivo = pagoSum - +fixatedAmount(+solicitud.monto_total);
    await Promise.all(
      payment.map(async (el) => {
        if (!el.costo) throw { status: 403, message: 'Debe incluir el monto a ser pagado' };
        const nearbyHolidays = (await client.query(queries.GET_HOLIDAYS_BASED_ON_PAYMENT_DATE, [el.fecha])).rows;
        const paymentDate = checkIfWeekend(moment(el.fecha));
        if (nearbyHolidays.length > 0) {
          while (nearbyHolidays.find((el) => moment(el.dia).format('YYYY-MM-DD') === paymentDate.format('YYYY-MM-DD'))) paymentDate.add({ days: 1 });
        }
        el.fecha = paymentDate;
        el.concepto = 'IMPUESTO';
        el.user = user.id;
        user.tipoUsuario === 4 ? await insertPaymentReference(el, application, client) : await insertPaymentCashier(el, application, client);
        if (el.metodoPago === 'CREDITO_FISCAL') {
          await updateFiscalCredit({ id: application, user, amount: -el.costo, client });
        }
      })
    );

    const state =
      user.tipoUsuario === 4
        ? (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.VALIDAR])).rows[0]
        : (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.APROBARCAJERO])).rows[0];

    await client.query('COMMIT');
    const applicationInstance = await getApplicationsAndSettlementsById({ id: application, user });
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [applicationInstance.contribuyente.id]);
    if (user.tipoUsuario !== 4) {
      if (creditoPositivo > 0) await updateFiscalCredit({ id: application, user, amount: creditoPositivo, client });
      applicationInstance.recibo = await generateReceipt({ application });
    }
    await sendNotification(
      user,
      `Se ${user.tipoUsuario === 4 ? `han ingresado los datos de pago` : `ha validado el pago`} de una solicitud de pago de impuestos para el contribuyente: ${applicationInstance.tipoDocumento}-${applicationInstance.documento}`,
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );
    return { status: 200, message: 'Pago añadido para la solicitud declarada', solicitud: applicationInstance };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al insertar referencias de pago',
    };
  } finally {
    client.release();
  }
};

export const addTaxApplicationPaymentRetention = async ({ payment, application, user }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const solicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [application])).rows[0];
    const applicationType = (await client.query('SELECT tipo_solicitud FROM impuesto.solicitud WHERE id_solicitud = $1', [application])).rows[0].tipo_solicitud;
    const pagoSum = payment.map((e) => e.costo).reduce((e, i) => e + i, 0);
    if (pagoSum < solicitud.monto_total) throw { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
    const creditoPositivo = pagoSum - solicitud.monto_total;
    await Promise.all(
      payment.map(async (el) => {
        if (!el.costo) throw { status: 403, message: 'Debe incluir el monto a ser pagado' };
        const nearbyHolidays = (await client.query(queries.GET_HOLIDAYS_BASED_ON_PAYMENT_DATE, [el.fecha])).rows;
        const paymentDate = checkIfWeekend(moment(el.fecha));
        if (nearbyHolidays.length > 0) {
          while (nearbyHolidays.find((el) => moment(el.dia).format('YYYY-MM-DD') === paymentDate.format('YYYY-MM-DD'))) paymentDate.add({ days: 1 });
        }
        el.fecha = paymentDate;
        el.concepto = applicationType;
        el.user = user.id;
        user.tipoUsuario === 4 ? await insertPaymentReference(el, application, client) : await insertPaymentCashier(el, application, client);
        if (el.metodoPago === 'CREDITO_FISCAL') {
          await updateFiscalCredit({ id: application, user, amount: -el.costo, client });
        }
      })
    );

    const state =
      user.tipoUsuario === 4
        ? (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.VALIDAR])).rows[0]
        : (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.APROBARCAJERO])).rows[0];

    if (user.tipoUsuario === 4 && applicationType === 'RETENCION') {
      const retentionDetail = (await client.query(queries.GET_RETENTION_DETAIL_BY_APPLICATION_ID, [application])).rows;
      await Promise.all(retentionDetail.map(async (x) => await client.query(queries.CREATE_RETENTION_FISCAL_CREDIT, [x.rif, x.numero_referencia, x.monto_retenido, true])));
    }

    await client.query('COMMIT');
    const applicationInstance = await getApplicationsAndSettlementsById({ id: application, user });
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [applicationInstance.contribuyente.id]);
    if (user.tipoUsuario !== 4) {
      if (creditoPositivo > 0) await updateFiscalCredit({ id: application, user, amount: creditoPositivo, client });
      applicationInstance.recibo = await generateReceipt({ application });
    }
    await sendNotification(
      user,
      `Se ${user.tipoUsuario === 4 ? `han ingresado los datos de pago` : `ha validado el pago`} de una solicitud de pago de impuestos para el contribuyente: ${applicationInstance.tipoDocumento}-${applicationInstance.documento}`,
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );
    return { status: 200, message: 'Pago añadido para la solicitud declarada', solicitud: applicationInstance };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al insertar referencias de pago',
    };
  } finally {
    client.release();
  }
};

const updateFiscalCredit = async ({ id, user, amount, client }) => {
  const fixatedApplication = await getApplicationsAndSettlementsById({ id, user });
  const idReferenciaMunicipal = fixatedApplication.referenciaMunicipal
    ? (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [fixatedApplication.referenciaMunicipal, fixatedApplication.contribuyente.id])).rows[0].id_registro_municipal
    : undefined;
  const payload = fixatedApplication.contribuyente.tipoContribuyente === 'JURIDICO' ? [idReferenciaMunicipal, 'JURIDICO', fixatedAmount(amount), false] : [fixatedApplication.contribuyente.id, 'NATURAL', fixatedAmount(amount), false];
  await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, payload);
};

export const addTaxApplicationPaymentAgreement = async ({ payment, agreement, fragment, user }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const fraccion = (await client.query(queries.GET_FRACTION_BY_AGREEMENT_AND_FRACTION_ID, [agreement, fragment])).rows[0];
    const pagoSum = payment.map((e) => e.costo).reduce((e, i) => e + i, 0);
    if (pagoSum < fraccion.monto) throw { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
    await Promise.all(
      payment.map(async (el) => {
        if (!el.costo) throw { status: 403, message: 'Debe incluir el monto a ser pagado' };
        const nearbyHolidays = (await client.query(queries.GET_HOLIDAYS_BASED_ON_PAYMENT_DATE, [el.fecha])).rows;
        const paymentDate = checkIfWeekend(moment(el.fecha));
        if (nearbyHolidays.length > 0) {
          while (nearbyHolidays.find((el) => moment(el.dia).format('YYYY-MM-DD') === paymentDate.format('YYYY-MM-DD'))) paymentDate.add({ days: 1 });
        }
        el.fecha = paymentDate;
        el.concepto = 'CONVENIO';
        el.user = user.id;
        user.tipoUsuario === 4 ? await insertPaymentReference(el, fragment, client) : await insertPaymentCashier(el, fragment, client);
      })
    );
    const state =
      user.tipoUsuario === 4 ? (await client.query(queries.UPDATE_FRACTION_STATE, [fragment, applicationStateEvents.VALIDAR])).rows[0] : (await client.query(queries.COMPLETE_FRACTION_STATE, [fragment, applicationStateEvents.APROBARCAJERO])).rows[0];
    const fractions = (await client.query(queries.GET_FRACTIONS_BY_AGREEMENT_ID, [agreement])).rows;
    if (fractions.every((x) => x.aprobado)) {
      const convenio = (await client.query('SELECT c.* FROM impuesto.convenio c INNER JOIN impuesto.fraccion f ON c.id_convenio = f.id_convenio WHERE f.id_fraccion = $1', [fragment])).rows[0];
      const applicationState = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [convenio.id_solicitud, applicationStateEvents.APROBARCAJERO])).rows[0].state;
    }
    await client.query('COMMIT');
    const applicationInstance = await getAgreementFractionById({ id: fragment });
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [applicationInstance.contribuyente.id]);
    console.log(applicationInstance);
    await sendNotification(
      user,
      `Se ${user.tipoUsuario === 4 ? `han ingresado los datos de pago` : `ha validado el pago`} de un convenio para el contribuyente: ${applicationInstance.tipoDocumento}-${applicationInstance.documento}`,
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );
    return { status: 200, message: 'Pago añadido para la solicitud declarada', solicitud: applicationInstance };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al insertar referencias de pago',
    };
  } finally {
    client.release();
  }
};

export const validateApplication = async (body, user, client) => {
  try {
    if (!body.solicitudAprobada) return;
    const state = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [body.idTramite, applicationStateEvents.FINALIZAR])).rows[0].state;
    const solicitud = (await client.query(queries.GET_APPLICATION_BY_ID, [body.idTramite])).rows[0];
    const totalLiquidacion = +(await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [body.idTramite])).rows[0].monto_total;
    const totalPago = +(await client.query('SELECT sum(monto) as monto_total FROM pago WHERE id_procedimiento = $1 AND concepto = $2', [body.idTramite, body.concepto])).rows[0].monto_total;
    const saldoPositivo = totalPago - totalLiquidacion;
    if (saldoPositivo > 0) {
      const fixatedApplication = await getApplicationsAndSettlementsById({ id: body.idTramite, user });
      const idReferenciaMunicipal = fixatedApplication.referenciaMunicipal
        ? (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [fixatedApplication.referenciaMunicipal, fixatedApplication.contribuyente.id])).rows[0].id_registro_municipal
        : undefined;
      const payload = fixatedApplication.contribuyente.tipoContribuyente === 'JURIDICO' ? [idReferenciaMunicipal, 'JURIDICO', saldoPositivo, false] : [fixatedApplication.contribuyente.id, 'NATURAL', saldoPositivo, false];
      await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, payload);
    }

    if (body.concepto === 'RETENCION') {
      /*TODO: logica de añadir retenciones a la tabla correspondiente, esto tiene que buscar los datos de la tabla 
      detalle_retencion joineando con liquidacion y solicitud. Eso hay que meterlo en la tabla credito_fiscal_retencion (?) y ya, listo*/
      const retentionDetail = (await client.query(queries.GET_RETENTION_DETAIL_BY_APPLICATION_ID, [body.idTramite])).rows;
      await Promise.all(retentionDetail.map(async (x) => await client.query(queries.CREATE_RETENTION_FISCAL_CREDIT, [x.rif, x.numero_referencia, x.monto_retenido, true])));
    }

    const applicationInstance = await getApplicationsAndSettlementsById({ id: body.idTramite, user: solicitud.id_usuario });
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [applicationInstance.contribuyente.id]);
    applicationInstance.aprobado = true;
    await sendNotification(
      user,
      `Se ha finalizado una solicitud de pago de impuestos para el contribuyente: ${applicationInstance.tipoDocumento}-${applicationInstance.documento}`,
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );

    return;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al validar el pago',
    };
  } finally {
  }
};

export const validateAgreementFraction = async (body, user, client: PoolClient) => {
  try {
    //este metodo es para validar los convenios y llevarlos al estado de finalizado
    const agreement = (await client.query('SELECT c.* FROM impuesto.convenio c INNER JOIN impuesto.fraccion f ON c.id_convenio = f.id_convenio WHERE f.id_fraccion = $1', [body.idTramite])).rows[0];
    const state = (await client.query(queries.COMPLETE_FRACTION_STATE, [body.idTramite, applicationStateEvents.FINALIZAR])).rows[0].state;
    const fractions = (await client.query(queries.GET_FRACTIONS_BY_AGREEMENT_ID, [agreement.id_convenio])).rows;
    if (!body.solicitudAprobada) return;
    const applicationState = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [agreement.id_solicitud, applicationStateEvents.APROBARCAJERO])).rows[0].state;
    const totalLiquidacion = +(await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [agreement.id_solicitud])).rows[0].monto_total;
    const totalPago = (await Promise.all(fractions.map(async (e) => +(await client.query('SELECT sum(monto) as monto_total FROM pago WHERE id_procedimiento = $1 AND concepto = $2', [e.id_fraccion, 'CONVENIO'])).rows[0].monto_total))).reduce(
      (x, j) => x + j
    );
    const saldoPositivo = totalPago - totalLiquidacion;
    if (saldoPositivo > 0) {
      const fixatedApplication = await getApplicationsAndSettlementsById({ id: agreement.id_solicitud, user });
      const idReferenciaMunicipal = fixatedApplication.referenciaMunicipal
        ? (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [fixatedApplication.referenciaMunicipal, fixatedApplication.contribuyente.id])).rows[0].id_registro_municipal
        : undefined;
      const payload = fixatedApplication.contribuyente.tipoContribuyente === 'JURIDICO' ? [idReferenciaMunicipal, 'JURIDICO', saldoPositivo, false] : [fixatedApplication.contribuyente.id, 'NATURAL', saldoPositivo, false];
      await client.query(queries.CREATE_OR_UPDATE_FISCAL_CREDIT, payload);
    }
    const applicationInstance = await getAgreementFractionById({ id: body.idTramite });
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [applicationInstance.contribuyente.id]);
    applicationInstance.aprobado = true;
    // await sendNotification(
    //   user,
    //   `Se ha finalizado un pago de convenios para el contribuyente: ${applicationInstance.tipoDocumento}-${applicationInstance.documento}`,
    //   'UPDATE_APPLICATION',
    //   'IMPUESTO',
    //   { ...applicationInstance, estado: state, nombreCorto: 'SEDEMAT' },
    //   client
    // );

    return;
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al validar el pago',
    };
  } finally {
  }
};

export const internalUserImport = async ({ reference, docType, document, typeUser, user }) => {
  const client = await pool.connect();
  try {
    if (typeUser === 'JURIDICO' && !reference) throw { status: 403, message: 'Debe proporcionar un RIM para importar un contribuyente juridico' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor?.id_contribuyente])).rows[0];
    // if (!!reference && !branch) throw { status: 404, message: 'No existe la sucursal solicitada' };
    const branchIsUpdated = branch?.actualizado;
    if (!contributor || (!!contributor && !!reference && !branchIsUpdated)) {
      const x = await externalLinkingForCashier({ document, docType, reference, user, typeUser });
      if (x.every((el) => el.hasOwnProperty('sinSucursales') && el.sinSucursales)) return { status: 200, message: 'El usuario ya esta registrado y actualizado, proceda a enlazarlo' };
      return { status: 202, message: 'Informacion de enlace de cuenta obtenida', datosEnlace: x };
    } else {
      return { status: 200, message: 'El usuario ya esta registrado y actualizado, proceda a enlazarlo' };
    }
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al obtener la informacion del usuario',
    };
  } finally {
    client.release();
  }
};

export const internalLicenseApproval = async (license, official: Usuario) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    console.log(license.datos.funcionario, license);
    const user = await getUserByUsername(license.username);
    if (!user) throw { status: 404, message: 'El usuario proporcionado no existe en SUT' };
    const userContributor = await hasLinkedContributor(user.id);
    if (license.datos.contribuyente.id !== userContributor?.id) throw { status: 401, message: 'El usuario de SUT proporcionado no tiene disponibilidad de crear licencias para el contribuyente seleccionado' };
    const procedure = (await initProcedureAnalist({ tipoTramite: 28, datos: license.datos, pago: license.pagos }, user as Usuario, client)).tramite;
    // license.datos.funcionario.pago = [license.pago]
    const res = await processProcedureAnalist({ idTramite: procedure.id, datos: license.datos, aprobado: true }, official, client);
    await client.query('COMMIT');
    return res;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al aprobar licencia de actividades economicas por interno',
    };
  } finally {
    client.release();
  }
};

export const internalContributorSignUp = async (contributor) => {
  const client = await pool.connect();
  const { correo, denominacionComercial, direccion, doc, puntoReferencia, razonSocial, sector, parroquia, siglas, telefono, tipoContribuyente, tipoDocumento } = contributor;
  try {
    let pivotUser;
    await client.query('BEGIN');
    const userExists = await getUserByUsername(correo);
    if (!userExists) {
      const user = { nombreCompleto: razonSocial, nombreUsuario: correo, direccion, cedula: doc, nacionalidad: tipoDocumento, password: '', telefono };
      const salt = genSaltSync(10);
      user.password = hashSync('123456', salt);
      const sutUser = await signUpUser(user);
      pivotUser = sutUser.user.id;
    } else {
      if (await hasLinkedContributor(userExists.id)) throw { status: 409, message: 'El usuario suministrado ya tiene un contribuyente asociado' };
      pivotUser = userExists.id;
    }
    const procedure = {
      datos: {
        funcionario: {
          documentoIdentidad: doc,
          razonSocial,
          denominacionComercial,
          siglas,
          parroquia,
          sector,
          direccion,
          puntoReferencia,
          tipoContribuyente,
          tipoDocumento,
        },
      },
      usuario: pivotUser,
    };
    const data = await approveContributorSignUp({ procedure, client });
    await client.query('COMMIT');
    return { status: 201, message: 'Contribuyente registrado', contribuyente: data };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear contribuyente por metodo interno',
    };
  } finally {
    client.release();
  }
};

export const approveContributorSignUp = async ({ procedure, client }: { procedure: any; client: PoolClient }) => {
  try {
    const { datos, usuario } = procedure;
    const { documentoIdentidad, razonSocial, denominacionComercial, siglas, parroquia, sector, direccion, puntoReferencia, tipoContribuyente, tipoDocumento } = datos.funcionario;
    const parish = (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [parroquia])).rows[0]?.id;
    const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documentoIdentidad, razonSocial, denominacionComercial, siglas, parish, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributor.id_contribuyente, usuario]);
    const x = (await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [usuario])).rows[0];
    console.log(procedure);
    return structureContributor(contributor);
  } catch (error) {
    console.log(error);
    throw error;
  }
};

export const internalUserLinking = async (data) => {
  const client = await pool.connect();
  const { username, documento, tipoDocumento, tipoContribuyente, referenciaMunicipal } = data;
  try {
    await client.query('BEGIN');
    const user = await getUserByUsername(username);
    if (!user) throw { status: 404, message: 'El usuario proporcionado no existe en SUT' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [tipoDocumento, documento])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    if (!!(await hasLinkedContributor(user.id))) throw { status: 409, message: 'El usuario suministrado ya tiene un contribuyente asociado' };
    await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributor.id_contribuyente, user.id]);
    if (tipoContribuyente === 'JURIDICO') {
      if (!referenciaMunicipal) throw { status: 404, message: 'Debe proporcionar un RIM para realizar el enlace para un contribuyente juridico' };
      const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [referenciaMunicipal, contributor.id_contribuyente])).rows[0];
      if (!branch) throw { status: 404, message: 'La sucursal proporcionada no existe' };
      if (!branch.actualizado) throw { status: 403, message: 'Debe pasar por el proceso de actualización para la sucursal seleccionada' };
      // await client.query('UPDATE impuesto.verificacion_telefono SET id_usuario = $1 WHERE id_verificacion_telefono = (SELECT id_verificacion_telefono FROM impuesto.registro_municipal_verificacion WHERE id_registro_municipal = $2 LIMIT 1)', [
      //   user.id,
      //   branch.id_registro_municipal,
      // ]);
      const verifiedId = (await client.query('SELECT * FROM impuesto.verificacion_telefono WHERE id_usuario = $1', [user.id])).rows[0]?.id_verificacion_telefono;
      if (!verifiedId) (await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [user.id])).rows[0];
      await client.query('UPDATE impuesto.solicitud s SET id_usuario = $1 FROM impuesto.liquidacion l WHERE s.id_solicitud = l.id_solicitud AND l.id_registro_municipal = $2', [user.id, branch.id_registro_municipal]);
    } else {
      const verifiedId = (await client.query('SELECT * FROM impuesto.verificacion_telefono WHERE id_usuario = $1', [user.id])).rows[0]?.id_verificacion_telefono;
      if (!verifiedId) (await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [user.id])).rows[0];
      await client.query('UPDATE impuesto.solicitud s SET id_usuario = $1 WHERE id_contribuyente = $2', [user.id, contributor.id_contribuyente]);
    }
    await client.query('COMMIT');
    return { status: 201, message: 'Usuario enlazado satisfactoriamente', usuario: user };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al realizar enlace de usuario por interno',
    };
  } finally {
    client.release();
  }
};

const recursiveRebate = (array, number): any[] => {
  const minus = number / array.filter((a) => +a.monto > 0).length;
  let _array = array.map((e) => {
    const _e = Object.assign({}, e);
    _e.monto = +_e.monto > 0 ? +_e.monto - minus : +_e.monto;
    return _e;
  });
  const diff = Math.abs(_array.filter((e) => +e.monto < 0).reduce((prev, current) => prev + +current.monto, 0));
  if (diff > 0) {
    return recursiveRebate(
      _array.map((e) => {
        const _e = Object.assign({}, e);
        _e.monto = +e.monto < 0 ? 0 : +e.monto;
        return _e;
      }),
      diff
    );
  } else return _array;
};

export const addRebateForDeclaration = async ({ process, user }) => {
  const client = await pool.connect();
  const { id, montoRebajado } = process;
  try {
    const { rebajado, id_solicitud: idSolicitud, id_contribuyente: contribuyente } = (await client.query(queries.GET_APPLICATION_BY_ID, [id])).rows[0];
    if (rebajado) throw { status: 403, message: 'Esta solicitud ya ha sido rebajada anteriormente' };
    const hasAE = (await client.query(`SELECT * FROM impuesto.liquidacion l INNER JOIN impuesto.subramo USING (id_subramo) INNER JOIN impuesto.ramo r USING (id_ramo) WHERE l.id_solicitud = $1 AND r.codigo = '112' AND l.monto > 0`, [idSolicitud]))
      .rows;
    if (!hasAE.length) throw { status: 403, message: 'La solicitud no posee liquidaciones de Actividad Económica' };
    const nroLiquidaciones = hasAE.length;
    const montoPerLiq = montoRebajado / nroLiquidaciones;
    await client.query('BEGIN');
    const test = await Promise.all(
      recursiveRebate(hasAE, montoRebajado).map(async (el) => {
        const oldValue = hasAE.find((x) => x.id_liquidacion === el.id_liquidacion).monto;
        console.log('if -> oldValue', oldValue);
        const newDatos = { ...el.datos, montoRebajado: oldValue - el.monto };
        console.log('montoRebajado', oldValue - el.monto);
        const liquidacion = (await client.query('UPDATE impuesto.liquidacion SET datos = $1, monto = $2 WHERE id_liquidacion = $3 RETURNING *;', [newDatos, el.monto, el.id_liquidacion])).rows[0];
        return liquidacion;
      })
    );
    // const settlements = await Promise.all(
    //   (
    //     await client.query(
    //       "UPDATE impuesto.liquidacion SET monto = monto - $1 WHERE id_solicitud = $2 AND id_subramo IN (SELECT id_subramo FROM impuesto.subramo s INNER JOIN impuesto.ramo r USING (id_ramo) WHERE codigo='112') AND l.monto > 0 RETURNING *;",
    //       [montoPerLiq, idSolicitud]
    //     )
    //   ).rows.map(async (el) => {
    //     const newDatos = { ...el.datos, montoRebajado: montoPerLiq };
    //     const liquidacion = (await client.query('UPDATE impuesto.liquidacion SET datos = $1 WHERE id_liquidacion = $2 RETURNING *;', [newDatos, el.id_liquidacion])).rows[0];
    //     return liquidacion;
    //   })
    // );
    await client.query('UPDATE impuesto.solicitud SET rebajado = true WHERE id_solicitud = $1', [idSolicitud]);
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [contribuyente]);
    await client.query('COMMIT');
    return { status: 200, message: 'Solicitud rebajada satisfactoriamente' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al aplicar rebaja a la declaración',
    };
  } finally {
    client.release();
  }
};

export const createSpecialSettlement = async ({ process, user }) => {
  const client = await pool.connect();
  const { impuestos } = process;
  let recibo: any = undefined;
  console.log(process);
  try {
    client.query('BEGIN');
    const userContributor = (await client.query(queries.TAX_PAYER_EXISTS, [process.tipoDocumento, process.documento])).rows;
    const userHasContributor = userContributor.length > 0;
    if (!userHasContributor) throw { status: 404, message: 'El usuario no esta asociado con ningun contribuyente' };
    const contributorReference = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [process.rim, userContributor[0].id_contribuyente])).rows[0];
    if (!contributorReference && !!process.rim) throw { status: 404, message: 'La sucursal solicitada no existe' };
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(user.tipoUsuario !== 4 && process.usuario) || user.id, userContributor[0].id_contribuyente])).rows[0];

    const settlement: Liquidacion[] = await Promise.all(
      impuestos.map(async (el) => {
        const isSpecialSettlement = (await client.query(queries.IS_SPECIAL_SETTLEMENT, [el.ramo])).rows.length > 0;
        if (!isSpecialSettlement) throw { status: 403, message: 'Error al insertar liquidacion especial' };
        const datos = {
          desglose: el.desglose ? el.desglose.map((al) => breakdownCaseHandler(el.ramo, al)) : undefined,
          fecha: { month: el.fechaCancelada.month, year: el.fechaCancelada.year },
        };
        const liquidacion = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            application.id_solicitud,
            fixatedAmount(+el.monto),
            el.ramo,
            el.descripcion || 'Pago ordinario',
            datos,
            moment().month(el.fechaCancelada.month).endOf('month').format('MM-DD-YYYY'),
            (contributorReference && contributorReference.id_registro_municipal) || null,
          ])
        ).rows[0];
        return {
          id: liquidacion.id_liquidacion,
          ramo: el.ramo,
          fecha: datos.fecha,
          monto: liquidacion.monto,
          certificado: liquidacion.certificado,
          recibo: liquidacion.recibo,
          desglose: datos.desglose,
        };
      })
    );

    let state = (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.INGRESARDATOS])).rows[0].state;
    // const solicitud: Solicitud & { registroMunicipal: string } = {
    //   id: application.id_solicitud,
    //   usuario: user,
    //   contribuyente: application.contribuyente,
    //   aprobado: application.aprobado,
    //   fecha: application.fecha,
    //   monto: finingMonths
    //     ?.concat(settlement)
    //     .map((el) => +el.monto)
    //     .reduce((x, j) => x + j, 0) as number,
    //   liquidaciones: settlement,
    //   multas: finingMonths,
    //   registroMunicipal: process.rim,
    // };
    if (!process.esVigente) {
      const costoSolicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [application.id_solicitud])).rows[0].monto_total;
      const pagoSum = process.pagos.map((e) => e.costo).reduce((e, i) => e + i, 0);
      if (pagoSum < costoSolicitud) throw { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
      const creditoPositivo = pagoSum - costoSolicitud;
      await Promise.all(
        process.pagos.map(async (el) => {
          if (!el.costo) throw { status: 403, message: 'Debe incluir el monto a ser pagado' };
          const nearbyHolidays = (await client.query(queries.GET_HOLIDAYS_BASED_ON_PAYMENT_DATE, [el.fecha])).rows;
          const paymentDate = checkIfWeekend(moment(el.fecha));
          if (nearbyHolidays.length > 0) {
            while (nearbyHolidays.find((el) => moment(el.dia).format('YYYY-MM-DD') === paymentDate.format('YYYY-MM-DD'))) paymentDate.add({ days: 1 });
          }
          el.fecha = paymentDate;
          el.concepto = 'IMPUESTO';
          el.user = user.id;
          user.tipoUsuario === 4 ? await insertPaymentReference(el, application.id_solicitud, client) : await insertPaymentCashier(el, application.id_solicitud, client);
          if (el.metodoPago === 'CREDITO_FISCAL') {
            await updateFiscalCredit({ id: application.id_solicitud, user, amount: -el.costo, client });
          }
        })
      );
      if (creditoPositivo > 0) await updateFiscalCredit({ id: application.id_solicitud, user, amount: creditoPositivo, client });

      state = await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
      recibo = await createReceiptForSpecialApplication({ pool: client, user, application: (await client.query(queries.GET_APPLICATION_VIEW_BY_SETTLEMENT, [settlement[0].id])).rows[0] });
      await client.query('UPDATE impuesto.liquidacion SET recibo = $1 WHERE id_solicitud = $2', [recibo, application.id_solicitud]);
    }
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [application.id_contribuyente]);
    await client.query('COMMIT');
    const solicitud = await getApplicationsAndSettlementsById({ id: application.id_solicitud, user });
    solicitud.recibo = recibo;
    await sendNotification(
      user,
      `Se ha completado una solicitud de pago especial para el contribuyente con el documento de identidad: ${solicitud.tipoDocumento}-${solicitud.documento}`,
      'CREATE_APPLICATION',
      'IMPUESTO',
      { ...solicitud, estado: state, nombreCorto: 'SEDEMAT' },
      client
    );
    return { status: 201, message: 'Solicitud de liquidacion especial creada satisfactoriamente', solicitud };
  } catch (error) {
    console.log(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear liquidaciones especiales',
    };
  } finally {
    client.release();
  }
};

export const approveContributorAELicense = async ({ data, client }: { data: any; client: PoolClient }) => {
  try {
    console.log(data);
    const { usuario: user, costo } = (await client.query(queries.GET_PROCEDURE_DATA, [data.idTramite])).rows[0];
    const { usuario, funcionario } = data;
    const { actividadesEconomicas } = funcionario;
    const { contribuyente } = usuario;
    const registry = (
      await client.query(queries.ADD_BRANCH_FOR_CONTRIBUTOR, [
        contribuyente.id,
        funcionario.telefono,
        funcionario.correo,
        funcionario.denominacionComercial,
        funcionario.nombreRepresentante,
        funcionario.capitalSuscrito,
        funcionario.tipoSociedad,
        funcionario.estadoLicencia,
        funcionario.direccion,
      ])
    ).rows[0];
    data.funcionario.referenciaMunicipal = registry.referencia_municipal;
    await Promise.all(
      actividadesEconomicas!.map(async (x) => {
        const settlement = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            null,
            fixatedAmount(0),
            'AE',
            'Pago ordinario',
            { month: moment(x.desde).toDate().toLocaleString('es-ES', { month: 'long' }), year: moment(x.desde).year(), desglose: [{ aforo: x.id }] },
            moment(x.desde).endOf('month').format('MM-DD-YYYY'),
            registry.id_registro_municipal,
          ])
        ).rows[0];
        await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [x.desde, settlement.id_liquidacion]);
        return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [registry.id_registro_municipal, x.codigo, x.desde]);
      })
    );
    const verifiedId = (await client.query('SELECT * FROM impuesto.verificacion_telefono WHERE id_usuario = $1', [user])).rows[0]?.id_verificacion_telefono;
    await client.query('INSERT INTO impuesto.registro_municipal_verificacion VALUES ($1, $2) RETURNING *', [registry.id_registro_municipal, verifiedId]);
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [contribuyente.id]);
    console.log(data);
    return data;
  } catch (error) {
    console.log(error);
    throw error;
  }
};

export const approveContributorBenefits = async ({ data, client }: { data: any; client: PoolClient }) => {
  try {
    const { contribuyente, beneficios, usuario } = data.funcionario;
    const contributorWithBranch = (await client.query(queries.GET_CONTRIBUTOR_WITH_BRANCH, [contribuyente.registroMunicipal])).rows[0];
    const benefittedUser = (await client.query(queries.GET_USER_IN_CHARGE_OF_BRANCH_BY_ID, [contributorWithBranch.id_registro_municipal])).rows[0];
    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [contributorWithBranch.id_contribuyente]);
    // if (!benefittedUser) throw { status: 404, message: 'No existe un usuario encargado de esta sucursal' };
    await Promise.all(
      beneficios.map(async (x) => {
        switch (x.tipoBeneficio) {
          case 'pagoCompleto':
            const applicationFP = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [usuario || benefittedUser?.id, contributorWithBranch.id_contribuyente])).rows[0];
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [applicationFP.id_solicitud, applicationStateEvents.INGRESARDATOS]);
            const benefitFullPayment = (await client.query(queries.CHANGE_SETTLEMENT_TO_NEW_APPLICATION, [applicationFP.id_solicitud, contributorWithBranch.id_registro_municipal, x.idRamo])).rows[0];
            return benefitFullPayment;
          case 'descuento':
            const settlements = (await client.query(queries.GET_SETTLEMENT_IDS_BY_RIM_AND_BRANCH, [contributorWithBranch.id_registro_municipal, x.idRamo])).rows;
            const benefitDiscount = await Promise.all(settlements.map(async (el) => await client.query(queries.INSERT_DISCOUNT_FOR_SETTLEMENT, [el.id_liquidacion, x.porcDescuento])));
            return benefitDiscount;
          case 'remision':
            const benefitRemission = (await client.query(queries.SET_SETTLEMENTS_AS_FORWARDED_BY_RIM, [contributorWithBranch.id_registro_municipal, x.idRamo])).rows[0];
            return benefitRemission;
          case 'convenio':
            const applicationAG = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [usuario || benefittedUser?.id, contributorWithBranch.id_contribuyente])).rows[0];
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.INGRESARDATOS]);
            await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['CONVENIO', applicationAG.id_solicitud]);
            const agreement = (await client.query(queries.CREATE_AGREEMENT, [applicationAG.id_solicitud, x.porciones.length])).rows[0];
            const settlementsAG = (await client.query(queries.CHANGE_SETTLEMENT_TO_NEW_APPLICATION, [applicationAG.id_solicitud, contributorWithBranch.id_registro_municipal, x.idRamo])).rows[0];
            const costo = (await client.query(queries.CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT, [x.idRamo, applicationAG.id_solicitud])).rows.reduce((x, j) => +fixatedAmount(x + j.monto), 0);
            console.log('//if -> costo', costo);
            const totalSolicitud = x.porciones.reduce((x, j) => +fixatedAmount(x + j.monto), 0);
            console.log('//if -> totalSolicitud', totalSolicitud);
            if (costo > totalSolicitud) throw { status: 403, message: 'La suma de las fracciones del convenio debe ser exactamente igual al total de la deuda' };
            const benefitAgreement = await Promise.all(
              x.porciones.map(async (el) => {
                const fraccion = (await client.query(queries.CREATE_AGREEMENT_FRACTION, [agreement.id_convenio, fixatedAmount(+el.monto), el.porcion, el.fechaDePago])).rows[0];
                await client.query(queries.UPDATE_FRACTION_STATE, [fraccion.id_fraccion, applicationStateEvents.INGRESARDATOS]);
              })
            );
            return benefitAgreement;
        }
      })
    );
    return true;
  } catch (error) {
    console.log(error);
    throw error;
  }
};

export const createCertificateForApplication = async ({ settlement, media, user }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    client.query('BEGIN');
    const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_SETTLEMENT, [settlement])).rows[0];
    if (applicationView[media]) return { status: 200, message: 'Certificado generado satisfactoriamente', media: applicationView[media] };
    const dir = await certificateCreationHandler(applicationView.descripcionCortaRamo, media, {
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
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los impuestos',
    };
  } finally {
    client.release();
    gtic.release();
  }
};
const mesesCardinal = {
  enero: 'Primer',
  febrero: 'Segundo',
  marzo: 'Tercer',
  abril: 'Cuarto',
  mayo: 'Quinto',
  junio: 'Sexto',
  julio: 'Séptimo',
  agosto: 'Octavo',
  septiembre: 'Noveno',
  octubre: 'Décimo',
  noviembre: 'Undécimo',
  diciembre: 'Duodécimo',
};
const mesesNumerico = {
  enero: 1,
  febrero: 2,
  marzo: 3,
  abril: 4,
  mayo: 5,
  junio: 6,
  julio: 7,
  agosto: 8,
  septiembre: 9,
  octubre: 10,
  noviembre: 11,
  diciembre: 12,
};
const createSolvencyForApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-solvencia-AE.pug`), {
        moment: require('moment'),
        tramite: 'PAGO DE IMPUESTOS',
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          codigo: application.id,
          contribuyente: application.razonSocial,
          rim: referencia?.referencia_municipal,
          cedulaORif: application.tipoDocumento + '-' + application.documento,
          direccion: application.direccion,
          representanteLegal: referencia?.nombre_representante,
          periodo: mesesCardinal[application.datos.fecha.month],
          anio: application.datos.fecha.year,
          fecha: moment().format('MM-DD-YYYY'),
          fechaLetra: `${moment().date()} de ${application.datos.fecha.month} de ${application.datos.fecha.year}`,
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/solvencia.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/solvencia.pdf`;
      if (dev) {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
          await pool.query(queries.UPDATE_CERTIFICATE_SETTLEMENT, [dir, application.idLiquidacion]);
          res(dir);
        });
      } else {
        try {
          await pool.query(queries.UPDATE_CERTIFICATE_SETTLEMENT, [dir, application.idLiquidacion]);
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/solvencia.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffer,
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            }
          });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createReceiptForSMOrIUApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    console.log('culo');
    let certInfo;
    let motivo;
    let ramo;
    let certInfoArray: any[] = [];
    motivo = application.descripcionSubramo;
    ramo = application.descripcionRamo;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    if (application.idSubramo === 107 || application.idSubramo === 108) {
      const breakdownGas = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, 107])).rows.map((row) => ({ ...row, monto: row.monto / 1.16 }));
      const breakdownAseo: any[] = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, 108])).rows.map((row) => ({ ...row, monto: row.monto / 1.16 }));
      const breakdownJoin = breakdownGas.reduce((prev: any[], next) => {
        let i = prev.findIndex((aseoRow) => aseoRow.datos.fecha.month === next.datos.fecha.month && aseoRow.datos.fecha.year === next.datos.fecha.year);
        if (i > -1) {
          prev[i].monto += next.monto;
        }
        return prev;
      }, breakdownAseo);
      const totalMonto = breakdownJoin.reduce((prev, next) => prev + +next.monto, 0);
      const totalIva = totalMonto * 0.16;

      if (breakdownAseo[0].datos.desglose[0].inmueble === 0) {
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('MM-DD-YYYY'),
          titulo: 'FACTURA POR SERVICIOS MUNICIPALES',
          institucion: 'SEDEMAT',
          datos: {
            nroSolicitud: application.id,
            nroPlanilla: 10010111,
            motivo: motivo,
            nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
            tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
            tipoInmueble: 'NO DISPONIBLE',
            fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
            propietario: {
              rif: `${application.tipoDocumento}-${application.documento}`,
              denomComercial: application.denominacionComercial,
              direccion: application.direccion,
              razonSocial: application.razonSocial,
            },
            items: breakdownJoin.map((row) => {
              return {
                direccion: 'No disponible',
                periodos: `${row.datos.fecha.month} ${row.datos.fecha.year}`.toUpperCase(),
                impuesto: formatCurrency(row.monto),
              };
            }),
            totalIva: `${formatCurrency(totalIva)} Bs.S`,
            totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
            totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
            montoTotalImpuesto: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
            interesesMoratorio: '0.00 Bs.S', // TODO: Intereses moratorios
            estatus: 'PAGADO',
            observacion: 'Pago por Servicios Municipales',
            totalLiq: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
            totalRecaudado: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
            totalCred: `0.00 Bs.S`, // TODO: Credito fiscal
          },
        };

        certInfoArray.push({ ...certInfo });
      } else {
        console.log(breakdownJoin[0].datos.desglose);
        let inmueblesContribuyente: any[] = await Promise.all(
          breakdownJoin[0].datos.desglose.map((row) => {
            return pool.query(queries.GET_SUT_ESTATE_BY_ID, [row.inmueble]);
          })
        );
        inmueblesContribuyente = inmueblesContribuyente.map((result) => result.rows[0]);
        console.log('BREAKDOWN JOIN', breakdownJoin);
        console.log(inmueblesContribuyente);
        for (let el of inmueblesContribuyente) {
          certInfo = {
            QR: linkQr,
            moment: require('moment'),
            fecha: moment().format('MM-DD-YYYY'),
            titulo: 'FACTURA POR SERVICIOS MUNICIPALES',
            institucion: 'SEDEMAT',
            datos: {
              nroSolicitud: application.id,
              nroPlanilla: 10010111,
              motivo: motivo,
              nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
              tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
              tipoInmueble: el?.tipo_inmueble || 'NO DISPONIBLE',
              fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
              fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
              fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
              propietario: {
                rif: `${application.tipoDocumento}-${application.documento}`,
                denomComercial: application.denominacionComercial,
                direccion: application.direccion,
                razonSocial: application.razonSocial,
              },
              items: breakdownJoin.map((row) => {
                return {
                  direccion: el?.direccion || 'No disponible',
                  periodos: `${row.datos.fecha.month} ${row.datos.fecha.year}`.toUpperCase(),
                  impuesto: formatCurrency(row.monto),
                };
              }),
              totalIva: `${formatCurrency(totalIva)} Bs.S`,
              totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
              totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
              montoTotalImpuesto: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
              interesesMoratorio: '0.00 Bs.S', // TODO: Intereses moratorios
              estatus: 'PAGADO',
              observacion: 'Pago por Servicios Municipales',
              totalLiq: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
              totalRecaudado: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
              totalCred: `0.00 Bs.S`, // TODO: Credito fiscal
            },
          };
          certInfoArray.push({ ...certInfo });
        }
      }
    } else if (application.idSubramo === 238) {
      const breakdownData: any[] = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, 238])).rows.map((row) => ({ ...row, monto: row.monto / 1.16 }));

      const totalMonto = breakdownData.reduce((prev, next) => prev + +next.monto, 0);
      const totalIva = totalMonto * 0.16;
      certInfo = {
        QR: linkQr,
        moment: require('moment'),
        fecha: moment().format('MM-DD-YYYY'),
        titulo: 'FACTURA POR SERVICIOS MUNICIPALES',
        institucion: 'SEDEMAT',
        datos: {
          nroSolicitud: application.id,
          nroPlanilla: 10010111,
          motivo: motivo,
          nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
          tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
          tipoInmueble: 'NO DISPONIBLE',
          fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
          fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
          fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
          propietario: {
            rif: `${application.tipoDocumento}-${application.documento}`,
            denomComercial: application.denominacionComercial,
            direccion: application.direccion,
            razonSocial: application.razonSocial,
          },
          items: breakdownData.map((row) => {
            return {
              direccion: 'No disponible',
              periodos: `${row.datos.fecha.month} ${row.datos.fecha.year}`.toUpperCase(),
              impuesto: formatCurrency(row.monto),
            };
          }),
          totalIva: `${formatCurrency(totalIva)} Bs.S`,
          totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
          totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
          montoTotalImpuesto: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
          interesesMoratorio: '0.00 Bs.S', // TODO: Intereses moratorios
          estatus: 'PAGADO',
          observacion: 'Pago por Servicios Municipales',
          totalLiq: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
          totalRecaudado: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
          totalCred: `0.00 Bs.S`, // TODO: Credito fiscal
        },
      };

      certInfoArray.push({ ...certInfo });
    }
    // const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;
    // let inmueblesContribuyente: any[] = await Promise.all(
    //   breakdownData[0].datos.desglose.map((row) => {
    //     return pool.query(queries.GET_SUT_ESTATE_BY_ID, [row.inmueble]);
    //   })
    // );
    // inmueblesContribuyente = inmueblesContribuyente.map((result) => result.rows[0]);

    // console.log('appli', application);
    // if (application.descripcionCortaRamo === 'SM') {
    //   motivo = application.descripcionSubramo;
    //   ramo = application.descripcionRamo;
    //   const totalIva =
    //     +breakdownData
    //       .map((row) => {
    //         return row.datos.desglose.reduce((prev, next) => {
    //           return prev + (next.montoGas ? next.montoAseo + +next.montoGas : +next.montoAseo);
    //         }, 0);
    //       })
    //       .reduce((prev, next) => prev + next, 0) * 0.16;

    //   const totalMonto = +breakdownData
    //     .map((row) => {
    //       return row.datos.desglose.reduce((prev, next) => {
    //         return prev + (next.montoGas ? next.montoAseo + +next.montoGas : +next.montoAseo);
    //       }, 0);
    //     })
    //     .reduce((prev, next) => prev + next, 0);
    //   for (const el of inmueblesContribuyente) {
    //     console.log('AAAAAAAAAAAAAAAAAAA');
    //     certInfo = {
    //       QR: linkQr,
    //       moment: require('moment'),
    //       fecha: moment().format('MM-DD-YYYY'),
    //       titulo: 'FACTURA POR SERVICIOS MUNICIPALES',
    //       institucion: 'SEDEMAT',
    //       datos: {
    //         nroSolicitud: application.id,
    //         nroPlanilla: 10010111,
    //         motivo: motivo,
    //         nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
    //         tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
    //         tipoInmueble: el.tipo_inmueble,
    //         fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
    //         fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
    //         fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
    //         propietario: {
    //           rif: `${application.tipoDocumento}-${application.documento}`,
    //           denomComercial: application.denominacionComercial,
    //           direccion: application.direccion,
    //           razonSocial: application.razonSocial,
    //         },
    //         items: breakdownData
    //           .map((row) => {
    //             console.log(el, row);
    //             return {
    //               desglose: row.datos.desglose.find((desglose) => desglose.inmueble === +el.id_inmueble),
    //               fecha: row.datos.fecha,
    //             };
    //           })
    //           .map((row) => {
    //             return {
    //               direccion: el.direccion,
    //               periodos: `${row.fecha.month} ${row.fecha.year}`.toUpperCase(),
    //               impuesto: row.desglose.montoGas ? formatCurrency(+row.desglose.montoGas + +row.desglose.montoAseo) : formatCurrency(row.desglose.montoAseo),
    //             };
    //           }),
    //         totalIva: `${formatCurrency(totalIva)} Bs.S`,
    //         totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
    //         totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
    //         montoTotalImpuesto: `${formatCurrency(
    //           +breakdownData
    //             .map((row) => {
    //               return {
    //                 desglose: row.datos.desglose.find((desglose) => desglose.inmueble === +el.id_inmueble),
    //                 fecha: row.datos.fecha,
    //               };
    //             })
    //             .map((row) => (row.desglose.montoGas ? +row.desglose.montoAseo + +row.desglose.montoGas : +row.desglose.montoAseo))
    //             .reduce((prev, next) => prev + next, 0) + totalIva
    //         )} Bs.S`,
    //         interesesMoratorio: '0.00 Bs.S', // TODO: Intereses moratorios
    //         estatus: 'PAGADO',
    //         observacion: 'Pago por Servicios Municipales',
    //         totalLiq: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
    //         totalRecaudado: `${formatCurrency(totalMonto + totalIva)} Bs.S`,
    //         totalCred: `0.00 Bs.S`, // TODO: Credito fiscal
    //       },
    //     };

    //     certInfoArray.push({ ...certInfo });
    //   }
    // }

    return new Promise(async (res, rej) => {
      try {
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-SM.pug`), certInfo));
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`;
        const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });

        let buffersArray: any[] = await Promise.all(
          htmlArray.map((html) => {
            return new Promise((res, rej) => {
              pdf
                .create(html, {
                  format: 'Letter',
                  border: '5mm',
                  header: { height: '0px' },
                  base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
                })
                .toBuffer((err, buffer) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(buffer);
                  }
                });
            });
          })
        );

        if (dev) {
          mkdir(dirname(pdfDir), { recursive: true }, (e) => {
            if (e) {
              rej(e);
            } else {
              if (buffersArray.length === 1) {
                writeFile(pdfDir, buffersArray[0], async (err) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(dir);
                  }
                });
              } else {
                let letter = 'A';
                let reduced: any = buffersArray.reduce((prev: any, next) => {
                  prev[letter] = next;
                  let codePoint = letter.codePointAt(0);
                  if (codePoint !== undefined) {
                    letter = String.fromCodePoint(++codePoint);
                  }
                  return prev;
                }, {});

                pdftk
                  .input(reduced)
                  .cat(`${Object.keys(reduced).join(' ')}`)
                  .output(pdfDir)
                  .then((buffer) => {
                    res(pdfDir);
                  })
                  .catch((e) => {
                    console.log(e);
                    rej(e);
                  });
              }
            }
          });
        } else {
          try {
            if (buffersArray.length === 1) {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffersArray[0],
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            } else {
              let letter = 'A';
              let reduced: any = buffersArray.reduce((prev: any, next) => {
                prev[letter] = next;
                let codePoint = letter.codePointAt(0);
                if (codePoint !== undefined) {
                  letter = String.fromCodePoint(++codePoint);
                }
                return prev;
              }, {});

              pdftk
                .input(reduced)
                .cat(`${Object.keys(reduced).join(' ')}`)
                .output()
                .then(async (buffer) => {
                  const bucketParams = {
                    Bucket: 'sut-maracaibo',
                    Key: `/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                })
                .catch((e) => {
                  console.log(e);
                  rej(e);
                });
            }
          } catch (e) {
            throw e;
          } finally {
          }
        }
      } catch (e) {
        throw {
          message: 'Error en generacion de certificado de SM',
          e: errorMessageExtractor(e),
        };
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createReceiptForIUApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    console.log('culo');
    let certInfo;
    let motivo;
    let ramo;
    let certInfoArray: any[] = [];
    motivo = application.descripcionSubramo;
    ramo = application.descripcionRamo;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    if (application.idSubramo === 9) {
      const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
      let breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, 9])).rows;
      breakdownData = breakdownData.sort((a, b) => {
        if (mesesNumerico[a.datos.fecha.mes] > mesesNumerico[b.datos.fecha.month]) return -1;
        else if (mesesNumerico[a.datos.fecha.mes] < mesesNumerico[b.datos.fecha.month]) return 1;
        else return 0;
      });
      for (let inm of breakdownData[breakdownData.length - 1].datos.desglose) {
        const inmueble = await pool.query(queries.GET_ESTATE_BY_ID, [inm.inmueble]);
        const avaluo = await pool.query(queries.GET_CURRENT_APPRAISALS_BY_ID, [inm.inmueble]);
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('MM-DD-YYYY'),
          titulo: 'CERTIFICADO POR PROPIEDAD INMOBILIARIA',
          institucion: 'SEDEMAT',
          datos: {
            mes: moment(breakdownData[0].fecha_liquidacion).get('month') + 1,
            anio: moment(breakdownData[0].fecha_liquidacion).get('year'),
            contribuyente: application.razonSocial,
            cedulaORif: `${application.tipoDocumento}-${application.documento}`,
            direccion: inmueble.rows[0]?.direccion,
            parroquia: inmueble?.rows[0]?.nombre,
            rim: referencia?.referencia_municipal || null, //Si no posee no me la envies o la envias null
            valorFiscal: avaluo?.rows[0]?.avaluo || null,
            periodo: mesesCardinal[breakdownData[breakdownData.length - 1].datos.fecha.month], //el mes
            fechaLetra: `${moment(breakdownData[0].fecha_liquidacion).get('date')} de ${breakdownData[breakdownData.length - 1].datos.fecha.month} del ${breakdownData[breakdownData.length - 1].datos.fecha.year}.`,
          },
        };
        certInfoArray.push({ ...certInfo });
      }
    }

    return new Promise(async (res, rej) => {
      try {
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-solvencia-IU.pug`), certInfo));
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/IU/${application.idLiquidacion}/certificado.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/IU/${application.idLiquidacion}/certificado.pdf`;
        const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });

        let buffersArray: any[] = await Promise.all(
          htmlArray.map((html) => {
            return new Promise((res, rej) => {
              pdf
                .create(html, {
                  format: 'Letter',
                  border: '5mm',
                  header: { height: '0px' },
                  base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
                })
                .toBuffer((err, buffer) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(buffer);
                  }
                });
            });
          })
        );

        if (dev) {
          mkdir(dirname(pdfDir), { recursive: true }, (e) => {
            if (e) {
              rej(e);
            } else {
              if (buffersArray.length === 1) {
                writeFile(pdfDir, buffersArray[0], async (err) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(dir);
                  }
                });
              } else {
                let letter = 'A';
                let reduced: any = buffersArray.reduce((prev: any, next) => {
                  prev[letter] = next;
                  let codePoint = letter.codePointAt(0);
                  if (codePoint !== undefined) {
                    letter = String.fromCodePoint(++codePoint);
                  }
                  return prev;
                }, {});

                pdftk
                  .input(reduced)
                  .cat(`${Object.keys(reduced).join(' ')}`)
                  .output(pdfDir)
                  .then((buffer) => {
                    res(pdfDir);
                  })
                  .catch((e) => {
                    console.log(e);
                    rej(e);
                  });
              }
            }
          });
        } else {
          try {
            if (buffersArray.length === 1) {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/IU/${application.idLiquidacion}/certificado.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffersArray[0],
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            } else {
              let letter = 'A';
              let reduced: any = buffersArray.reduce((prev: any, next) => {
                prev[letter] = next;
                let codePoint = letter.codePointAt(0);
                if (codePoint !== undefined) {
                  letter = String.fromCodePoint(++codePoint);
                }
                return prev;
              }, {});

              pdftk
                .input(reduced)
                .cat(`${Object.keys(reduced).join(' ')}`)
                .output()
                .then(async (buffer) => {
                  const bucketParams = {
                    Bucket: 'sut-maracaibo',
                    Key: `/sedemat/${application.id}/IU/${application.idLiquidacion}/certificado.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                })
                .catch((e) => {
                  console.log(e);
                  rej(e);
                });
            }
          } catch (e) {
            throw e;
          } finally {
          }
        }
      } catch (e) {
        throw {
          message: 'Error en generacion de certificado de IU',
          e: errorMessageExtractor(e),
        };
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createReceiptForSpecialApplication = async ({ pool, user, application }) => {
  try {
    const breakdownData = (
      await pool.query(
        `SELECT l.datos, l.monto, l.fecha_liquidacion, l.fecha_vencimiento, r.descripcion, r.codigo FROM impuesto.ramo r INNER JOIN impuesto.subramo USING (id_ramo) INNER JOIN impuesto.liquidacion l USING (id_subramo) INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud WHERE l.id_solicitud = $1 AND l.id_subramo = $2;`,
        [application.id, application.idSubramo]
      )
    ).rows;
    const UTMM = (await pool.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const impuestoRecibo = UTMM * 2;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    const payment = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID_DEST, [application.id, 'IMPUESTO'])).rows;

    moment.locale('es');
    let certInfoArray: any[] = [];
    let certAE;
    for (const el of breakdownData) {
      certAE = {
        fecha: moment().format('YYYY-MM-DD'),
        tramite: 'LIQUIDACIONES ESPECIALES',
        institucion: 'SEDEMAT',
        moment: require('moment'),
        QR: linkQr,
        datos: {
          nroSolicitud: application.id,
          nroPlanilla: new Date().getTime().toString().slice(7),
          motivo: `D${el.datos.fecha.month.substr(0, 3).toUpperCase()}${el.datos.fecha.year}`,
          porcion: '1/1',
          categoria: application.descripcionRamo,
          rif: `${application.tipoDocumento}-${application.documento}`,
          ref: referencia?.referencia_municipal || 'No posee RIM',
          razonSocial: application.razonSocial,
          direccion: application.direccion || 'Dirección Sin Asignar',
          fechaCre: moment(application.fechaCreacion).format('YYYY-MM-DD'),
          fechaLiq: moment().format('YYYY-MM-DD'),
          fechaVenc: moment().date(31).format('YYYY-MM-DD'),
          items: [
            {
              codigo: el.codigo,
              descripcion: el.descripcion,
              impuesto: el.monto,
            },
          ],
          metodoPago: payment.map((row) => {
            return {
              monto: row.monto,
              formaPago: row.metodo_pago,
              banco: row.nombre,
              fecha: row.fecha_de_pago,
              nro: row.referencia,
            };
          }),
          tramitesInternos: 0.0,
          totalTasaRev: 0.0,
          anticipoYRetenciones: 0.0,
          interesMora: 0.0,
          montoTotal: 0.0,
          observacion: 'Pago por Concepto(s) de ' + el.descripcion,
          estatus: 'PAGADO',
          totalLiq: application.montoLiquidacion,
          totalRecaudado: application.montoLiquidacion,
          totalCred: 0.0,
        },
      };
      certAE.totalImpuestoDet = certAE.datos.items.reduce((prev, next) => prev + +next.impuesto, 0);

      certInfoArray.push(certAE);
    }

    return new Promise(async (res, rej) => {
      try {
        console.log('AAAAAAAA');
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-LE.pug`), certInfo));
        console.log(htmlArray.length);
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/special/${application.idLiquidacion}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/special/${application.idLiquidacion}/recibo.pdf`;
        const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });

        let buffersArray: any[] = await Promise.all(
          htmlArray.map((html) => {
            return new Promise((res, rej) => {
              pdf
                .create(html, {
                  format: 'Letter',
                  border: '5mm',
                  header: { height: '0px' },
                  base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
                })
                .toBuffer((err, buffer) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(buffer);
                  }
                });
            });
          })
        );
        console.log(buffersArray);

        if (dev) {
          mkdir(dirname(pdfDir), { recursive: true }, (e) => {
            if (e) {
              rej(e);
            } else {
              if (buffersArray.length === 1) {
                writeFile(pdfDir, buffersArray[0], async (err) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(dir);
                  }
                });
              } else {
                let letter = 'A';
                let reduced: any = buffersArray.reduce((prev: any, next) => {
                  prev[letter] = next;
                  let codePoint = letter.codePointAt(0);
                  if (codePoint !== undefined) {
                    letter = String.fromCodePoint(++codePoint);
                  }
                  return prev;
                }, {});

                pdftk
                  .input(reduced)
                  .cat(`${Object.keys(reduced).join(' ')}`)
                  .output(pdfDir)
                  .then((buffer) => {
                    console.log('a', buffer);
                    res(dir);
                  })
                  .catch((e) => {
                    console.log(e);
                    rej(e);
                  });
              }
            }
          });
        } else {
          try {
            if (buffersArray.length === 1) {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/special/${application.idLiquidacion}/recibo.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffersArray[0],
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            } else {
              let letter = 'A';
              let reduced: any = buffersArray.reduce((prev: any, next) => {
                prev[letter] = next;
                let codePoint = letter.codePointAt(0);
                if (codePoint !== undefined) {
                  letter = String.fromCodePoint(++codePoint);
                }
                return prev;
              }, {});

              pdftk
                .input(reduced)
                .cat(`${Object.keys(reduced).join(' ')}`)
                .output()
                .then(async (buffer) => {
                  const bucketParams = {
                    Bucket: 'sut-maracaibo',
                    Key: `/sedemat/${application.id}/special/${application.idLiquidacion}/recibo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                })
                .catch((e) => {
                  console.log(e);
                  rej(e);
                });
            }
          } catch (e) {
            rej(e);
          } finally {
          }
        }
      } catch (e) {
        rej({
          message: 'Error en generacion de certificado de liquidaciones especiales',
          e: errorMessageExtractor(e),
        });
      }
    });

    // return new Promise(async (res, rej) => {

    //   // const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-AE.pug`), certAE);
    //   // const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
    //   // const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
    //   // const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    //   // if (dev) {
    //   //   pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
    //   //     await pool.query(queries.UPDATE_RECEIPT_FOR_SETTLEMENTS, [dir, application.idProcedimiento, application.id]);
    //   //     res(dir);
    //   //   });
    //   // } else {
    //   //   try {
    //   //     pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
    //   //       if (err) {
    //   //         rej(err);
    //   //       } else {
    //   //         const bucketParams = {
    //   //           Bucket: 'sut-maracaibo',
    //   //           Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`,
    //   //         };
    //   //         await S3Client.putObject({
    //   //           ...bucketParams,
    //   //           Body: buffer,
    //   //           ACL: 'public-read',
    //   //           ContentType: 'application/pdf',
    //   //         }).promise();
    //   //         res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
    //   //       }
    //   //     });
    //   //   } catch (e) {
    //   //     throw e;
    //   //   } finally {
    //   //   }
    //   // }
    // });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createReceiptForAEApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;

    const UTMM = (await pool.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const impuestoRecibo = UTMM * 2;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    const economicActivities = (await pool.query(queries.GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR, [referencia.id_registro_municipal])).rows;
    moment.locale('es');
    let certInfoArray: any[] = [];
    let certAE;
    for (const el of breakdownData) {
      console.log('el', el, el.datos);
      certAE = {
        fecha: moment().format('YYYY-MM-DD'),
        tramite: 'PAGO DE IMPUESTOS',
        moment: require('moment'),
        QR: linkQr,
        datos: {
          nroSolicitud: application.id,
          nroPlanilla: new Date().getTime().toString().slice(7),
          motivo: `D${el.datos.fecha.month.substr(0, 3).toUpperCase()}${el.datos.fecha.year}`,
          porcion: '1/1',
          categoria: application.descripcionRamo,
          rif: `${application.tipoDocumento}-${application.documento}`,
          ref: referencia.referencia_municipal,
          razonSocial: application.razonSocial,
          direccion: application.direccion || 'Dirección Sin Asignar',
          fechaCre: moment(application.fechaCreacion).format('YYYY-MM-DD'),
          fechaLiq: moment().format('YYYY-MM-DD'),
          fechaVenc: moment().date(31).format('YYYY-MM-DD'),
          items: economicActivities.map((row) => {
            console.log('row', row);
            let desglose = el.datos.desglose ? el.datos.desglose.find((d) => d.aforo === row.id) : { montoDeclarado: 0 };
            desglose = desglose ? desglose : { montoDeclarado: 0 };
            return {
              codigo: row.numeroReferencia,
              descripcion: row.descripcion,
              montoDeclarado: desglose.montoDeclarado,
              montoRebajado: el.datos?.montoRebajado || 0,
              alicuota: row.alicuota / 100,
              minTrib: row.minimoTributable,
              impuesto: desglose.montoCobrado || 0,
            };
          }),

          tramitesInternos: impuestoRecibo,
          totalTasaRev: 0.0,
          anticipoYRetenciones: 0.0,
          interesMora: 0.0,
          montoTotal: +application.montoLiquidacion + impuestoRecibo,
          observacion: 'Pago por Impuesto de Actividad Economica - VIA WEB',
          estatus: 'PAGADO',
          totalLiq: +application.montoLiquidacion + impuestoRecibo,
          totalRecaudado: +application.montoLiquidacion + impuestoRecibo,
          totalCred: 0.0,
        },
      };
      certAE.totalImpuestoDet = certAE.datos.items.reduce((prev, next) => prev + +next.impuesto, 0);

      certInfoArray.push(certAE);
    }

    return new Promise(async (res, rej) => {
      try {
        console.log('AAAAAAAA');
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-AE.pug`), certInfo));
        console.log(htmlArray.length);
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
        const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });
        console.log(pdfDir);
        console.log(dir);
        let buffersArray: any[] = await Promise.all(
          htmlArray.map((html) => {
            return new Promise((res, rej) => {
              pdf
                .create(html, {
                  format: 'Letter',
                  border: '5mm',
                  header: { height: '0px' },
                  base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
                })
                .toBuffer((err, buffer) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(buffer);
                  }
                });
            });
          })
        );
        console.log(buffersArray);

        if (dev) {
          mkdir(dirname(pdfDir), { recursive: true }, (e) => {
            if (e) {
              rej(e);
            } else {
              if (buffersArray.length === 1) {
                writeFile(pdfDir, buffersArray[0], async (err) => {
                  if (err) {
                    rej(err);
                  } else {
                    res(dir);
                  }
                });
              } else {
                let letter = 'A';
                let reduced: any = buffersArray.reduce((prev: any, next) => {
                  prev[letter] = next;
                  let codePoint = letter.codePointAt(0);
                  if (codePoint !== undefined) {
                    letter = String.fromCodePoint(++codePoint);
                  }
                  return prev;
                }, {});

                pdftk
                  .input(reduced)
                  .cat(`${Object.keys(reduced).join(' ')}`)
                  .output(pdfDir)
                  .then((buffer) => {
                    console.log('a', buffer);
                    res(dir);
                  })
                  .catch((e) => {
                    console.log(e);
                    rej(e);
                  });
              }
            }
          });
        } else {
          try {
            if (buffersArray.length === 1) {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffersArray[0],
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            } else {
              let letter = 'A';
              let reduced: any = buffersArray.reduce((prev: any, next) => {
                prev[letter] = next;
                let codePoint = letter.codePointAt(0);
                if (codePoint !== undefined) {
                  letter = String.fromCodePoint(++codePoint);
                }
                return prev;
              }, {});

              pdftk
                .input(reduced)
                .cat(`${Object.keys(reduced).join(' ')}`)
                .output()
                .then(async (buffer) => {
                  const bucketParams = {
                    Bucket: 'sut-maracaibo',
                    Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                })
                .catch((e) => {
                  console.log(e);
                  rej(e);
                });
            }
          } catch (e) {
            rej(e);
          } finally {
          }
        }
      } catch (e) {
        rej({
          message: 'Error en generacion de certificado de AE',
          e: errorMessageExtractor(e),
        });
      }
    });

    // return new Promise(async (res, rej) => {

    //   // const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-AE.pug`), certAE);
    //   // const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
    //   // const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
    //   // const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    //   // if (dev) {
    //   //   pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
    //   //     await pool.query(queries.UPDATE_RECEIPT_FOR_SETTLEMENTS, [dir, application.idProcedimiento, application.id]);
    //   //     res(dir);
    //   //   });
    //   // } else {
    //   //   try {
    //   //     pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
    //   //       if (err) {
    //   //         rej(err);
    //   //       } else {
    //   //         const bucketParams = {
    //   //           Bucket: 'sut-maracaibo',
    //   //           Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`,
    //   //         };
    //   //         await S3Client.putObject({
    //   //           ...bucketParams,
    //   //           Body: buffer,
    //   //           ACL: 'public-read',
    //   //           ContentType: 'application/pdf',
    //   //         }).promise();
    //   //         res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
    //   //       }
    //   //     });
    //   //   } catch (e) {
    //   //     throw e;
    //   //   } finally {
    //   //   }
    //   // }
    // });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};
const createReceiptForPPApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical ? [application.documento, application.rim, application.nacionalidad] : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    let motivo = (await gticPool.query(queries.gtic.GET_MOTIVE_BY_TYPE_ID, [idTiposSolicitud.PP])).rows[0];
    let ramo = (await gticPool.query(queries.gtic.GET_BRANCH_BY_TYPE_ID, [idTiposSolicitud.PP])).rows[0];
    const subarticulos = (await gticPool.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id])).rows;
    const totalIva = +breakdownData.map((row) => row.monto).reduce((prev, next) => +prev + +next, 0) * 0.16;
    const totalMonto = +breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0);
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-PP.pug`), {
        QR: linkQr,
        moment: require('moment'),
        fecha: moment().format('MM-DD-YYYY'),

        datos: {
          nroSolicitud: 856535, //TODO: Reemplazar con el valor de co_solicitud creado en GTIC
          nroPlanilla: 10010111, //TODO: Ver donde se guarda esto
          motivo: motivo.tx_motivo,
          nroFactura: `${application.anio}-${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
          tipoTramite: `${ramo.nb_ramo} - ${ramo.tx_ramo}`,
          fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
          fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
          fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
          propietario: {
            rif: `${application.nacionalidad}-${application.documento}`,
            denomComercial: datosContribuyente.tx_denom_comercial,
            razonSocial: isJuridical ? datosContribuyente.tx_razon_social : datosContribuyente.nb_contribuyente.trim() + datosContribuyente.ap_contribuyente.trim(),
          },
          items: breakdownData.map((row) => {
            return {
              articulo: subarticulos.find((el) => +el.co_medio === row.id_subarticulo).tx_medio,
              periodos: `${row.mes} ${row.anio}`.toUpperCase(),
              impuesto: formatCurrency(row.monto),
            };
          }),
          totalIva: `${formatCurrency(totalIva)} Bs.S`,
          totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
          totalIvaPagar: `${formatCurrency(
            totalIva //TODO: Retencion
          )} Bs.S`,
          montoTotalImpuesto: `${formatCurrency(+breakdownData.map((row) => row.monto).reduce((prev, next) => +prev + +next, 0) + +totalIva)} Bs.S`,
          interesesMoratorio: '0.00 Bs.S', // TODO: Intereses moratorios
          estatus: 'PAGADO',
          observacion: 'Pago por Publicidad y Propaganda',
          totalLiq: `${formatCurrency(+totalMonto + +totalIva)} Bs.S`,
          totalRecaudado: `${formatCurrency(+totalMonto + +totalIva)} Bs.S`,
          totalCred: `0.00 Bs.S`, // TODO: Credito fiscal
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/PP/${application.idLiquidacion}/recibo.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/PP/${application.idLiquidacion}/recibo.pdf`;
      if (dev) {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
          res(dir);
        });
      } else {
        try {
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/PP/${application.idLiquidacion}/recibo.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffer,
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            }
          });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createPatentDocument = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;
    const economicActivities = (await pool.query(queries.GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR, [referencia?.referencia_municipal])).rows;

    const payment = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID, [application.id, 'TRAMITE'])).rows;
    const cashier = (await pool.query(queries.GET_USER_INFO_BY_ID, [payment[0].id_usuario])).rows;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-LAE.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          contribuyente: {
            razonSocial: application.razonSocial,
            denomComercial: application.denomComercial,
            rif: `${application.tipoDocumento}-${application.documento}`,
            rim: referencia?.referencia_municipal,
            direccion: application.direccion,
          },
          nroSolicitud: application.id,
          nroPlanilla: 112,
          motivo: application.descripcionSubramo,
          usuario: user.nombreCompleto,
          cajero: cashier[0]?.nombreCompleto,
          fechaLiq: breakdownData[0].fecha_liquidacion,
          fechaVenc: breakdownData[0].fecha_vencimiento,
          capitalSubs: '',
          fechaReg: application.fechaCreacion,
          fechaInsc: application.fechaCreacion,
          tipoSoc: '',
          fechaSolt: application.fechaCreacion,
          tipoDocumento: application.tipoDocumento,
          nroReg: 0,
          actividades: economicActivities.map((row) => {
            return {
              codigo: row.numeroReferencia,
              descripcion: row.descripcion,
              alicuota: row.alicuota,
              periodo: application.datos.fecha.year,
              fechaIni: application.fechaCreacion,
            };
          }),
          metodoPago: payment.map((row) => {
            return {
              monto: row.monto,
              formaPago: row.metodo_pago,
              banco: row.nombre,
              fecha: row.fecha_de_pago,
              nro: row.referencia,
            };
          }),
          totalLiq: 1000000,
          totalRecaudado: payment.reduce((prev, next) => prev + next.monto, 0),
          totalCred: '',
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/patente.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/patente.pdf`;
      if (dev) {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
          res(dir);
        });
      } else {
        try {
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/AE/${application.idLiquidacion}/patente.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffer,
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            }
          });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

const createFineDocument = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-MULTAS.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          razonSocial: application.razonSocial,
          tipoDocumento: application.tipoDocumento,
          documentoIden: application.documento,
          rim: referencia?.referencia_municipal,
          direccion: application.direccion || 'Sin Asignar',
          telefono: referencia.telefono_celular,
          email: referencia.email,
          items: breakdownData.map((row) => {
            return {
              fecha: `${row.datos.fecha.month.toUpperCase()} ${row.datos.fecha.year}`,
              descripcion: row.datos.descripcion,
              monto: row.monto,
            };
          }),
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/MUL/${application.idLiquidacion}/mult.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/MUL/${application.idLiquidacion}/mult.pdf`;
      if (dev) {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
          res(dir);
        });
      } else {
        try {
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const bucketParams = {
                Bucket: 'sut-maracaibo',
                Key: `/sedemat/${application.id}/MUL/${application.idLiquidacion}/solvencia.pdf`,
              };
              await S3Client.putObject({
                ...bucketParams,
                Body: buffer,
                ACL: 'public-read',
                ContentType: 'application/pdf',
              }).promise();
              res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            }
          });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

export const createAccountStatement = async ({ contributor, reference, typeUser }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const paymentState = switchcase({ ingresardatos: 'VIGENTE', validando: 'VIGENTE', finalizado: 'PAGADO' })(null);
    const contribuyente = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [contributor])).rows[0];
    const branch = reference && (await client.query('SELECT r.* FROM impuesto.registro_municipal r WHERE referencia_municipal = $1', [reference])).rows[0];
    const contributorQuery = typeUser === 'JURIDICO' ? queries.GET_SETTLEMENTS_FOR_CODE_AND_RIM_OPTIMIZED : queries.GET_SETTLEMENTS_FOR_CODE_AND_CONTRIBUTOR;
    const contributorPayload = typeUser === 'JURIDICO' ? branch.referencia_municipal : contribuyente.id_contribuyente;
    const economicActivities =
      (reference &&
        (
          await client.query(
            'SELECT id_actividad_economica AS id, ae.numero_referencia AS "numeroReferencia", descripcion as "nombreActividad", alicuota, minimo_tributable AS "minimoTributable" FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_sucursal aec ON ae.numero_referencia = aec.numero_referencia WHERE aec.id_registro_municipal = $1',
            [branch.id_registro_municipal]
          )
        ).rows) ||
      [];
    const ae =
      (economicActivities.length > 0 &&
        (await client.query(contributorQuery, [codigosRamo.AE, contributorPayload])).rows.map((el) => {
          // const activity = economicActivities.find((x) => x.numeroReferencia.endsWith(el.id_aforo));
          return {
            planilla: new Date().getTime().toString().substr(6),
            solicitud: el.id,
            porcion: '1/1',
            fechaLiquidacion: moment(el.fecha_liquidacion).format('DD/MM/YYYY'),
            fechaVencimiento: moment(el.fecha_vencimiento).format('DD/MM/YYYY'),
            motivo: el.descripcion_corta,
            estado: paymentState(el.state),
            montoPorcion: parseFloat(el.monto),
            // montoPorcion: activity && parseInt(activity.nu_ut) * UTMM > parseFloat(el.monto_declarado) ? parseInt(activity.nu_ut) * UTMM : parseFloat(el.monto_declarado),
          };
        })) ||
      [];
    const sm = (await client.query(contributorQuery, [codigosRamo.SM, contributorPayload])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fecha_liquidacion).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fecha_vencimiento).format('DD/MM/YYYY'),
        motivo: el.descripcion_corta,
        estado: paymentState(el.state),
        montoPorcion: parseFloat(el.monto),
        // montoPorcion: +el.monto_gas + +el.monto_aseo,
      };
    });
    const iu = (await client.query(contributorQuery, [codigosRamo.IU, contributorPayload])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fecha_liquidacion).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fecha_vencimiento).format('DD/MM/YYYY'),
        motivo: el.descripcion_corta,
        estado: paymentState(el.state),
        montoPorcion: parseFloat(el.monto),
      };
    });
    const pp = (await client.query(contributorQuery, [codigosRamo.PP, contributorPayload])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fecha_liquidacion).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fecha_vencimiento).format('DD/MM/YYYY'),
        motivo: el.descripcion_corta,
        estado: paymentState(el.state),
        montoPorcion: parseFloat(el.monto),
      };
    });
    const datosContribuyente = {
      nombreORazon: contribuyente.razon_social,
      cedulaORif: `${contribuyente.tipo_documento}-${contribuyente.documento}`,
      rim: branch.referencia_municipal || null,
      direccion: contribuyente.direccion,
      telefono: branch.telefono_celular || '',
    };
    const statement = ae
      .concat(sm)
      .concat(iu)
      .concat(pp)
      .filter((el) => el)
      .sort((a, b) => (a.fechaLiquidacion === b.fechaLiquidacion ? 0 : a.fechaLiquidacion > b.fechaLiquidacion ? 1 : -1));
    const saldoFinal = statement.map((e) => switchcase({ PAGADO: e.montoPorcion, VIGENTE: -e.montoPorcion, VALIDANDO: 0 })(null)(e.estado)).reduce((e, x) => e + x, 0);
    const datosCertificado: accountStatement = {
      actividadesContribuyente: economicActivities,
      datosContribuyente,
      datosLiquidacion: chunk(statement, 22),
      saldoFinal,
    };
    console.log(datosCertificado);
    const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-EC.pug`), {
      ...datosCertificado,
      cache: false,
      moment: require('moment'),
      written,
      institucion: 'SEDEMAT',
    });
    return pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' });
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear el certificado',
    };
  } finally {
    gtic.release();
    client.release();
  }
};

export const fixatedAmount = (num: number) => {
  return parseFloat((+num).toPrecision(15)).toFixed(2);
};

export const getSettlementsReport = async (user, payload: { from: Date; to: Date; ramo: number }) => {
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      const workbook = new ExcelJs.Workbook();
      workbook.creator = 'SUT';
      workbook.created = new Date();
      workbook.views = [
        {
          x: 0,
          y: 0,
          width: 10000,
          height: 20000,
          firstSheet: 0,
          activeTab: 1,
          visibility: 'visible',
        },
      ];

      const sheet = workbook.addWorksheet('Reporte');

      const result = await client.query(payload.ramo ? queries.GET_SETTLEMENT_REPORT_BY_BRANCH : queries.GET_SETTLEMENTS_REPORT, payload.ramo ? [payload.from, payload.to, payload.ramo] : [payload.from, payload.to]);

      console.log(result);

      sheet.columns = result.fields.map((row) => {
        return { header: row.name, key: row.name, width: 32 };
      });
      sheet.addRows(result.rows, 'i');

      sheet.eachRow((row, rownumber) => {
        console.log(rownumber, 'row:', row);
      });
      if (dev) {
        const dir = '../../archivos/test.xlsx';
        const stream = fs.createWriteStream(require('path').resolve('./archivos/test.xlsx'));
        await workbook.xlsx.write(stream);
        res(dir);
      } else {
        try {
          const bucketParams = {
            Bucket: 'sut-maracaibo',
            Key: '/sedemat/reportes/liquidaciones.xlsx',
          };
          await S3Client.putObject({
            ...bucketParams,
            Body: await workbook.xlsx.writeBuffer(),
            ACL: 'public-read',
            ContentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          }).promise();
          res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
        } catch (e) {
          rej(e);
        } finally {
        }
      }
    });
  } catch (error) {
    throw errorMessageExtractor(error);
  } finally {
    client.release();
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
  IU: { recibo: createReceiptForSMOrIUApplication, certificado: createReceiptForIUApplication },
  PP: { recibo: createReceiptForPPApplication },
  MUL: { multa: createFineDocument },
})(null);

const breakdownCases = switchcase({
  AE: queries.CREATE_AE_BREAKDOWN_FOR_SETTLEMENT,
  SM: queries.CREATE_SM_BREAKDOWN_FOR_SETTLEMENT,
  IU: queries.CREATE_IU_BREAKDOWN_FOR_SETTLEMENT,
  PP: queries.CREATE_PP_BREAKDOWN_FOR_SETTLEMENT,
})(null);

const branchNames = {
  AE: 'ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES',
  SM: 'SERVICIOS MUNICIPALES',
  IU: 'PROPIEDAD INMOBILIARIA',
  PP: 'PROPAGANDAS Y AVISOS COMERCIALES',
  SAE: 'TASA ADMINISTRATIVA DE SOLVENCIA DE AE',
};

const applicationStateEvents = {
  INGRESARDATOS: 'ingresardatos_pi',
  APROBARCAJERO: 'aprobacioncajero_pi',
  VALIDAR: 'validar_pi',
  FINALIZAR: 'finalizar_pi',
  REBOTAR: 'rebotado_pi',
};

const breakdownCaseHandler = (settlementType, breakdown) => {
  // const query = breakdownCases(settlementType);
  const payload = switchcase({
    'AE': { aforo: breakdown.aforo, montoDeclarado: breakdown.montoDeclarado, montoCobrado: breakdown.montoCobrado },
    'SM': { inmueble: breakdown.inmueble, montoAseo: +breakdown.montoAseo, montoGas: breakdown.montoGas },
    'SERVICIOS MUNICIPALES': { inmueble: breakdown.inmueble, montoAseo: +breakdown.montoAseo, montoGas: +breakdown.montoGas },
    'IU': { inmueble: breakdown.inmueble, monto: breakdown.monto },
    'PP': { subarticulo: breakdown.subarticulo, monto: breakdown.monto, cantidad: breakdown.cantidad },
    'SAE': { monto: breakdown.monto },
  })(null)(settlementType);
  return payload;
};

const certificateCreationHandler = async (process, media, payload: CertificatePayload) => {
  try {
    const result = certificateCases(process)[media];
    if (result) return await result(payload);
    throw new Error('No se encontró el tipo de certificado seleccionado');
  } catch (e) {
    console.log(e);
    throw errorMessageExtractor(e);
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

interface CertificatePayload {
  gticPool: PoolClient;
  pool: PoolClient;
  user: Usuario;
  application: any;
}

interface accountStatement {
  datosContribuyente: Contribuyente;
  actividadesContribuyente: AE[];
  datosLiquidacion: datoLiquidacion[][];
  saldoFinal: number;
}

interface Contribuyente {
  nombreORazon: string;
  cedulaORif: string;
  rim: string;
  direccion: string;
  telefono: string;
}

interface AE {
  id: string;
  nombreActividad: string;
}

interface datoLiquidacion {
  planilla: string;
  solicitud: number;
  porcion: string;
  fechaLiquidacion: string;
  fechaVencimiento: string;
  motivo: string;
  estado: string;
  montoPorcion: number;
}

// export const getSettlements = async ({ document, reference, type, user }) => {
//   const client = await pool.connect();
//   const gtic = await gticPool.connect();
//   const montoAcarreado: any = {};
//   let AE, SM, IU, PP;
//   try {
//     const AEApplicationExists = (await client.query(queries.CURRENT_AE_APPLICATION_EXISTS, [document, reference, type])).rows[0];
//     const SMApplicationExists = (await client.query(queries.CURRENT_SM_APPLICATION_EXISTS, [document, reference, type])).rows[0];
//     const IUApplicationExists = (await client.query(queries.CURRENT_IU_APPLICATION_EXISTS, [document, reference, type])).rows[0];
//     const PPApplicationExists = (await client.query(queries.CURRENT_PP_APPLICATION_EXISTS, [document, reference, type])).rows[0];

//     if (AEApplicationExists && SMApplicationExists && IUApplicationExists && PPApplicationExists) return { status: 409, message: 'Ya existe una declaracion de impuestos para este mes' };
//     const contributor = (reference ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference, type]) : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document, type])).rows[0];
//     if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
//     const now = moment(new Date());
//     const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
//     //AE
//     if (contributor.nu_referencia && !AEApplicationExists) {
//       const economicActivities = (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [contributor.co_contribuyente])).rows;
//       if (economicActivities.length === 0) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
//       let lastEA = (await gtic.query(queries.gtic.GET_ACTIVE_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//       if (!lastEA) lastEA = (await gtic.query(queries.gtic.GET_PAID_ECONOMIC_ACTIVITIES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//       if (!lastEA) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
//       const lastEAPayment = moment(lastEA.fe_liquidacion);
//       const pastMonthEA = moment(lastEA.fe_liquidacion).subtract(1, 'M');
//       const EADate = moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
//       const dateInterpolation = Math.floor(now.diff(EADate, 'M'));
//       montoAcarreado.AE = {
//         monto: lastEA.mo_pendiente ? parseFloat(lastEA.mo_pendiente) : 0,
//         fecha: { month: pastMonthEA.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthEA.year() },
//       };
//       if (dateInterpolation !== 0) {
//         AE = economicActivities.map((el) => {
//           return {
//             id: el.nu_ref_actividad,
//             minimoTributable: Math.round(el.nu_ut) * UTMM,
//             nombreActividad: el.tx_actividad,
//             idContribuyente: el.co_contribuyente,
//             alicuota: el.nu_porc_alicuota / 100,
//             costoSolvencia: UTMM * 2,
//             deuda: new Array(dateInterpolation).fill({ month: null, year: null }).map((value, index) => {
//               const date = addMonths(new Date(lastEAPayment.toDate()), index);
//               return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
//             }),
//           };
//         });
//       }
//     }
//     //SM
//     const estates = (await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows;
//     if (estates.length > 0) {
//       if (!SMApplicationExists) {
//         let lastSM = (await gtic.query(queries.gtic.GET_ACTIVE_MUNICIPAL_SERVICES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//         if (!lastSM) lastSM = (await gtic.query(queries.gtic.GET_PAID_MUNICIPAL_SERVICES_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//         if (!lastSM) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
//         const lastSMPayment = moment(lastSM.fe_liquidacion);
//         const pastMonthSM = moment(lastSM.fe_liquidacion).subtract(1, 'M');
//         const SMDate = moment([lastSMPayment.year(), lastSMPayment.month(), 1]);
//         const dateInterpolationSM = Math.floor(now.diff(SMDate, 'M'));
//         montoAcarreado.SM = {
//           monto: lastSM.mo_pendiente ? parseFloat(lastSM.mo_pendiente) : 0,
//           fecha: { month: pastMonthSM.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthSM.year() },
//         };
//         const debtSM = new Array(dateInterpolationSM).fill({ month: null, year: null }).map((value, index) => {
//           const date = addMonths(new Date(lastSMPayment.toDate()), index);
//           return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
//         });
//         SM = await Promise.all(
//           estates.map(async (el) => {
//             const calculoAseo =
//               el.tx_tp_inmueble === 'COMERCIAL'
//                 ? el.nu_metro_cuadrado && el.nu_metro_cuadrado !== 0
//                   ? 0.15 * el.nu_metro_cuadrado
//                   : (await gtic.query(queries.gtic.GET_MAX_CLEANING_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa
//                 : (await gtic.query(queries.gtic.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].nu_tarifa;
//             const tarifaAseo = calculoAseo / UTMM > 300 ? UTMM * 300 : calculoAseo;
//             const calculoGas =
//               el.tx_tp_inmueble === 'COMERCIAL' ? (await gtic.query(queries.gtic.GET_MAX_GAS_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa : (await gtic.query(queries.gtic.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].nu_tarifa;
//             const tarifaGas = calculoGas / UTMM > 300 ? UTMM * 300 : calculoGas;
//             return { id: el.co_inmueble, tipoInmueble: el.tx_tp_inmueble, direccionInmueble: el.tx_direccion, tarifaAseo, tarifaGas, deuda: debtSM };
//           })
//         );
//       }

//       //IU
//       if (!IUApplicationExists) {
//         let lastIU = (await gtic.query(queries.gtic.GET_ACTIVE_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//         if (!lastIU) lastIU = (await gtic.query(queries.gtic.GET_PAID_URBAN_ESTATE_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//         if (!lastIU) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
//         const lastIUPayment = moment(lastIU.fe_liquidacion);
//         const pastMonthIU = moment(lastIU.fe_liquidacion).subtract(1, 'M');
//         const IUDate = moment([lastIUPayment.year(), lastIUPayment.month(), 1]);
//         const dateInterpolationIU = Math.floor(now.diff(IUDate, 'M'));
//         montoAcarreado.IU = {
//           monto: lastIU.mo_pendiente ? parseFloat(lastIU.mo_pendiente) : 0,
//           fecha: { month: pastMonthIU.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthIU.year() },
//         };
//         if (dateInterpolationIU > 0) {
//           const debtIU = new Array(dateInterpolationIU).fill({ month: null, year: null }).map((value, index) => {
//             const date = addMonths(new Date(lastIUPayment.toDate()), index);
//             return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
//           });
//           IU = estates.map((el) => {
//             return {
//               id: el.co_inmueble,
//               direccionInmueble: el.tx_direccion,
//               ultimoAvaluo: el.nu_monto,
//               impuestoInmueble: (el.nu_monto * 0.01) / 12,
//               deuda: debtIU,
//             };
//           });
//         }
//       }
//     }

//     //PP
//     if (!PPApplicationExists) {
//       let debtPP;
//       let lastPP = (await gtic.query(queries.gtic.GET_ACTIVE_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//       if (!lastPP) lastPP = (await gtic.query(queries.gtic.GET_PAID_PUBLICITY_SETTLEMENT, [contributor.co_contribuyente])).rows[0];
//       if (lastPP) {
//         const lastPPPayment = moment(lastPP.fe_liquidacion);
//         const pastMonthPP = moment(lastPP.fe_liquidacion).subtract(1, 'M');
//         const PPDate = moment([lastPPPayment.year(), lastPPPayment.month(), 1]);
//         const dateInterpolationPP = Math.floor(now.diff(PPDate, 'M'));
//         montoAcarreado.PP = {
//           monto: lastPP.mo_pendiente ? parseFloat(lastPP.mo_pendiente) : 0,
//           fecha: { month: pastMonthPP.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthPP.year() },
//         };
//         if (dateInterpolationPP > 0) {
//           debtPP = new Array(dateInterpolationPP).fill({ month: null, year: null }).map((value, index) => {
//             const date = addMonths(new Date(lastPPPayment.toDate()), index);
//             return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
//           });
//         }
//       } else {
//         debtPP = new Array(now.month() + 1).fill({ month: null, year: null }).map((value, index) => {
//           const date = addMonths(moment(`${now.year()}-01-01`).toDate(), index);
//           return { month: date.toLocaleString('ES', { month: 'long' }), year: date.getFullYear() };
//         });
//       }
//       if (debtPP) {
//         const publicityArticles = (await gtic.query(queries.gtic.GET_PUBLICITY_ARTICLES)).rows;
//         const publicitySubarticles = (await gtic.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
//         PP = {
//           deuda: debtPP,
//           articulos: publicityArticles.map((el) => {
//             return {
//               id: +el.co_articulo,
//               nombreArticulo: el.tx_articulo,
//               subarticulos: publicitySubarticles
//                 .filter((al) => +el.co_articulo === al.co_articulo)
//                 .map((el) => {
//                   return {
//                     id: +el.co_medio,
//                     nombreSubarticulo: el.tx_medio,
//                     parametro: el.parametro,
//                     costo: +el.ut_medio * UTMM,
//                     costoAlto: el.parametro === 'BANDA' ? (+el.ut_medio + 2) * UTMM : undefined,
//                   };
//                 }),
//             };
//           }),
//         };
//       }
//     }
//     return {
//       status: 200,
//       message: 'Impuestos obtenidos satisfactoriamente',
//       impuesto: {
//         contribuyente: contributor.co_contribuyente,
//         razonSocial: contributor.tx_razon_social || `${contributor.nb_contribuyente} ${contributor.ap_contribuyente}`,
//         siglas: contributor.tx_siglas,
//         rim: contributor.nu_referencia,
//         documento: contributor.tx_rif || contributor.nu_cedula,
//         AE,
//         SM,
//         IU,
//         PP,
//         montoAcarreado: addMissingCarriedAmounts(montoAcarreado),
//       },
//     };
//   } catch (error) {
//     console.log(error);
//     throw {
//       status: 500,
//       error: errorMessageExtractor(error),
//       message: errorMessageGenerator(error) || 'Error al obtener los impuestos',
//     };
//   } finally {
//     client.release();
//     gtic.release();
//   }
// };
