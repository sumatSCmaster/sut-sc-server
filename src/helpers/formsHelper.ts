import { resolve } from 'path'
import { readFile } from 'fs';
import { renderFile } from 'pug';
import * as pdf from 'html-pdf';
import * as templateToPdf from 'html-template-pdf';

const dev = process.env.NODE_ENV !== 'production';

const archivosDict = {
    'CBM': 'bomberos',
    'SAGAS': 'sagas'
}

export const createForm = ({ fecha, codigo,formato, tramite, institucion, datos}) => {
    return new Promise((res, rej) => {
        console.log('ola', "file://" + resolve(__dirname, '../views/planillas/') + '/')
        const html = renderFile(resolve(__dirname, `../views/planillas/${archivosDict[institucion]}.pug`), { fecha, codigo, formato, tramite, institucion,  datos,cache: false });
        const dir = resolve(__dirname, `../../archivos/${codigo}.pdf`);
        console.log(html)
        if(dev){
            pdf.create(html, {format: 'Letter',  border: '5mm', header: { height: '75px' }, base: "file://" + resolve(__dirname, '../views/planillas/') + '/'}).toFile(dir, () => {
                res(dir);
            })
        }else{
            throw new Error('Creacion de planillas en produccion no implementada');
        }
    });
}