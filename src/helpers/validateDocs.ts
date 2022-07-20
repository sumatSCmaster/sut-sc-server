import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const validateDocById = async (id: string) => {
  const client = await pool.connect();
  const response = { message: '', status: 0, data: {} };
  try {
    const res = await client.query(queries.GET_APPLICATION_BY_ID, [id]);
    // const cert = await client.query(queries.GET_CERTIFICATE_BY_PROCEDURE_ID, [id]);
    if (res.rowCount !== 0 && res.rows[0].aprobado) {
      const tramite = res.rows[0];
      // delete tramite.state;
      const usuario = (await client.query(queries.GET_USER_INFO_BY_ID, [tramite.id_usuario])).rows[0];
      // const tipoTramite = (await client.query(queries.GET_ONE_PROCEDURE_INFO, [tramite.tipotramite])).rows[0];
      // const institucion = (await client.query(queries.GET_ONE_INSTITUTION_INFO, [tipoTramite.idInstitucion])).rows[0];
      const data = {
        datosSolicitante: usuario,
        tipoTramite: 39,
        institucion: 'HACIENDA',
        tramite,
        // urlCertificado: cert.rows[0].urlCertificado,
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
      error: errorMessageExtractor(e),
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
    const res = await client.query(queries.GET_APPLICATION_VIEW_BY_ID, [id]);
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
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener informacion de validacion',
    };
  } finally {
    client.release();
  }
}

export const validateVehicle = async (placa: string) => {
  const client = await pool.connect();
  try {
    let notExists = false;
    if((await client.query(queries.CHECK_VEHICLE_EXISTS, [placa])).rowCount === 0){
      notExists = true;
    }
    const multasVehiculo = await client.query(queries.APPROVED_FINING_BY_VEHICLE_PLATE, [placa])
    const vehiculoSolvente = await client.query(queries.IS_VEHICLE_UP_TO_DATE, [placa])
    
    return { fines: multasVehiculo.rowCount > 0, solvent: notExists ? false : vehiculoSolvente.rows[0].solvente, status: 200 }
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: e.message || 'Error al obtener informacion de validacion',
    };
  } finally {
    client.release();
  }
}

export const validatePerson = async (tipo_documento:string, documento: string) => {
  const client = await pool.connect();
  try {
    const multasUsuario = await client.query(queries.APPROVED_FINING_BY_DOC, [tipo_documento, documento]);
    return { fines: multasUsuario.rowCount > 0, status: 200 };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener informacion de validacion',
    };
  } finally {
    client.release();
  }
}