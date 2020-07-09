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



export const generateCashierReport = async (user, payload: { day: Date }) => {
    if(user.institucion.cargo.id !== 22){
        throw new Error('El usuario en sesión no es un cajero');
    }
    const client = await pool.connect();
    const userId = user.id;
    const userName = user.nombreCompleto;

    const cashierPos = (await client.query(queries.GET_CASHIER_POS, [payload.day, userId])).rows
    const cashierPosTotal = +cashierPos.reduce((prev, next) => prev + (+next.monto), 0)
    const cashierPosTransactions = +cashierPos.reduce((prev, next) => prev + (+next.transacciones), 0);

    const cashierCash = (await client.query(queries.GET_CASHIER_CASH, [payload.day, userId])).rows

    const cashierChecks = (await client.query(queries.GET_CASHIER_CHECKS, [payload.day, userId])).rows
    const cashierTransfers = (await client.query(queries.GET_CASHIER_TRANSFERS, [payload.day, userId])).rows
    const cashierTransfersTotal = +cashierTransfers.reduce((prev, next) => prev + (+next.monto) ,0);
    const cashierTransfersTransactions = +cashierTransfers.reduce((prev, next) => prev + (+next.transacciones) ,0);
    const cashierTransfersByBank = cashierTransfers.reduce((prev, next) => {
        switch(next.id_banco){
            case 1:
                prev.bod = {
                    total: next.monto,
                    transacciones: next.transacciones
                }
            break;
            case 2:
                prev.banesco = {
                    total: next.monto,
                    transacciones: next.transacciones
                }
            break;
            case 3:
                prev.bnc = {
                    total: next.monto,
                    transacciones: next.transacciones
                }
        }
        return prev;
    }, {})
    try {
        return new Promise(async (res, rej) => {
            
          const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-cierreCaja.pug`), {
            moment: require('moment'),
            institucion: 'SEDEMAT',
            datos:{

                cajero: userName,
                fecha: payload.day,
                metodoPago:{
                  punto:{
                    total: cashierPosTotal,
                    transacciones: cashierPosTransactions ,
                    items: cashierPos
                  },
                  efectivo: cashierCash[0],
                  credFiscal:{
                    total: 0,
                    transacciones:0
                  },
                  cheques: cashierChecks[0],
                  transferencias: cashierTransfersByBank,
                  transacciones: cashierPosTransactions + cashierCash[0].transacciones + cashierChecks[0].transacciones + cashierTransfersTransactions,
                  total: cashierPosTotal + cashierCash[0].monto + cashierChecks[0].monto + cashierTransfersTotal
                },
        }
          });
          const pdfDir = resolve(__dirname, `../../archivos/sedemat/cierreCaja/${userId}/cierre.pdf`);
          const dir = `${process.env.SERVER_URL}/sedemat/cierreCaja/${userId}/cierre.pdf`;
          if (dev) {
            pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
              
              res(dir);
            });
          } else {
            try {
              pdf
                .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
                .toBuffer(async (err, buffer) => {
                  if (err) {
                    rej(err);
                  } else {
                    const bucketParams = {
                      Bucket: 'sut-maracaibo',
                      Key: `/sedemat/cierreCaja/${userId}/cierre.pdf`,
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
        client.release()
      }
}