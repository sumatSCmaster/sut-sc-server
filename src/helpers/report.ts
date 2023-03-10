import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { renderFile } from 'pug';
import { resolve } from 'path';
import Pool from '@utils/Pool';
import * as pdf from 'html-pdf';
import moment from 'moment';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';
import { groupBy } from 'lodash';

const pool = Pool.getInstance();
const dev = process.env.NODE_ENV !== 'production';
const formatCurrency = (number: number) => new Intl.NumberFormat('de-DE', { minimumFractionDigits: 2 }).format(number);

export const createRepotRMP = async (fecha) =>{
  const client = await pool.connect();
  try {
    console.log('PABLO',fecha)
    let transferDiffNow = (await client.query(queries.GET_ALL_TRANSFERS_DIFF_NOW_TOTAL, [fecha])).rows;
    let cash = (await client.query(queries.GET_ALL_CASH_TOTAL, [fecha])).rows;
    let payDiffCash = (await client.query(queries.GET_ALL_PAY_DIFF_CASH_TOTAL, [fecha])).rows;
    let totalMetodoPago = (await client.query(queries.TOTAL_PAY_DIFF_CASH, [fecha])).rows;

    return new Promise(async (res, rej) => {
      let totalTrans = transferDiffNow.map(t => +t.total).reduce((prev,curr) => curr + prev, 0);
      let totalCash = cash.map(c => +c.total).reduce((prev,curr) => curr + prev, 0);
      let totalPayDiffCash = totalMetodoPago.map(t => +t.total).reduce((prev,curr) => curr + prev, 0);
      
      let recaudado = totalCash + totalPayDiffCash;
      let totalRecaudado = formatCurrency(recaudado);
      let totalIngresado = formatCurrency(Math.abs(recaudado - totalTrans));
      let totalTransferDiffNow = formatCurrency(totalTrans)

      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RMP.pug`), {
        institucion: 'HACIENDA',
        cash,
        transferDiffNow,
        payDiffCash,
        totalTransferDiffNow,
        totalPayDiffCash,
        totalMetodoPago,
        totalRecaudado,
        totalIngresado,
        fecha: moment().format('DD/MM/YYYY'),
        fechaReporte: moment(fecha).format('DD/MM/YYYY')
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

export const createReportRID = async ({ fecha }) =>{
  const client = await pool.connect();
  try {

    const reportName = 'ReporteIngresadoDetallado.pdf'
    console.log('PABLO REPORTE RID',fecha)
    
    let result = (await client.query(queries.GET_ENTERED_DETAILED, [fecha])).rows;
    let resultByBranch = (await client.query(queries.GET_TOTAL_ENTERED_DETAILED_BY_BRANCH, [fecha])).rows;
    let totalMontoPagado =  resultByBranch.map(d => +d.monto_pagado).reduce((prev,curr)=>{ return curr + prev },0)
    let totalMontoLiquidacion =  resultByBranch.map(d => +d.monto_liquidacion).reduce((prev,curr)=>{ return curr + prev },0)

    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RID.pug`), {
        institucion: 'HACIENDA',
        fecha: moment().format('DD/MM/YYYY'),
        fecha_desde: moment(fecha).format('DD/MM/YYYY'),
        totalMontoPagado,
        totalMontoLiquidacion,
        resultByBranch,
        data: result
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
