import { resolve } from 'path';
import { access, unlink } from 'fs';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';

const dev = process.env.NODE_ENV !== 'production';

export const createForm = async ({ fecha, codigo, formato, tramite, institucion, id, datos, tipoTramite, estado }, client) => {
  const response = (await client.query('SELECT planilla, certificado FROM tipos_tramites WHERE id_tipo_tramite=$1', [tipoTramite])).rows[0];
  const planilla = estado === 'iniciado' ? response.planilla : response.certificado;
  const dir = estado === 'iniciado' ? `${process.env.SERVER_URL}/${codigo}.pdf` : `${process.env.SERVER_URL}/${codigo}-certificado.pdf`;
  return new Promise(async (res, rej) => {
    const html = renderFile(resolve(__dirname, `../views/planillas/${planilla}.pug`), {
      fecha,
      codigo,
      formato,
      tramite,
      institucion,
      datos,
      id,
      cache: false,
      moment: require('moment')
    });
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${id}`, { errorCorrectionLevel: 'H' });
    const pdfDir = resolve(__dirname, `../../archivos/${dir.split('/')[3].split('.')[0]}.pdf`);
    if (dev) {
      pdf
        .create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
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
              const bucketParams = { Bucket: 'sut-maracaibo', Key: estado === 'iniciado' ? `${institucion}/planillas/${codigo}` : `${institucion}/certificados/${codigo}` };
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
