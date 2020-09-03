import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import * as fs from 'fs';

const pool = Pool.getInstance();
const dev = process.env.NODE_ENV !== 'production';

export const getSettlementsReport = async ({ query, reportName }) => {
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      const workbook = new ExcelJs.Workbook();
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

      const result = await client.query(query);

      //   console.log(result);

      sheet.columns = result.fields.map((row) => {
        return { header: row.name, key: row.name, width: 32 };
      });
      sheet.addRows(result.rows, 'i');

      sheet.eachRow((row, rownumber) => {
        console.log(rownumber, 'row:', row);
      });
      if (dev) {
        const dir = `../../archivos/${reportName}.xlsx`;
        const stream = fs.createWriteStream(require('path').resolve(`./archivos/${reportName}.xlsx`));
        await workbook.xlsx.write(stream);
        res(dir);
      } else {
        try {
          const bucketParams = {
            Bucket: 'sut-maracaibo',
            Key: '/sedemat/reportes/liquidaciones.xlsx',
          };
          await S3Client.putObject({
            ...bucketParams,
            Body: await workbook.xlsx.writeBuffer(),
            ACL: 'public-read',
            ContentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          }).promise();
          res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
        } catch (e) {
          rej(e);
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

export const executeReport = async () => {
  const Reporte0309 = await Promise.all(
    [
      {
        query: `SELECT DISTINCT ON (denominacion_comercial) rm.denominacion_comercial, rm.referencia_municipal, telefono_celular, email
        FROM impuesto.registro_municipal rm 
        INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal
        INNER JOIN impuesto.solicitud_state s ON s.id = l.id_liquidacion
        WHERE s.state != 'finalizado' AND l.id_subramo IN (30, 101, 105, 277) ORDER BY denominacion_comercial;`,
        reportName: `CONTRIBUYENTES CON MULTA VIGENTE`,
      },
      {
        query: `SELECT DISTINCT ON (denominacion_comercial) rm.denominacion_comercial, rm.referencia_municipal, telefono_celular, email
        FROM impuesto.registro_municipal rm
        WHERE id_registro_municipal IN (SELECT id_registro_municipal 
                                            FROM impuesto.liquidacion l
                                            INNER JOIN impuesto.solicitud s USING (id_solicitud) 
                                            WHERE id_subramo = 10 AND l.fecha_liquidacion BETWEEN '08-01-2020' AND '09-01-2020' and s.aprobado = true)
        AND   id_registro_municipal NOT IN (SELECT id_registro_municipal 
                                            FROM impuesto.liquidacion l
                                            INNER JOIN impuesto.solicitud s USING (id_solicitud) 
                                            WHERE id_subramo = 66 AND l.fecha_liquidacion BETWEEN '08-01-2020' AND '09-01-2020' and s.aprobado = false);
        `,
        reportName: `CONTRIBUYENTES QUE PAGARON AE Y NO SM`,
      },
      {
        query: `WITH rimsAR AS (
            SELECT id_registro_municipal
            FROM impuesto.registro_municipal rm 
            INNER JOIN impuesto.contribuyente c USING (id_contribuyente)
            WHERE es_agente_retencion = true AND referencia_municipal NOT ILIKE 'AR%'
        ), output AS (
        SELECT denominacion_comercial, referencia_municipal, email, telefono_celular
        FROM impuesto.registro_municipal rm
         INNER JOIN impuesto.liquidacion l ON rm.id_registro_municipal = l.id_registro_municipal
        WHERE l.id_registro_municipal IN (SELECT * FROM rimsAR)
         AND   l.id_registro_municipal NOT IN (SELECT id_registro_municipal FROM (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal 
                                             FROM impuesto.liquidacion l
                                             INNER JOIN impuesto.solicitud s USING (id_solicitud) 
                                             WHERE id_subramo = 9 AND l.fecha_liquidacion BETWEEN '08-01-2020' AND '09-01-2020') l WHERE id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR))
        GROUP BY id_contribuyente, email, rm.id_registro_municipal
        
        )
        SELECT * FROM output`,
        reportName: `RIMS DE AGENTES DE RETENCION QUE NO PAGARON IU`,
      },
    ].map(async (el, i) => {
      console.log(i + 1);
      await getSettlementsReport(el);
    })
  );
};
