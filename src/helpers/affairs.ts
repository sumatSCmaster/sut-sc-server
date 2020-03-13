import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Tramite, Usuario } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import switchcase from '@utils/switch';
const pool = Pool.getInstance();

export const affairInit = async (affair, user) => {
  const client = await pool.connect();
  const { tipoTramite, datos } = affair;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.PROCEDURE_INIT, [tipoTramite, JSON.stringify(datos), user.id])).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [response.tipotramite])).rows[0];
    response.pagoPrevio = resources.pago_previo;
    const nextEvent = await getNextEventForSocialCase(response, client);
    const respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent, null, resources.costo_base || null, null]);

    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: response.datos,
      costo: +resources.costo_base,
      fechaCreacion: response.fechacreacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
    };
    client.query('COMMIT');
    return {
      status: 201,
      message: 'Tramite iniciado!',
      tramite,
    };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      ...error,
      message: errorMessageGenerator(error) || error.message || 'Error al iniciar el tramite',
    };
  } finally {
    client.release();
  }
};

export const updateAffair = async affair => {
  const client = await pool.connect();
  let { datos } = affair;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [affair.tipoTramite])).rows[0];
    const nextEvent = await getNextEventForSocialCase(affair, client);
    if (!nextEvent) return { status: 403, message: 'El caso social ya ha finalizado, no se puede modificar' };
    if (datos) {
      const prevData = (await client.query('SELECT datos FROM tramites WHERE id_tramite=$1', [affair.idTramite])).rows[0];
      if (!prevData.datos.usuario && !prevData.datos.funcionario) datos = { usuario: prevData.datos, funcionario: datos };
      else datos = prevData.datos;
    }
    // const dir = await createRequestForm(procedure, client);
    const respState = await client.query(queries.UPDATE_STATE, [affair.idTramite, nextEvent, datos || null, affair.costo || null, null]);
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [affair.idTramite])).rows[0];
    client.query('COMMIT');
    const tramite: Partial<Tramite> = {
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
    return { status: 200, message: 'Trámite actualizado', tramite };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al actualizar el tramite',
    };
  } finally {
    client.release();
  }
};

//TODO: completar para casos sociales
const getNextEventForSocialCase = async (affair, client) => {
  const response = (await client.query(queries.GET_PROCEDURE_STATE_FOR_SOCIAL_CASE, [affair.idCaso])).rows[0];
  const nextEvent = socialCaseHandler(response.state, affair.state);
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
