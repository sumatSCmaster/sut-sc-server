import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import * as fs from 'fs';
import { mainLogger } from '@utils/logger';

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

      sheet.columns = result.fields.map((row) => {
        return { header: row.name, key: row.name, width: 32 };
      });
      sheet.addRows(result.rows, 'i');

      if (dev) {
        const dir = `../../archivos/${reportName}.xlsx`;
        const stream = fs.createWriteStream(require('path').resolve(`./archivos/${reportName}.xlsx`));
        await workbook.xlsx.write(stream);
        res(dir);
      } else {
        try {
          const bucketParams = {
            Bucket: process.env.BUCKET_NAME as string,

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
    mainLogger.error(error);
    return errorMessageExtractor(error);
  } finally {
    client.release();
  }
};

export const executeReport = async () => {
  const Reporte0909 = await Promise.all(
    [
      {
        query: `WITH liquidaciones AS (
        SELECT l.*, r.* FROM impuesto.ramo r INNER JOIN impuesto.subramo sr USING (id_ramo) INNER JOIN impuesto.liquidacion l USING (id_subramo) WHERE fecha_liquidacion BETWEEN '09-01-2020' AND '09-08-2020'
       ),
       solicitudes AS (
       SELECT * FROM impuesto.solicitud WHERE id_solicitud IN (SELECT id_solicitud FROM liquidaciones)
       )
       
         SELECT l.monto, l.fecha_liquidacion AS "fechaLiquidacion", 
         CASE 
           WHEN s.aprobado = true OR s.aprobado IS NULL THEN 'PAGADO' 
           ELSE 'VIGENTE' END
          AS estado,
         c.razon_social AS "razonSocial", c.documento, c.tipo_documento AS "tipoDocumento", rm.referencia_municipal AS "RIM", l.descripcion as ramo
       FROM impuesto.contribuyente c
       INNER JOIN (SELECT * FROM solicitudes) s USING (id_contribuyente) FULL OUTER JOIN (SELECT * FROM liquidaciones) l USING (id_solicitud) 
       LEFT JOIN impuesto.registro_municipal rm USING (id_registro_municipal)
       ORDER BY l.fecha_liquidacion, l.id_registro_municipal`,
        reportName: 'LIQUIDACIONES SEPTIEMBRE SIIIII (SUT)',
      },
    ].map(async (el, i) => {
      await getSettlementsReport(el);
    })
  );
};
