import { resolve } from 'path';
import { readFile } from 'fs';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
const dev = process.env.NODE_ENV !== 'production';

const archivosDict = {
  CBM: 'bomberos',
  SAGAS: 'sagas',
};

export const createForm = ({ fecha, codigo, formato, tramite, institucion, id, datos }) => {
  return new Promise(async (res, rej) => {
    console.log('marica ya', resolve(__dirname, `../views/planillas/${archivosDict[institucion]}.pug`));
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
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${id}`, {errorCorrectionLevel: 'H'});
    if (dev) {
      pdf
        .create(html, { format: 'Letter', border: '5mm', header: { height: '75px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
        .toFile(resolve(__dirname, `../../archivos/${codigo}.pdf`), () => {
          res(dir);
        });
    } else {
      throw new Error('Creacion de planillas en produccion no implementada');
    }
  });
};
