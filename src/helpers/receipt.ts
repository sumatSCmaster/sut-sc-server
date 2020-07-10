import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import * as pdf from 'html-pdf';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const generateReceipt = async (payload: { application: number }) => {
  const client = await pool.connect();
  const applicationView = (await client.query(queries.GET_APPLICATION_VIEW_BY_ID, [payload.application])).rows[0];
  const payment = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE, [applicationView.id])).rows;
  const paymentTotal = payment.reduce((prev, next) => prev + +next.monto, 0);
  const cashier = (await client.query(queries.GET_USER_INFO_BY_ID, [payment[0].id_usuario])).rows;
  const breakdownData = (await client.query(queries.GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID, [applicationView.id])).rows;
  const referencia = (await pool.query(queries.REGISTRY_BY_SETTLEMENT_ID, [applicationView.idLiquidacion])).rows[0];

  try {
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-recibo.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        datos: {
          razonSocial: applicationView.razonSocial,
          tipoDocumento: applicationView.tipoDocumento,
          documentoIden: applicationView.documento,
          direccion: applicationView.direccion,
          cajero: cashier?.[0]?.nombreCompleto,
          rim: referencia?.referencia_municipal,
          telefono: referencia?.telefono_celular,
          items: breakdownData.map((row) => {
            return {
              descripcion: `${row.datos.descripcion ? row.datos.descripcion : `${row.datos.descripcionRamo} - ${row.datos.descripcionSubramo}`} (${row.datos.fecha.month} ${row.datos.fecha.year})`,
              fecha: row.fechaLiquidacion,
              monto: row.monto,
            };
          }),
          metodoPago: payment,
          total: paymentTotal,
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/sedemat/recibo/${applicationView.id}/cierre.pdf`);
      const dir = `${process.env.SERVER_URL}/sedemat/recibo/${applicationView.id}/cierre.pdf`;
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
                Key: `/sedemat/recibo/${applicationView.id}/cierre.pdf`,
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
