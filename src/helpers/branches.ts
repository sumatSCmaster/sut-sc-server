import { resolve } from 'path';

import moment, { Moment } from 'moment';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import { QueryResult } from 'pg';
import * as pdf from 'html-pdf';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const generateBranchesReport = async (user, payload: { from: Date, to: Date }) => {
    const client = await pool.connect();
    try {
        return new Promise(async (res, rej) => {
            const ingress = await client.query(queries.GET_INGRESS, [payload.from, payload.to]);
            const liquidated = await client.query(queries.GET_LIQUIDATED, [payload.from, payload.to]);
            let pivot;
            let other;
            let pivotColumns;
            let columns;
            if(ingress.rowCount > liquidated.rowCount){
                pivot = ingress;
                pivotColumns = ['cantidading', 'ingresado']
                other = liquidated;
                columns = ['cantidadliq', 'liquidado']
            } else if (liquidated.rowCount > ingress.rowCount){
                pivot = liquidated;
                pivotColumns = ['cantidadliq', 'liquidado']
                other = ingress;
                columns = ['cantidading', 'ingresado']
            } else{
                pivot = ingress;
                pivotColumns = ['cantidading', 'ingresado']
                other = liquidated;
                columns = ['cantidadliq', 'liquidado']
            }

            let result = pivot.rows.reduce((prev, next) => {
                if(other.rows.some((otherRow) => otherRow.ramo === next.ramo)){
                    let otherRow = other.rows.find((el) => el.ramo === next.ramo);
                    next[columns[0]] = otherRow[columns[0]];
                    next[columns[1]] = otherRow[columns[1]];
                }
                prev.push(next)
                return prev;
            }, []);

            console.log('other',other.rows)

            console.log('result pre filter', result)
            let filtered = other.rows.filter((val) => !result.find((resultRow) => resultRow.ramo === val.ramo) )
            console.log('filtered', filtered)

            result.push(...filtered)
            console.log('result',result)
            pivotColumns.push(...columns);
            console.log(pivotColumns)
            result = result.map((val) => {
                for(let col of pivotColumns){
                    val[col] = val[col] || 0
                }
                return val;
            });

            console.log('FINAL RES', result)


          const html = renderFile(resolve(__dirname, `../views/planillas/sedemat-RPR.pug`), {
            moment: require('moment'),
            datos: {
                ingresos: result,
                acumuladoIngresos: `CONTENIDO: TODOS LOS RAMOS, DESDE EL ${moment(payload.from).format('DD/MM/YYYY')} AL ${moment(payload.to).format('DD/MM/YYYY')}`,
                cantidadLiqTotal:liquidated.rows.reduce((prev, next) =>  prev + next.liquidado, 0) ,
                liquidadoTotal: liquidated.rows.reduce((prev, next) => prev + next.cantidadliq, 0),
                ingresadoTotal: ingress.rows.reduce((prev, next) => prev + next.cantidading, 0),
                cantidadIngTotal: ingress.rows.reduce((prev, next) =>  prev + next.ingresado, 0) ,
                metodoPago: {
                  total:1231233213.00,
                  transferencias:{
                    total:123123,
                    items:[{
                    banco:'BOD',
                    fecha:"2020-06-23T13:00:22.167Z",
                    monto: 12312313.00
                  }]
                  },
                  efectivo:{
                    total: 0,
                    items:[{
                      moneda:'BS',
                      fecha:"2020-06-23T13:00:22.167Z",
                      monto: 12312313.00
                    }]
                  },
                  punto:{
                    total:13123123,
                    items:[{
                      banco:'BOD',
                      fecha:"2020-06-23T13:00:22.167Z",
                      monto: 12312313.00
                    }]
                  },
                  cheques:{
                    total:123123,
                    items:[{
                      banco:'BOD',
                      fecha:"2020-06-23T13:00:22.167Z",
                      monto: 12312313.00
                    }]
                  }
                }
              }
          });
          const pdfDir = resolve(__dirname, `../../archivos/sedemat/reportes/RPR.pdf`);
          const dir = `${process.env.SERVER_URL}/sedemat/reportes/RPR.pdf`;
          if (dev) {
            pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
              
              res(dir);
            });
          } else {
            // try {
            //   pdf
            //     .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
            //     .toBuffer(async (err, buffer) => {
            //       if (err) {
            //         rej(err);
            //       } else {
            //         const bucketParams = {
            //           Bucket: 'sut-maracaibo',
            //           Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
            //         };
            //         await S3Client.putObject({
            //           ...bucketParams,
            //           Body: buffer,
            //           ACL: 'public-read',
            //           ContentType: 'application/pdf',
            //         }).promise();
            //         res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
            //       }
            //     });
            // } catch (e) {
            //   throw e;
            // } finally {
            // }
          }
        });
      } catch (error) {
        throw errorMessageExtractor(error);
      } finally {
        client.release()
      }
}