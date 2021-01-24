import { Transform, Readable } from 'stream';
import { resolve } from 'path';
import { chunk } from 'lodash';
import { promisify } from 'util';
import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import { QueryResult } from 'pg';
import * as fs from 'fs';
import * as pdf from 'html-pdf';
import { groupBy } from 'lodash';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';

import ExcelJs from 'exceljs';
import tracer from 'dd-trace';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getBranchesD = async () => {
  mainLogger.info(`getBranches`);
  const client = await pool.connect();
  const redisClient = Redis.getInstance();
  try {
    mainLogger.info(`getBranches - try`);
    let cachedBranches = await redisClient.getAsync('branches');
    if (cachedBranches !== null) {
      mainLogger.info('getBranches - getting cached branches');
      return JSON.parse(cachedBranches);
    } else {
      mainLogger.info('getBranches - getting branches from db');
      const branches = await client.query(queries.GET_BRANCHES);
      let allBranches = await Promise.all(
        branches.rows.map(async (el) => {
          el.subramos = (await client.query(queries.GET_SUBRANCHES_BY_ID, [el.id])).rows;
          return el;
        })
      );
      await redisClient.setAsync('branches', JSON.stringify(allBranches));
      await redisClient.expireAsync('branches', 36000);
      return allBranches;
    }
  } catch (e) {
    mainLogger.error(`getBranches - ERROR ${e.message}`);
    throw e;
  } finally {
    client.release();
  }
};

export const getBranches = async () => {
  return await tracer.trace('getBranches', getBranchesD);
};

export const generateBranchesReport = async (user, payload: { from: Date; to: Date; alcaldia: boolean }) => {
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      mainLogger.info(payload);
      const alcaldia = payload.alcaldia;
      let pagos = {};
      const ingress = await client.query(queries.GET_INGRESS, [payload.from, payload.to]);
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
          {
            ramo: '122.SAGAS',
            descripcion: 'IVA SM - IVA SAGAS',
            codigo: '122',
            ...(await client.query(queries.GET_SM_IVA_SAGAS, [payload.from, payload.to])).rows[0],
            liquidado: 0,
            cantidadLiq: 0,
          },
          {
            ramo: '122.IMAU',
            descripcion: 'IVA SM - IVA IMAU',
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
      const html = renderFile(resolve(__dirname, alcaldia ? `../views/planillas/sedemat-RPRA.pug` : `../views/planillas/sedemat-RPR.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        datos: {
          ingresos: chunk(branches, 8),
          acumuladoIngresos: `CONTENIDO: TODOS LOS RAMOS, DESDE EL ${moment(payload.from).subtract(4, 'h').format('DD/MM/YYYY')} AL ${moment(payload.to).subtract(4, 'h').format('DD/MM/YYYY')}`,
          cantidadLiqTotal: liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0) + compens.cantidadLiqTotal + ivaSM.cantidadLiqTotal,
          liquidadoTotal: liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0) + compens.liquidadoTotal + ivaSM.liquidadoTotal,
          ingresadoTotal: ingress.rows.reduce((prev, next) => prev + +next.ingresado, 0) + compens.ingresadoTotal + ivaSM.ingresadoTotal,
          cantidadIngTotal: ingress.rows.reduce((prev, next) => prev + +next.cantidadIng, 0) + compens.cantidadIngTotal + ivaSM.cantidadIngTotal,
          metodoPago: pagos,
        },
      });
      const pdfDir = resolve(__dirname, alcaldia ? `../../archivos/sedemat/reportes/RPRA.pdf` : `../../archivos/sedemat/reportes/RPR.pdf`);
      const dir = alcaldia ? `${process.env.SERVER_URL}/sedemat/reportes/RPRA.pdf` : `${process.env.SERVER_URL}/sedemat/reportes/RPR.pdf`;
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
                Key: alcaldia ? 'sedemat/reportes/RPRA.pdf' : 'sedemat/reportes/RPR.pdf',
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

export const getTransfersReport = async ({ reportName = 'RPRTransferencias', from, to }) => {
  mainLogger.info(`getTransfersReport - Creating transfers by method of approval from ${from} to ${to}`);
  const client = await pool.connect();
  try {
    const transformStream = new Transform({
      transform(chunk, encoding, callback) {
        this.push(chunk);
        callback();
      },
    });

    transformStream.on('finish', () => {
      mainLogger.info('getTransfersReport - Stream finished writing');
    });

    const workbook = new ExcelJs.stream.xlsx.WorkbookWriter({
      stream: transformStream,
    });
    workbook.creator = 'SUT';
    workbook.created = new Date();
    workbook.views = [
      {
        x: 0,
        y: 0,
        width: 10000,
        height: 20000,
        firstSheet: 0,
        activeTab: 1,
        visibility: 'visible',
      },
    ];

    const sheet = workbook.addWorksheet(reportName);
    const result = await client.query(queries.GET_TRANSFERS_BY_BANK_BY_APPROVAL, [from, to, from, to, from, to, from, to, from, to]);

    mainLogger.info(`getTransfersReport - Got query, rowCount: ${result.rowCount}`);

    sheet.columns = result.fields.map((row) => {
      return { header: row.name, key: row.name, width: 32 };
    });

    for (let row of result.rows) {
      sheet.addRow(row, 'i').commit();
    }

    sheet.commit();

    await workbook.commit();

    mainLogger.info(`getTransfersReport - Committed workbook`);
    if (dev) {
      const dir = `../../archivos/${reportName}.xlsx`;
      const stream = fs.createWriteStream(require('path').resolve(`./archivos/${reportName}.xlsx`));
      await workbook.xlsx.write(stream);
      return dir;
    } else {
      const bucketParams = {
        Bucket: process.env.BUCKET_NAME as string,

        Key: `/sedemat/reportes/${reportName}.xlsx`,
      };
      await S3Client.upload({ ...bucketParams, Body: transformStream, ACL: 'public-read', ContentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }).promise();

      return `${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`;
    }
  } catch (error) {
    mainLogger.error(error);
    throw errorMessageExtractor(error);
  } finally {
    client.release();
  }
};
