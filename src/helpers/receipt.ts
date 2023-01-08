import { dirname, resolve } from 'path';
import { mkdir, writeFile } from 'fs';
import * as pdftk from 'node-pdftk';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import { chunk, round } from 'lodash';
import { mainLogger } from '@utils/logger';
import { collapseTextChangeRangesAcrossMultipleVersions } from 'typescript';
const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const generateReceipt = async (payload: { application: number }, clientParam?) => {
  const client = clientParam ? clientParam : await pool.connect();
  try {
    const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_ID, [payload.application])).rows[0];
    const direccionRim = (await client.query(queries.GET_RIM_DIR_BY_SOL_ID, [payload.application]))?.rows[0]?.direccion;
    const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE, [applicationView.id])).rows;
    const paymentRows = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [applicationView.id, 'IMPUESTO'])).rows;
    const paymentRowsDescDate = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_DESC_DATE, [applicationView.id, 'IMPUESTO'])).rows;
    const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
    const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
    let breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
    const recibo = await client.query(queries.INSERT_RECEIPT_RECORD, [
      paymentRows[0]?.id_usuario,
      `${process.env.AWS_ACCESS_URL}/hacienda/recibo/${applicationView.id}/recibo.pdf`,
      applicationView.razonSocial,
      referencia?.referencia_municipal,
      'IMPUESTO',
      applicationView.id,
    ]);
    if (!recibo.rows[0]) {
      return (await client.query(`SELECT recibo FROM impuesto.registro_recibo WHERE id_solicitud = $1 AND recibo != ''`, [applicationView.id])).rows[0].recibo;
    }
    const idRecibo = recibo.rows[0].id_registro_recibo;
    // applications.map((a) => {
    //   a.montout = a.porciones.reduce((prev, next) => prev + +next.montout, 0);
    //   return {...a};
    // })

    breakdownData.map( async (el) => {
      let base = 1;
      const ramosPublicidad = [
        'ART. 63-1 EXHIBICIÓN DE PROPAGANDA O PUBLICIDAD COMERCIAL A TRAVÉS DE VALLAS, POSTES PUBLICITARIOS, COLUMNAS INFORMATIVAS, CORTINAS Y ALFOMBRAS, INSTALACIONES PARA EL COMERCIO TEMPORAL Y EVENTUAL',
        'ART. 63-5 EXHIBICIÓN DE PROPAGANDA O PUBLICIDAD COMERCIAL A TRAVÉS DE AVISOS FIJOS INTERNOS, NEVERAS, MUEBLES, ALFOMBRAS INTERNAS Y SIMILARES',
        'ART. 63-15 EXHIBICIÓN DE PUBLICIDAD IMPRESA O SOBREPUESTA EN LA SUPERFICIE DE VEHÍCULOS DE USO PARTICULAR Y TAXIS'
      ];
      let ramo = el.descripcionRamo || '';
      let today = moment(paymentRowsDescDate[0]?.fecha_de_pago);
      
      if(ramo === 'VH' || ramo === 'PATENTE DE VEHICULO') {
        if(el.datos?.fecha?.year === 2023 && today.get('month') <= 2 && today.get('year') === 2023){
          base = base - 0.20;
        }
      }
      else if(ramosPublicidad.includes(ramo)){
        if(moment(el.fechaLiquidacion).get('month') <= 1 && moment(el.fechaLiquidacion).get('year') === 2023 && today.get('month') <= 1 && today.get('year') === 2023) {
          if(today.get('month') === 0){
            base = base - 0.15;
          }
          else if (today.get('month') === 1){
            base = base - 0.10;
          }
        }
      }
      else if(ramo === 'IU' || ramo === 'INMUEBLES URBANOS'){
        //check if all iu 2023 present
        const firstS = breakdownData.find((l) => l.datos?.fecha?.month === 'Primer Trimestre' && l.datos?.fecha?.year === 2023 );
        const secondS = breakdownData.find((l) => l.datos?.fecha?.month === 'Segundo Trimestre' && l.datos?.fecha?.year === 2023 );
        const thirdS = breakdownData.find((l) => l.datos?.fecha?.month === 'Tercer Trimestre' && l.datos?.fecha?.year === 2023 );
        const fourthS = breakdownData.find((l) => l.datos?.fecha?.month === 'Cuarto Trimestre' && l.datos?.fecha?.year === 2023 );
        const anualS = breakdownData.find((l) => l.datos?.fecha?.month === 'Anual' && l.datos?.fecha?.year === 2023 );

        const applyDiscount = ((firstS && secondS && thirdS && fourthS) || anualS) && (el.datos?.fecha?.year === 2023 && today.get('month') <= 2 && today.get('year') === 2023);

        if(applyDiscount) {
          const esEjido = (await client.query(queries.GET_ESTATE_BY_ID, [el.datos?.desglose[0]?.inmueble])).rows[0]?.clasificacion === 'EJIDO';
          if(esEjido) {
            base = base - 0.10;
          }
          else if (today.get('month') === 0) {
            base = base - 0.25;
          }
          else if (today.get('month') === 1) {
            base = base - 0.15;
          }
          else if (today.get('month') === 2) {
            base = base - 0.10;
          }
        }
      }
      el.montoConDescuento = base !== 1 ? round(el.monto * base,4) : 0;
      el.diferencia = base !== 1 ? round(el.monto * (1 - base),2) : 0;
      return {...el}
    });

    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/recibo/${applicationView.id}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/recibo/${applicationView.id}/recibo.pdf`;
      let total = breakdownData.reduce((prev, next) =>  prev + +next.monto, 0);
      let totalReal = round(breakdownData.reduce((prev, next) =>  prev + +( next.montoConDescuento !== 0 ? next.montoConDescuento : next.monto), 0),2);
      let diferencia = round(total - totalReal,2);
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/hacienda/recibo/${applicationView.id}/recibo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-recibo.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        QR: linkQr,
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: direccionRim || applicationView.direccion,
          cajero: cashier?.[0]?.nombreCompleto,
          codigoRecibo: String(idRecibo).padStart(16, '0'),
          rim: referencia?.referencia_municipal,
          telefono: referencia?.telefono_celular,
          items: chunk(
            await Promise.all(breakdownData.map(async(row) => {
              const direccion = row.descripcionRamo === 'INMUEBLES URBANOS' && row.datos?.desglose[0]?.inmueble ? (await client.query('SELECT direccion FROM inmueble_urbano WHERE id_inmueble = $1', [row.datos?.desglose[0]?.inmueble])).rows[0]?.direccion : '';
              return {
                descripcion: `${row.datos.descripcion ? row.datos.descripcion : `${row.descripcionRamo} - ${row.descripcionSubramo}`} (${row.datos.fecha.month} ${row.datos.fecha.year}) ${direccion}`,
                fecha: row.fechaLiquidacion,
                monto: row.montoConDescuento !== 0 ? round(row.montoConDescuento,2) : row.monto,
                diferencia: row.diferencia,
              };
            })),
            14
          ),
          metodoPago: payment,
          total: totalReal !== 0 ? totalReal : total,
          credito: (paymentTotal - (totalReal !== 0 ? totalReal : total)) < 0.01 ? 0 : paymentTotal - (totalReal !== 0 ? totalReal : total),
          diferencia: diferencia,
        },
      });
      if (dev) {
        pdf
          .create(html, {
            format: 'Letter',
            border: '5mm',
            header: { height: '0px' },
            base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
          })
          .toFile(pdfDir, async () => {
            res(dir);
          });
      } else {
        try {
          pdf
            .create(html, {
              format: 'Letter',
              border: '5mm',
              header: { height: '0px' },
              base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
            })
            .toBuffer(async (err, buffer) => {
              if (err) {
                rej(err);
              } else {
                const regClient = await pool.connect();
                try {
                  await regClient.query('BEGIN');
                  const bucketParams = {
                    Bucket: process.env.BUCKET_NAME as string,
                    Key: `hacienda/recibo/${applicationView.id}/recibo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  //await regClient.query(queries.UPDATE_RECEIPT_RECORD, [idRecibo, `${process.env.AWS_ACCESS_URL}${bucketParams.Key}`]);
                  await regClient.query('COMMIT');
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                } catch (e) {
                  await regClient.query('ROLLBACK');
                  rej(e);
                } finally {
                  regClient.release();
                }
              }
            });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    if (!clientParam) await client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  } finally {
    if (!clientParam) client.release();
  }
};

export const generateReceiptAgreement = async (payload: { agreement: number }, clientParam?) => {
  const client = clientParam ? clientParam : await pool.connect();
  try {
    await client.query('REFRESH MATERIALIZED VIEW impuesto.solicitud_view');
    const applicationView = (await client.query(queries.GET_AGREEMENT_VIEW_BY_FRACTION_ID_FIX, [payload.agreement])).rows[0];
    const direccionRim = (await client.query(queries.GET_RIM_DIR_BY_FRA_ID, [payload.agreement]))?.rows[0]?.direccion;
    const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE_AGREEMENT, [applicationView.id_fraccion])).rows;
    const paymentRows = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [applicationView.id_fraccion, 'CONVENIO'])).rows;
    const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
    const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
    const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
    const recibo = await client.query(queries.INSERT_AGREEMENT_RECEIPT_RECORD, [
      paymentRows[0]?.id_usuario,
      `${process.env.AWS_ACCESS_URL}//hacienda/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`,
      applicationView.razonSocial,
      referencia?.referencia_municipal,
      'CONVENIO',
      applicationView.id_fraccion,
    ]);
    if (!recibo.rows[0]) {
      return (await client.query(`SELECT recibo FROM impuesto.registro_recibo_convenio WHERE id_fraccion = $1 AND recibo != ''`, [applicationView.id_fraccion])).rows[0].recibo;
    }
    const idRecibo = recibo.rows[0].id_registro_recibo_convenio;

    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/recibo/agreement/${applicationView.id_fraccion}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`;
      const date = moment(applicationView.fechaCreacion).locale('ES');
      let total = breakdownData.reduce((prev, next) => prev + +next.monto, 0);
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/hacienda/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RC.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        QR: linkQr,
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: direccionRim || applicationView.direccion,
          cajero: cashier?.[0]?.nombreCompleto,
          codigoRecibo: String(idRecibo).padStart(16, '0'),
          rim: referencia?.referencia_municipal,
          telefono: referencia?.telefono_celular,
          items: [
            [
              {
                fecha: applicationView.fecha,
                fechaAprobacion: applicationView.fechaAprobacionFraccion,
                monto: applicationView.montoFraccion,
                porcion: `${applicationView.porcion}/${applicationView.cantidad}`,
                descripcion: applicationView.descripcionRamo ? `${applicationView.descripcionRamo} - ${applicationView.descripcionSubramo}  (${date.format('MMMM')} ${date.format('YYYY')})` : `Pago de Cuota (${date.format('MMMM')} ${date.format('YYYY')})`  ,
              },
            ],
          ],
          metodoPago: payment,
          total: applicationView.montoFraccion,
          credito: paymentTotal - applicationView.montoFraccion,
        },
      });
      if (dev) {
        pdf
          .create(html, {
            format: 'Letter',
            border: '5mm',
            header: { height: '0px' },
            base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
          })
          .toFile(pdfDir, async () => {
            res(dir);
          });
      } else {
        try {
          pdf
            .create(html, {
              format: 'Letter',
              border: '5mm',
              header: { height: '0px' },
              base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
            })
            .toBuffer(async (err, buffer) => {
              if (err) {
                rej(err);
              } else {
                const regClient = await pool.connect();
                try {
                  await regClient.query('BEGIN');
                  const bucketParams = {
                    Bucket: process.env.BUCKET_NAME as string,
                    Key: `/hacienda/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  await regClient.query('COMMIT');
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                } catch (e) {
                  await regClient.query('ROLLBACK');
                  rej(e);
                } finally {
                  regClient.release();
                }
              }
            });
        } catch (e) {
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    if (!clientParam) await client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  } finally {
    if (!clientParam) client.release();
  }
};

export const generateRepairReceipt = async (payload: { application: number; breakdownData; total; cashier }) => {
  const client = await pool.connect();
  const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_ID, [payload.application])).rows[0];
  const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE, [applicationView.id])).rows;
  const paymentRows = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [applicationView.id, 'IMPUESTO'])).rows;
  mainLogger.info('payment', payment);
  mainLogger.info('paymentRows', paymentRows);
  const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
  mainLogger.info('paymentTotal', paymentTotal);
  // const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
  // const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
  const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
  const recibo = await client.query(queries.INSERT_RECEIPT_RECORD, [paymentRows[0]?.id_usuario, ``, applicationView.razonSocial, referencia?.referencia_municipal, 'REPARO', applicationView.id]);
  if (!recibo.rows[0]) {
    return (await client.query('SELECT recibo FROM impuesto.registro_recibo WHERE id_solicitud = $1', [applicationView.id])).rows[0].recibo;
  }
  const idRecibo = recibo.rows[0].id_registro_recibo;
  // mainLogger.info('breakdowndata', breakdownData)
  const aforos: any[] = [];
  payload.breakdownData.map((el) => el.desglose.map((x) => aforos.push({ ...x, fecha: el.fecha })));
  try {
    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/recibo/${applicationView.id}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/recibo/${applicationView.id}/reparo.pdf`;
      // lest total = breakdownData.reduce((prev,next) => prev + (+next.monto), 0);
      // mainLogger.info('total',total)
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/hacienda/recibo/${applicationView.id}/reparo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-reparo.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        QR: linkQr,
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: applicationView.direccion,
          cajero: payload.cashier,
          rim: referencia?.referencia_municipal,
          telefono: referencia?.telefono_celular,
          items: chunk(
            aforos.map((row) => {
              mainLogger.info('generateRepairReceipt -> row', row);
              return {
                id: row.aforo,
                descripcion: row.descripcion,
                mes: row.fecha.month,
                anio: row.fecha.year,
                fechaLiquidacion: moment().format('MM-DD-YYYY'),
                monto: row.monto,
              };
            }),
            14
          ),
          metodoPago: payment,
          total: payload.total * 1.3,
          subTotal: payload.total,
          multa: payload.total * 0.3,
        },
      });
      if (dev) {
        pdf
          .create(html, {
            format: 'Letter',
            border: '5mm',
            header: { height: '0px' },
            base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
          })
          .toFile(pdfDir, async (err) => {
            mainLogger.info(err);
            res(dir);
          });
      } else {
        try {
          pdf
            .create(html, {
              format: 'Letter',
              border: '5mm',
              header: { height: '0px' },
              base: 'file://' + resolve(__dirname, '../views/planillas/') + '/',
            })
            .toBuffer(async (err, buffer) => {
              if (err) {
                rej(err);
              } else {
                const regClient = await pool.connect();
                try {
                  await regClient.query('BEGIN');
                  const bucketParams = {
                    Bucket: process.env.BUCKET_NAME as string,

                    Key: `/hacienda/recibo/${applicationView.id}/reparo.pdf`,
                  };
                  await S3Client.putObject({
                    ...bucketParams,
                    Body: buffer,
                    ACL: 'public-read',
                    ContentType: 'application/pdf',
                  }).promise();
                  await regClient.query(queries.UPDATE_RECEIPT_RECORD, [idRecibo, `${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`]);
                  // await regClient.query(queries.INSERT_RECEIPT_RECORD, [paymentRows[0].id_usuario, `${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`, applicationView.razonSocial, referencia?.referencia_municipal]);
                  await regClient.query('COMMIT');
                  res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
                } catch (e) {
                  await regClient.query('ROLLBACK');
                  rej(e);
                } finally {
                  regClient.release();
                }
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
  } finally {
    client.release();
  }
};

export const createOnDemandCertificate = async (type: string, data: any[]): Promise<{ status: number; messsage: string; url: string }> => {
  const client = await pool.connect();
  let certificateValues = [...data];
  mainLogger.info(`1 ${JSON.stringify(certificateValues, null, 2)}`);
  try {
    const pugFile = {
      IU: 'hacienda-solvencia-IU',
      SM: 'hacienda-solvencia-SM',
      LIC: 'hacienda-cert-EL',
      SOLA: 'hacienda-solvencia-A'
    };

    if(type === 'SOLA') {
      certificateValues[0].datos.cedulaList = chunk(certificateValues[0].datos.cedulaList, 4)
      certificateValues[0].datos.codCatList = chunk(certificateValues[0].datos.codCatList, 2)
      await client.query(`UPDATE consecutivo SET consecutivo = consecutivo + 1 WHERE descripcion = 'SOLVENCIA A'`);
      const correlativo =  (await client.query(`SELECT consecutivo FROM consecutivo WHERE descripcion = 'SOLVENCIA A'`)).rows[0]?.consecutivo + '';
      certificateValues[0].datos.correlativo = correlativo.length < 6 ? new Array(6 - correlativo.length).fill(0).concat(correlativo.split('')).join('') : correlativo;
    }

    if (type === 'LIC') {
      const { renovacion } = certificateValues[0].datos;
      if (!renovacion) {
        const numeroLicencia = (await client.query(`SELECT concat(date_part('year'::text, CURRENT_DATE), '-', lpad(nextval('impuesto.licencia_seq'::regclass)::text, 7, '0'::text)) AS "numeroLicencia"`)).rows[0].numeroLicencia;
        certificateValues = certificateValues.map((el) => {
          el.licencia = `${el.datos.funcionario.licencia}-${numeroLicencia}`;
          return el;
        });
      } else {
        certificateValues = certificateValues.map((el) => {
          el.licencia = el.datos.funcionario.licencia;
          return el;
        });
      }
    }
    mainLogger.info(`2 ${JSON.stringify(certificateValues, null, 2)}`);
    const index = new Date().getTime().toString().substr(6);
    const bucketKey = `//hacienda/${type}/${index}/certificado.pdf`;
    const buffers = await createCertificateBuffers(certificateValues, pugFile[type], bucketKey);
    const url = await createCertificate(buffers, bucketKey);
    return { status: 200, messsage: 'Certificado generado', url };
  } catch (e) {
    mainLogger.error(e);
    throw { status: 500, message: 'Error al generar certificado', error: e };
  } finally {
    client.release();
  }
};

export const createCertificateBuffers = async (certInfoArray: any[], pugFileName: string, bucketKey: string): Promise<Buffer[]> => {
  const linkQr = await qr.toDataURL(`${process.env.AWS_ACCESS_URL}${bucketKey}`, { errorCorrectionLevel: 'H' });
  console.log('PRUEBA', certInfoArray);
  let htmlArray = certInfoArray.map((certInfo) =>
    renderFile(resolve(__dirname, `../views/planillas/${pugFileName}.pug`), {
      moment: require('moment'),
      institucion: 'HACIENDA',
      QR: linkQr,
      ...certInfo,
    })
  );
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

  return buffersArray;
};

export const createCertificate = async (buffersArray: Buffer[], bucketKey: string, pdfDir?: string | undefined): Promise<string> => {
  return new Promise(async (res, rej) => {
    if (dev && pdfDir) {
      mkdir(dirname(pdfDir), { recursive: true }, (e) => {
        if (e) {
          rej(e);
        } else {
          if (buffersArray.length === 1) {
            writeFile(pdfDir, buffersArray[0], async (err) => {
              if (err) {
                rej(err);
              } else {
                res(`${process.env.SERVER_URL}${bucketKey}`);
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

            Key: `${bucketKey}`,
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

                Key: `${bucketKey}`,
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
        mainLogger.error('e', e);
        throw e;
      } finally {
      }
    }
  });
};
