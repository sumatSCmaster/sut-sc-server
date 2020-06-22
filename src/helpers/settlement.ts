import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import GticPool from '@utils/GticPool';
import { insertPaymentReference } from './banks';
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
const formatCurrency = (number: number) => new Intl.NumberFormat('de-DE').format(number);

export const getSettlements = async ({ document, reference, type, user }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  const montoAcarreado: any = {};
  let AE, SM, IU, PP;
  try {
    const AEApplicationExists = (await client.query(queries.CURRENT_AE_APPLICATION_EXISTS, [document, reference, type])).rows[0];
    const SMApplicationExists = (await client.query(queries.CURRENT_SM_APPLICATION_EXISTS, [document, reference, type])).rows[0];
    const IUApplicationExists = (await client.query(queries.CURRENT_IU_APPLICATION_EXISTS, [document, reference, type])).rows[0];
    const PPApplicationExists = (await client.query(queries.CURRENT_PP_APPLICATION_EXISTS, [document, reference, type])).rows[0];

    if (AEApplicationExists && SMApplicationExists && IUApplicationExists && PPApplicationExists)
      return { status: 409, message: 'Ya existe una declaracion de impuestos para este mes' };
    const contributor = (reference
      ? await gtic.query(queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS, [document, reference, type])
      : await gtic.query(queries.gtic.NATURAL_CONTRIBUTOR_EXISTS, [document, type])
    ).rows[0];
    if (!contributor) return { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const now = moment(new Date());
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    //AE
    if (contributor.nu_referencia && !AEApplicationExists) {
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
            minimoTributable: Math.round(el.nu_ut) * UTMM,
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
    //SM
    const estates = (await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows;
    if (estates.length > 0) {
      if (!SMApplicationExists) {
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
            const calculoAseo =
              el.tx_tp_inmueble === 'COMERCIAL'
                ? el.nu_metro_cuadrado && el.nu_metro_cuadrado !== 0
                  ? 0.15 * el.nu_metro_cuadrado
                  : (await gtic.query(queries.gtic.GET_MAX_CLEANING_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa
                : (await gtic.query(queries.gtic.GET_RESIDENTIAL_CLEANING_TARIFF)).rows[0].nu_tarifa;
            const tarifaAseo = calculoAseo / UTMM > 300 ? UTMM * 300 : calculoAseo;
            const calculoGas =
              el.tx_tp_inmueble === 'COMERCIAL'
                ? (await gtic.query(queries.gtic.GET_MAX_GAS_TARIFF_BY_CONTRIBUTOR, [contributor.co_contribuyente])).rows[0].nu_tarifa
                : (await gtic.query(queries.gtic.GET_RESIDENTIAL_GAS_TARIFF)).rows[0].nu_tarifa;
            const tarifaGas = calculoGas / UTMM > 300 ? UTMM * 300 : calculoGas;
            return { id: el.co_inmueble, tipoInmueble: el.tx_tp_inmueble, direccionInmueble: el.tx_direccion, tarifaAseo, tarifaGas, deuda: debtSM };
          })
        );
      }

      //IU
      if (!IUApplicationExists) {
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
            return {
              id: el.co_inmueble,
              direccionInmueble: el.tx_direccion,
              ultimoAvaluo: el.nu_monto,
              impuestoInmueble: (el.nu_monto * 0.01) / 12,
              deuda: debtIU,
            };
          });
        }
      }
    }

    //PP
    if (!PPApplicationExists) {
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
        debtPP = new Array(now.month() + 1).fill({ month: null, year: null }).map((value, index) => {
          const date = addMonths(moment(`${now.year()}-01-01`).toDate(), index);
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
    }
    return {
      status: 200,
      message: 'Impuestos obtenidos satisfactoriamente',
      impuesto: {
        contribuyente: contributor.co_contribuyente,
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
        parroquia: naturalContributor.tx_direccion
          ? (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [naturalContributor.tx_direccion.split('Parroquia')[1].split('Sector')[0].trim()])).rows[0]
              .id || undefined
          : undefined,
        sector: nullStringCheck(naturalContributor.sector).trim(),
        direccion: naturalContributor.tx_direccion
          ? 'Avenida ' + naturalContributor.tx_direccion.split('Parroquia')[1].split('Avenida')[1].split('Pto')[0].trim().replace(/.$/, '')
          : undefined,
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
        parroquia: juridicalContributor.tx_direccion
          ? (await client.query(queries.GET_PARISH_BY_DESCRIPTION, [juridicalContributor.tx_direccion.split('Parroquia')[1].split('Sector')[0].trim()])).rows[0]
              .id || undefined
          : undefined,
        sector: nullStringCheck(juridicalContributor.sector).trim(),
        direccion: juridicalContributor.tx_direccion
          ? 'Avenida ' + juridicalContributor.tx_direccion.split('Parroquia')[1].split('Avenida')[1].split('Pto')[0].trim().replace(/.$/, '')
          : undefined,
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
    denomComercial: nullStringCheck(x.tx_denom_comercial),
    metrosCuadrados: +x.nu_metro_cuadrado,
    cuentaContrato: x.cuenta_contrato,
    nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined),
  };
};

const structureSettlements = (x: any) => {
  return {
    id: nullStringCheck(x.co_liquidacion),
    estado: nullStringCheck(x.co_estatus === 1 ? 'VIGENTE' : 'PAGADO'),
    ramo: nullStringCheck(x.tx_ramo),
    codigoRamo: nullStringCheck(x.nb_ramo),
    monto: nullStringCheck(x.nu_monto),
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

export const logInExternalLinking = async ({ credentials }) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const { attemptedUser, canBeLinked } = await externalUserForLinkingExists({ user: credentials.nombreUsuario, password: credentials.password, gtic });
    if (!canBeLinked) return { status: 403, message: 'Credenciales incorrectas' };
    const contributors = await Promise.all(
      (await gtic.query(queries.gtic.GET_CONTRIBUTOR_BY_REPRESENTATIVE_USER_EXTENDED, [attemptedUser.id_tb004_contribuyente])).rows
        .map(async (el) => {
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
                    const inmuebles = await Promise.all(
                      (await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j))
                    );
                    const liquidaciones = await Promise.all(
                      (await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j))
                    );
                    const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                    const multas = await Promise.all(
                      (await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j))
                    );
                    inmuebles.push({
                      id: x.co_contribuyente,
                      direccion: nullStringCheck(x.tx_direccion),
                      email: nullStringCheck(x.tx_email),
                      razonSocial: nullStringCheck(x.tx_razon_social),
                      denomComercial: nullStringCheck(x.tx_denom_comercial),
                      metrosCuadrados: 0.0,
                      cuentaContrato: 0.0,
                      nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
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
                      const inmuebles = await Promise.all(
                        (await gtic.query(queries.gtic.GET_ESTATES_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureEstates(j))
                      );
                      const liquidaciones = await Promise.all(
                        (await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureSettlements(j))
                      );
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows[0];
                      const multas = await Promise.all(
                        (await gtic.query(queries.gtic.GET_FININGS_BY_MUNICIPAL_REGISTRY, [x.nu_referencia])).rows.map((j) => structureFinings(j))
                      );

                      inmuebles.push({
                        id: x.co_contribuyente,
                        direccion: nullStringCheck(x.tx_direccion),
                        email: nullStringCheck(x.tx_email),
                        razonSocial: nullStringCheck(x.tx_razon_social),
                        denomComercial: nullStringCheck(x.tx_denom_comercial),
                        metrosCuadrados: 0.0,
                        cuentaContrato: 0.0,
                        nombreRepresentante: nullStringCheck(x.nb_representante_legal || undefined).trim(),
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
                      const liquidaciones = await Promise.all(
                        (await gtic.query(queries.gtic.GET_SETTLEMENTS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureSettlements(j))
                      );
                      const creditoFiscal = (await gtic.query(queries.gtic.GET_FISCAL_CREDIT_BY_CONTRIBUTOR, [x.co_contribuyente])).rows[0];
                      const inmuebles = await Promise.all(
                        (await gtic.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureEstates(j))
                      );
                      const multas = await Promise.all(
                        (await gtic.query(queries.gtic.GET_FININGS_BY_CONTRIBUTOR, [x.co_contribuyente])).rows.map((j) => structureFinings(j))
                      );
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

export const getApplicationsAndSettlementsById = async ({ id, user }): Promise<Solicitud> => {
  const client = await pool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application: Solicitud[] = await Promise.all(
      (await client.query(queries.GET_APPLICATION_BY_ID, [id])).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;
        return {
          id: el.id_solicitud,
          usuario: typeof user === 'object' ? user : { id: user },
          contribuyente: el.id_contribuyente,
          aprobado: el.aprobado,
          fecha: el.fecha,
          monto: (await client.query('SELECT SUM(monto) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1', [el.id_solicitud])).rows[0]
            .monto_total,
          liquidaciones: liquidaciones
            .filter((el) => el.tipoProcedimiento !== 'MUL')
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
            .filter((el) => el.tipoProcedimiento === 'MUL')
            .map((el) => {
              return {
                id: el.id_liquidacion,
                ramo: el.tipoProcedimiento,
                fecha: el.datos.fecha,
                monto: el.monto * UTMM,
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

        return {
          id: el.id_solicitud,
          usuario: user,
          contribuyente: el.id_contribuyente,
          aprobado: el.aprobado,
          fecha: el.fecha,
          monto: (await client.query('SELECT SUM(monto) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1', [el.id_solicitud])).rows[0]
            .monto_total,
          liquidaciones: liquidaciones
            .filter((el) => el.tipoProcedimiento !== 'MUL')
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
            .filter((el) => el.tipoProcedimiento === 'MUL')
            .map((el) => {
              return {
                id: el.id_liquidacion,
                ramo: el.tipoProcedimiento,
                fecha: el.datos.fecha,
                monto: el.monto * UTMM,
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
    const applications: Solicitud[] = await Promise.all(
      (typeUser === 'JURIDICO'
        ? await client.query(queries.GET_APPLICATION_INSTANCES_BY_CONTRIBUTOR, [referencia, document, docType])
        : await client.query(queries.GET_APPLICATION_INSTANCES_FOR_NATURAL_CONTRIBUTOR, [document, docType])
      ).rows.map(async (el) => {
        const liquidaciones = (await client.query(queries.GET_SETTLEMENTS_BY_APPLICATION_INSTANCE, [el.id_solicitud])).rows;

        return {
          id: el.id_solicitud,
          usuario: el.usuario,
          contribuyente: el.id_contribuyente,
          aprobado: el.aprobado,
          fecha: el.fecha,
          monto: (await client.query('SELECT SUM(monto) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1', [el.id_solicitud])).rows[0]
            .monto_total,
          liquidaciones: liquidaciones
            .filter((el) => el.tipoProcedimiento !== 'Multas')
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
            .filter((el) => el.tipoProcedimiento === 'Multas')
            .map((el) => {
              return {
                id: el.id_liquidacion,
                ramo: el.tipoProcedimiento,
                fecha: el.datos.fecha,
                monto: el.monto * UTMM,
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
  const { datosContribuyente, sucursales, datosContacto } = linkingData;
  const { tipoDocumento, documento, razonSocial, denomComercial, siglas, parroquia, sector, direccion, puntoReferencia } = datosContribuyente;
  let payload;
  try {
    client.query('BEGIN');
    const contributorExists = (await client.query(queries.TAX_PAYER_EXISTS, [tipoDocumento, documento])).rows;
    if (contributorExists.length > 0) {
      let hasNewCode;
      const rims: number[] = await Promise.all(
        await sucursales.map(async (el) => {
          const { datosSucursal } = el;
          const { nombreRepresentante, telefonoMovil, email, denomComercial, representado } = datosSucursal;
          const updatedRegistry = (
            await client.query(
              'UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4 WHERE id_contribuyente = $5 RETURNING *',
              [
                denomComercial,
                nombreRepresentante,
                representado ? datosContacto.telefono : telefonoMovil,
                representado ? datosContacto.correo : email,
                contributorExists[0].id_contribuyente,
              ]
            )
          ).rows[0];
          return representado ? updatedRegistry.id_registro_municipal : undefined;
        })
      );
      try {
        await resendCode(
          rims.filter((el) => el),
          VerificationValue.CellPhone
        );
        hasNewCode = true;
      } catch (e) {
        console.log(e.message);
        if (e.message === 'No existe una verificacion para la sucursal seleccionada')
          await sendRimVerification(
            rims.filter((el) => el),
            VerificationValue.CellPhone,
            datosContacto.telefono,
            client
          );
        else throw e;
        hasNewCode = true;
      }
      payload = { rims: rims.filter((el) => el) };
      return { status: 200, message: 'Datos actualizados para las sucursales del contribuyente', hasNewCode, payload };
    }
    const contributor = (
      await client.query(queries.CREATE_CONTRIBUTOR_FOR_LINKING, [
        tipoDocumento,
        documento,
        razonSocial,
        denomComercial,
        siglas,
        parroquia,
        sector,
        direccion,
        puntoReferencia,
        true,
      ])
    ).rows[0];
    await client.query('UPDATE USUARIO SET id_contribuyente = $1 WHERE id_usuario = $2', [contributor.id_contribuyente, user.id]);
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
            ])
          ).rows[0];
          const estates =
            inmuebles.length > 0
              ? await Promise.all(
                  inmuebles.map(
                    async (el) => (await client.query(queries.CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR, [registry.id_referencia_municipal, el.direccion])).rows[0]
                  )
                )
              : undefined;
          if (pagados.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'aprobacioncajero_pi']);
            await Promise.all(
              pagados.map(
                async (el) =>
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    el.monto,
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
              )
            );
          }

          if (vigentes.length > 0) {
            const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, contributor.id_contribuyente])).rows[0];
            await Promise.all(
              vigentes.map(
                async (el) =>
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    application.id_solicitud,
                    el.monto,
                    el.ramo,
                    { fecha: el.fecha },
                    moment().month(el.fecha.month).format('MM-DD-YYYY'),
                    registry.id_registro_municipal,
                  ])
              )
            );
          }
          return representado ? registry.id_registro_municipal : undefined;
        })
      );
      await sendRimVerification(
        rims.filter((el) => el),
        VerificationValue.CellPhone,
        datosContacto.telefono,
        client
      );
      payload = { rims: rims.filter((el) => el) };
    } else {
      sucursales.map((x) => {
        const { inmuebles, liquidaciones, multas, datosSucursal } = x;
        if (datosSucursal.hasOwnProperty('registroMunicipal')) {
        } else {
        }
      });
    }
    client.query('COMMIT');
    return { status: 201, message: 'Enlace inicial completado', rims: payload.rims };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al iniciar el enlace de usuario de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

export const verifyUserLinking = async ({ code, rims, user }) => {
  const client = await pool.connect();
  try {
    await verifyCode(rims, VerificationValue.CellPhone, code);
    return { status: 200, message: 'Usuario enlazado y verificado' };
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

export const resendUserCode = async ({ rims, user }) => {
  const client = await pool.connect();
  try {
    await resendCode(rims, VerificationValue.CellPhone);
    return { status: 200, message: 'Usuario enlazado y verificado' };
  } catch (error) {
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
    const contributorExists = (
      await client.query(
        'SELECT * FROM impuesto.contribuyente c INNER JOIN impuesto.registro_municipal rm ON c.id_contribuyente = rm.id_contribuyente WHERE rm.referencia_municipal = $1',
        [process.rim]
      )
    ).rows[0];
    if (!contributorExists) return { status: 404, message: 'No existe un contribuyente registrado en el sistema' };
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [user.id, process.rim])).rows[0];

    const hasAE = impuestos.find((el) => el.ramo === 'AE');
    if (hasAE) {
      const now = moment().locale('ES');
      const pivot = moment().locale('ES');
      const onlyAE = impuestos
        .filter((el) => el.ramo === 'AE')
        .sort((a, b) =>
          pivot.month(a.fechaCancelada.month).toDate() === pivot.month(b.fechaCancelada.month).toDate()
            ? 0
            : pivot.month(a.fechaCancelada.month).toDate() > pivot.month(b.fechaCancelada.month).toDate()
            ? 1
            : -1
        );
      const lastSavedFine = (await client.query(queries.GET_LAST_FINE_FOR_LATE_APPLICATION, [application.id_contribuyente])).rows[0];
      if (lastSavedFine && lastSavedFine.anio === now.year()) {
        finingAmount = lastSavedFine.monto;
        const proposedFiningDate = moment().locale('ES').month(onlyAE[0].fechaCancelada.month).month();
        const finingDate = moment().month(lastSavedFine.mes).month() < proposedFiningDate ? moment().month(lastSavedFine.mes).month() : proposedFiningDate;
        finingMonths = new Array(now.month() - finingDate).fill({});
        if (finingMonths.length > 0) {
          let counter = finingDate;
          finingMonths = await Promise.all(
            finingMonths.map((el, i) => {
              const multa = Promise.resolve(
                client.query(queries.CREATE_FINING_FOR_LATE_APPLICATION, [
                  application.id_solicitud,
                  finingAmount,
                  {
                    fecha: {
                      month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
                      year: now.year(),
                    },
                    descripcion: 'Multa por Declaracion Fuera de Plazo',
                  },
                  moment().month(counter).date(1).format('DD-MM-YYYY'),
                  contributorExists.id_registro_municipal,
                ])
              )
                .then((el) => el.rows[0])
                .then((data) => {
                  return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto * UTMM, descripcion: data.datos.descripcion };
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
              finingAmount,
              {
                fecha: {
                  month: moment().toDate().toLocaleDateString('ES', { month: 'long' }),
                  year: now.year(),
                },
                descripcion: 'Multa por Declaracion Fuera de Plazo',
              },
              moment().date(1).format('DD-MM-YYYY'),
              contributorExists.id_registro_municipal,
            ])
          ).rows[0];
          const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: multa.monto * UTMM, descripcion: multa.datos.descripcion };
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
                  finingAmount,
                  {
                    fecha: {
                      month: moment().month(counter).toDate().toLocaleDateString('ES', { month: 'long' }),
                      year: now.year(),
                    },
                    descripcion: 'Multa por Declaracion Fuera de Plazo',
                  },
                  moment().month(counter).date(1).format('DD-MM-YYYY'),
                  contributorExists.id_registro_municipal,
                ])
              )
                .then((el) => el.rows[0])
                .then((data) => {
                  return { id: data.id_liquidacion, fecha: data.datos.fecha, monto: +data.monto * UTMM, descripcion: data.datos.descripcion };
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
              finingAmount,
              {
                fecha: {
                  month: moment().toDate().toLocaleDateString('ES', { month: 'long' }),
                  year: now.year(),
                },
                descripcion: 'Multa por Declaracion Fuera de Plazo',
              },
              moment().date(1).format('DD-MM-YYYY'),
              contributorExists.id_registro_municipal,
            ])
          ).rows[0];
          const fine = { id: multa.id_liquidacion, fecha: multa.datos.fecha, monto: multa.monto * UTMM, descripcion: multa.datos.descripcion };

          finingAmount = finingAmount + augment < maxFining ? finingAmount + augment : maxFining;
          finingMonths.push(fine);
        }
      }
    }

    const settlement: Liquidacion[] = await Promise.all(
      impuestos.map(async (el) => {
        const datos = {
          desglose: el.desglose ? el.desglose.map((al) => breakdownCaseHandler(el.ramo, al)) : undefined,
          fecha: { month: el.fechaCancelada.month, year: el.fechaCancelada.year },
        };
        const liquidacion = (
          await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            application.id_solicitud,
            el.monto,
            el.ramo,
            datos,
            moment().month(el.fechaCancelada.month).date(1).format('DD-MM-YYYY'),
            contributorExists.id_registro_municipal,
          ])
        ).rows[0];

        return {
          id: liquidacion.id_liquidacion,
          tipoProcedimiento: el.ramo,
          fecha: datos.fecha,
          monto: liquidacion.monto,
          certificado: liquidacion.certificado,
          recibo: liquidacion.recibo,
          desglose: datos.desglose,
        };
      })
    );

    const solicitud: Solicitud = {
      id: application.id_solicitud,
      usuario: user,
      contribuyente: application.contribuyente,
      aprobado: application.aprobado,
      fecha: application.fecha,
      monto: application.monto_total,
      liquidaciones: settlement,
      multas: finingMonths,
    };
    await sendNotification(
      user,
      // `Se ha iniciado una solicitud para el contribuyente con el documento de identidad: ${solicitud.nacionalidad}-${solicitud.documento}`,
      'si',
      'CREATE_APPLICATION',
      'IMPUESTO',
      { ...solicitud, estado: 'ingresardatos', nombreCorto: 'SEDEMAT' },
      client
    );
    client.query('COMMIT');
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
    const solicitud = (await client.query(queries.GET_APPLICATION_BY_ID, [application])).rows[0];
    const pagoSum = payment.map((e) => e.costo).reduce((e, i) => e + i, 0);
    if (pagoSum < solicitud.monto_total) return { status: 401, message: 'La suma de los montos es insuficiente para poder insertar el pago' };
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
        await insertPaymentReference(el, application, client);
      })
    );
    await client.query(queries.UPDATE_PAID_STATE_FOR_TAX_PAYMENT_APPLICATION, [application]);
    const applicationInstance = await getApplicationsAndSettlementsById({ id: application, user });
    console.log(applicationInstance);
    await sendNotification(
      user,
      // `Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: ${applicationInstance.nacionalidad}-${applicationInstance.documento}`,
      'si',
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: 'validando', nombreCorto: 'SEDEMAT' },
      client
    );
    client.query('COMMIT');
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

export const validateApplication = async (body, user) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const solicitud = (await client.query(queries.GET_APPLICATION_BY_ID, [body.idTramite])).rows[0];
    const applicationInstance = await getApplicationsAndSettlementsById({ id: body.idTramite, user: solicitud.id_usuario });
    applicationInstance.aprobado = true;
    await sendNotification(
      user,
      // `Se ha finalizado una solicitud de pago de impuestos para el contribuyente: ${applicationInstance.nacionalidad}-${applicationInstance.documento}`,
      'si',
      'UPDATE_APPLICATION',
      'IMPUESTO',
      { ...applicationInstance, estado: 'finalizado', nombreCorto: 'SEDEMAT' },
      client
    );
    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al validar el pago',
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
      error: errorMessageExtractor(error),
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
    throw errorMessageExtractor(error);
  }
};

const createReceiptForSMOrIUApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    console.log('culo');
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical
      ? [application.documento, application.rim, application.nacionalidad]
      : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const inmueblesContribuyente = (await gticPool.query(queries.gtic.GET_ESTATES_BY_CONTRIBUTOR, [datosContribuyente.co_contribuyente])).rows;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    let certInfo;
    let motivo;
    let ramo;
    let certInfoArray: any[] = [];
    console.log('appli', application);
    if (application.tipoLiquidacion === 'SM') {
      motivo = (await gticPool.query(queries.gtic.GET_MOTIVE_BY_TYPE_ID, [idTiposSolicitud.SM])).rows[0];
      ramo = (await gticPool.query(queries.gtic.GET_BRANCH_BY_TYPE_ID, [idTiposSolicitud.SM])).rows[0];
      const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID('SM'), [application.id])).rows;
      const totalIva =
        +breakdownData.map((row) => (row.monto_gas ? +row.monto_aseo + +row.monto_gas : +row.monto_aseo)).reduce((prev, next) => prev + next, 0) * 0.16;
      const totalMonto = +breakdownData
        .map((row) => (row.monto_gas ? +row.monto_aseo + +row.monto_gas : +row.monto_aseo))
        .reduce((prev, next) => prev + next, 0);
      console.log('culo2');
      console.log(breakdownData);
      console.log(totalIva, totalMonto);
      for (const el of inmueblesContribuyente) {
        console.log('AAAAAAAAAAAAAAAAAAA');
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('DD-MM-YYYY'),

          datos: {
            nroSolicitud: 856535, //TODO: Reemplazar con el valor de co_solicitud creado en GTIC
            nroPlanilla: 10010111, //TODO: Ver donde se guarda esto
            motivo: motivo.tx_motivo,
            nroFactura: `${application.anio}-${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
            tipoTramite: `${ramo.nb_ramo} - ${ramo.tx_ramo}`,
            cuentaOContrato: el.cuenta_contrato,
            tipoInmueble: el.tx_tp_inmueble,
            fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
            propietario: {
              rif: `${application.nacionalidad}-${application.documento}`,
              denomComercial: datosContribuyente.tx_denom_comercial,
              direccion: datosContribuyente.tx_direccion,
              razonSocial: isJuridical
                ? datosContribuyente.tx_razon_social
                : datosContribuyente.nb_contribuyente.trim() + datosContribuyente.ap_contribuyente.trim(),
            },
            items: breakdownData
              .filter((row) => row.id_inmueble === +el.co_inmueble)
              .map((row) => {
                return {
                  direccion: el.direccion_inmueble,
                  periodos: `${row.mes} ${row.anio}`.toUpperCase(),
                  impuesto: row.monto_gas ? formatCurrency(+row.monto_gas + +row.monto_aseo) : formatCurrency(row.monto_aseo),
                };
              }),
            totalIva: `${formatCurrency(totalIva)} Bs.S`,
            totalRetencionIva: '0,00 Bs.S ', // TODO: Retencion
            totalIvaPagar: `${formatCurrency(totalIva)} Bs.S`,
            montoTotalImpuesto: `${formatCurrency(
              +breakdownData
                .filter((row) => row.id_inmueble === +el.co_inmueble)
                .map((row) => (row.monto_gas ? +row.monto_aseo + +row.monto_gas : +row.monto_aseo))
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
        console.log('bbbBBBBBBBBBBBBB');
        console.log(certInfo);
        certInfoArray.push({ ...certInfo });
      }
    } else if (application.tipoLiquidacion === 'IU') {
      motivo = (await gticPool.query(queries.gtic.GET_MOTIVE_BY_TYPE_ID, [idTiposSolicitud.IU])).rows[0];
      ramo = (await gticPool.query(queries.gtic.GET_BRANCH_BY_TYPE_ID, [idTiposSolicitud.IU])).rows[0];
      const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID('IU'), [application.id])).rows;
      const totalIva = breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0) * 0.16;
      const totalMonto = +breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0);
      console.log('culo2');
      console.log(breakdownData);
      console.log(totalIva, totalMonto);
      for (const el of inmueblesContribuyente) {
        console.log('AAAAAAAAAAAAAAAAAAA');
        certInfo = {
          QR: linkQr,
          moment: require('moment'),
          fecha: moment().format('DD-MM-YYYY'),

          datos: {
            nroSolicitud: 856535, //TODO: Reemplazar con el valor de co_solicitud creado en GTIC
            nroPlanilla: 10010111, //TODO: Ver donde se guarda esto
            motivo: motivo.tx_motivo,
            nroFactura: `${application.anio}-${new Date().getTime().toString().slice(5)}`, //TODO: Ver como es el mani con esto
            tipoTramite: `${ramo.nb_ramo} - ${ramo.tx_ramo}`,
            cuentaOContrato: el.cuenta_contrato,
            tipoInmueble: el.tx_tp_inmueble,
            fechaCre: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaLiq: moment(application.fechaCreacion).format('DD/MM/YYYY'),
            fechaVenc: moment(application.fechaCreacion).endOf('month').format('DD/MM/YYYY'),
            propietario: {
              rif: `${application.nacionalidad}-${application.documento}`,
              denomComercial: datosContribuyente.tx_denom_comercial,
              direccion: datosContribuyente.tx_direccion,
              razonSocial: isJuridical
                ? datosContribuyente.tx_razon_social
                : datosContribuyente.nb_contribuyente.trim() + datosContribuyente.ap_contribuyente.trim(),
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
        console.log('bbbBBBBBBBBBBBBB');
        console.log(certInfo);
        certInfoArray.push({ ...certInfo });
      }
    }

    return new Promise(async (res, rej) => {
      try {
        console.log('XD');
        console.log(inmueblesContribuyente[0]);
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-SM.pug`), certInfo));
        console.log('auxilio');
        const pdfDir = resolve(__dirname, `../../archivos/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/sedemat/${application.id}/SM/${application.idLiquidacion}/recibo.pdf`;
        const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/sedemat/${application.id}`, { errorCorrectionLevel: 'H' });

        if (dev) {
          let buffersArray = await Promise.all(
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
                      console.log(err);
                      rej(err);
                    } else {
                      res(buffer);
                      console.log('buffer');
                    }
                  });
              });
            })
          );
          console.log(buffersArray);

          mkdir(dirname(pdfDir), { recursive: true }, (e) => {
            if (e) {
              console.log(e);
              rej(e);
            } else {
              if (buffersArray.length === 1) {
                writeFile(pdfDir, buffersArray[0], async (err) => {
                  if (err) {
                    console.log(err);
                    rej(err);
                  } else {
                    console.log('suicidio');
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
                console.log('red', reduced);
                console.log('ke', Object.keys(reduced).join(' '));
                pdftk
                  .input(reduced)
                  .cat(`${Object.keys(reduced).join(' ')}`)
                  .output('/home/eabs/Documents/xd.pdf', pdfDir)
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
            // pdf
            //   .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
            //   .toBuffer(async (err, buffer) => {
            //     if (err) {
            //       rej(err);
            //     } else {
            //       const bucketParams = {
            //         Bucket: 'sut-maracaibo',
            //         Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
            //       };
            //       await S3Client.putObject({
            //         ...bucketParams,
            //         Body: buffer,
            //         ACL: 'public-read',
            //         ContentType: 'application/pdf',
            //       }).promise();
            //       res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            //     }
            //   });
          } catch (e) {
            throw e;
          } finally {
          }
        }
      } catch (e) {
        console.log('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        console.log(e);
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
    throw errorMessageExtractor(error);
  }
};

const createReceiptForPPApplication = async ({ gticPool, pool, user, application }: CertificatePayload) => {
  try {
    const isJuridical = application.tipoContribuyente === 'JURIDICO';
    const queryContribuyente = isJuridical ? queries.gtic.JURIDICAL_CONTRIBUTOR_EXISTS : queries.gtic.NATURAL_CONTRIBUTOR_EXISTS;
    const payloadContribuyente = isJuridical
      ? [application.documento, application.rim, application.nacionalidad]
      : [application.nacionalidad, application.nacionalidad];
    const datosContribuyente = (await gticPool.query(queryContribuyente, payloadContribuyente)).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarSedemat/${application.id}`, { errorCorrectionLevel: 'H' });
    let motivo = (await gticPool.query(queries.gtic.GET_MOTIVE_BY_TYPE_ID, [idTiposSolicitud.PP])).rows[0];
    let ramo = (await gticPool.query(queries.gtic.GET_BRANCH_BY_TYPE_ID, [idTiposSolicitud.PP])).rows[0];
    const subarticulos = (await gticPool.query(queries.gtic.GET_PUBLICITY_SUBARTICLES)).rows;
    const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID('PP'), [application.id])).rows;
    const totalIva = +breakdownData.map((row) => row.monto).reduce((prev, next) => +prev + +next, 0) * 0.16;
    const totalMonto = +breakdownData.map((row) => row.monto).reduce((prev, next) => prev + next, 0);
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cert-PP.pug`), {
        QR: linkQr,
        moment: require('moment'),
        fecha: moment().format('DD-MM-YYYY'),

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
            razonSocial: isJuridical
              ? datosContribuyente.tx_razon_social
              : datosContribuyente.nb_contribuyente.trim() + datosContribuyente.ap_contribuyente.trim(),
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
        pdf
          .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
          .toFile(pdfDir, async () => {
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
    throw errorMessageExtractor(error);
  }
};

export const createAccountStatement = async (contributor) => {
  const client = await pool.connect();
  const gtic = await gticPool.connect();
  try {
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const contribuyente = (await gtic.query(queries.gtic.GET_CONTRIBUTOR_BY_ID, [contributor])).rows[0];
    const economicActivities = (await gtic.query(queries.gtic.CONTRIBUTOR_ECONOMIC_ACTIVITIES, [contributor])).rows;
    const ae = (await client.query(queries.GET_AE_SETTLEMENTS_FOR_CONTRIBUTOR, [contributor])).rows.map((el) => {
      const activity = economicActivities.find((x) => x.nu_ref_actividad.endsWith(el.id_aforo));
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fechaCreacion).month(el.mes).year(el.anio).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fechaLiquidacion).endOf('month').format('DD/MM/YYYY'),
        motivo: el.tipoLiquidacion,
        estado: el.aprobado && el.pagado ? 'PAGADO' : el.pagado ? 'VALIDANDO' : 'VIGENTE',
        montoPorcion:
          activity && parseInt(activity.nu_ut) * UTMM > parseFloat(el.monto_declarado) ? parseInt(activity.nu_ut) * UTMM : parseFloat(el.monto_declarado),
      };
    });
    const sm = (await client.query(queries.GET_SM_SETTLEMENTS_FOR_CONTRIBUTOR, [contributor])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fechaCreacion).month(el.mes).year(el.anio).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fechaLiquidacion).endOf('month').format('DD/MM/YYYY'),
        motivo: el.tipoLiquidacion,
        estado: el.aprobado && el.pagado ? 'PAGADO' : el.pagado ? 'VALIDANDO' : 'VIGENTE',
        montoPorcion: +el.monto_gas + +el.monto_aseo,
      };
    });
    const iu = (await client.query(queries.GET_IU_SETTLEMENTS_FOR_CONTRIBUTOR, [contributor])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fechaCreacion).month(el.mes).year(el.anio).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fechaLiquidacion).endOf('month').format('DD/MM/YYYY'),
        motivo: el.tipoLiquidacion,
        estado: el.aprobado && el.pagado ? 'PAGADO' : el.pagado ? 'VALIDANDO' : 'VIGENTE',
        montoPorcion: parseFloat(el.monto),
      };
    });
    const pp = (await client.query(queries.GET_PP_SETTLEMENTS_FOR_CONTRIBUTOR, [contributor])).rows.map((el) => {
      return {
        planilla: new Date().getTime().toString().substr(6),
        solicitud: el.id,
        porcion: '1/1',
        fechaLiquidacion: moment(el.fechaCreacion).month(el.mes).year(el.anio).format('DD/MM/YYYY'),
        fechaVencimiento: moment(el.fechaLiquidacion).endOf('month').format('DD/MM/YYYY'),
        motivo: el.tipoLiquidacion,
        estado: el.aprobado && el.pagado ? 'PAGADO' : el.pagado ? 'VALIDANDO' : 'VIGENTE',
        montoPorcion: parseFloat(el.monto),
      };
    });
    const datosContribuyente = {
      nombreORazon: contribuyente.tx_razon_social || `${contribuyente.nb_contribuyente} ${contribuyente.ap_contribuyente}`,
      cedulaORif: contribuyente.tx_rif ? `${contribuyente.tx_tp_doc}-${contribuyente.tx_rif}` : `${contribuyente.tx_tp_doc}-${contribuyente.nu_cedula}`,
      rim: contribuyente.nu_referencia,
      direccion: contribuyente.tx_direccion,
      telefono: contribuyente.nu_telf_movil || contribuyente.nu_telf_hab,
    };
    const actividadesContribuyente = economicActivities.map((el) => ({ id: el.co_actividad, nombreActividad: el.tx_actividad }));
    const statement = ae
      .concat(sm)
      .concat(iu)
      .concat(pp)
      .filter((el) => el)
      .sort((a, b) => (a.fechaLiquidacion === b.fechaLiquidacion ? 0 : a.fechaLiquidacion > b.fechaLiquidacion ? 1 : -1));
    const saldoFinal = statement
      .map((e) => switchcase({ PAGADO: e.montoPorcion, VIGENTE: -e.montoPorcion, VALIDANDO: 0 })(null)(e.estado))
      .reduce((e, x) => e + x, 0);
    const datosCertificado: accountStatement = {
      actividadesContribuyente,
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

const breakdownCaseHandler = (settlementType, breakdown) => {
  // const query = breakdownCases(settlementType);
  const payload = switchcase({
    AE: { aforo: breakdown.aforo, montoDeclarado: breakdown.montoDeclarado },
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
