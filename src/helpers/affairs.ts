import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Tramite, Usuario } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import switchcase from '@utils/switch';
import { sendNotification } from './notification';
const pool = Pool.getInstance();

export const affairInit = async (affair, user) => {
  const client = await pool.connect();
  const { tipoTramite, datos } = affair;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.SOCIAL_CASE_INIT, [JSON.stringify(datos), user.id])).rows[0];
    const caso: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      fechaCreacion: response.fechacreacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
    };
    client.query('COMMIT');
    sendNotification(user, 'Un trámite ha sido actualizado', 'CREATE_SOCIAL_AFFAIR', 'TRAMITE', caso);
    return {
      status: 201,
      message: 'Caso social iniciado',
      caso,
    };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      ...error,
      message: errorMessageGenerator(error) || error.message || 'Error al iniciar el caso social',
    };
  } finally {
    client.release();
  }
};

export const updateAffair = async (affair, user) => {
  const client = await pool.connect();
  let { estado, datos } = affair;
  try {
    client.query('BEGIN');
    const respState = await client.query(queries.UPDATE_STATE_SOCIAL_CASE, [affair.id, estado, datos || null]);
    const response = (await client.query(queries.GET_SOCIAL_CASE_BY_ID, [affair.id])).rows[0];
    client.query('COMMIT');
    const caso: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      planilla: response.planilla,
      costo: response.costo,
      fechaCreacion: response.fechacreacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
    };
    sendNotification(user, 'Un trámite ha sido actualizado', 'UPDATE_SOCIAL_AFFAIR', 'TRAMITE', caso);
    return { status: 200, message: 'Caso social actualizado', caso };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al actualizar el caso social',
    };
  } finally {
    client.release();
  }
};

//TODO: completar para casos sociales
const getNextEventForSocialCase = async (affair, client) => {
  const response = (await client.query(queries.GET_PROCEDURE_STATE_FOR_SOCIAL_CASE, [affair.id])).rows[0];
  const nextEvent = socialCaseHandler(response.state, affair.estado || 'iniciado');
  return nextEvent;
};

const socialCases = switchcase({
  iniciado: { porrevisar: 'porrevisar', visto: 'visto', aprobado: 'aprobado', negado: 'negado' },
  porrevisar: { visto: 'visto', aprobado: 'aprobado', negado: 'negado' },
  visto: { aprobado: 'aprobado', negado: 'negado' },
  aprobado: { atendido: 'atendido' },
  negado: null,
  atendido: null,
})(null);

const socialCaseHandler = (state, event) => {
  return socialCases(state)[event];
};
