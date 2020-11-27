import { resolve, dirname } from 'path';
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
import { chunk } from 'lodash';
const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const generateReceipt = async (payload: { application: number }, clientParam?) => {
  const client = clientParam ? clientParam : await pool.connect();
  try {
    const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_ID, [payload.application])).rows[0];
    const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE, [applicationView.id])).rows;
    const paymentRows = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [applicationView.id, 'IMPUESTO'])).rows;
    console.log('payment', payment);
    console.log('paymentRows', paymentRows);
    const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
    console.log('paymentTotal', paymentTotal);
    const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
    const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
    console.log('breakdowndata', breakdownData);
    const recibo = await client.query(queries.INSERT_RECEIPT_RECORD, [
      paymentRows[0]?.id_usuario,
      `${process.env.AWS_ACCESS_URL}//sedemat/recibo/${applicationView.id}/recibo.pdf`,
      applicationView.razonSocial,
      referencia?.referencia_municipal,
      'IMPUESTO',
      applicationView.id,
    ]);
    console.log('recibo', recibo.rows);
    if (!recibo.rows[0]) {
      console.log('not recibo', recibo.rows[0]);
      return (await client.query(`SELECT recibo FROM impuesto.registro_recibo WHERE id_solicitud = $1 AND recibo != ''`, [applicationView.id])).rows[0].recibo;
    }
    const idRecibo = recibo.rows[0].id_registro_recibo;
    console.log('IDRECIBO', idRecibo);

    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/recibo/${applicationView.id}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/recibo/${applicationView.id}/recibo.pdf`;
      let total = breakdownData.reduce((prev, next) => prev + +next.monto, 0);
      console.log('total', total);
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/sedemat/recibo/${applicationView.id}/recibo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-recibo.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: applicationView.direccion,
          cajero: cashier?.[0]?.nombreCompleto,
          codigoRecibo: String(idRecibo).padStart(16, '0'),
          rim: referencia?.referencia_municipal,
          telefono: referencia?.telefono_celular,
          items: chunk(
            breakdownData.map((row) => {
              return {
                descripcion: `${row.datos.descripcion ? row.datos.descripcion : `${row.descripcionRamo} - ${row.descripcionSubramo}`} (${row.datos.fecha.month} ${row.datos.fecha.year})`,
                fecha: row.fechaLiquidacion,
                monto: row.monto,
              };
            }),
            14
          ),
          metodoPago: payment,
          total: total,
          credito: paymentTotal - total,
        },
      });
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
              const regClient = await pool.connect();
              try {
                await regClient.query('BEGIN');
                const bucketParams = {
                  Bucket: process.env.BUCKET_NAME as string,
                  Key: `/sedemat/recibo/${applicationView.id}/recibo.pdf`,
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
    const applicationView = (await client.query(queries.GET_AGREEMENT_VIEW_BY_FRACTION_ID, [payload.agreement])).rows[0];
    const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE_AGREEMENT, [applicationView.id_fraccion])).rows;
    const paymentRows = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [applicationView.id_fraccion, 'CONVENIO'])).rows;
    console.log('payment', payment);
    console.log('paymentRows', paymentRows);
    const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
    console.log('paymentTotal', paymentTotal);
    const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
    const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
    const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
    console.log('breakdowndata', breakdownData);
    const recibo = await client.query(queries.INSERT_AGREEMENT_RECEIPT_RECORD, [
      paymentRows[0]?.id_usuario,
      `${process.env.AWS_ACCESS_URL}//sedemat/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`,
      applicationView.razonSocial,
      referencia?.referencia_municipal,
      'CONVENIO',
      applicationView.id_fraccion,
    ]);
    console.log('recibo', recibo.rows);
    if (!recibo.rows[0]) {
      console.log('not recibo', recibo.rows[0]);
      return (await client.query(`SELECT recibo FROM impuesto.registro_recibo_convenio WHERE id_fraccion = $1 AND recibo != ''`, [applicationView.id_fraccion])).rows[0].recibo;
    }
    const idRecibo = recibo.rows[0].id_registro_recibo_convenio;
    console.log('IDRECIBO', idRecibo);

    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/recibo/agreement/${applicationView.id_fraccion}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`;
      const date = moment(applicationView.fechaCreacion).locale('ES');
      let total = breakdownData.reduce((prev, next) => prev + +next.monto, 0);
      console.log('total', total);
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/sedemat/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-RC.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        QR: linkQr,
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: applicationView.direccion,
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
                descripcion: `${applicationView.descripcionRamo} - ${applicationView.descripcionSubramo} (${date.format('MMMM')} ${date.format('YYYY')})`,
              },
            ],
          ],
          metodoPago: payment,
          total: applicationView.montoFraccion,
          credito: paymentTotal - applicationView.montoFraccion,
        },
      });
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
              const regClient = await pool.connect();
              try {
                console.log('aydiosmio yaaaaaaaaaaaaa');
                await regClient.query('BEGIN');
                const bucketParams = {
                  Bucket: process.env.BUCKET_NAME as string,
                  Key: `/sedemat/recibo/agreement/${applicationView.id_fraccion}/recibo.pdf`,
                };
                console.log('Key', bucketParams.Key);
                await S3Client.putObject({
                  ...bucketParams,
                  Body: buffer,
                  ACL: 'public-read',
                  ContentType: 'application/pdf',
                }).promise();
                //await regClient.query(queries.UPDATE_AGREEMENT_RECEIPT_RECORD, [idRecibo, `${process.env.AWS_ACCESS_URL}${bucketParams.Key}`]);
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
  console.log('payment', payment);
  console.log('paymentRows', paymentRows);
  const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
  console.log('paymentTotal', paymentTotal);
  // const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [paymentRows[0]?.id_usuario])).rows;
  // const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
  const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];
  const recibo = await client.query(queries.INSERT_RECEIPT_RECORD, [paymentRows[0]?.id_usuario, ``, applicationView.razonSocial, referencia?.referencia_municipal, 'REPARO', applicationView.id]);
  if (!recibo.rows[0]) {
    return (await client.query('SELECT recibo FROM impuesto.registro_recibo WHERE id_solicitud = $1', [applicationView.id])).rows[0].recibo;
  }
  const idRecibo = recibo.rows[0].id_registro_recibo;
  // console.log('breakdowndata', breakdownData)
  const aforos: any[] = [];
  payload.breakdownData.map((el) => el.desglose.map((x) => aforos.push({ ...x, fecha: el.fecha })));
  try {
    return new Promise(async (res, rej) => {
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/recibo/${applicationView.id}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/recibo/${applicationView.id}/reparo.pdf`;
      // lest total = breakdownData.reduce((prev,next) => prev + (+next.monto), 0);
      // console.log('total',total)
      const linkQr = await qr.toDataURL(dev ? dir : `${process.env.AWS_ACCESS_URL}/sedemat/recibo/${applicationView.id}/reparo.pdf`, { errorCorrectionLevel: 'H' });
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-reparo.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
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
              console.log('generateRepairReceipt -> row', row);
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
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async (err) => {
          console.log(dir);
          console.log(pdfDir);
          console.log(err);
          res(dir);
        });
      } else {
        try {
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const regClient = await pool.connect();
              try {
                await regClient.query('BEGIN');
                const bucketParams = {
                  Bucket: process.env.BUCKET_NAME as string,

                  Key: `/sedemat/recibo/${applicationView.id}/reparo.pdf`,
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
  try {
    const pugFile = {
      IU: 'sedemat-solvencia-IU',
      SM: 'sedemat-solvencia-SM',
      LIC: 'sedemat-cert-EL',
    };
    const index = new Date().getTime().toString().substr(6);
    const bucketKey = `/sedemat/${type}/${index}/certificado.pdf`;
    const buffers = await createCertificateBuffers(data, pugFile[type], bucketKey);
    const url = await createCertificate(buffers, bucketKey);
    return { status: 200, messsage: 'Certificado generado', url };
  } catch (e) {
    console.log(e);
    throw { status: 500, message: 'Error al generar certificado', error: e };
  }
};

export const createCertificateBuffers = async (certInfoArray: any[], pugFileName: string, bucketKey: string): Promise<Buffer[]> => {
  const linkQr = await qr.toDataURL(`${process.env.AWS_ACCESS_URL}${bucketKey}`, { errorCorrectionLevel: 'H' });
  let htmlArray = certInfoArray.map((certInfo) => renderFile(resolve(__dirname, `../views/planillas/${pugFileName}.pug`), { moment: require('moment'), institucion: 'SEDEMAT', QR: linkQr, ...certInfo }));

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
              console.log(e);
              rej(e);
            });
        }
      } catch (e) {
        console.log('e', e);
        throw e;
      } finally {
      }
    }
  });
};
