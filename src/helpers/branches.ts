import { resolve } from 'path';
import { chunk } from 'lodash';
import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';
import { QueryResult } from 'pg';
import * as pdf from 'html-pdf';
import { groupBy } from 'lodash';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getBranches = async () => {
  const client = await pool.connect();
  try {
    const branches = await client.query(queries.GET_BRANCHES);
    return Promise.all(
      branches.rows.map(async (el) => {
        el.subramos = (await client.query(queries.GET_SUBRANCHES_BY_ID, [el.id])).rows;
        return el;
      })
    );
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const generateBranchesReport = async (user, payload: { from: Date; to: Date; alcaldia: boolean }) => {
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      console.log(payload)
      console.log((await client.query('SELECT $1 AS from, $2 AS to', [payload.from, payload.to])).rows)
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

      //console.log('other', other.rows);

      //console.log('result pre filter', result);
      let filtered = other.rows.filter((val) => !result.find((resultRow) => resultRow.ramo === val.ramo));
      //console.log('filtered', filtered);

      result.push(...filtered);
      //console.log('result', result);
      pivotColumns.push(...columns);
      //console.log(pivotColumns);
      result = result.map((val) => {
        for (let col of pivotColumns) {
          val[col] = val[col] || 0;
        }
        return val;
      });

      //console.log('FINAL RES', result);
      //console.log(
      //  'FILTERED THING',
      //  groupBy(result, (res) => res.codigo)
      //);
      let final = groupBy(result, (res) => res.codigo);
      let branches = (await client.query(queries.GET_BRANCHES_FOR_REPORT)).rows.filter((row) => row.ramo in final);
      //console.log(branches);
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
      //console.log('branches', branches);
      //console.log(branches[0].subRamo);
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
      //console.log(compens);
      //console.log('branches 2', branches);
      if (!alcaldia) {
        console.log(1, (await client.query(`
        SELECT * FROM pago p 
        INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
        INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
        WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_aprobacion BETWEEN '2020-08-06T00:00:00.000Z' AND '2020-08-06T23:59:59.999Z'
        `)).rows)
        console.log(2, (await client.query(`
        SELECT *, (SELECT current_setting('TIMEZONE')) as timezss FROM pago p 
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_aprobacion BETWEEN $1 AND $2`, [payload.from, payload.to])))
        const transfersByBank = (await client.query(queries.GET_TRANSFERS_BY_BANK, [payload.from, payload.to])).rows;
        const totalTranfersByBank = +transfersByBank.reduce((prev, next) => prev + +next.monto, 0);

        const cash = (await client.query(queries.GET_CASH_REPORT, [payload.from, payload.to])).rows;
        const cashTotal = +cash[0].monto || 0;

        const pos = +(await client.query(queries.GET_POS, [payload.from, payload.to])).rows[0].total || 0;

        const check = +(await client.query(queries.GET_CHECKS, [payload.from, payload.to])).rows[0].total || 0;

        const cred = +(await client.query(queries.GET_CREDIT_REPORT, [payload.from, payload.to])).rows[0].total || 0;

        console.log('transfersBybank', transfersByBank);
        console.log('totaltransfersbybank', totalTranfersByBank);
        console.log('cash', cash);
        console.log('pos', pos);
        console.log('check', check);
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
      
      const html = renderFile(resolve(__dirname, alcaldia ? `../views/planillas/sedemat-RPRA.pug` : `../views/planillas/sedemat-RPR.pug`), {
        moment: require('moment'),
        institucion: 'SEDEMAT',
        datos: {
          ingresos: chunk(branches, 10),
          acumuladoIngresos: `CONTENIDO: TODOS LOS RAMOS, DESDE EL ${moment.utc(payload.from).format('DD/MM/YYYY')} AL ${moment.utc(payload.to).format('DD/MM/YYYY')}`,
          cantidadLiqTotal: liquidated.rows.reduce((prev, next) => prev + +next.cantidadLiq, 0) + compens.cantidadLiqTotal,
          liquidadoTotal: liquidated.rows.reduce((prev, next) => prev + +next.liquidado, 0) + compens.liquidadoTotal,
          ingresadoTotal: ingress.rows.reduce((prev, next) => prev + +next.ingresado, 0) + compens.ingresadoTotal,
          cantidadIngTotal: ingress.rows.reduce((prev, next) => prev + +next.cantidadIng, 0) + compens.cantidadIngTotal,
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
                Bucket: 'sut-maracaibo',
                Key: alcaldia ? '/sedemat/reportes/RPRA.pdf' : '/sedemat/reportes/RPR.pdf',
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
