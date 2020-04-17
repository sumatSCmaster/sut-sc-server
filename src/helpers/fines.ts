import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Usuario, Multa } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import switchcase from '@utils/switch';
import { sendNotification } from './notification';
import { sendEmail } from './events/procedureUpdateState';
import { insertPaymentReference } from './banks';
import { createFiningCertificate } from '@utils/forms';
const pool = Pool.getInstance();

export const finingInit = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  const { tipoTramite, datos, monto } = procedure;
  let costo, respState;
  try {
    client.query('BEGIN');
    const response = (
      await client.query(queries.FINING_INIT, [tipoTramite, JSON.stringify({ usuario: datos }), procedure.nacionalidad, procedure.cedula, user.id])
    ).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_FINING, [response.tipotramite, response.idTramite])).rows[0];
    response.sufijo = resources.sufijo;
    costo = resources.sufijo === 'ml' ? monto || resources.costo_base : null;
    const nextEvent = await getNextEventForFining(response, client);

    respState = await client.query(queries.UPDATE_FINING, [response.id, nextEvent, null, costo, null]);
    const multa: Partial<Multa> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: response.datos,
      costo,
      fechaCreacion: response.fechacreacion,
      fechaCulminacion: response.fechaculminacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
      cedula: response.cedula,
      nacionalidad: response.nacionalidad,
    };
    client.query('COMMIT');

    sendEmail({ ...multa, nombreUsuario: user.nombreUsuario, nombreCompletoUsuario: user.nombreCompleto, estado: respState.rows[0].state });
    // sendNotification(user, `Un trámite de tipo ${tramite.nombreTramiteLargo} ha sido creado`, 'CREATE_FINING', 'MULTA', multa);

    return {
      status: 201,
      message: 'Multa asignada!',
      multa,
    };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      ...error,
      message: errorMessageGenerator(error) || error.message || 'Error al asignar una multa',
    };
  } finally {
    client.release();
  }
};

const addPaymentFining = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let { pago } = procedure;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_FINING, [procedure.tipoTramite, procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = (await getNextEventForFining(procedure, client)) as string;

    if (pago && nextEvent.startsWith('validar')) {
      pago.costo = resources.costo;
      pago.concepto = 'MULTA';
      await insertPaymentReference(pago, procedure.idTramite, client);
    }

    const respState = await client.query(queries.UPDATE_FINING, [procedure.idTramite, nextEvent, null, procedure.costo || null, null]);
    const response = (await client.query(queries.GET_FINING_BY_ID, [procedure.idTramite])).rows[0];
    client.query('COMMIT');
    const multa: Partial<Multa> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      boleta: response.urlboleta,
      certificado: null,
      costo: response.costo,
      fechaCreacion: response.fechacreacion,
      fechaCulminacion: response.fechaculminacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
      cedula: response.cedula,
      nacionalidad: response.nacionalidad,
    };
    sendEmail({ ...multa, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
    // sendNotification(user, `Se añadieron los datos de pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_FINING', 'MULTA', multa);
    return { status: 200, message: 'Datos de pago para multa insertados', multa };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al insertar datos de pago',
    };
  } finally {
    client.release();
  }
};

export const validateFining = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let dir, respState;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_FINING, [procedure.tipoTramite, procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('aprobado')) {
      return { status: 403, message: 'No es posible actualizar este estado' };
    }

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }

    const nextEvent = (await getNextEventForFining(procedure, client)) as string;
    if (nextEvent.startsWith('finalizar')) {
      dir = await createFiningCertificate(procedure, client);
      respState = await client.query(queries.COMPLETE_FINING, [procedure.idTramite, nextEvent, null, dir, true]);
    } else {
      respState = await client.query(queries.UPDATE_FINING, [procedure.idTramite, nextEvent, null, null, null]);
    }
    const response = (await client.query(queries.GET_FINING_BY_ID, [procedure.idTramite])).rows[0];
    client.query('COMMIT');
    const multa: Partial<Multa> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      boleta: response.urlboleta,
      certificado: dir,
      costo: response.costo,
      fechaCreacion: response.fechacreacion,
      fechaCulminacion: response.fechaculminacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
      cedula: response.cedula,
      nacionalidad: response.nacionalidad,
    };
    sendEmail({ ...multa, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
    // sendNotification(user, `Se ha validado el pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_FINING', 'MULTA', multa);
    return { status: 200, message: 'Pago de multa validado', multa };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al validar pago de multa',
    };
  } finally {
    client.release();
  }
};

const getNextEventForFining = async (procedure, client): Promise<object | string> => {
  const response = (await client.query(queries.GET_FINING_STATE, [procedure.idTramite])).rows[0];
  const nextEvent = fineEventHandler(procedure.sufijo, response.state);
  return nextEvent;
};

const fineEvents = switchcase({ ml: { iniciado: 'ingresardatos_ml', ingresardatos: 'validar_ml', validando: 'finalizar_ml' } })(null);

const fineEventHandler = (suffix, state) => {
  return fineEvents(suffix)[state];
};

const updateFining = switchcase({
  validando: null,
  ingresardatos: addPaymentFining,
  finalizado: null,
})(null);

export const updateFiningHandler = async (procedure, user) => {
  const client = await pool.connect();
  const response = (await client.query(queries.GET_FINING_STATE, [procedure.idTramite])).rows[0];
  client.release();
  const newFiningState = updateFining(response.state);
  return newFiningState ? await newFiningState(procedure, user) : { status: 500, message: 'No es posible actualizar el estado del proceso de multa' };
};
