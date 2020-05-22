import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';

const pool = Pool.getInstance();

export const validateDocById = async (id: string) => {
  const client = await pool.connect();
  const response = { message: '', status: 0, data: {} };
  try {
    const res = await client.query(queries.GET_PROCEDURE_BY_ID, [id]);
    const cert = await client.query(queries.GET_CERTIFICATE_BY_PROCEDURE_ID, [id]);
    if (res.rowCount !== 0 && cert.rowCount !== 0) {
      const tramite = res.rows[0];
      delete tramite.state;
      const usuario = (await client.query(queries.GET_USER_INFO_BY_ID, [tramite.usuario])).rows[0];
      const tipoTramite = (await client.query(queries.GET_ONE_PROCEDURE_INFO, [tramite.tipotramite])).rows[0];
      const institucion = (await client.query(queries.GET_ONE_INSTITUTION_INFO, [tipoTramite.idInstitucion])).rows[0];
      const data = {
        datosSolicitante: usuario,
        tipoTramite,
        institucion,
        tramite,
        urlCertificado: cert.rows[0].urlCertificado,
      };
      response.message = 'Tramite encontrado';
      response.status = 200;
      response.data = data;
      return response;
    } else {
      response.message = 'Tramite no encontrado';
      response.status = 404;
    }
    return response;
  } catch (e) {
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || 'Error al obtener informacion de validacion',
    };
  } finally {
    client.release();
  }
};

export const validateSedematById = async (id: string) => {
  const client = await pool.connect();
  const response = { message: '', status: 0, data: {} };
  try {
    const res = await client.query(queries.GET_APPLICATION_VIEW_BY_SETTLEMENT, [id]);
    if (res.rowCount !== 0) {
      
      response.message = 'Liquidacion encontrada';
      response.status = 200;
      response.data = res.rows[0];
      return response;
    } else {
      response.message = 'Liquidacion no encontrada';
      response.status = 404;
    }
    return response;
  } catch (e) {
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || 'Error al obtener informacion de validacion',
    };
  } finally {
    client.release();
  }
}