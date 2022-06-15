import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import * as pdf from 'html-pdf';
import { groupBy, chunk } from 'lodash';
import { mainLogger } from '@utils/logger';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getCashierReceipts = async (payload: { id: string | number }) => {
  const client = await pool.connect();
  try {
    const res = await client.query(queries.GET_RECEIPT_RECORDS_BY_USER, [payload.id]);
    return res.rows;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const generateCashierReport = async (user, payload: { day: Date }) => {
  if (user.institucion.id !== 9) {
    throw new Error('El usuario en sesión no tiene permisos.');
  }
  const client = await pool.connect();
  const userId = user.id;
  const userName = user.nombreCompleto;

  const cashierPos = (await client.query(queries.GET_CASHIER_POS, [payload.day, userId])).rows;
  const cashierPosTotal = +cashierPos.reduce((prev, next) => prev + +next.monto, 0);
  const cashierPosTransactions = +cashierPos.reduce((prev, next) => prev + +next.transacciones, 0);

  const cashierCash = (await client.query(queries.GET_CASHIER_CASH, [payload.day, userId])).rows;

  const cashierChecks = (await client.query(queries.GET_CASHIER_CHECKS, [payload.day, userId])).rows;
  const cashierCredit = (await client.query(queries.GET_CASHIER_CREDIT, [payload.day, userId])).rows;
  const cashierTransfers = (await client.query(queries.GET_CASHIER_TRANSFERS, [payload.day, userId])).rows;
  mainLogger.info(cashierTransfers);
  const cashierTransfersTotal = +cashierTransfers.reduce((prev, next) => prev + +next.monto, 0);
  const cashierTransfersTransactions = +cashierTransfers.reduce((prev, next) => prev + +next.transacciones, 0);
  const cashierTransfersByBank = cashierTransfers.reduce((prev, next) => {
    switch (next.id) {
      case 1:
        prev.bod = {
          total: next.monto,
          transacciones: next.transacciones,
        };
        break;
      case 2:
        prev.banesco = {
          total: next.monto,
          transacciones: next.transacciones,
        };
        break;
      case 3:
        prev.bnc = {
          total: next.monto,
          transacciones: next.transacciones,
        };
    }
    return prev;
  }, {});
  try {
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-cierreCaja.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        datos: {
          cajero: userName,
          fecha: payload.day,
          metodoPago: {
            punto: {
              total: cashierPosTotal,
              transacciones: cashierPosTransactions,
              items: cashierPos,
            },
            efectivo: cashierCash[0],
            credFiscal: cashierCredit[0],
            cheques: cashierChecks[0],
            transferencias: cashierTransfersByBank,
            transacciones: +cashierPosTransactions + +cashierCash[0].transacciones + +cashierChecks[0].transacciones + +cashierTransfersTransactions + +cashierCredit[0].transacciones,
            total: +cashierPosTotal + +cashierCash[0].total + +cashierChecks[0].total + +cashierTransfersTotal + +cashierCredit[0].total,
          },
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/cierreCaja/${userId}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/cierreCaja/${userId}/cierre.pdf`;
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
                Bucket: process.env.BUCKET_NAME as string,
                Key: `/hacienda/cierreCaja/${userId}/cierre.pdf`,
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
  } finally {
    client.release();
  }
};

export const generateAllCashiersReport = async (user, payload: { from?: Date; to?: Date }) => {
  const client = await pool.connect();
  let payment, paymentTotal, paymentBreakdown;

  payment = (await client.query(queries.GET_ALL_CASHIERS_TOTAL_INT, [payload.from, payload.to])).rows;
  paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
  paymentBreakdown = (await client.query(queries.GET_ALL_CASHIERS_METHODS_TOTAL_NEW_INT, [payload.from, payload.to])).rows;

  paymentBreakdown = groupBy(paymentBreakdown, (el) => el.nombre_completo);

  for (let x in paymentBreakdown) {
    paymentBreakdown[x] = groupBy(paymentBreakdown[x], (val) => val.metodo_pago);
  }
  console.log(paymentBreakdown, 'WILKMER')
  try {
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-cierreCajaJefe.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        chunk,
        datos: paymentBreakdown,
      });
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/cajaAll/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/cajaAll/cierre.pdf`;
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
                Bucket: process.env.BUCKET_NAME as string,
                Key: `/hacienda/cajaAll/cierre.pdf`,
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
  } finally {
    client.release();
  }
};
