import { Transform, Readable } from 'stream';
import { resolve } from 'path';
import { chunk } from 'lodash';
import { inspect } from 'util';
import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import { PoolClient, QueryResult } from 'pg';
import * as fs from 'fs';
import * as pdf from 'html-pdf';
import { groupBy } from 'lodash';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';

import ExcelJs from 'exceljs';
import tracer from 'dd-trace';
import { createRPR } from '@utils/createRPR';
import { response } from 'express';
import { arrayreports } from '@utils/arrayReports';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getBranchesD = async (all, id) => {
  mainLogger.info(`getBranches`);
  let client: PoolClient | undefined;
  const redisClient = Redis.getInstance();
  try {
    mainLogger.info(`getBranches - try`);
    // let cachedBranches = await redisClient.getAsync('branches');
    // if (cachedBranches !== null) {
    //   mainLogger.info('getBranches - getting cached branches');
    //   return JSON.parse(cachedBranches);
    // } else {
      mainLogger.info('getBranches - getting branches from db');
      client = await pool.connect();
      let branches;
      console.log(all, 'PABLITO SE SALVOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO')
      if (all) {
        branches = await client.query(queries.GET_BRANCHES);
      } else {
        const idCargo = (await client.query(`SELECT id_cargo FROM cuenta_funcionario WHERE id_usuario = $1`, [id])).rows[0].id_cargo;
        branches = await client.query(queries.GET_BRANCHES_BY_ROL, [idCargo]);
      }
      let allBranches = await Promise.all(
        branches.rows.map(async (el) => {
          if (client) {
            el.subramos = (await client.query(queries.GET_SUBRANCHES_BY_ID, [el.id])).rows;
            return el;
          }
        })
      );
      // await redisClient.setAsync('branches', JSON.stringify(allBranches));
      // await redisClient.expireAsync('branches', 36000);
      return allBranches;
      // }
  } catch (e) {
    mainLogger.error(`getBranches - ERROR ${e.message}`);
    throw e;
  } finally {
    if (client) client.release();
  }
};

export const getBranches = async (all, id) => {
  return await tracer.trace('getBranches', () => getBranchesD(all, id));
};

export const generateBranchesReport = async (user, payload: { from: Date; to: Date; alcaldia: boolean }) => {
  const client = await pool.connect();
  try {
    const id = Math.trunc(Math.random() * 10000).toString();
    createRPR(id, payload);
    return id;
  } catch (error) {
    throw errorMessageExtractor(error);
  } finally {
    client.release();
  }
};

export const generateBranchesReportById = async (id) => {
  try {
    const report = arrayreports.find((ele) => ele.id === id)?.url; //handle not found report
    if (!report) throw new Error('La solicitud sigue en proceso...');
    arrayreports.splice(arrayreports.findIndex((ele) => ele.id === id));
    return report;
  } catch (error) {
    throw errorMessageExtractor(error);
  }
};

export const getTransfersReportBank = async ({ reportName = 'RPRTransferenciasBanco', day, id }) => {
  mainLogger.info(`getTransfersReport - Creating transfers by method of approval from ${day}`);
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
    const result = await client.query(queries.GET_TRANSFERS_BY_BANK_BY_APPROVAL_NEW, [day, id]);

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

        Key: `/hacienda/reportes/${reportName}.xlsx`,
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

        Key: `/hacienda/reportes/${reportName}.xlsx`,
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

export const getCondoReport = async (payload) => {
  mainLogger.info(payload, 'condoReport info');
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      mainLogger.info(payload, 'payload');
      let pagos = {};
      const ingress = await client.query(queries.GET_INGRESS_CONDO, [payload.from, payload.to]);
      const liquidated = await client.query(queries.GET_LIQUIDATED_CONDO, [payload.from, payload.to]);
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

      // let result = pivot.rows.reduce((prev, next) => {
      //   if (other.rows.some((otherRow) => otherRow.ramo === next.ramo)) {
      //     let otherRow = other.rows.find((el) => el.ramo === next.ramo);
      //     next[columns[0]] = otherRow[columns[0]];
      //     next[columns[1]] = otherRow[columns[1]];
      //   }
      //   prev.push(next);
      //   return prev;
      // }, []);

      // let filtered = other.rows.filter((val) => !result.find((resultRow) => resultRow.ramo === val.ramo));

      // result.push(...filtered);
      // pivotColumns.push(...columns);
      // result = result.map((val) => {
      //   for (let col of pivotColumns) {
      //     val[col] = val[col] || 0;
      //   }
      //   return val;
      // });

      // let final = groupBy(result, (res) => res.codigo);
      // let branches = (await client.query(queries.GET_BRANCHES_FOR_REPORT)).rows.filter((row) => row.ramo in final);

      // branches = branches
      //   .map((branch) => {
      //     return {
      //       ...branch,
      //       subRamo: final[branch.ramo],
      //     };
      //   })
      //   .map((branch) => {
      //     return {
      //       ...branch,
      //       liquidadoTotal: branch.subRamo.reduce((prev, next) => prev + +next.liquidado, 0),
      //       cantidadLiqTotal: branch.subRamo.reduce((prev, next) => prev + +next.cantidadLiq, 0),
      //       ingresadoTotal: branch.subRamo.reduce((prev, next) => prev + +next.ingresado, 0),
      //       cantidadIngTotal: branch.subRamo.reduce((prev, next) => prev + +next.cantidadIng, 0),
      //     };
      //   })
      //   .filter((branch) => branch.subRamo.reduce((prev, next) => prev + +next.ingresado + +next.liquidado, 0) > 0);

      mainLogger.info(liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0));
      mainLogger.info(liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0));
      const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RPRA.pug`), {
        moment: require('moment'),
        institucion: 'HACIENDA',
        datos: {
          // ingresos: chunk(branches, 8),
          acumuladoIngresos: `CONTENIDO: CONDOMINIOS, DESDE EL ${moment(payload.from).subtract(4, 'h').format('DD/MM/YYYY')} AL ${moment(payload.to).subtract(4, 'h').format('DD/MM/YYYY')}`,
          cantidadLiqTotal: liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0),
          liquidadoTotal: liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0),
          ingresadoTotal: ingress.rows.reduce((prev, next) => prev + +next.ingresado, 0),
          cantidadIngTotal: ingress.rows.reduce((prev, next) => prev + +next.cantidadIng, 0),
          metodoPago: pagos,
        },
      });
      const pdfDir = resolve(__dirname, `../../archivos/hacienda/reportes/RPRA.pdf`);
      const dir = `${process.env.SERVER_URL}/hacienda/reportes/RPRA.pdf`;
      if (dev) {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, async () => {
          res(dir);
        });
      } else {
        try {
          pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
            if (err) {
              mainLogger.error(err);
              rej(err);
            } else {
              const bucketParams = {
                Bucket: process.env.BUCKET_NAME as string,
                Key: 'hacienda/reportes/RPRCondominio.pdf',
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
          mainLogger.info(e.message);
          throw e;
        } finally {
        }
      }
    });
  } catch (error) {
    mainLogger.info(error.message);
    throw errorMessageExtractor(error);
  } finally {
    client.release();
  }
};

export const getCondoReportDisclosed = async ({ reportName = 'ReporteCondoL', from, to }) => {
  mainLogger.info(`getCondoLReport`);
  const client = await pool.connect();
  try {
    const transformStream = new Transform({
      transform(chunk, encoding, callback) {
        this.push(chunk);
        callback();
      },
    });

    transformStream.on('finish', () => {
      mainLogger.info('getCondoLReport - Stream finished writing');
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
    const result = await client.query(queries.GET_LIQUIDATED_CONDO_DISCLOSED, [from, to]);

    mainLogger.info(`getCondoLReport - Got query, rowCount: ${result.rowCount}`);

    sheet.columns = result.fields.map((row) => {
      return { header: row.name, key: row.name, width: 32 };
    });

    for (let row of result.rows) {
      sheet.addRow(row, 'i').commit();
    }

    sheet.commit();

    await workbook.commit();

    mainLogger.info(`getCondoLReport - Committed workbook`);
    if (dev) {
      const dir = `../../archivos/${reportName}.xlsx`;
      const stream = fs.createWriteStream(require('path').resolve(`./archivos/${reportName}.xlsx`));
      await workbook.xlsx.write(stream);
      return dir;
    } else {
      const bucketParams = {
        Bucket: process.env.BUCKET_NAME as string,

        Key: `/hacienda/reportes/${reportName}.xlsx`,
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
