import { Transform, Readable } from 'stream';
import { resolve } from 'path';
import { chunk } from 'lodash';
import { inspect } from 'util';
import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { PoolClient, QueryResult } from 'pg';
import * as fs from 'fs';
import * as pdf from 'html-pdf';
import { groupBy } from 'lodash';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';
import { arrayreports } from './arrayReports';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const createRPR = async (id: string, payload: { from: Date; to: Date; alcaldia: boolean }, type: string) => {
  const client = await pool.connect();
  return new Promise(async (res, rej) => {
    mainLogger.info(payload);
    const alcaldia = payload.alcaldia;
    let pagos = {};
    const ingress = type === 'IDR' ? await client.query(queries.GET_PAID_LIQUIDATED, [payload.from, payload.to]) : await client.query(queries.GET_INGRESS, [payload.from, payload.to]);
    const liquidated = await client.query(queries.GET_LIQUIDATED, [payload.from, payload.to]);
    let pivot;
    let other;
    let pivotColumns;
    let columns;
    if (ingress.rowCount > liquidated.rowCount) {
      pivot = ingress;
      pivotColumns = ['cantidadIng', 'ingresado'];
      other = liquidated;
      columns = ['cantidadliq', 'liquidado'];
    } else if (liquidated.rowCount > ingress.rowCount) {
      pivot = liquidated;
      pivotColumns = ['cantidadLiq', 'liquidado'];
      other = ingress;
      columns = ['cantidadIng', 'ingresado'];
    } else {
      pivot = ingress;
      pivotColumns = ['cantidadIng', 'ingresado'];
      other = liquidated;
      columns = ['cantidadLiq', 'liquidado'];
    }

    let result = pivot.rows.reduce((prev, next) => {
      if (other.rows.some((otherRow) => otherRow.ramo === next.ramo)) {
        let otherRow = other.rows.find((el) => el.ramo === next.ramo);
        next[columns[0]] = otherRow[columns[0]];
        next[columns[1]] = otherRow[columns[1]];
      }
      prev.push(next);
      return prev;
    }, []);

    let filtered = other.rows.filter((val) => !result.find((resultRow) => resultRow.ramo === val.ramo));

    result.push(...filtered);
    pivotColumns.push(...columns);
    result = result.map((val) => {
      for (let col of pivotColumns) {
        val[col] = val[col] || 0;
      }
      return val;
    });

    let final = groupBy(result, (res) => res.codigo);
    let branches = (await client.query(queries.GET_BRANCHES_FOR_REPORT)).rows.filter((row) => row.ramo in final);

    let ivaSM: any = {
      id: 53,
      ramo: '122',
      descripcion: 'IVA SM',
      descripcion_corta: null,
      subRamo: [
        // {
        //   ramo: '122.SAGAS',
        //   descripcion: 'IVA SM - IVA SAGAS',
        //   codigo: '122',
        //   ...(await client.query(queries.GET_SM_IVA_SAGAS, [payload.from, payload.to])).rows[0],
        //   liquidado: 0,
        //   cantidadLiq: 0,
        // },
        {
          ramo: '122.ASEO',
          descripcion: 'IVA SM - IVA ASEO',
          codigo: '122',
          ...(await client.query(queries.GET_SM_IVA_IMAU, [payload.from, payload.to])).rows[0],
          liquidado: 0,
          cantidadLiq: 0,
        },
      ],
    };
    ivaSM.liquidadoTotal = ivaSM.cantidadLiqTotal = 0;
    ivaSM.ingresadoTotal = ivaSM.subRamo.reduce((prev, next) => prev + +next.ingresado, 0);
    ivaSM.cantidadIngTotal = ivaSM.subRamo.reduce((prev, next) => prev + +next.cantidadIng, 0);

    final['122'] = final['122'].concat(ivaSM.subRamo);

    branches = branches
      .map((branch) => {
        return {
          ...branch,
          subRamo: final[branch.ramo],
        };
      })
      .map((branch) => {
        return {
          ...branch,
          liquidadoTotal: branch.subRamo.reduce((prev, next) => prev + +next.liquidado, 0),
          cantidadLiqTotal: branch.subRamo.reduce((prev, next) => prev + +next.cantidadLiq, 0),
          ingresadoTotal: branch.subRamo.reduce((prev, next) => prev + +next.ingresado, 0),
          cantidadIngTotal: branch.subRamo.reduce((prev, next) => prev + +next.cantidadIng, 0),
        };
      })
      .filter((branch) => branch.subRamo.reduce((prev, next) => prev + +next.ingresado + +next.liquidado, 0) > 0);

    let compens: any = {
      id: 53,
      ramo: '925',
      descripcion: 'COMPENSACIONES',
      descripcion_corta: null,
      subRamo: [
        {
          ramo: '925.1',
          descripcion: 'COMPENSACIONES - Credito fiscal por pago excesivo',
          codigo: '925',
          ...(await client.query(queries.GET_CREDIT_INGRESS_BY_INTERVAL, [payload.from, payload.to])).rows[0],
          liquidado: 0,
          cantidadLiq: 0,
        },
        {
          ramo: '925.2',
          descripcion: 'COMPENSACIONES - Credito fiscal por agente de retencion',
          codigo: '925',
          ...(await client.query(queries.GET_RETENTION_CREDIT_INGRESS_BY_INTERVAL, [payload.from, payload.to])).rows[0],
          liquidado: 0,
          cantidadLiq: 0,
        },
      ],
    };
    compens.liquidadoTotal = compens.cantidadLiqTotal = 0;
    compens.ingresadoTotal = compens.subRamo.reduce((prev, next) => prev + +next.ingresado, 0);
    compens.cantidadIngTotal = compens.subRamo.reduce((prev, next) => prev + +next.cantidadIng, 0);
    branches = branches.concat(compens);
    //mainLogger.info('Branches');
    //mainLogger.info(inspect(branches));
    if (!alcaldia) {
      const transfersByBank = (await client.query(queries.GET_TRANSFERS_BY_BANK, [payload.from, payload.to, payload.from, payload.to, payload.from, payload.to, payload.from, payload.to, payload.from, payload.to])).rows;

      const totalTranfersByBank = +transfersByBank.reduce((prev, next) => prev + +next.monto, 0);

      const cash = (await client.query(queries.GET_CASH_REPORT, [payload.from, payload.to])).rows;
      const cashTotal = +cash[0].monto || 0;

      const pos = +(await client.query(queries.GET_POS, [payload.from, payload.to, payload.from, payload.to])).rows[0].total || 0;

      const check = +(await client.query(queries.GET_CHECKS, [payload.from, payload.to])).rows[0].total || 0;

      const cred = +(await client.query(queries.GET_CREDIT_REPORT, [payload.from, payload.to])).rows[0].total || 0;

      pagos = {
        total: totalTranfersByBank + cashTotal + pos + check + cred,
        transferencias: {
          total: totalTranfersByBank,
          items: transfersByBank,
        },
        efectivo: {
          total: cashTotal,
          items: cash,
        },
        punto: {
          total: pos,
        },
        cheques: {
          total: check,
        },
        creditoFiscal: cred,
      };
    }
    mainLogger.info(liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0) + compens.cantidadLiqTotal);
    mainLogger.info(liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0) + compens.liquidadoTotal);
    const html = renderFile(resolve(__dirname, alcaldia ? `../views/planillas/hacienda-RPRA.pug` : `../views/planillas/hacienda-RPR.pug`), {
      moment: require('moment'),
      institucion: 'HACIENDA',
      datos: {
        type,
        ingresos: chunk(branches, 8),
        acumuladoIngresos: `CONTENIDO: TODOS LOS RAMOS, DESDE EL ${moment(payload.from).subtract(4, 'h').format('DD/MM/YYYY')} AL ${moment(payload.to).subtract(4, 'h').format('DD/MM/YYYY')}`,
        cantidadLiqTotal: liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0) + compens.cantidadLiqTotal + ivaSM.cantidadLiqTotal,
        liquidadoTotal: liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0) + compens.liquidadoTotal + ivaSM.liquidadoTotal,
        ingresadoTotal: ingress.rows.reduce((prev, next) => prev + +next.ingresado, 0) + compens.ingresadoTotal + ivaSM.ingresadoTotal,
        cantidadIngTotal: ingress.rows.reduce((prev, next) => prev + +next.cantidadIng, 0) + compens.cantidadIngTotal + ivaSM.cantidadIngTotal,
        metodoPago: pagos,
      },
    });
    const pdfDir = resolve(__dirname, alcaldia ? `../../archivos/hacienda/reportes/RPRA.pdf` : type === 'IDR' ? `../../archivos/hacienda/reportes/IDR.pdf` : `../../archivos/hacienda/reportes/RPR.pdf`);
    const dir = alcaldia ? `${process.env.SERVER_URL}/hacienda/reportes/RPRA.pdf` : type === 'IDR' ? `${process.env.SERVER_URL}/hacienda/reportes/IDR.pdf` : `${process.env.SERVER_URL}/hacienda/reportes/RPR.pdf`;
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
              Key: alcaldia ? 'hacienda/reportes/RPRA.pdf' : type === 'IDR' ? `hacienda/reportes/IDR.pdf` : `hacienda/reportes/RPR.pdf`,
            };
            await S3Client.putObject({
              ...bucketParams,
              Body: buffer,
              ACL: 'public-read',
              ContentType: 'application/pdf',
            }).promise();
            arrayreports.push({
              id,
              url: `${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`,
            });
            res('resolved');
          }
        });
      } catch (e) {
        throw e;
      } finally {
      }
    }
  });
};


export const createIDR = async (payload: {from: string, to: string}) => {
  const client = await pool.connect();
  try{
    const {from, to} = payload;
    const isSameDay = from.slice(0, from.split('').findIndex(elem => elem === 'T')) === to.slice(0, to.split('').findIndex(elem => elem === 'T'))
    const newFrom = isSameDay ? moment(from.slice(0, from.split('').findIndex(elem => elem === 'T'))).subtract(1, 'day').format('YYYY-MM-DD') + 'T23:59:59.999-04:00' : from;
    // const fromMoment = moment(from)
    // const toMoment = moment (to)
    // const isSameDay = moment([fromMoment.year(), fromMoment.month(), fromMoment.day()]).isSame([toMoment.year(), toMoment.month(), toMoment.day()]);
    const data = (await client.query(queries.GET_IDR_DATA, [newFrom, to])).rows;
    console.log(from, to, data, isSameDay)
    return new Promise(async (res, rej) => {
      const html = renderFile(resolve(__dirname,  `../views/planillas/hacienda-IDR.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        datos: {
          ingresos: chunk(data, 8),
          acumuladoIngresos: `CONTENIDO: TODOS LOS RAMOS, DESDE EL ${moment(payload.from).subtract(4, 'h').format('DD/MM/YYYY')} AL ${moment(payload.to).subtract(4, 'h').format('DD/MM/YYYY')}`,
          cantidadLiqTotal: data.reduce((a, c) => a + Number(c.cantidadLiquidado), 0),
          liquidadoTotal: data.reduce((a, c) => a + Number(c.totalLiquidado), 0),
          ingresadoTotal: data.reduce((a, c) => a + Number(c.totalIngresado), 0),
          cantidadIngTotal: data.reduce((a, c) => a + Number(c.cantidadIngresado), 0),
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/reportes/IDR.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/reportes/IDR.pdf`;
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
                Key:`hacienda/reportes/IDR.pdf`,
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
    });
  } catch(e) {
    let message = 'Error al crear IDR';
    if (e instanceof Error) message = e.message;
    throw {status: 500, message}
  }
}