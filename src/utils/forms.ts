import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { PoolClient } from 'pg';
import { createForm } from '@helpers/formsHelper';
import { renderFile } from 'pug';
import { resolve } from 'path';
import * as pdf from 'html-pdf';
import * as qr from 'qrcode';
import { errorMessageGenerator } from '@helpers/errors';

const pool = Pool.getInstance();

export const createRequestForm = async (procedure, client: PoolClient): Promise<string> => {
  const tramite = (
    await client.query(
      'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
      [procedure.idTramite]
    )
  ).rows[0];
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
  const tramite = (
    await client.query(
      'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
      [procedure.idTramite]
    )
  ).rows[0];
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
  };
  const form = (await createForm(procedureData, client)) as string;
  return form;
};

export const createMockCertificate = async (procedure) => {
  const client = await pool.connect();
  try {
    const tramite = (
      await client.query(
        'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado as formatoCertificado FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
        [procedure]
      )
    ).rows[0];
    const linkQr = await qr.toDataURL(`${process.env.CLIENT_URL}/validarDoc/${tramite.id}`, { errorCorrectionLevel: 'H' });
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
      certificado: tramite.formatocertificado,
    };
    const html = renderFile(resolve(__dirname, `../views/planillas/${datosCertificado.certificado}.pug`), {
      ...datosCertificado,
      cache: false,
      moment: require('moment'),
      QR: linkQr,
    });
    return pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' });
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el certificado',
    };
  } finally {
    client.release();
  }
};
