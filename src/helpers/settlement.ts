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
import bcrypt from 'bcryptjs';
import md5 from 'md5';
import { query } from 'express-validator';
import { sendNotification } from './notification';
import { sendRimVerification, verifyCode, resendCode } from './verification';
import { hasLinkedContributor } from './user';
import e from 'express';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import * as fs from 'fs';
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

const codigosRamo = {
  AE: 112,
  SM: 122,
  PP: 114,
  IU: 111,
};
const formatCurrency = (number: number) => new Intl.NumberFormat('de-DE').format(number);

export const checkContributorExists = () => async (req: any, res, next) => {
  const client = await pool.connect();
  const { user } = req;
  const { doc, ref, pref, contrib } = req.query;
  try {
    if (user.tipoUsuario !== 3) return next();
    const contributorExists = (await client.query(queries.TAX_PAYER_EXISTS, [pref, doc])).rowCount > 0;
    if (!contributorExists) {
      const x = await externalLinkingForCashier({ document: doc, docType: pref, reference: ref, user, typeUser: contrib });
      return x.linked && next();
    } else {
      return next();
    }
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

export const getSettlements = async ({ document, reference, type, user }: { document: string; reference: string | null; type: string; user: Usuario }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  const montoAcarreado: any = {};
  let AE, SM, IU, PP;
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [type, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if ((!branch && truthyCheck(reference)) || (branch && !branch.actualizado)) throw { status: 404, message: 'La sucursal no esta actualizada o no esta registrada en SEDEMAT' };
    const lastSettlementQuery = contributor.tipo_contribuyente === 'JURIDICO' ? queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM : queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_CONTRIBUTOR;
    const lastSettlementPayload = contributor.tipo_contribuyente === 'JURIDICO' ? branch.referencia_municipal : contributor.id_contribuyente;
    const AEApplicationExists = contributor.tipo_contribuyente === 'JURIDICO' || reference ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.AE, reference])).rows[0] : false;
    const SMApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.SM, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.SM, contributor.id_contribuyente])).rows[0];
    const IUApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.IU, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.IU, contributor.id_contribuyente])).rows[0];
    const PPApplicationExists =
      contributor.tipo_contribuyente === 'JURIDICO'
        ? (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.PP, reference])).rows[0]
        : (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR, [codigosRamo.PP, contributor.id_contribuyente])).rows[0];

    if (AEApplicationExists && SMApplicationExists && IUApplicationExists && PPApplicationExists) return { status: 409, message: 'Ya existe una declaracion de impuestos para este mes' };
    const now = moment(new Date());
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    //AE
    if (branch && branch.referencia_municipal && !AEApplicationExists) {
      const economicActivities = (await client.query(queries.GET_ECONOMIC_ACTIVITIES_BY_CONTRIBUTOR, [contributor.id_contribuyente])).rows;
      if (economicActivities.length === 0) return { status: 404, message: 'Debe completar su pago en las oficinas de SEDEMAT' };
      let lastEA = (await client.query(lastSettlementQuery, [codigosRamo.AE, lastSettlementPayload])).rows[0];
      const lastEAPayment = (lastEA && moment(lastEA.fecha_liquidacion)) || moment().month(0);
      const pastMonthEA = (lastEA && moment(lastEA.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
      const EADate = moment([lastEAPayment.year(), lastEAPayment.month(), 1]);
      const dateInterpolation = Math.floor(now.diff(EADate, 'M'));
      montoAcarreado.AE = {
        monto: lastEA && lastEA.mo_pendiente ? parseFloat(lastEA.mo_pendiente) : 0,
        fecha: { month: pastMonthEA.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthEA.year() },
      };
      if (dateInterpolation !== 0) {
        AE = economicActivities.map((el) => {
          return {
            id: el.id_actividad_economica,
            minimoTributable: Math.round(el.minimo_tributable) * UTMM,
            nombreActividad: el.descripcion,
            idContribuyente: branch.id_registro_municipal,
            alicuota: el.alicuota / 100,
            costoSolvencia: UTMM * 2,
            deuda: new Array(dateInterpolation).fill({ month: null, year: null }).map((value, index) => {
              const date = addMonths(new Date(lastEAPayment.toDate()), index);
              return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
            }),
          };
        });
      }
    }
    //SM
    const estates = (await client.query(branch ? queries.GET_ESTATES_FOR_JURIDICAL_CONTRIBUTOR : queries.GET_ESTATES_FOR_NATURAL_CONTRIBUTOR, [branch ? branch.id_registro_municipal : contributor.id_contribuyente])).rows;
    if (estates.length > 0) {
      if (!SMApplicationExists) {
        let lastSM = (await client.query(lastSettlementQuery, [codigosRamo.SM, lastSettlementPayload])).rows[0];
        const lastSMPayment = (lastSM && moment(lastSM.fecha_liquidacion)) || moment().month(0);
        const pastMonthSM = (lastSM && moment(lastSM.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
        const SMDate = moment([lastSMPayment.year(), lastSMPayment.month(), 1]);
        const dateInterpolationSM = Math.floor(now.diff(SMDate, 'M'));
        montoAcarreado.SM = {
          monto: lastSM && lastSM.mo_pendiente ? parseFloat(lastSM.mo_pendiente) : 0,
          fecha: { month: pastMonthSM.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthSM.year() },
        };
        const debtSM = new Array(dateInterpolationSM + 1).fill({ month: null, year: null }).map((value, index) => {
          const date = addMonths(new Date(lastSMPayment.toDate()), index);
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
        });
        SM = await Promise.all(
          estates.map(async (el) => {
            const calculoAseo =
              el.tipo_inmueble === 'COMERCIAL'
                ? el.metros_construccion && el.metros_construccion !== 0
                  ? 0.15 * el.metros_construccion
                  : (await client.query(queries.GET_AE_CLEANING_TARIFF, [contributor.id_contribuyente])).rows[0].monto
                : (await client.query(queries.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].monto;
            const tarifaAseo = calculoAseo / UTMM > 300 ? UTMM * 300 : calculoAseo;
            const calculoGas = el.tipo_inmueble === 'COMERCIAL' ? (await client.query(queries.GET_AE_GAS_TARIFF, [contributor.id_contribuyente])).rows[0].monto : (await client.query(queries.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].monto;
            const tarifaGas = calculoGas / UTMM > 300 ? UTMM * 300 : calculoGas;
            return { id: el.id_inmueble, tipoInmueble: el.tipo_inmueble, direccionInmueble: el.direccion, tarifaAseo, tarifaGas, deuda: debtSM };
          })
        );
      }

      //IU
      if (!IUApplicationExists) {
        let lastIU = (await client.query(lastSettlementQuery, [codigosRamo.IU, lastSettlementPayload])).rows[0];
        const lastIUPayment = (lastIU && moment(lastIU.fecha_liquidacion)) || moment().month(0);
        const pastMonthIU = (lastIU && moment(lastIU.fecha_liquidacion).subtract(1, 'M')) || moment().month(0);
        const IUDate = moment([lastIUPayment.year(), lastIUPayment.month(), 1]);
        const dateInterpolationIU = Math.floor(now.diff(IUDate, 'M'));
        montoAcarreado.IU = {
          monto: lastIU && lastIU.mo_pendiente ? parseFloat(lastIU.mo_pendiente) : 0,
          fecha: { month: pastMonthIU.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthIU.year() },
        };
        if (dateInterpolationIU > 0) {
          const debtIU = new Array(dateInterpolationIU + 1).fill({ month: null, year: null }).map((value, index) => {
            const date = addMonths(new Date(lastIUPayment.toDate()), index);
            return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
          });
          IU = estates
            .filter((el) => +el.avaluo)
            .map((el) => {
              return {
                id: el.id_inmueble,
                direccionInmueble: el.direccion,
                ultimoAvaluo: el.avaluo,
                impuestoInmueble: (el.avaluo * 0.01) / 12,
                deuda: debtIU,
              };
            })
            .filter((el) => el.id);
        }
      }
    }

    //PP
    if (!PPApplicationExists) {
      let debtPP;
      let lastPP = (await client.query(lastSettlementQuery, [codigosRamo.PP, lastSettlementPayload])).rows[0];
      if (lastPP) {
        const lastPPPayment = moment(lastPP.fecha_liquidacion);
        const pastMonthPP = moment(lastPP.fecha_liquidacion).subtract(1, 'M');
        const PPDate = moment([lastPPPayment.year(), lastPPPayment.month(), 1]);
        const dateInterpolationPP = Math.floor(now.diff(PPDate, 'M'));
        montoAcarreado.PP = {
          monto: lastPP && lastPP.mo_pendiente ? parseFloat(lastPP.mo_pendiente) : 0,
          fecha: { month: pastMonthPP.toDate().toLocaleString('es-ES', { month: 'long' }), year: pastMonthPP.year() },
        };
        if (dateInterpolationPP > 0) {
          debtPP = new Array(dateInterpolationPP + 1).fill({ month: null, year: null }).map((value, index) => {
            const date = addMonths(new Date(lastPPPayment.toDate()), index);
            return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear() };
          });
        }
      } else {
        debtPP = new Array(now.month() + 1).fill({ month: null, year: null }).map((value, index) => {
          const date = addMonths(moment(`${now.year()}-01-01`).toDate(), index);
          return { month: date.toLocaleString('ES', { month: 'long' }), year: date.getFullYear() };
        });
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
        documento: contributor.documento,
        tipoDocumento: contributor.tipo_documento,
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
        nombreCompleto: `${naturalContributor.nb_contribuyente} ${naturalContributor.ap_contribuyente}`.replace('null', '').trim(),
        telefonoMovil: nullStringCheck(naturalContributor.nu_telf_movil).trim(),
        telefonoHabitacion: nullStringCheck(naturalContributor.nu_telf_hab).trim(),
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
    estado: nullStringCheck(x.co_estatus === 1 ? 'VIGENTE' : 'PAGADO'),
    ramo: nullStringCheck(x.tx_ramo),
    codigoRamo: nullStringCheck(x.nb_ramo),
    monto: nullStringCheck(x.nu_monto),
    fechaLiquidacion: x.fe_liquidacion,
    fecha: { month: moment(x.fe_liquidacion).toDate().toLocaleDateString('ES', { month: 'long' }), year: moment(x.fe_liquidacion).year() },
  };
};

const structureFinings = (x: any) => {
  return {
    id: nullStringCheck(x.co_decl_multa),
    estado: nullStringCheck(x.in_activo ? 'VIGENTE' : 'PAGADO'),
    monto: nullStringCheck(x.nu_monto),
    fecha: { month: moment(x.created_at).toDate().toLocaleDateString('ES', { month: 'long' }), year: moment(x.created_at).year() },
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
                    const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                    const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                    const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                    const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
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
                    return { datosSucursal, inmuebles, liquidaciones, multas };
                  })
                : (await gtic.query(queries.gtic.GET_NATURAL_CONTRIBUTOR, [el.nu_cedula, el.tx_tp_doc])).rows.map(async (x) => {
                    let datos;
                    if (x.nu_referencia) {
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));

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
                        datosSucursal,
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
          };
        })
        .filter((el) => el)
    );
    await client.query('BEGIN');
    const { datosContribuyente, sucursales, actividadesEconomicas } = linkingData[0];
    const { tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, tipoContribuyente } = datosContribuyente;
    const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    if (actividadesEconomicas!.length > 0) {
      await Promise.all(
        actividadesEconomicas!.map(async (x) => {
          return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [contributor.id_contribuyente, x.id]);
        })
      );
    }
    if (datosContribuyente.tipoContribuyente === 'JURIDICO') {
      const rims: number[] = await Promise.all(
        await sucursales.map(async (x) => {
          const { inmuebles, liquidaciones, multas, datosSucursal } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
          const registry = (await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [contributor.id_contribuyente, registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado || false])).rows[0];
          const estates =
            inmuebles.length > 0
              ? await Promise.all(
                  inmuebles.map(async (el) => {
                    const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble])).rows[0];
                    console.log(inmueble);
                    await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                  })
                )
              : undefined;
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
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
    } else {
      const rims: number[] = await Promise.all(
        await sucursales.map(async (x) => {
          const { inmuebles, liquidaciones, multas, datosSucursal } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
          let registry;

          if (registroMunicipal) {
            registry = (await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [contributor.id_contribuyente, registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado || false])).rows[0];
            const estates =
              inmuebles.length > 0
                ? await Promise.all(
                    inmuebles.map(async (el) => {
                      const inmueble = await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble]);
                      await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.rows[0].id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                    })
                  )
                : undefined;
          } else {
            const estates =
              inmuebles.length > 0
                ? await Promise.all(
                    inmuebles.map(async (el) => {
                      const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [(registry && registry.id_registro_municipal) || null, el.direccion, el.tipoInmueble])).rows[0];
                      await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [inmueble.id_inmueble, contributor.id_contribuyente]);
                      await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                      return 0;
                    })
                  )
                : undefined;
          }
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }
          return representado ? registry.id_registro_municipal : undefined;
        })
      );
    }
    await client.query('COMMIT');
    return { linked: true };
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
                    const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                    const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                    const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                    const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));
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
                    return { datosSucursal, inmuebles, liquidaciones, multas };
                  })
                : (await gtic.query(queries.gtic.GET_NATURAL_CONTRIBUTOR, [el.nu_cedula, el.tx_tp_doc])).rows.map(async (x) => {
                    let datos;
                    if (x.nu_referencia) {
                      const inmuebles = await Promise.all((await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j)));
                      const liquidaciones = await Promise.all((await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j)));
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                      const multas = await Promise.all((await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j)));

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
                        datosSucursal,
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
          };
        })
        .filter((el) => el)
    );
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
    return { datosContribuyente, sucursales };
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

export const getApplicationsAndSettlementsById = async ({ id, user }): Promise<Solicitud & any> => {
  const client = await pool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = await Promise.all(
      (await client.query(queries.GET_APPLICATION_BY_ID, [id])).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
        return {
          id: el.id_solicitud,
          usuario: typeof user === 'object' ? user : { id: user },
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          estado: (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state,
          referenciaMunicipal: liquidaciones[0]?.registro_municipal
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
      (await client.query(queries.GET_APPLICATION_INSTANCES_BY_USER, [user.id])).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];
        return {
          id: el.id_solicitud,
          usuario: user,
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          estado: (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state,
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
        };
      })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', solicitudes: applications };
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
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const userApplications = (referencia ? await client.query(queries.GET_APPLICATION_INSTANCES_BY_CONTRIBUTOR, [referencia, document, docType]) : await client.query(queries.GET_APPLICATION_INSTANCES_FOR_NATURAL_CONTRIBUTOR, [document, docType]))
      .rows;
    const hasApplications = userApplications.length > 0;
    if (!hasApplications) return { status: 404, message: 'El usuario no tiene solicitudes' };
    const applications: Solicitud[] = await Promise.all(
      userApplications.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        const docs = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [el.id_contribuyente])).rows[0];

        return {
          id: el.id_solicitud,
          usuario: el.usuario,
          contribuyente: structureContributor(docs),
          aprobado: el.aprobado,
          fecha: el.fecha,
          documento: docs.documento,
          tipoDocumento: docs.tipo_documento,
          estado: (await client.query(queries.GET_APPLICATION_STATE, [el.id_solicitud])).rows[0].state,
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
        };
      })
    );
    return { status: 200, message: 'Instancias de solicitudes obtenidas satisfactoriamente', solicitudes: applications };
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

const formatContributor = async (contributor, client: PoolClient) => {
  try {
    const branches = (await client.query('SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = $1', [contributor.id_contribuyente])).rows;
    return {
      id: contributor.id_contribuyente,
      tipoDocumento: contributor.tipo_documento,
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      razonSocial: contributor.razon_social,
      denomComercial: contributor.denominacion_comercial || undefined,
      siglas: contributor.siglas || undefined,
      parroquia: contributor.parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      puntoReferencia: contributor.punto_referencia,
      verificado: contributor.verificado,
      sucursales: branches.length > 0 ? branches.map((el) => formatBranch(el)) : undefined,
    };
  } catch (e) {
    throw e;
  }
};

const formatBranch = (branch) => {
  return {
    id: branch.id_registro_municipal,
    referenciaMunicipal: branch.referencia_municipal,
    fechaAprobacion: branch.fecha_aprobacion,
    telefono: branch.telefono_celular,
    email: branch.email,
    denomComercial: branch.denominacion_comercial,
    nombreRepresentante: branch.nombre_representante,
    actualizado: branch.actualizado,
  };
};

export const contributorSearch = async ({ document, docType, name }) => {
  const client = await pool.connect();
  let contribuyentes: any[] = [];
  try {
    if ((!document && !name) || (document.length < 6 && name.length < 3)) throw { status: 406, message: 'Debe aportar mas datos para la busqueda' };
    contribuyentes = document && document.length > 6 ? (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows : (await client.query(queries.SEARCH_CONTRIBUTOR_BY_NAME, [`%${name}%`])).rows;
    const contributorExists = contribuyentes.length > 0;
    if (!contributorExists) return { status: 404, message: 'No existe un contribuyente registrado con ese documento' };
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
            const { nombreRepresentante, telefonoMovil, email, denomComercial, representado, registroMunicipal } = datosSucursal;
            const updatedRegistry = (
              await client.query(queries.UPDATE_BRANCH_INFO, [denomComercial, nombreRepresentante, representado ? datosContacto.telefono : telefonoMovil, representado ? datosContacto.correo : email, representado, registroMunicipal])
            ).rows[0];
            return representado ? updatedRegistry.id_registro_municipal : undefined;
          })
        );
        await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributorExists[0].id_contribuyente, user.id]);
        await client.query('COMMIT');
        await sendRimVerification(VerificationValue.CellPhone, { idRim: rims.filter((el) => el), content: datosContacto.telefono, user: user.id });
        hasNewCode = true;

        payload = { rims: rims.filter((el) => el) };
        return { status: 200, message: 'Datos actualizados para las sucursales del contribuyente', hasNewCode, payload };
      } else {
      }
    }
    const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributor.id_contribuyente, user.id]);
    if (actividadesEconomicas && actividadesEconomicas.length > 0) {
      await Promise.all(
        actividadesEconomicas.map(async (x) => {
          return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [contributor.id_contribuyente, x.id]);
        })
      );
    }
    if (datosContribuyente.tipoContribuyente === 'JURIDICO') {
      const rims: number[] = await Promise.all(
        await sucursales.map(async (x) => {
          const { inmuebles, liquidaciones, multas, datosSucursal } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
          const registry = (
            await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [
              contributor.id_contribuyente,
              registroMunicipal,
              nombreRepresentante,
              representado ? datosContacto.telefono : telefonoMovil,
              representado ? datosContacto.correo : email,
              denomComercial,
              representado || false,
            ])
          ).rows[0];
          const estates =
            inmuebles.length > 0
              ? await Promise.all(
                  inmuebles.map(async (el) => {
                    const x = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble])).rows[0];
                    await client.query(queries.INSERT_ESTATE_VALUE, [x.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                  })
                )
              : undefined;
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [(representado && user.id) || null, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
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
          const { inmuebles, liquidaciones, multas, datosSucursal } = x;
          const liquidacionesPagas = liquidaciones.filter((el) => el.estado === 'PAGADO');
          const liquidacionesVigentes = liquidaciones.filter((el) => el.estado !== 'PAGADO');
          const multasPagas = multas.filter((el) => el.estado === 'PAGADO');
          const multasVigentes = multas.filter((el) => el.estado !== 'PAGADO');
          const pagados = liquidacionesPagas.concat(multasPagas);
          const vigentes = liquidacionesVigentes.concat(multasVigentes);
          const { registroMunicipal, nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
          let registry;

          if (registroMunicipal) {
            registry = (
              await client.query(queries.CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR, [
                contributor.id_contribuyente,
                registroMunicipal,
                nombreRepresentante,
                representado ? datosContacto.telefono : telefonoMovil,
                representado ? datosContacto.correo : email,
                denomComercial,
                representado || false,
              ])
            ).rows[0];
            const estates =
              inmuebles.length > 0
                ? await Promise.all(
                    inmuebles.map(async (el) => {
                      const inmueble = await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_registro_municipal, el.direccion, el.tipoInmueble]);
                      await client.query(queries.INSERT_ESTATE_VALUE, [x.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                    })
                  )
                : undefined;
          } else {
            const estates =
              inmuebles.length > 0
                ? await Promise.all(
                    inmuebles.map(async (el) => {
                      const inmueble = (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [(registry && registry.id_registro_municipal) || null, el.direccion, el.tipoInmueble])).rows[0];
                      await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [inmueble.id_inmueble, contributor.id_contribuyente]);
                      await client.query(queries.INSERT_ESTATE_VALUE, [inmueble.id_inmueble, el.ultimoAvaluo.monto, el.ultimoAvaluo.year]);
                      return 0;
                    })
                  )
                : undefined;
          }
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_APPROVED_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, applicationStateEvents.APROBARCAJERO]);
            await Promise.all(
              pagados.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
                  ])
                ).rows[0];
                await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [el.fechaLiquidacion, settlement.id_liquidacion]);
              })
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [pagados[0].fechaLiquidacion, application.id_solicitud]);
            await Promise.all(
              vigentes.map(async (el) => {
                const settlement = (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    fixatedAmount(+el.monto),
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).endOf('month').format('MM-DD-YYYY'),
                    (registry && registry.id_registro_municipal) || null,
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
    }
    client.query('COMMIT');
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

//FIXME: acoplar a los estandares actuales de SUT
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
    console.log(contributorReference);
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, process.contribuyente])).rows[0];

    const hasAE = impuestos.find((el) => el.ramo === 'AE');
    if (hasAE) {
      const now = moment().locale('ES');
      const pivot = moment().locale('ES');
      const onlyAE = impuestos
        .filter((el) => el.ramo === 'AE')
        .sort((a, b) => (pivot.month(a.fechaCancelada.month).toDate() === pivot.month(b.fechaCancelada.month).toDate() ? 0 : pivot.month(a.fechaCancelada.month).toDate() > pivot.month(b.fechaCancelada.month).toDate() ? 1 : -1));
      const lastSavedFine = (await client.query(queries.GET_LAST_FINE_FOR_LATE_APPLICATION, [contributorReference.id_registro_municipal])).rows[0];
      if (lastSavedFine && moment(lastSavedFine.fecha_liquidacion).year() === now.year() && moment(lastSavedFine.fecha_liquidacion).month() < now.month()) {
        finingAmount = lastSavedFine.datos.monto;
        const proposedFiningDate = moment().locale('ES').month(onlyAE[0].fechaCancelada.month).month();
        const finingDate = moment().month(lastSavedFine.fecha_liquidacion).month() < proposedFiningDate ? moment().month(lastSavedFine.fecha_liquidacion).month() : proposedFiningDate;
        finingMonths = new Array(now.month() - finingDate).fill({});
        if (finingMonths.length > 0) {
          let counter = finingDate;
          finingMonths = await Promise.all(
            finingMonths.map((el, i) => {
              const multa = Promise.resolve(
                client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
                  application.id_solicitud,
                  fixatedAmount(finingAmount * UTMM),
                  {
                    fecha: {
                      month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
                      year: now.year(),
                    },
                    descripcion: 'Multa por Declaracion Fuera de Plazo',
                    monto: finingAmount,
                  },
                  moment().month(counter).endOf('month').format('MM-DD-YYYY'),
                  (contributorReference && contributorReference.id_registro_municipal) || null,
                ])
              )
                .then((el) => el.rows[0])
                .then((data) => {
                  return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto, descripcion: data.datos.descripcion };
                });
              counter++;
              finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
              return multa;
            })
          );
        }
        if (now.date() > 10) {
          const multa = (
            await client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
              application.id_solicitud,
              fixatedAmount(finingAmount * UTMM),
              {
                fecha: {
                  month: moment().toDate().toLocaleDateString('ES', { month: 'long' }),
                  year: now.year(),
                },
                descripcion: 'Multa por Declaracion Fuera de Plazo',
                monto: finingAmount,
              },
              moment().endOf('month').format('MM-DD-YYYY'),
              (contributorReference && contributorReference.id_registro_municipal) || null,
            ])
          ).rows[0];
          const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };
          finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
          finingMonths.push(fine);
        }
      } else {
        finingAmount = 10;
        const finingDate = moment().locale('ES').month(onlyAE[0].fechaCancelada.month).month();
        finingMonths = new Array(now.month() - finingDate).fill({});
        if (finingMonths.length > 0) {
          let counter = finingDate;
          finingMonths = await Promise.all(
            finingMonths.map((el, i) => {
              const multa = Promise.resolve(
                client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
                  application.id_solicitud,
                  fixatedAmount(finingAmount * UTMM),
                  {
                    fecha: {
                      month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
                      year: now.year(),
                    },
                    descripcion: 'Multa por Declaracion Fuera de Plazo',
                    monto: finingAmount,
                  },
                  moment().month(counter).endOf('month').format('MM-DD-YYYY'),
                  (contributorReference && contributorReference.id_registro_municipal) || null,
                ])
              )
                .then((el) => el.rows[0])
                .then((data) => {
                  return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto, descripcion: data.datos.descripcion };
                });
              counter++;
              finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
              return multa;
            })
          );
        }
        if (now.date() > 10) {
          const multa = (
            await client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
              application.id_solicitud,
              fixatedAmount(finingAmount * UTMM),
              {
                fecha: {
                  month: moment().toDate().toLocaleDateString('ES', { month: 'long' }),
                  year: now.year(),
                },
                descripcion: 'Multa por Declaracion Fuera de Plazo',
                monto: finingAmount,
              },
              moment().endOf('month').format('MM-DD-YYYY'),
              (contributorReference && contributorReference.id_registro_municipal) || null,
            ])
          ).rows[0];
          const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: +multa.monto, descripcion: multa.datos.descripcion };

          finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
          finingMonths.push(fine);
        }
      }
    }

    const impuestosExt = impuestos.map((x, i, j) => {
      if (x.ramo === 'AE') {
        const costoSolvencia = 2 * UTMM;
        x.monto = +x.monto - costoSolvencia;
        j.push({ monto: costoSolvencia, ramo: 'SAE', fechaCancelada: x.fechaCancelada });
      }
      return x;
    });

    const settlement: Liquidacion[] = await Promise.all(
      impuestosExt.map(async (el) => {
        const datos = {
          desglose: el.desglose ? el.desglose.map((al) => breakdownCaseHandler(el.ramo, al)) : undefined,
          fecha: { month: el.fechaCancelada.month, year: el.fechaCancelada.year },
        };
        const liquidacion = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            application.id_solicitud,
            fixatedAmount(+el.monto),
            el.ramo,
            datos,
            moment().month(el.fechaCancelada.month).endOf('month').format('MM-DD-YYYY'),
            contributorReference.id_registro_municipal || null,
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

//TODO: revisar mayana
export const addTaxApplicationPayment = async ({ payment, application, user }) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const solicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [application])).rows[0];
    const pagoSum = payment.map((e) => e.costo).reduce((e, i) => e + i, 0);
    if (pagoSum < solicitud.monto_total) throw { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
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
        user.tipoUsuario === 4 ? await insertPaymentReference(el, application, client) : await insertPaymentCashier(el, application, client);
      })
    );
    const state =
      user.tipoUsuario === 4
        ? (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.VALIDAR])).rows[0]
        : (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application, applicationStateEvents.APROBARCAJERO])).rows[0];
    client.query('COMMIT');
    const applicationInstance = await getApplicationsAndSettlementsById({ id: application, user });
    console.log(applicationInstance);
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

export const addTaxApplicationPaymentAgreement = async ({ payment, agreement, fragment, user }) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
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
        user.tipoUsuario === 4 ? await insertPaymentReference(el, fragment, client) : await insertPaymentCashier(el, fragment, client);
      })
    );
    const state =
      user.tipoUsuario === 4 ? (await client.query(queries.UPDATE_FRACTION_STATE, [fragment, applicationStateEvents.VALIDAR])).rows[0] : (await client.query(queries.COMPLETE_FRACTION_STATE, [fragment, applicationStateEvents.APROBARCAJERO])).rows[0];
    client.query('COMMIT');
    const applicationInstance = await getAgreementFractionById({ id: fragment });
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
    if (body.concepto === 'CONVENIO' && body.solicitudAprobada) {
      //este metodo es para validar los convenios y llevarlos al estado de finalizado
      const state = (await client.query(queries.COMPLETE_FRACTION_STATE, [body.idTramite, applicationStateEvents.FINALIZAR])).rows[0].state;
    }
    const state = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [body.idTramite, applicationStateEvents.FINALIZAR])).rows[0].state;
    const solicitud = (await client.query(queries.GET_APPLICATION_BY_ID, [body.idTramite])).rows[0];
    const applicationInstance = await getApplicationsAndSettlementsById({ id: body.idTramite, user: solicitud.id_usuario });
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

export const approveContributorSignUp = async ({ procedure, client }: { procedure: any; client: PoolClient }) => {
  try {
    const { datos, usuario } = procedure;
    const { documentoIdentidad, razonSocial, denominacionComercial, siglas, parroquia, sector, direccion, puntoReferencia, tipoContribuyente, tipoDocumento } = datos.funcionario;
    const parish = (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [parroquia])).rows[0]?.id;
    const contributor = (await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [tipoDocumento, documentoIdentidad, razonSocial, denominacionComercial, siglas, parish, sector, direccion, puntoReferencia, true, tipoContribuyente])).rows[0];
    await client.query(queries.ASSIGN_CONTRIBUTOR_TO_USER, [contributor.id_contribuyente, usuario]);
    await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [usuario]);
    console.log(procedure);
    return true;
  } catch (error) {
    console.log(error);
    throw error;
  }
};

export const approveContributorAELicense = async ({ data, client }: { data: any; client: PoolClient }) => {
  try {
    const { usuario, funcionario } = data;
    const { actividadesEconomicas } = funcionario;
    const { contribuyente } = usuario;
    const registry = (await client.query(queries.ADD_BRANCH_FOR_CONTRIBUTOR, [contribuyente.id, funcionario.telefono, funcionario.correo, funcionario.denominacionComercial, funcionario.nombreRepresentante])).rows[0];
    data.funcionario.referenciaMunicipal = registry.referencia_municipal;
    await Promise.all(
      actividadesEconomicas!.map(async (x) => {
        return await client.query(queries.CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR, [contribuyente.id, x.codigo]);
      })
    );
    console.log(data);
    return data;
  } catch (error) {
    console.log(error);
    throw error;
  }
};

export const approveContributorBenefits = async ({ data, client }: { data: any; client: PoolClient }) => {
  try {
    const { contribuyente, beneficios } = data.funcionario;
    const contributorWithBranch = (await client.query(queries.GET_CONTRIBUTOR_WITH_BRANCH, [contribuyente.registroMunicipal])).rows[0];
    const benefittedUser = (await client.query(queries.GET_USER_BY_APPLICATION_AND_RIM, [contributorWithBranch.id_registro_municipal])).rows[0].id_usuario;
    await Promise.all(
      beneficios.map(async (x) => {
        switch (x.tipoBeneficio) {
          case 'pagoCompleto':
            const applicationFP = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [benefittedUser, contributorWithBranch.id_contribuyente])).rows[0];
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
            const applicationAG = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [benefittedUser, contributorWithBranch.id_contribuyente])).rows[0];
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [applicationAG.id_solicitud, applicationStateEvents.INGRESARDATOS]);
            await client.query('UPDATE impuesto.solicitud SET tipo_solicitud = $1 WHERE id_solicitud = $2', ['CONVENIO', applicationAG.id_solicitud]);
            const agreement = (await client.query(queries.CREATE_AGREEMENT, [applicationAG.id_solicitud, x.porciones.length])).rows[0];
            const settlementsAG = (await client.query(queries.CHANGE_SETTLEMENT_TO_NEW_APPLICATION, [applicationAG.id_solicitud, contributorWithBranch.id_registro_municipal, x.idRamo])).rows[0];
            await client.query(queries.CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT, [x.idRamo, applicationAG.id_solicitud]);
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
          contribuyente: application.razonSocial,
          rim: referencia?.referencia_municipal,
          cedulaORif: application.tipoDocumento + '-' + application.documento,
          direccion: application.direccion,
          representanteLegal: referencia?.nombre_representante,
          periodo: mesesCardinal[application.datos.fecha.mes],
          anio: application.datos.fecha.anio,
          fecha: moment().format('MM-DD-YYYY'),
          fechaLetra: `${moment().date()} de ${application.datos.fecha.mes} de ${application.datos.fecha.anio}`,
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
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;
    let inmueblesContribuyente: any[] = (await Promise.all(breakdownData[0].datos.desglose.map((row) => {
      return pool.query(queries.GET_SUT_ESTATE_BY_ID, [row.inmueble]);
    })));
    inmueblesContribuyente = inmueblesContribuyente.map(result => result.rows[0]);
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    let certInfo;
    let motivo;
    let ramo;
    let certInfoArray: any[] = [];
    console.log('appli', application);
    if (application.descripcionCortaRamo === 'SM') {
      motivo = application.descripcionSubramo;
      ramo = application.descripcionRamo;
      
      console.log('breakdownData', breakdownData)
      console.log('datos sample',breakdownData[0].datos)
      const totalIva = +breakdownData.map((row) => {
        return row.datos.desglose.reduce((prev, next) => {
          return prev + (next.montoGas ? next.montoAseo + +next.montoGas : +next.montoAseo)
        }, 0)
      }).reduce((prev, next) => prev + next, 0) * 0.16;

      const totalMonto = +breakdownData.map((row) => {
        return row.datos.desglose.reduce((prev, next) => {
          return prev + (next.montoGas ? next.montoAseo + +next.montoGas : +next.montoAseo)
        }, 0)
      }).reduce((prev, next) => prev + next, 0);
      for (const el of inmueblesContribuyente) {
        console.log('AAAAAAAAAAAAAAAAAAA');
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('MM-DD-YYYY'),

          datos: {
            nroSolicitud: application.id,
            nroPlanilla: 10010111,
            motivo: motivo,
            nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
            tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
            tipoInmueble: el.tipo_inmueble,
            fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
            propietario: {
              rif: `${application.tipoDocumento}-${application.documento}`,
              denomComercial: application.denominacionComercial,
              direccion: application.direccion || 'Dirección Sin Asignar',
              razonSocial: application.razonSocial,
            },
            items: breakdownData
              .map((row) => {
                console.log(el, row)
                return {
                  desglose: row.datos.desglose.find((desglose) => desglose.inmueble === +el.id_inmueble),
                  fecha: row.datos.fecha,
                };
              })
              .map((row) => {
                return {
                  direccion: el.direccion || 'Dirección Sin Asignar',
                  periodos: `${row.fecha.month} ${row.fecha.year}`.toUpperCase(),
                  impuesto: row.desglose.montoGas ? formatCurrency(+row.desglose.montoGas + +row.desglose.montoAseo) : formatCurrency(row.desglose.montoAseo),
                };
              }),
            totalIva: `${formatCurrency(totalIva)} Bs.S`,
            totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
            totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
            montoTotalImpuesto: `${formatCurrency(
              +breakdownData
                .map((row) => {
                  return {
                    desglose: row.datos.desglose.find((desglose) => desglose.inmueble === +el.id_inmueble),
                    fecha: row.datos.fecha,
                  };
                })
                .map((row) => (row.desglose.montoGas ? +row.desglose.montoAseo + +row.desglose.montoGas : +row.desglose.montoAseo))
                .reduce((prev, next) => prev + next, 0) + totalIva
            )} Bs.S`,
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
    } else if (application.descripcionCortaRamo === 'IU') {
      motivo = (await gticPool.query(queries.gtic.GET_MOTIVE_BY_TYPE_ID, [idTiposSolicitud.IU])).rows[0];
      ramo = (await gticPool.query(queries.gtic.GET_BRANCH_BY_TYPE_ID, [idTiposSolicitud.IU])).rows[0];
      const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id])).rows;
      const totalIva = breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0) * 0.16;
      const totalMonto = +breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0);

      for (const el of inmueblesContribuyente) {
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('MM-DD-YYYY'),

          datos: {
            nroSolicitud: application.id,
            nroPlanilla: 10010111,
            motivo: motivo,
            nroFactura: `${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
            tipoTramite: `${application.codigoRamo} - ${application.descripcionRamo}`,
            cuentaOContrato: el.cuenta_contrato,
            tipoInmueble: el.tx_tp_inmueble,
            fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
            propietario: {
              rif: `${application.nacionalidad}-${application.documento}`,
              denomComercial: application.denominacionComercial,
              direccion: application.direccion,
              razonSocial: application.razonSocial,
            },
            items: breakdownData
              .filter((row) => row.id_inmueble === +el.co_inmueble)
              .map((row) => {
                return {
                  direccion: el.direccion_inmueble,
                  periodos: `${row.mes} ${row.anio}`.toUpperCase(),
                  impuesto: formatCurrency(row.monto),
                };
              }),
            totalIva: `${formatCurrency(totalIva)} Bs.S`,
            totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
            totalIvaPagar: `${formatCurrency(
              totalIva //TODO: Retencion
            )} Bs.S`,
            montoTotalImpuesto: `${formatCurrency(
              +breakdownData
                .filter((row) => row.id_inmueble === +el.co_inmueble)
                .map((row) => row.monto)
                .reduce((prev, next) => prev + next, 0) + totalIva
            )} Bs.S`,
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
                  .output('../../xd.pdf')
                  .then((buffer) => {
                    console.log('finalbuf', buffer);
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

//TODO: terminar esto
const createReceiptForAEApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const economicActivities = (await pool.query(queries.GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR, [application.contribuyente])).rows
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;
    const UTMM = (await pool.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const impuestoRecibo = UTMM * 2;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    moment.locale('es');
    let certInfoArray: any[] = [];
    let certAE;
    for(const el of breakdownData){
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
            let desglose = el.datos.desglose.find((d) => d.aforo === row.id);
            return {
            codigo: row.numeroReferencia,
            descripcion: row.descripcion,
            montoDeclarado: desglose.montoDeclarado,
            alicuota: row.alicuota / 100,
            minTrib: row.minimoTributable,
            impuesto: el.datos.montoCobrado || 0,
            }
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
      certAE.totalImpuestoDet = certAE.datos.items.reduce((prev, next) => prev + (+next.impuesto),0)

      certInfoArray.push(certAE)
    }
    


    return new Promise(async (res, rej) => {
      try {
        console.log('AAAAAAAA')
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-AE.pug`), certInfo));
        console.log(htmlArray.length)
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
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
        console.log(buffersArray)

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
                    console.log('a', buffer)
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
            rej(e)
          } finally {
          }
        }
      } catch (e) {
        rej({
          message: 'Error en generacion de certificado de AE',
          e: errorMessageExtractor(e),
        })
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

export const createAccountStatement = async ({ contributor, reference, typeUser }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const paymentState = switchcase({ ingresardatos: 'VIGENTE', validando: 'VIGENTE', finalizado: 'PAGADO' })(null);
    const contribuyente = (await client.query(queries.GET_CONTRIBUTOR_BY_ID, [contributor])).rows[0];
    const branch = reference && (await client.query('SELECT r.* FROM impuesto.registro_municipal r WHERE referencia_municipal = $1', [reference])).rows[0];
    const contributorQuery = typeUser === 'JURIDICO' ? queries.GET_SETTLEMENTS_FOR_CODE_AND_RIM : queries.GET_SETTLEMENTS_FOR_CODE_AND_CONTRIBUTOR;
    const contributorPayload = typeUser === 'JURIDICO' ? branch.referencia_municipal : contribuyente.id_contribuyente;
    const economicActivities = (
      await client.query(
        'SELECT id_actividad_economica AS id, ae.numero_referencia AS "numeroReferencia", descripcion as "nombreActividad", alicuota, minimo_tributable AS "minimoTributable" FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_contribuyente aec ON ae.numero_referencia = aec.numero_referencia WHERE aec.id_contribuyente = $1',
        [contribuyente.id_contribuyente]
      )
    ).rows;
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
      datosLiquidacion: statement,
      saldoFinal,
    };
    const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-EC.pug`), {
      ...datosCertificado,
      cache: false,
      moment: require('moment'),
      written,
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

const fixatedAmount = (num) => {
  return parseFloat(num.toPrecision(15)).toFixed(2);
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
            Key: '/sedemat/reportes/liquidaciones.pdf',
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
  IU: { recibo: createReceiptForSMOrIUApplication },
  PP: { recibo: createReceiptForPPApplication },
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
    AE: { aforo: breakdown.aforo, montoDeclarado: breakdown.montoDeclarado, montoCobrado: breakdown.montoCobrado },
    SM: { inmueble: breakdown.inmueble, montoAseo: +breakdown.montoAseo, montoGas: breakdown.montoGas },
    IU: { inmueble: breakdown.inmueble, monto: breakdown.monto },
    PP: { subarticulo: breakdown.subarticulo, monto: breakdown.monto, cantidad: breakdown.cantidad },
  })(null)(settlementType);
  return payload;
};

const certificateCreationHandler = async (process, media, payload: CertificatePayload) => {
  try {
    const result = certificateCases(process)[media];
    if (result) return await result(payload);
    throw new Error('No se encontró el tipo de certificado seleccionado');
  } catch (e) {
    console.log(e)
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
  datosLiquidacion: datoLiquidacion[];
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
