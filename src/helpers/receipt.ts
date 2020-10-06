import { resolve } from 'path';

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
    const recibo = await client.query(queries.INSERT_RECEIPT_RECORD, [paymentRows[0]?.id_usuario, `${process.env.AWS_ACCESS_URL}/sedemat/recibo/${applicationView.id}/recibo.pdf`, applicationView.razonSocial, referencia?.referencia_municipal, 'IMPUESTO', applicationView.id]);
    console.log('recibo', recibo.rows)
    if (!recibo.rows[0]) {
      console.log('not recibo', recibo.rows[0])
      return (await client.query(`SELECT recibo FROM impuesto.registro_recibo WHERE id_solicitud = $1 AND recibo != ''`, [applicationView.id])).rows[0].recibo;
    }
    const idRecibo = recibo.rows[0].id_registro_recibo;
    console.log('IDRECIBO', idRecibo)

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
                  Bucket: 'sut-maracaibo',
                  Key: `/sedemat/recibo/${applicationView.id}/recibo.pdf`,
                };
                await S3Client.putObject({
                  ...bucketParams,
                  Body: buffer,
                  ACL: 'public-read',
                  ContentType: 'application/pdf',
                }).promise();
                await regClient.query(queries.UPDATE_RECEIPT_RECORD, [idRecibo, `${process.env.AWS_ACCESS_URL}${bucketParams.Key}`]);
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
    if(!clientParam) await client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  } finally {
    if(!clientParam) client.release();
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
                  Bucket: 'sut-maracaibo',
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
