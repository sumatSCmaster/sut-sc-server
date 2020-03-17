import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Campo, Tramite, Usuario } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
import { insertPaymentReference } from './banks';
import MailEmitter from './events/procedureUpdateState';
import { PoolClient } from 'pg';
import { createForm } from './formsHelper';
import switchcase from '@utils/switch';
const pool = Pool.getInstance();

export const getAvailableProcedures = async (user): Promise<{ options: Institucion[]; instanciasDeTramite: any }> => {
  const client: any = await pool.connect();
  client.tipoUsuario = user.tipoUsuario;
  console.log(user);
  try {
    const response = await client.query(queries.GET_ALL_INSTITUTION);
    let institution: Institucion[] = response.rows.map(el => {
      return {
        id: el.id_institucion,
        nombreCompleto: el.nombre_completo,
        nombreCorto: el.nombre_corto,
      };
    });
    if (user.tipoUsuario === 4) {
      institution = institution.filter(el => el.id !== 0);
    }
    const options: Institucion[] = await getProcedureByInstitution(institution, client);
    const instanciasDeTramite = await getProcedureInstances(user, client);
    return { options, instanciasDeTramite };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

export const getAvailableProceduresOfInstitution = async (req: {
  params: { [id: string]: number };
  user: { tipoUsuario: number };
}): Promise<{ options: Institucion; instanciasDeTramite: object[] }> => {
  console.log(req.user);
  const client: PoolClient & { tipoUsuario?: number } = await pool.connect(); //Para cascadear el tipousuario a la busqueda de campos
  client.tipoUsuario = req.user.tipoUsuario;
  const id = req.params['id'];
  try {
    const response = (await client.query(queries.GET_ONE_INSTITUTION, [id])).rows[0];
    const institution: Institucion = {
      id: response.id_institucion,
      nombreCompleto: response.nombre_completo,
      nombreCorto: response.nombre_corto,
    };
    const options = await getProcedureByInstitution([institution], client);
    const instanciasDeTramite = await getProcedureInstancesByInstitution(institution, req.user.tipoUsuario, client);
    return { options, instanciasDeTramite };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

const getProcedureInstances = async (user, client) => {
  try {
    const response = (
      await procedureInstanceHandler(
        user.tipoUsuario === 2 && user.institucion.id === 0 ? 0 : user.tipoUsuario,
        user.tipoUsuario !== 4 ? (user.institucion ? user.institucion.id : 0) : user.id,
        client
      )
    ).rows;
    const takings = (await client.query(queries.GET_TAKINGS_OF_INSTANCES, [response.map(el => +el.id)])).rows;
    return response.map(el => {
      const tramite: Partial<Tramite> = {
        id: el.id,
        tipoTramite: el.tipotramite,
        estado: el.state,
        datos: el.datos,
        planilla: el.planilla,
        certificado: el.certificado,
        costo: el.costo,
        fechaCreacion: el.fechacreacion,
        codigoTramite: el.codigotramite,
        usuario: el.usuario,
        nombreLargo: el.nombrelargo,
        nombreCorto: el.nombrecorto,
        nombreTramiteLargo: el.nombretramitelargo,
        nombreTramiteCorto: el.nombretramitecorto,
        recaudos: takings.filter(taking => taking.id_tramite === el.id).map(taking => taking.url_archivo_recaudo),
      };
      return tramite;
    });
  } catch (error) {
    throw {
      status: 400,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener instancias de tramite',
    };
  }
};

const getProcedureInstancesByInstitution = async (institution, tipoUsuario, client) => {
  try {
    const response = (await procedureInstanceHandler(tipoUsuario, institution.id, client)).rows;
    return response.map(el => {
      const tramite: Partial<Tramite> = {
        id: el.id,
        tipoTramite: el.tipotramite,
        estado: el.state,
        datos: el.datos,
        planilla: el.planilla,
        certificado: el.certificado,
        costo: el.costo,
        fechaCreacion: el.fechacreacion,
        codigoTramite: el.codigotramite,
        usuario: el.usuario,
        nombreLargo: el.nombrelargo,
        nombreCorto: el.nombrecorto,
        nombreTramiteLargo: el.nombretramitelargo,
        nombreTramiteCorto: el.nombretramitecorto,
      };
      return tramite;
    });
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener instancias de tramite',
    };
  }
};

const getProcedureByInstitution = async (institution, client): Promise<Institucion[] | any> => {
  return Promise.all(
    institution.map(async institucion => {
      const procedures = (await client.query(queries.GET_PROCEDURE_BY_INSTITUTION, [institucion.id])).rows;
      institucion.cuentasBancarias = (await client.query(queries.GET_BANK_ACCOUNTS_FOR_INSTITUTION, [institucion.id])).rows.map(cuenta => {
        const documento = cuenta.documento.split(':');
        return {
          id: cuenta.id,
          institucion: cuenta.institucion,
          banco: cuenta.banco,
          numeroCuenta: cuenta.numerocuenta,
          nombreTitular: cuenta.nombretitular,
          [documento[0]]: documento[1].trim(),
        };
      });
      institucion.tramitesDisponibles = await getSectionByProcedure(procedures, client);
      return institucion;
    })
  ).catch(error => {
    throw errorMessageGenerator(error) || error.message || 'Error al obtener las instituciones';
  });
};

const getSectionByProcedure = async (procedure, client): Promise<TipoTramite[] | any> => {
  return await Promise.all(
    procedure.map(async al => {
      const tramite: Partial<TipoTramite> = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base,
        pagoPrevio: al.pago_previo,
      };
      const secciones = (await client.query(queries.GET_SECTIONS_BY_PROCEDURE, [tramite.id])).rows;
      tramite.secciones = await getFieldsBySection(secciones, tramite.id, client);
      tramite.secciones = tramite.secciones?.filter(el => el.campos!.length > 0);
      if (tramite.secciones!.length < 1) {
        delete tramite.secciones;
      }
      tramite.recaudos = (await client.query(queries.GET_TAKINGS_BY_PROCEDURE, [tramite.id])).rows.map(el => {
        return {
          nombreCompleto: el.nombrecompleto,
          nombreCorto: el.nombrecorto,
          id: el.id,
          fisico: el.fisico,
        };
      });
      return tramite;
    })
  ).catch(error => {
    console.log(error);
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las secciones',
    };
  });
};

const getFieldsBySection = async (section, tramiteId, client): Promise<Campo[] | any> => {
  return Promise.all(
    section.map(async el => {
      el.campos = (await fieldsBySectionHandler(tramiteId === 0 ? 0 : client.tipoUsuario, [el.id, tramiteId], client)).rows.map(ul => {
        const id = ul.id_campo;
        delete ul.id_tipo_tramite;
        delete ul.id_campo;
        return { id, ...ul };
      });
      return el;
    })
  ).catch(error => {
    console.log(error);
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los campos',
    };
  });
};

export const updateProcedureCost = async (id: string, newCost: string): Promise<Partial<TipoTramite>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_PROCEDURE_COST, [id, newCost])).rows[0];
    const newProcedure = (await client.query(queries.GET_ONE_PROCEDURE, [id])).rows[0];
    const procedure: Partial<TipoTramite> = {
      id: newProcedure.id_tipo_tramite,
      titulo: newProcedure.nombre_tramite,
      costo: newProcedure.costo_base,
      pagoPrevio: newProcedure.pago_previo,
    };
    client.query('COMMIT');
    return procedure;
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

export const getFieldsForValidations = async (idProcedure, state) => {
  const client = await pool.connect();
  try {
    let takings = 0;
    const response = (await client.query(queries.VALIDATE_FIELDS_FROM_PROCEDURE, [idProcedure, state])).rows;
    if (state === 'iniciado') {
      takings = (await client.query(queries.GET_TAKINGS_FOR_VALIDATION, [idProcedure])).rowCount;
    }
    return { fields: response, takings };
  } catch (error) {
    console.log(error);
    throw {
      status: 400,
      error,
      message: errorMessageGenerator(error) || 'Error en los campos',
    };
  } finally {
    client.release();
  }
};

export const procedureInit = async (procedure, user) => {
  const client = await pool.connect();
  const { tipoTramite, datos, pago, recaudos } = procedure;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.PROCEDURE_INIT, [tipoTramite, JSON.stringify({ usuario: datos }), user.id])).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [response.tipotramite])).rows[0];
    response.sufijo = resources.sufijo;
    const nextEvent = await getNextEventForProcedure(response, client);
    const dir = await createRequestForm(response, client);
    const respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent, null, resources.costo_base || null, dir]);
    if (recaudos.length > 0) {
      recaudos.map(async urlRecaudo => {
        await client.query(queries.INSERT_TAKINGS_IN_PROCEDURE, [response.id, urlRecaudo]);
      });
    }

    if (pago && nextEvent === 'validar_pa') {
      await insertPaymentReference(pago, response.id, client);
    }
    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: response.datos,
      planilla: dir,
      certificado: response.url_certificado,
      costo: +resources.costo_base,
      fechaCreacion: response.fechacreacion,
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
      recaudos,
    };
    client.query('COMMIT');
    sendEmail({ ...tramite, nombreUsuario: user.nombreUsuario, nombreCompletoUsuario: user.nombreCompleto, estado: respState.rows[0].state });
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

//TODO: hacer que el front incluya el estado actual para hacer validaciones
//TODO: validar los eventos del tramite, hacer switchcase de validaciones

export const validateProcedure = async procedure => {
  const client = await pool.connect();
  let dir, respState;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];
    if (!procedure.hasOwnProperty('aprobado') && procedure.estado === 'validando') {
      return { status: 403, message: 'No es posible actualizar este estado' };
    }
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);
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
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
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

export const processProcedure = async procedure => {
  const client = await pool.connect();
  let { datos } = procedure;
  let dir, respState;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);
    if (datos) {
      const prevData = (await client.query('SELECT datos FROM tramites WHERE id_tramite=$1', [procedure.idTramite])).rows[0];
      if (!prevData.datos.funcionario) datos = { usuario: prevData.datos, funcionario: datos };
      else datos = prevData.datos;
    }
    if (nextEvent === 'finalizar') {
      dir = await createCertificate(procedure, client);
      respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, datos || null, dir || null, true]);
    } else {
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, datos || null, procedure.costo || null, null]);
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
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
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

export const addPaymentProcedure = async procedure => {
  const client = await pool.connect();
  let { pago } = procedure;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);
    if (pago && nextEvent.startsWith('validar')) {
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
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
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

export const reviseProcedure = async procedure => {
  const client = await pool.connect();
  const { aprobado, observaciones } = procedure.revision;
  let dir,
    respState,
    datos = null;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.tipoTramite])).rows[0];
    if (!procedure.hasOwnProperty('aprobado')) {
      return { status: 403, message: 'No es posible actualizar este estado' };
    }
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);
    if (observaciones && !aprobado) {
      const prevData = (await client.query('SELECT datos FROM tramites WHERE id_tramite=$1', [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, observaciones };
      datos = prevData.datos;
    }
    if (nextEvent.startsWith('finalizar') && aprobado) {
      dir = await createCertificate(procedure, client);
      respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, datos || null, dir || null, aprobado]);
    } else {
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, datos || null, procedure.costo || null, null]);
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
      codigoTramite: response.codigotramite,
      usuario: response.usuario,
      nombreLargo: response.nombrelargo,
      nombreCorto: response.nombrecorto,
      nombreTramiteLargo: response.nombretramitelargo,
      nombreTramiteCorto: response.nombretramitecorto,
      aprobado: response.aprobado,
    };
    sendEmail({ ...tramite, nombreUsuario: resources.nombreusuario, nombreCompletoUsuario: resources.nombrecompleto, estado: respState.rows[0].state });
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

const createRequestForm = async (procedure, client): Promise<string> => {
  const tramite = (
    await client.query(
      'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado FROM tramites_state_with_resources tsr INNER JOIN tipos_tramites ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
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

const createCertificate = async (procedure, client): Promise<string> => {
  const tramite = (
    await client.query(
      'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado FROM tramites_state_with_resources tsr INNER JOIN tipos_tramites ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
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
    estado: 'finalizado',
    tipoTramite: tramite.tipotramite,
  };
  const form = (await createForm(procedureData, client)) as string;
  return form;
};

const sendEmail = procedure => {
  const mailData = {
    codigoTramite: procedure.codigoTramite,
    emailUsuario: procedure.nombreUsuario,
    nombreCompletoUsuario: procedure.nombreCompletoUsuario,
    nombreTipoTramite: procedure.nombreTramiteLargo,
    nombreCortoInstitucion: procedure.nombreCorto,
    status: procedure.estado,
  };
  MailEmitter.emit('procedureEventUpdated', mailData);
};

const getNextEventForProcedure = async (procedure, client) => {
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
  const nextEvent = procedureEventHandler(procedure.sufijo, response.state);
  return nextEvent;
};

const procedureEvents = switchcase({
  pa: { iniciado: 'validar_pa', validando: 'enproceso_pa', enproceso: 'finalizar_pa' },
  pd: { iniciado: 'enproceso_pd', enproceso: 'ingresardatos_pd', ingresardatos: 'validar_pd', validando: 'finalizar_pd' },
  cr: { iniciado: 'validar_cr', validando: 'enproceso_cr', enproceso: 'revisar_cr', enrevision: 'finalizar_cr' },
})(null);

const procedureEventHandler = (suffix, state) => {
  return procedureEvents(suffix)[state];
};

const procedureInstances = switchcase({
  0: 'SELECT * FROM CASOS_SOCIALES_STATE WHERE tipotramite=$1',
  1: queries.GET_ALL_PROCEDURE_INSTANCES,
  2: queries.GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID,
  3: queries.GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION,
  4: queries.GET_PROCEDURE_INSTANCES_FOR_USER,
})(null);

const procedureInstanceHandler = (typeUser, payload, client) => {
  return typeUser === 1 ? client.query(procedureInstances(typeUser)) : client.query(procedureInstances(typeUser), [payload]);
};

const fieldsBySection = switchcase({
  0: queries.GET_FIELDS_FOR_SOCIAL_CASE,
  4: queries.GET_FIELDS_BY_SECTION,
})(queries.GET_FIELDS_BY_SECTION_FOR_OFFICIALS);

const fieldsBySectionHandler = (typeUser, payload, client) => {
  return client.query(fieldsBySection(typeUser), [...payload]);
};

const updateProcedure = switchcase({
  validando: null,
  enproceso: processProcedure,
  enrevision: reviseProcedure,
  ingresardatos: addPaymentProcedure,
  finalizado: null,
})(null);

export const updateProcedureHandler = async procedure => {
  const client = await pool.connect();
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
  client.release();
  const newProcedureState = updateProcedure(response.state);
  return newProcedureState ? await newProcedureState(procedure) : { status: 500, message: 'No es posible actualizar el trámite' };
};
