import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { PoolClient } from 'pg';
import { createForm } from '@helpers/formsHelper';
import { renderFile } from 'pug';
import { resolve } from 'path';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import { errorMessageGenerator, errorMessageExtractor } from '@helpers/errors';
import { getAllBanks } from '@helpers/banks';
import { mainLogger } from './logger';
import S3Client from '@utils/s3';
import { inspect } from 'util';
const written = require('written-number');

const pool = Pool.getInstance();

export const createRequestForm = async (procedure, client: PoolClient): Promise<string> => {
  const tramite = (await client.query(queries.GET_PROCEDURE_STATE_AND_TYPE_INFORMATION, [procedure.idTramite])).rows[0];
  const procedureData = {
    id: procedure.idTramite,
    fecha: tramite.fechacreacion,
    codigo: tramite.codigotramite,
    formato: tramite.formato,
    tramite: tramite.nombretramitelargo,
    institucion: tramite.nombrecorto,
    datos: tramite.datos,
    estado: tramite.state,
    tipoTramite: tramite.tipotramite,
  };
  const form = (await createForm(procedureData, client)) as string;
  return form;
};

export const createCertificate = async (procedure, client: PoolClient): Promise<string> => {
  const tramite = (await client.query(queries.GET_PROCEDURE_STATE_AND_TYPE_INFORMATION, [procedure.idTramite])).rows[0];
  const PETRO = (await client.query(queries.GET_PETRO_VALUE_FORMAT)).rows[0].valor;
  const costoFormateado = tramite?.costo ? new Intl.NumberFormat('de-DE').format(parseFloat(tramite?.costo)) : '0';
  const procedureData = {
    id: procedure.idTramite,
    fecha: tramite.fechacreacion,
    codigo: tramite.codigotramite,
    formato: tramite.formato,
    tramite: tramite.nombretramitelargo,
    institucion: tramite.nombrecorto,
    datos: procedure.datos || tramite.datos,
    estado: 'finalizado',
    tipoTramite: tramite.tipotramite,
    PETRO,
    costoFormateado,
    bancos: (await getAllBanks()).banks,
  };
  const form = (await createForm(procedureData, client)) as string;
  return form;
};

export const createFiningForm = async (procedure, client: PoolClient): Promise<string> => {
  const tramite = (await client.query(queries.GET_FINING_STATE_AND_TYPE_INFORMATION, [procedure.idTramite])).rows[0];
  const procedureData = {
    id: procedure.idTramite,
    fecha: tramite.fechacreacion,
    codigo: tramite.codigomulta,
    formato: tramite.formato,
    tramite: tramite.nombretramitelargo,
    institucion: tramite.nombrecorto,
    costo: tramite.costo,
    datos: tramite.datos,
    estado: tramite.state,
    tipoTramite: tramite.tipotramite,
  };
  const form = (await createForm(procedureData, client)) as string;
  return form;
};

export const createFiningCertificate = async (procedure, client: PoolClient): Promise<string> => {
  const multa = (await client.query(queries.GET_FINING_STATE_AND_TYPE_INFORMATION, [procedure.idTramite])).rows[0];
  const costoFormateado = new Intl.NumberFormat('de-DE').format(parseFloat(multa.costo));
  const PETRO = new Intl.NumberFormat('de-DE').format(parseFloat(multa.costo) / multa.datos.funcionario.petro);
  const finingData = {
    id: procedure.idTramite,
    fecha: multa.fechacreacion,
    costo: parseFloat(multa.costo),
    costoFormateado,
    codigo: multa.codigomulta,
    formato: multa.formato,
    tramite: multa.nombretramitelargo,
    institucion: multa.nombrecorto,
    datos: procedure.datos || multa.datos,
    estado: 'finalizado',
    tipoTramite: multa.tipotramite,
    PETRO,
  };
  const form = (await createForm(finingData, client)) as string;
  return form;
};

export const createMockCertificate = async (procedure) => {
  const client = await pool.connect();
  try {
    const tramite = (await client.query(queries.GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK, [procedure])).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${tramite.id}`, { errorCorrectionLevel: 'H' });
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    mainLogger.info(tramite.datos, 'tramite.datos');
    const datosCertificado = {
      id: tramite.id,
      fecha: tramite.fechacreacion,
      codigo: tramite.codigotramite,
      formato: tramite.formato,
      tramite: tramite.nombretramitelargo,
      institucion: tramite.nombrecorto,
      datos: tramite.datos,
      estado: 'finalizado',
      tipoTramite: tramite.tipotramite,
      certificado: tramite.sufijo === 'ompu' ? (tramite.aprobado ? tramite.formatocertificado : tramite.formatorechazo) : tramite.formatocertificado,
      bancos: (await getAllBanks()).banks,
    };
    mainLogger.info('<-----------datos certificado----------->:', datosCertificado);

    const html = renderFile(resolve(__dirname, `../views/planillas/${datosCertificado.certificado}.pug`), {
      ...datosCertificado,
      cache: false,
      moment: require('moment'),
      PETRO,
      QR: linkQr,
      written,
    });
    return pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' });
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear el certificado',
    };
  } finally {
    client.release();
  }
};

export const createRRICertificate = async (procedure, areaTerreno, areaConstruccion, codigoRRI) => {
  const client = await pool.connect();
  try {
    return new Promise(async (res, rej) => {
      const tramite = (await client.query(queries.GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK, [procedure])).rows[0];
      mainLogger.info(tramite.datos, 'tramite.datos');
      const datosCertificado = {
        id: tramite.id,
        fecha: tramite.fechacreacion,
        codigo: tramite.codigotramite,
        formato: tramite.formato,
        tramite: tramite.nombretramitelargo,
        institucion: tramite.nombrecorto,
        datos: {
          ...tramite.datos,
          areaTerreno,
          areaConstruccion,
          codigoRRI,
        },
        estado: 'finalizado',
        tipoTramite: tramite.tipotramite,
        certificado: 'cpu-solv-RRI',
      };
      mainLogger.info('<-----------datos certificado----------->:', datosCertificado);
      console.log(datosCertificado, 'PABLITO');
      console.log(tramite, 'PABLITO');
      const html = renderFile(resolve(__dirname, `../views/planillas/${datosCertificado.certificado}.pug`), {
        ...datosCertificado,
        cache: false,
        moment: require('moment'),
      });

      pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' }).toBuffer(async (err, buffer) => {
        if (err) {
          rej(err);
        } else {
          const bucketParams = {
            Bucket: process.env.BUCKET_NAME as string,
            Key: `CPU/planillas/${tramite.id}/certificadoRRI.pdf`,
          };
          await S3Client.putObject({
            ...bucketParams,
            Body: buffer,
            ACL: 'public-read',
            ContentType: 'application/pdf',
          }).promise();
          client.query(queries.INSERT_RRI, [codigoRRI, procedure, `${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`]);
          res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
        }
      });
    });
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al crear el certificado RRI',
    };
  } finally {
    client.release();
  }
};
