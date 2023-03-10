import { resolve } from 'path';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';
import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
const written = require('written-number');

const dev = process.env.NODE_ENV !== 'production';

export const createForm = async ({ fecha, codigo, formato, tramite, institucion, id, datos, tipoTramite, estado, costoFormateado = '', PETRO = '', costo = 0, codigoRRI = '' }, client) => {
  const response = (await client.query(queries.GET_PLANILLA_AND_CERTIFICATE_TYPE_PROCEDURE, [tipoTramite])).rows[0];
  // const aprobado = (await client.query(queries.GET_APPROVED_STATE_FOR_PROCEDURE, [id])).rows[0]?.aprobado;
  const aprobado = true;
  const planilla = estado === 'iniciado' ? response.planilla : response.sufijo === 'ompu' ? (aprobado ? response.certificado : response.planilla_rechazo) : response.certificado;
  const dir = estado === 'iniciado' ? `${process.env.SERVER_URL}/tramites/${codigo}/planilla.pdf` : `${process.env.SERVER_URL}/tramites/${codigo}/certificado.pdf`;
  const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${id}`, { errorCorrectionLevel: 'H' });
  return new Promise(async (res, rej) => {
    console.log(datos, 'marditos datos dios');
    const html = renderFile(resolve(__dirname, `../views/planillas/${planilla}.pug`), {
      fecha,
      codigo,
      formato,
      tramite,
      institucion,
      datos,
      id,
      cache: false,
      moment: require('moment'),
      QR: linkQr,
      costoFormateado,
      PETRO,
      costo,
      written,
      codigoRRI
    });

    const pdfDir = resolve(__dirname, `../../archivos/tramites/${codigo}/${dir.split('/').pop()}`);
    if (dev) {
      pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, () => {
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
              Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}`,
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
        throw errorMessageExtractor(e);
      } finally {
      }
    }
  });
};


export const createQRForm = async (client) => {
  // const response = (await client.query(queries.GET_PLANILLA_AND_CERTIFICATE_TYPE_PROCEDURE, [tipoTramite])).rows[0];
  // const aprobado = (await client.query(queries.GET_APPROVED_STATE_FOR_PROCEDURE, [id])).rows[0]?.aprobado;
  // const aprobado = true;
  // const planilla = estado === 'iniciado' ? response.planilla : response.sufijo === 'ompu' ? (aprobado ? response.certificado : response.planilla_rechazo) : response.certificado;
  // const dir = estado === 'iniciado' ? `${process.env.SERVER_URL}/tramites/${codigo}/planilla.pdf` : `${process.env.SERVER_URL}/tramites/${codigo}/certificado.pdf`;
  const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/documento`, { errorCorrectionLevel: 'H' });
  return new Promise(async (res, rej) => {
    // console.log(datos, 'marditos datos dios');
    const html = renderFile(resolve(__dirname, `../views/planillas/QRalone.pug`), {
      QR: linkQr,
    });

    // const pdfDir = resolve(__dirname, `../../archivos/tramites/${codigo}/${dir.split('/').pop()}`);
    // if (dev) {
    //   pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toFile(pdfDir, () => {
    //     res(dir);
    //   });
    // } else {
      try {
        pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
          if (err) {
            rej(err);
          } else {
            const bucketParams = {
              Bucket: process.env.BUCKET_NAME as string,
              Key: `QRAlone`,
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
        throw errorMessageExtractor(e);
      } finally {
      }
    // }
  });
};
