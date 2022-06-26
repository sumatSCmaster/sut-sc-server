import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import { fixatedAmount, isExonerated } from './settlement';
import { uniqBy } from 'lodash';
import { resolve } from 'path';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import { writeFile, mkdir } from 'fs';
import { dirname } from 'path';
import * as qr from 'qrcode';
import * as pdftk from 'node-pdftk';
import S3Client from '@utils/s3';
import { mainLogger } from '@utils/logger';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

const template = async (props) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return { status: 200, message: '' };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getDataForDefinitiveDeclaration = async ({ document, reference, docType }) => {
  const client = await pool.connect();
  const breakdownArray: any[] = [];
  try {
    const now = moment(new Date());
    const proposedYear = now.clone().subtract(1, 'year');
    if (!reference) throw { status: 403, message: 'Debe incluir un RIM' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en HACIENDA' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'No existe el RIM proporcionado' };
    const lastYearDeclaration = (await client.query(queries.ALL_YEAR_SETTLEMENTS_EXISTS_FOR_LAST_YEAR_AE_DECLARATION, [codigosRamo.AE, branch.id_registro_municipal, proposedYear.year()])).rows;
    const definitiveDeclaration = uniqBy(lastYearDeclaration, (settlement) => settlement.datos.fecha.month)
      .filter((el) => !!el.datos.desglose)
      .sort((a, b) => (moment().locale('ES').month(a.datos.fecha.month).year(a.datos.fecha.year).isBefore(moment().locale('ES').month(b.datos.fecha.month).year(b.datos.fecha.year)) ? 1 : -1));
    if (definitiveDeclaration.length === 0) throw { status: 409, message: 'Debe poseer declaraciones de AE correspondientes al año previo para generar el certificado' };
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    const solvencyCost = branch?.estado_licencia === 'PERMANENTE' ? +(await client.query(queries.GET_SCALE_FOR_PERMANENT_AE_SOLVENCY)).rows[0].indicador : +(await client.query(queries.GET_SCALE_FOR_PROVISIONAL_AE_SOLVENCY)).rows[0].indicador;
    const liquidaciones = await Promise.all(
      definitiveDeclaration.map(async (el) => {
        const startingDate = moment().locale('ES').month(el.datos.fecha.month).year(el.datos.fecha.year).startOf('month');
        el.datos.desglose = await Promise.all(
          el.datos.desglose.map(async (d) => {
            const aforo = (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_ID, [d.aforo])).rows[0];
            const exonerado = await isExonerated({ branch: 112, contributor: branch?.id_registro_municipal, activity: aforo.id_actividad_economica, startingDate }, client);
            return {
              id: aforo.id_actividad_economica,
              minTrib: Math.round(aforo.minimo_tributable) * PETRO,
              descripcion: aforo.descripcion,
              codigo: aforo.numero_referencia,
              // idContribuyente: +branch.id_registro_municipal,
              alicuota: aforo.alicuota / 100,
              exonerado,
              montoDeclarado: fixatedAmount(d.montoDeclarado),
              impuesto: d.montoCobrado,
              costoSolvencia: PETRO * solvencyCost,
            };
          })
        );
        breakdownArray.push(el.datos.desglose);
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

    const totalLiquidado = fixatedAmount(breakdownArray.flat().reduce((x, j) => x + j.montoDeclarado, 0));
    const totalPagado = fixatedAmount(breakdownArray.flat().reduce((x, j) => x + j.impuesto, 0));
    const ramo = (await client.query(`SELECT descripcion FROM impuesto.ramo WHERE descripcion_corta = 'AE'`)).rows[0].descripcion;
    const contribuyente = {
      id: branch.id_registro_municipal,
      rif: `${contributor.tipo_documento}-${contributor.documento}`,
      ref: branch.referencia_municipal,
      razonSocial: branch.denominacion_comercial,
      direccion: branch.direccion || 'Dirección Sin Asignar',
      anio: proposedYear.year(),
    };

    const payload = {
      liquidaciones,
      contribuyente,
      totalLiquidado,
      totalPagado,
      ramo,
    };

    const recibo = await createReceiptForAEApplication(payload);

    return { status: 200, message: 'Declaraciones previas obtenidas', data: recibo };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener declaraciones previas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const insertDefinitiveYearlyDeclaration = async ({ process, user }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return { status: 200, message: 'Declaracion anual creada' };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al insertar declaracion definitiva anual',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param payload
 */
const createReceiptForAEApplication = async (payload: { liquidaciones; contribuyente; totalLiquidado; totalPagado; ramo }) => {
  const { liquidaciones, contribuyente, totalLiquidado, totalPagado, ramo } = payload;
  try {
    // if (application.idSubramo === 23) throw new Error('No es una liquidacion admisible para generar recibo');
    // const breakdownData = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, application.idSubramo])).rows;

    // const PETRO = (await pool.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;

    // const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [application.idLiquidacion])).rows[0];
    // const economicActivities = (await pool.query(queries.GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR, [referencia.id_registro_municipal])).rows;
    // const taxSettlement = (await pool.query(queries.GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID, [application.id, 100])).rows[0];
    // const impuestoRecibo = taxSettlement?.monto || PETRO * 2;
    moment.locale('es');
    let certInfoArray: any[] = [];
    let certAE;
    for (const el of liquidaciones) {
      mainLogger.info('el', el, el.datos);
      certAE = {
        fecha: moment().format('YYYY-MM-DD'),
        tramite: 'PAGO DE IMPUESTOS',
        moment: require('moment'),
        institucion: 'HACIENDA',
        datos: {
          nroSolicitud: el.id,
          nroPlanilla: new Date().getTime().toString().slice(7),
          motivo: `D${el.datos.fecha.month.substr(0, 3).toUpperCase()}${el.datos.fecha.year}`,
          porcion: '1/1',
          categoria: ramo,
          rif: contribuyente.rif,
          ref: contribuyente.ref,
          razonSocial: contribuyente.razonSocial,
          direccion: contribuyente.direccion || 'Dirección Sin Asignar',
          // fechaCre: moment(application.fechaCreacion).format('YYYY-MM-DD'),
          // fechaLiq: moment().format('YYYY-MM-DD'),
          // fechaVenc: moment().date(31).format('YYYY-MM-DD'),
          items: el.datos.desglose,

          // tramitesInternos: +impuestoRecibo,
          totalTasaRev: 0.0,
          anticipoYRetenciones: 0.0,
          interesMora: 0.0,
          montoTotal: fixatedAmount(el.datos.desglose.reduce((x, j) => x + j.impuesto, 0)),
          observacion: `ACTIVIDADES ECONOMICAS EN EL AÑO FISCAL, MES DE ${el.datos.fecha.month.toUpperCase()}`,
          // estatus: 'PAGADO',
          totalLiq: totalLiquidado,
          totalRecaudado: totalPagado,
          totalCred: 0.0,
        },
      };
      certAE.totalImpuestoDet = certAE.datos.items.reduce((prev, next) => prev + +next.impuesto, 0);

      certInfoArray.push(certAE);
    }

    return new Promise(async (res, rej) => {
      try {
        let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/hacienda-cert-DAE.pug`), certInfo));
        const pdfDir = resolve(__dirname, `../../archivos/hacienda/definitive-declaration/AE/${contribuyente.anio}/${contribuyente.id}/recibo.pdf`);
        const dir = `${process.env.SERVER_URL}/hacienda/definitive-declaration/AE/${contribuyente.anio}/${contribuyente.id}/recibo.pdf`;
        // const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/hacienda/${application.id}`, { errorCorrectionLevel: 'H' });
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
                    res(dir);
                  })
                  .catch((e) => {
                    mainLogger.error(e);
                    rej(e);
                  });
              }
            }
          });
        } else {
          try {
            if (buffersArray.length === 1) {
              const bucketParams = {
                Bucket: process.env.BUCKET_NAME as string,
                Key: `/hacienda/definitive-declaration/AE/${contribuyente.anio}/${contribuyente.id}/recibo.pdf`,
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
                    Bucket: process.env.BUCKET_NAME as string,
                    Key: `/hacienda/definitive-declaration/AE/${contribuyente.anio}/${contribuyente.id}/recibo.pdf`,
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
                  mainLogger.error(e);
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

    //   // const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-cert-AE.pug`), certAE);
    //   // const pdfDir = resolve(__dirname, `../../archivos/hacienda/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`);
    //   // const dir = `${process.env.SERVER_URL}/hacienda/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`;
    //   // const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/hacienda/${application.id}`, { errorCorrectionLevel: 'H' });
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
    //   //           Bucket: process.env.BUCKET_NAME as string,

    //   //           Key: `/hacienda/${application.id}/AE/${application.idLiquidacion}/recibo.pdf`,
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

const codigosRamo = {
  AE: 112,
  SM: 122,
  MUL: 501,
  PP: 114,
  IU: 111,
  RD0: 915,
};
