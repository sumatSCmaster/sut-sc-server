import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Tramite, Usuario } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import switchcase from '@utils/switch';
import { sendNotification } from './notification';
import { createForm } from './formsHelper';
import { PoolClient } from 'pg';
import { sendEmail } from './events/procedureUpdateState';
import { insertPaymentReference } from './banks';
const pool = Pool.getInstance();

export const finingInit = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  const { tipoTramite, datos, pago } = procedure;
  let costo, respState, dir, cert;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.PROCEDURE_INIT, [tipoTramite, JSON.stringify({ funcionario: datos }), user.id])).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [response.tipotramite])).rows[0];
    response.sufijo = resources.sufijo;
    costo = resources.sufijo === 'ml' ? pago.costo || resources.costo_base : null;
    const nextEvent = await getNextEventForFining(response, client);

    dir = await createRequestForm(response, client);
    respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent, null, costo, dir]);

    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: response.datos,
      planilla: dir,
      certificado: cert,
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
    };
    client.query('COMMIT');

    sendEmail({ ...tramite, nombreUsuario: user.nombreUsuario, nombreCompletoUsuario: user.nombreCompleto, estado: respState.rows[0].state });
    sendNotification(user.cedula, `Un trámite de tipo ${tramite.nombreTramiteLargo} ha sido creado`, 'CREATE', tramite);

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

const addPaymentFining = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let { pago } = procedure;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = (await getNextEventForFining(procedure, client)) as string;
    if (pago && nextEvent.startsWith('validar')) {
      pago.costo = resources.costo;
      await insertPaymentReference(pago, procedure.idTramite, client);
    }

    const respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, null, procedure.costo || null, null]);
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
    client.query('COMMIT');
    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      planilla: response.planilla,
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
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
    sendNotification(user.cedula, `Se añadieron los datos de pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE', tramite);
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

export const validateFining = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let dir, respState;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];
    if (!procedure.hasOwnProperty('aprobado')) {
      return { status: 403, message: 'No es posible actualizar este estado' };
    }
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = (await getNextEventForFining(procedure, client)) as string;
    if (nextEvent.startsWith('finalizar')) {
      dir = await createCertificate(procedure, client);
      respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, null, dir || null, true]);
    } else {
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, null, null, null]);
    }
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
    client.query('COMMIT');
    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      planilla: response.planilla,
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
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
    sendNotification(user.cedula, `Se ha validado el pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE', tramite);
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

const createRequestForm = async (procedure, client: PoolClient): Promise<string> => {
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

const createCertificate = async (procedure, client: PoolClient): Promise<string> => {
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

const getNextEventForFining = async (procedure, client): Promise<object | string> => {
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
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
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
  client.release();
  const newFiningState = updateFining(response.state);
  return newFiningState ? await newFiningState(procedure, user) : { status: 500, message: 'No es posible actualizar el estado del proceso de multa' };
};
