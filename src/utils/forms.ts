import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { PoolClient } from 'pg';
import { createForm } from '@helpers/formsHelper';
import { renderFile } from 'pug';
import { resolve } from 'path';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import { errorMessageGenerator, errorMessageExtractor } from '@helpers/errors';
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
  const UTMM = (await client.query(queries.GET_UTMM_VALUE_FORMAT)).rows[0].valor;
  const costoFormateado = tramite.datos?.funcionario?.costo ? new Intl.NumberFormat('de-DE').format(parseFloat(tramite.datos?.funcionario?.costo)) : '0';
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
    UTMM,
    costoFormateado,
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
  const UTMM = new Intl.NumberFormat('de-DE').format(parseFloat(multa.costo) / multa.datos.funcionario.utmm);
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
    UTMM,
  };
  const form = (await createForm(finingData, client)) as string;
  return form;
};

export const createMockCertificate = async (procedure) => {
  const client = await pool.connect();
  try {
    const tramite = (await client.query(queries.GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK, [procedure])).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${tramite.id}`, { errorCorrectionLevel: 'H' });
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
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
    };
    console.log('datos:', datosCertificado.datos, 'datos.funcionario:', datosCertificado.datos.funcionario);
    const html = renderFile(resolve(__dirname, `../views/planillas/${datosCertificado.certificado}.pug`), {
      ...datosCertificado,
      cache: false,
      moment: require('moment'),
      UTMM,
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
