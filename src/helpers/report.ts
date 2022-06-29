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

    return new Promise(async (res, rej) => {
      let totalTransferDiffNow = transferDiffNow.reduce((prev,curr) => curr.total + prev.total, 0)

      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RMP.pug`), {
        cash,
        transferDiffNow,
        payDiffCash,
        totalTransferDiffNow
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