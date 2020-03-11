import { resolve } from 'path';
import { access, unlink } from 'fs';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';

const dev = process.env.NODE_ENV !== 'production';

const archivosDict = {
  CBM: 'bomberos',
  SAGAS: 'sagas',
};

export const createForm = ({ fecha, codigo, formato, tramite, institucion, id, datos }) => {
  return new Promise(async (res, rej) => {
    const html = renderFile(resolve(__dirname, `../views/planillas/${archivosDict[institucion]}.pug`), {
      fecha,
      codigo,
      formato,
      tramite,
      institucion,
      datos,
      id,
      cache: false,
    });
    const dir = `${process.env.SERVER_URL}/${codigo}.pdf`;
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${id}`, { errorCorrectionLevel: 'H' });
    const pdfDir = resolve(__dirname, `../../archivos/${codigo}.pdf`);
    if (dev) {
      pdf
        .create(html, { format: 'Letter', border: '5mm', header: { height: '75px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        .toFile(pdfDir, () => {
          res(dir);
        });
    } else {
      try {
        pdf
          .create(html, { format: 'Letter', border: '5mm', header: { height: '75px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
          .toBuffer(async (err, buffer) => {
            if (err) {
              rej(err);
            } else {
              const bucketParams = { Bucket: 'sut-maracaibo', Key: `${institucion}/planillas/${codigo}` };
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
};
