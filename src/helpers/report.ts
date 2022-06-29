import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { renderFile } from 'pug';
import { resolve } from 'path';
import Pool from '@utils/Pool';
import * as pdf from 'html-pdf';
import moment from 'moment';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';

const pool = Pool.getInstance();
const dev = process.env.NODE_ENV !== 'production';

export const createRepotRMP = async () =>{
  const client = await pool.connect();
  try {

    let transferDiffNow = (await client.query(queries.GET_ALL_TRANSFERS_DIFF_NOW_TOTAL)).rows;
    let cash = (await client.query(queries.GET_ALL_CASH_TOTAL)).rows;
    let payDiffCash = (await client.query(queries.GET_ALL_PAY_DIFF_CASH_TOTAL)).rows;
    let totalMetodoPago = (await client.query(queries.TOTAL_TRANSFERS_DIFF_NOW)).rows;

    return new Promise(async (res, rej) => {
      let totalTransferDiffNow = transferDiffNow.map(t => +t.total).reduce((prev,curr) => curr + prev, 0);
      let totalCash = cash.map(c => +c.total).reduce((prev,curr) => curr + prev, 0);
      let totalPayDiffCash = totalMetodoPago.map(t => +t.total).reduce((prev,curr) => curr + prev, 0);
      let totalRecaudado = totalCash + totalPayDiffCash;
      let totalIngresado = totalRecaudado - totalTransferDiffNow;

      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RMP.pug`), {
        institucion: 'HACIENDA',
        cash,
        transferDiffNow,
        payDiffCash,
        totalTransferDiffNow,
        totalPayDiffCash,
        totalMetodoPago,
        totalRecaudado,
        totalIngresado
      });

      pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        .toBuffer(async (err, buffer) => {
          if (err) {
            rej(err);
          } else {
            const bucketParams = {
              Bucket: process.env.BUCKET_NAME as string,
              Key: `/hacienda/ReporteRecaudadoIngresadoMetodoPago.pdf`,
            };
            await S3Client.putObject({
              ...bucketParams,
              Body: buffer,
              ACL: 'public-read',
              ContentType: 'application/pdf',
            }).promise();
            res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
          }
        })
      })
    
  }  catch (error) {
      console.log('PABLO',error)
      throw {
        status: 500,
        error: errorMessageExtractor(error),
        message: error,
      };
  } finally {
    client.release();
  }
}

export const createReportRID = async () =>{
  const client = await pool.connect();
  try {

    const reportName = 'ReporteIngresadoDetallado.pdf'

    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RMP.pug`), {
        institucion: 'HACIENDA',
      });

      pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        .toBuffer(async (err, buffer) => {
          if (err) {
            rej(err);
          } else {
            const bucketParams = {
              Bucket: process.env.BUCKET_NAME as string,
              Key: `/hacienda/${reportName}`,
            };
            await S3Client.putObject({
              ...bucketParams,
              Body: buffer,
              ACL: 'public-read',
              ContentType: 'application/pdf',
            }).promise();
            res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
          }
        })
      })
    
  }  catch (error) {
      console.log('PABLO',error)
      throw {
        status: 500,
        error: errorMessageExtractor(error),
        message: error,
      };
  } finally {
    client.release();
  }
}