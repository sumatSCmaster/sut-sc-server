import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Institucion, TipoTramite, Campo, Tramite, Usuario, Liquidacion } from '@interfaces/sigt';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { insertPaymentReference, insertPaymentCashier } from './banks';
import { PoolClient } from 'pg';
import switchcase from '@utils/switch';
import { sendNotification } from './notification';
import { sendEmail } from './events/procedureUpdateState';
import { createRequestForm, createCertificate } from '@utils/forms';
import { approveContributorBenefits, approveContributorSignUp, approveContributorAELicense, createSettlementForProcedure } from './settlement';
import { installLiquorLicense, renewLiquorLicense } from './liquors';
import { createVehicleStructureForProcedure } from './vehicles';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

export const getAvailableProcedures = async (user): Promise<{ instanciasDeTramite: any; instanciasDeMulta: any; instanciasDeImpuestos: any; instanciasDeSoporte: any }> => {
  const client: any = await pool.connect();
  client.tipoUsuario = user.tipoUsuario;
  mainLogger.info(`getAvailableProcedures: user: ${user.id}`);

  try {
    const response = await client.query(queries.GET_ALL_INSTITUTION);
    let institution: Institucion[] = response.rows.map((el) => {
      return {
        id: el.id_institucion,
        nombreCompleto: el.nombre_completo,
        nombreCorto: el.nombre_corto,
      };
    });
    if (user.tipoUsuario === 4) {
      institution = institution.filter((el) => el.id !== 0);
    }
    // const options: Institucion[] = await getProcedureByInstitution(institution, client);
    mainLogger.info(`getAvailableProcedures: obtaining instances`);
    const instanciasDeTramiteP = getProcedureInstances(user, client);
    const instanciasDeMultaP = getFineInstances(user, client);
    const instanciasDeImpuestosP = getSettlementInstances(user, client);
    const instanciasDeSoporteP = getProcedureInstances(user, client, true);
    const [instanciasDeTramite, instanciasDeMulta, instanciasDeImpuestos, instanciasDeSoporte] = await Promise.all([instanciasDeTramiteP, instanciasDeMultaP, instanciasDeImpuestosP, instanciasDeSoporteP]);
    mainLogger.info(`getAvailableProcedures: finished obtaining instances`);
    return { instanciasDeTramite, instanciasDeMulta, instanciasDeImpuestos, instanciasDeSoporte };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

export const getAvailableProceduresOfInstitution = async (req: { params: { [id: string]: number }; user: { tipoUsuario: number } }): Promise<{ options: Institucion; instanciasDeTramite }> => {
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
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

const esDaniel = ({ tipoUsuario, institucion }) => {
  return tipoUsuario === 2 && institucion.id === 9;
};

const getProcedureInstances = async (user, client: PoolClient, support?) => {
  try {
    let response = (await procedureInstanceHandler(user, client, support)).rows; //TODO: corregir el handler para que no sea tan forzado
    const takings = (await client.query(queries.GET_TAKINGS_OF_INSTANCES, [response.map((el) => +el.id)])).rows;
    if (user.tipoUsuario === 3) {
      const permissions = (await client.query(queries.GET_USER_PERMISSIONS, [user.id])).rows.map((row) => +row.id_tipo_tramite) || [];
      response = response.filter((tram) => permissions.includes(tram.tipotramite));
    }
    let res: any[] = await Promise.all(
      response.map(async (el) => {
        let ordinances;
        if (!el.pagoPrevio) {
          ordinances = (await client.query(queries.ORDINANCES_PROCEDURE_INSTANCES, [el.id])).rows;
        }
        const tramite: Partial<Tramite> = {
          id: el.id,
          tipoTramite: el.tipotramite,
          estado: el.state,
          aprobado: el.aprobado,
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
          recaudos: takings.filter((taking) => taking.id_tramite === el.id).map((taking) => taking.url_archivo_recaudo),
          bill: !el.pagoPrevio
            ? {
                items: ordinances.map((ord) => {
                  return {
                    id: ord.id,
                    idTramite: ord.idTramite,
                    costoOrdenanza: +ord.costoOrdenanza,
                    ordenanza: ord.ordenanza,
                    factor: ord.factor,
                    factorValue: +ord.factorValue,
                    petro: +ord.petro,
                    valorCalc: +ord.valorCalc,
                  };
                }),
                totalBs: ordinances.reduce((p, n) => p + +n.valorCalc, 0),
                totalPetro: ordinances.reduce((p, n) => p + +n.petro, 0),
              }
            : undefined,
        };
        return tramite;
      })
    );
    if (!support) {
      res = res.filter((row) => row.tipoTramite !== 37);
    }
    return esDaniel(user) ? res.filter((row) => ![27, 39, 40].includes(row.tipoTramite)) : res;
  } catch (error) {
    mainLogger.error(errorMessageExtractor(error));
    throw new Error('Error al obtener instancias de tramite');
  }
};

const getFineInstances = async (user, client: PoolClient) => {
  try {
    let response = (await fineInstanceHandler(user, client)).rows;
    return response.map((el) => {
      const multa = {
        id: el.id,
        datos: el.datos,
        estado: el.state,
        tipoTramite: el.tipoTramite,
        costo: el.costo,
        fechaCreacion: el.fechacreacion,
        codigoMulta: el.codigomulta,
        certificado: el.urlcertificado,
        boleta: el.urlboleta,
        usuario: el.usuario,
        cedula: el.cedula,
        nacionalidad: el.nacionalidad,
        aprobado: el.aprobado,
        nombreTramiteLargo: el.nombretramitelargo,
        nombreTramiteCorto: el.nombretramitecorto,
        nombreLargo: el.nombrelargo,
        nombreCorto: el.nombrecorto,
      };

      return multa;
    });
  } catch (error) {
    mainLogger.error(errorMessageExtractor(error));
    throw new Error('Error al obtener instancias de multa');
  }
};

const getSettlementInstances = async (user, client: PoolClient) => {
  try {
    if (belongsToAnInstitution(user)) {
      return [];
    } else {
    }
    let query = queries.GET_SETTLEMENT_INSTANCES_BY_ID;
    let payload = [user.id];
    let response = (await client.query(query, payload)).rows;
    return response.map((el) => {
      const liquidacion: Liquidacion & { pagado: string; aprobado: string; nombreCorto: string } = {
        id: el.id_liquidacion,
        ramo: el.descripcion,
        nombreCorto: el.descripcion_corta,
        fecha: { month: el.datos.fecha?.month || el.datos.month, year: el.datos.fecha?.year || el.datos.year },
        monto: el.monto,
        montoPetro: el.monto_petro,
        certificado: el.certificado,
        recibo: el.recibo,
        pagado: el.pagado,
        aprobado: el.aprobado,
        estado: el.state,
      };

      return liquidacion;
    });
  } catch (error) {
    mainLogger.error(errorMessageExtractor(error));
    throw new Error('Error al obtener instancias de liquidacion');
  }
};

const getProcedureInstancesByInstitution = async (institution, tipoUsuario, client: PoolClient) => {
  try {
    const response = (await procedureInstanceHandlerByInstitution(tipoUsuario, institution.id, client)).rows;
    return Promise.all(
      response.map(async (el) => {
        let ordinances;
        if (!el.pagoPrevio) {
          ordinances = (await client.query(queries.ORDINANCES_PROCEDURE_INSTANCES, [el.id])).rows;
        }
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
          bill: !el.pagoPrevio
            ? {
                items: ordinances.map((ord) => {
                  return {
                    id: ord.id,
                    idTramite: ord.idTramite,
                    costoOrdenanza: +ord.costoOrdenanza,
                    ordenanza: ord.ordenanza,
                    factor: ord.factor,
                    factorValue: +ord.factorValue,
                    petro: +ord.petro,
                    valorCalc: +ord.valorCalc,
                  };
                }),
                totalBs: ordinances.reduce((p, n) => p + +n.valorCalc, 0),
                totalPetro: ordinances.reduce((p, n) => p + +n.petro, 0),
              }
            : undefined,
        };
        return tramite;
      })
    );
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener instancias de tramite',
    };
  }
};

const getProcedureByInstitution = async (institution, client: PoolClient): Promise<Institucion[] | any> => {
  return Promise.all(
    institution.map(async (institucion) => {
      institucion.tiposUsuarios = await Promise.all(
        (await client.query(queries.GET_USER_TYPES)).rows.map(async (el) => ({
          id: el.id_tipo_usuario,
          descripcion: el.descripcion,
          cargos: await Promise.all((await client.query(queries.GET_JOBS_BY_TYPES_AND_INSTITUTION, [el.id_tipo_usuario, institucion.id])).rows),
        }))
      );
      const procedures = (await client.query(queries.GET_PROCEDURE_BY_INSTITUTION, [institucion.id])).rows;
      institucion.cuentasBancarias = (await client.query(queries.GET_BANK_ACCOUNTS_FOR_INSTITUTION, [institucion.id])).rows.map((cuenta) => {
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
  ).catch((error) => {
    throw errorMessageGenerator(error) || error.message || 'Error al obtener las instituciones';
  });
};

const getSectionByProcedure = async (procedure, client: PoolClient): Promise<TipoTramite[] | any> => {
  return await Promise.all(
    procedure.map(async (al) => {
      const tramite: Partial<TipoTramite> = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base,
        petro: al.costo_petro,
        pagoPrevio: al.pago_previo,
        sufijo: al.sufijo,
        necesitaCodCat: al.utiliza_informacion_catastral,
      };
      const secciones = (await client.query(queries.GET_SECTIONS_BY_PROCEDURE, [tramite.id])).rows;
      tramite.secciones = await getFieldsBySection(secciones, tramite.id, client);
      tramite.secciones = tramite.secciones?.filter((el) => el.campos!.length > 0);
      if (tramite.secciones!.length < 1) {
        delete tramite.secciones;
      }
      tramite.recaudos = (await client.query(queries.GET_TAKINGS_BY_PROCEDURE, [tramite.id])).rows.map((el) => {
        return {
          nombreCompleto: el.nombrecompleto,
          nombreCorto: el.nombrecorto,
          id: el.id,
          fisico: el.fisico,
          obligatorio: el.obligatorio,
          planilla: el.planilla,
          extension: el.extension,
        };
      });
      return tramite;
    })
  ).catch((error) => {
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las secciones',
    };
  });
};

const getFieldsBySection = async (section, tramiteId, client): Promise<Campo[] | any> => {
  return Promise.all(
    section.map(async (el) => {
      el.campos = (await fieldsBySectionHandler(tramiteId === 0 ? 0 : client.tipoUsuario, [el.id, tramiteId], client)).rows.map((ul) => {
        const id = ul.id_campo;
        delete ul.id_tipo_tramite;
        delete ul.id_campo;
        return { id, ...ul };
      });
      return el;
    })
  ).catch((error) => {
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los campos',
    };
  });
};

export const updateProcedureCost = async (id: string, newCost: string): Promise<Partial<TipoTramite>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = (await client.query(queries.GET_PETRO_VALUE)).rows[0];
    const response = (await client.query(queries.UPDATE_PROCEDURE_COST, [id, newCost, parseFloat(newCost) * parseFloat(res.valor_en_bs)])).rows[0];
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
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

export const getFieldsForValidations = async ({ id, type }) => {
  const client = await pool.connect();
  let response;
  try {
    let takings = 0;
    if (id) {
      const resources = (await client.query(queries.GET_STATE_AND_TYPE_OF_PROCEDURE, [id])).rows[0];
      response = (await client.query(queries.VALIDATE_FIELDS_FROM_PROCEDURE, [resources.tipotramite, resources.state])).rows;
    } else {
      response = (await client.query(queries.VALIDATE_FIELDS_FROM_PROCEDURE, [type, 'iniciado'])).rows;
    }
    // if (resources.state === 'iniciado') {
    //   takings = (await client.query(queries.GET_TAKINGS_FOR_VALIDATION, [resources.tipotramite])).rowCount;
    // }
    return { fields: response, takings };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 400,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error en los campos',
    };
  } finally {
    client.release();
  }
};

export const getProcedureById = async ({ id, client }: { id: number; client: PoolClient }): Promise<Partial<Tramite>> => {
  try {
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [id])).rows[0];
    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: response.state,
      datos: response.datos,
      planilla: response.planilla,
      certificado: response.certificado,
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
    return tramite;
  } catch (e) {
    throw e;
  }
};

const isNotPrepaidProcedure = ({ suffix, user }: { suffix: string; user: Usuario }) => {
  const condition = false;
  if ((suffix === 'tl' && user.tipoUsuario !== 4) || !!['pd', 'ompu', 'rc', 'bc', 'lic', 'lict', 'sup'].find((el) => el === suffix)) return !condition;
  return condition;
};

export const getProcedureCosts = async () => {
  const client = await pool.connect();
  try {
    const tramites = await client.query('SELECT id_tipo_tramite AS id, costo_base AS costo FROM tipo_tramite WHERE id_institucion = 9');
    return { status: 200, message: 'Costos de tramites obtenidos', tramites };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener los costos de los tramites',
    };
  } finally {
    client.release();
  }
};

export const procedureInit = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  const { tipoTramite, datos, pago } = procedure;
  let costo, respState, dir, cert, datosP;
  try {
    client.query('BEGIN');
    datosP = { usuario: datos };
    if (tipoTramite === 26) {
      const { tipoDocumento, documento, registroMunicipal } = datos.contribuyente;
      const hasActiveAgreement = (await client.query(queries.CONTRIBUTOR_HAS_ACTIVE_AGREEMENT_PROCEDURE, [tipoDocumento, documento, registroMunicipal])).rowCount > 0;
      if (hasActiveAgreement) throw { status: 403, message: 'El contribuyente ya posee una solicitud de beneficio en revision' };
    }

    if (!![39, 40].find((el) => el === tipoTramite)) {
      datos.vehiculo = await createVehicleStructureForProcedure(datos.vehiculo, client);
    }

    const response = (await client.query(queries.PROCEDURE_INIT, [tipoTramite, JSON.stringify(datosP), user.id])).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [response.idTramite])).rows[0];
    response.sufijo = resources.sufijo;
    costo = isNotPrepaidProcedure({ suffix: resources.sufijo, user }) ? null : pago.costo || resources.costo_base;
    mainLogger.info('🚀 ~ file: procedures.ts ~ line 473 ~ procedureInit ~ costo', costo);
    const nextEvent = await getNextEventForProcedure(response, client);

    if (pago && resources.sufijo !== 'tl' && nextEvent.startsWith('validar')) {
      pago.costo = costo;
      pago.concepto = 'TRAMITE';
      pago.user = user.id;
      await insertPaymentReference(pago, response.id, client);
    }

    if (resources.sufijo === 'tl') {
      const pointerEvent = user.tipoUsuario === 4;
      if (pointerEvent) {
        if (pago) {
          pago.costo = costo;
          pago.concepto = 'TRAMITE';
          pago.user = user.id;
          await insertPaymentReference(pago, response.id, client);
        }
        dir = await createRequestForm(response, client);
        respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent[pointerEvent.toString()], null, costo, dir]);
      } else {
        cert = await createCertificate(response, client);
        respState = await client.query(queries.COMPLETE_STATE, [response.idTramite, nextEvent[pointerEvent.toString()], null, dir || null, true]);
      }
    } else {
      if (resources.planilla) dir = await createRequestForm(response, client);
      if (response.sufijo === 'bc' || response.sufijo === 'veh') datosP = { funcionario: datos };
      respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent, response.sufijo === 'bc' || response.sufijo === 'veh' ? JSON.stringify(datosP) : null, costo, dir]);
    }

    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: datosP,
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
    await sendNotification(user, `Un trámite de tipo ${tramite.nombreTramiteLargo} ha sido creado`, 'CREATE_PROCEDURE', 'TRAMITE', tramite, client);
    client.query('COMMIT');

    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: user.nombreUsuario,
      nombreCompletoUsuario: user.nombreCompleto,
      estado: respState.rows[0].state,
    });

    return {
      status: 201,
      message: 'Tramite iniciado!',
      tramite,
    };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al iniciar el tramite',
    };
  } finally {
    client.release();
  }
};

export const validateProcedure = async (procedure, user: Usuario, client) => {
  let dir, respState;
  try {
    mainLogger.info('si');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('aprobado')) {
      return { status: 403, message: 'No es posible actualizar este estado' };
    }

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }

    if (!!resources.id_ramo) {
      const ramo = (await client.query('SELECT * FROM impuesto.ramo WHERE id_ramo = $1', [resources.id_ramo])).rows[0].descripcion;
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      procedure.sufijo === 'veh' && (await client.query(queries.UPDATE_VEHICLE_PAYMENT_DATE, [prevData.datos.funcionario.vehiculo.id]));
      await createSettlementForProcedure({ monto: +procedure.monto, ramo, idTramite: procedure.idTramite, payload: prevData.datos.funcionario }, client);
    }

    const nextEvent = await getNextEventForProcedure(procedure, client);
    if (nextEvent.startsWith('finalizar')) {
      // dir = await createCertificate(procedure, client);
      respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, null, dir || null, true]);
    } else {
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, null, null, null]);
    }
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
    await sendNotification(user, `Se ha validado el pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client, true);
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Pago del tramite validado', tramite };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al validar el pago del trámite',
    };
  } finally {
  }
};

export const processProcedure = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let { datos, bill } = procedure;
  let dir,
    respState,
    ordenanzas,
    costo = null;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];
    procedure.tipoTramite = resources.tipoTramite;
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }

    if (!!['pd', 'ompu', 'lic', 'lict'].find((el) => el === procedure.sufijo)) {
      if (!bill) return { status: 400, message: 'Es necesario asignar un precio a un tramite postpago' };
      costo = bill.totalBs;
      ordenanzas = {
        items: await insertOrdinancesByProcedure(bill.items, procedure.idTramite, procedure.tipoTramite, client),
        totalBs: bill.totalBs,
        totalPetro: bill.totalPetro,
      };
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);

    if (datos) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      if (!prevData.datos.funcionario) datos = { usuario: prevData.datos.usuario, funcionario: datos };
      else if (prevData.datos.funcionario) datos = { usuario: prevData.datos.usuario, funcionario: datos };
      else datos = prevData.datos;
    }

    if (procedure.sufijo === 'ompu' || procedure.sufijo === 'rc') {
      const { aprobado } = procedure;
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, costo, null]);
      await client.query(queries.UPDATE_APPROVED_STATE_FOR_PROCEDURE, [aprobado, procedure.idTramite]);

      if (procedure.sufijo === 'rc' && aprobado) {
        if (resources.tipoTramite === 27) await approveContributorSignUp({ procedure: (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0], client });
        else if (resources.tipoTramite === 38) mainLogger.info('si');
      }
    } else if (resources.tipoTramite === 37) {
      const { aprobado, estado } = procedure;
      respState =
        estado === 'finalizado'
          ? await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[estado], datos || null, dir || null, true])
          : await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, costo, null]);
    } else if (!![28, 36].find((type) => type === resources.tipoTramite)) {
      const { aprobado } = procedure;
      datos.funcionario.pago = (await client.query(queries.GET_PAYMENT_FROM_REQ_ID, [procedure.idTramite, 'TRAMITE'])).rows.map((row) => ({
        monto: row.monto,
        formaPago: row.metodo_pago,
        banco: row.nombre,
        fecha: row.fecha_de_pago,
        nro: row.referencia,
      }));
      mainLogger.info(datos);
      mainLogger.info('creo y me parec q se rompio aki');
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, costo, null]);
    } else {
      if (nextEvent.startsWith('finalizar')) {
        procedure.datos = datos;
        dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, datos || null, dir || null, true]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, datos || null, costo || null, null]);
      }
    }

    await client.query('COMMIT');
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
      bill: ordenanzas,
    };

    await sendNotification(user, `Se ha procesado un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Tramite procesado', tramite };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al procesar el trámite',
    };
  } finally {
    client.release();
  }
};

export const addPaymentProcedure = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  let { pago } = procedure;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);
    if (pago && nextEvent.startsWith('validar')) {
      pago.costo = resources.costo;
      pago.concepto = 'TRAMITE';
      pago.user = user.id;
      await insertPaymentReference(pago, procedure.idTramite, client);
    }

    const respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, null, resources.costo || null, null]);
    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
    await sendNotification(user, `Se añadieron los datos de pago de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    client.query('COMMIT');
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Datos de pago de trámite añadidos', tramite };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al añadir datos de pago del trámite',
    };
  } finally {
    client.release();
  }
};

export const reviseProcedure = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  const { aprobado, observaciones } = procedure.revision;
  let dir, respState, datos;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('revision')) {
      throw { status: 403, message: 'No es posible actualizar este estado' };
    }

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);

    if (observaciones && !aprobado) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, observaciones };
      datos = prevData.datos;
    }

    if (procedure.sufijo === 'bc' && aprobado) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...procedure.datos.funcionario, observaciones };
      datos = prevData.datos;
      await approveContributorBenefits({ data: datos, client });
    }

    if (resources.tipoTramite === 28 || resources.tipoTramite === 36) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...procedure.datos };
      datos = prevData.datos;
      datos.idTramite = procedure.idTramite;
      datos.funcionario.estadoLicencia = resources.tipoTramite === 28 ? 'PERMANENTE' : 'TEMPORAL';
      datos.funcionario.pago = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID, [procedure.idTramite, 'TRAMITE'])).rows.map((row) => ({
        monto: row.monto,
        formaPago: row.metodo_pago,
        banco: row.nombre,
        fecha: row.fecha_de_pago,
        nro: row.referencia,
      }));
    }

    if (!![29, 30, 31, 32, 33, 34, 35, 37].find((el) => el === resources.tipoTramite)) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, ...procedure.datos };
      datos = prevData.datos;
      datos.idTramite = procedure.idTramite;
      datos.tipoTramite = resources.tipoTramite;
    }

    if (procedure.sufijo === 'ompu') {
      if (aprobado) {
        dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, dir, null]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
      }
    } else if (!!['lic', 'lict'].find((el) => el === procedure.sufijo)) {
      if (procedure.hasOwnProperty('rebotado')) {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent['rebotar'], datos || null, null, null]);
      } else {
        if (aprobado && nextEvent[aprobado].startsWith('aprobar')) {
          datos = !![29, 30, 31, 32].find((el) => el === resources.tipoTramite) ? await installLiquorLicense(datos, client) : await renewLiquorLicense(datos, client);
          procedure.datos = datos;
          dir = await createCertificate(procedure, client);
          respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, dir, null]);
        } else {
          respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
        }
      }
    } else {
      if (aprobado) {
        if (resources.tipoTramite === 28 || resources.tipoTramite === 36) procedure.datos = await approveContributorAELicense({ data: datos, client });
        if (procedure.sufijo !== 'bc' && procedure.sufijo !== 'sup') dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, dir || null, aprobado]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
      }
    }

    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
    await sendNotification(user, `Se realizó la revisión de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    client.query('COMMIT');
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Trámite revisado', tramite };
  } catch (error) {
    mainLogger.error(error);
    client.query('ROLLBACK');
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al revisar el tramite',
    };
  } finally {
    client.release();
  }
};

export const inspectProcedure = async (procedure, user: Usuario) => {
  const client = await pool.connect();
  const { aprobado, observaciones } = procedure.revision;
  let dir, respState, datos;
  try {
    client.query('BEGIN');
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);

    if (!!observaciones) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, observaciones };
      datos = prevData.datos;
    }

    if (resources.tipoTramite === 28) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...procedure.datos };
      datos = prevData.datos;
      datos.idTramite = procedure.idTramite;
      datos.funcionario.pago = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID, [procedure.idTramite, 'TRAMITE'])).rows.map((row) => ({
        monto: row.monto,
        formaPago: row.metodo_pago,
        banco: row.nombre,
        fecha: row.fecha_de_pago,
        nro: row.referencia,
      }));
    }

    // if (procedure.sufijo === 'ompu') {
    //   if (aprobado) {
    //     dir = await createCertificate(procedure, client);
    //     respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, dir, null]);
    //   } else {
    //     respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
    //   }
    // } else {
    respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
    // }

    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
    await sendNotification(user, `Se realizó la inspección de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    client.query('COMMIT');
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Inspección del trámite cargada', tramite };
  } catch (error) {
    mainLogger.error(error);
    client.query('ROLLBACK');
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al cargar la inspección correspondiente al tramite',
    };
  } finally {
    client.release();
  }
};

const reviseProcedureForMassiveApproval = async (procedure: Partial<Tramite | any>, client: PoolClient): Promise<Partial<Tramite>> => {
  const { aprobado, observaciones } = procedure.revision;
  let dir, respState, datos;
  try {
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];

    if (!procedure.hasOwnProperty('revision')) {
      throw { status: 403, message: 'No es posible actualizar este estado' };
    }

    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);

    if (observaciones && !aprobado) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, observaciones };
      datos = prevData.datos;
    }

    if (procedure.sufijo === 'bc' && aprobado) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...procedure.datos.funcionario, observaciones };
      datos = prevData.datos;
      await approveContributorBenefits({ data: datos, client });
    }

    if (resources.tipoTramite === 28 || resources.tipoTramite === 36) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...procedure.datos, observaciones };
      datos = prevData.datos;
      datos.idTramite = procedure.idTramite;
      datos.funcionario.estadoLicencia = resources.tipoTramite === 28 ? 'PERMANENTE' : 'TEMPORAL';
      datos.funcionario.pago = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID, [procedure.idTramite, 'TRAMITE'])).rows.map((row) => ({
        monto: row.monto,
        formaPago: row.metodo_pago,
        banco: row.nombre,
        fecha: row.fecha_de_pago,
        nro: row.referencia,
      }));
    }

    if (!![29, 30, 31, 32, 33, 34, 35, 37].find((el) => el === resources.tipoTramite)) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      prevData.datos.funcionario = { ...prevData.datos.funcionario, ...procedure.datos };
      datos = prevData.datos;
      datos.idTramite = procedure.idTramite;
      datos.tipoTramite = resources.tipoTramite;
    }

    if (procedure.sufijo === 'ompu') {
      if (aprobado) {
        dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, dir, null]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
      }
    } else if (!!['lic', 'lict'].find((el) => el === procedure.sufijo)) {
      if (procedure.hasOwnProperty('rebotado')) {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent['rebotar'], datos || null, null, null]);
      } else {
        if (aprobado && nextEvent[aprobado].startsWith('aprobar')) {
          datos = !![29, 30, 31, 32].find((el) => el === resources.tipoTramite) ? await installLiquorLicense(datos, client) : await renewLiquorLicense(datos, client);
          procedure.datos = datos;
          // dir = await createCertificate(procedure, client);
          respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, dir || null, null]);
        } else {
          respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
        }
      }
    } else {
      if (aprobado) {
        if (resources.tipoTramite === 28 || resources.tipoTramite === 36) procedure.datos = await approveContributorAELicense({ data: datos, client });
        // if (procedure.sufijo !== 'bc' && procedure.sufijo !== 'sup') dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, dir || null, aprobado]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos || null, null, null]);
      }
    }

    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
    // await sendNotification(user, `Se realizó la revisión de un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    // sendEmail({
    //   ...tramite,
    //   codigo: tramite.codigoTramite,
    //   nombreUsuario: resources.nombreusuario,
    //   nombreCompletoUsuario: resources.nombrecompleto,
    //   estado: respState.rows[0].state,
    // });
    return tramite;
  } catch (error) {
    mainLogger.error(error);
    throw error;
  }
};

export const approveAllLicenses = async (idArray: number[], user: Usuario): Promise<any> => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const tramites = await Promise.all(
      idArray.map((id) => {
        return (async () => {
          try {
            const procedure: Partial<Tramite | any> = await getProcedureById({ id, client });
            procedure.idTramite = procedure.id;
            procedure.datos = procedure.datos.funcionario;
            procedure.revision = {
              aprobado: true,
              observaciones: 'Aprobación masiva',
            };
            mainLogger.info('Soy retrasao mental', procedure);
            const tramite = await reviseProcedureForMassiveApproval(procedure, client);
            return tramite;
          } catch (e) {
            throw e;
          }
        })();
      })
    );
    await client.query('COMMIT');
    return { status: 200, message: 'Licencias aprobadas satisfactoriamente', tramites };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al realizar la aprobación masiva de licencias',
    };
  } finally {
    client.release();
  }
};

export const generateCertificate = async (id) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const url = await createCertificate({ idTramite: id }, client);
    await client.query('UPDATE tramite SET url_certificado = $1 WHERE id_tramite = $2', [url, id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Certificado de tramite generado', url };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

const insertOrdinancesByProcedure = async (ordinances, id, type, client: PoolClient) => {
  return Promise.all(
    ordinances.map(async (el, key) => {
      if (el.factor) {
        if (el.valorCalc !== el.costoOrdenanza * el.factorValue) {
          throw new Error('Error en validación del valor calculado');
        }
      }
      const response = (await client.query(queries.CREATE_ORDINANCE_FOR_PROCEDURE, [id, type, el.ordenanza, el.petro, el.valorCalc, el.factor, el.factorValue, el.costoOrdenanza])).rows[0];
      const ordinance = {
        id: key,
        idTramite: response.id_tramite,
        ordenanza: el.ordenanza,
        factor: response.factor,
        factorValue: +response.factor_value,
        petro: +response.petro,
        valorCalc: +response.valor_calc,
      };
      return ordinance;
    })
  );
};

export const initProcedureAnalist = async (procedure, user: Usuario, client: PoolClient, analyst) => {
  // const client = await pool.connect();
  const { tipoTramite, datos, pago } = procedure;
  let costo, respState, dir, cert, datosP;
  try {
    datosP = { usuario: datos };
    const response = (await client.query(queries.PROCEDURE_INIT, [tipoTramite, JSON.stringify(datosP), user.id])).rows[0];
    response.idTramite = response.id;
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [response.idTramite])).rows[0];
    response.sufijo = resources.sufijo;
    costo = isNotPrepaidProcedure({ suffix: resources.sufijo, user }) ? null : pago.costo || resources.costo_base;
    const nextEvent = await getNextEventForProcedure(response, client);

    if (pago.length > 0 && resources.sufijo !== 'tl' && nextEvent.startsWith('validar')) {
      await Promise.all(
        pago.map(async (p) => {
          p.concepto = 'TRAMITE';
          p.user = analyst;
          await insertPaymentCashier(p, response.id, client);
        })
      );
    }

    if (resources.sufijo === 'tl') {
      const pointerEvent = user.tipoUsuario === 4;
      if (pointerEvent) {
        if (pago) {
          pago.costo = costo;
          pago.concepto = 'TRAMITE';
          pago.user = user.id;
          await insertPaymentReference(pago, response.id, client);
        }
        dir = await createRequestForm(response, client);
        respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent[pointerEvent.toString()], null, costo, dir]);
      } else {
        cert = await createCertificate(response, client);
        respState = await client.query(queries.COMPLETE_STATE, [response.idTramite, nextEvent[pointerEvent.toString()], null, dir || null, true]);
      }
    } else {
      if (resources.planilla) dir = await createRequestForm(response, client);
      if (response.sufijo === 'bc') datosP = { funcionario: datos };
      respState = await client.query(queries.UPDATE_STATE, [response.id, nextEvent, response.sufijo === 'bc' ? JSON.stringify(datosP) : null, costo, dir]);
    }

    const ultEvent = await getNextEventForProcedure(response, client);
    respState = await client.query(queries.UPDATE_STATE, [response.id, ultEvent, null, costo, dir]);

    const tramite: Partial<Tramite> = {
      id: response.id,
      tipoTramite: response.tipotramite,
      estado: respState.rows[0].state,
      datos: datosP,
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
    // await sendNotification(user, `Un trámite de tipo ${tramite.nombreTramiteLargo} ha sido creado`, 'CREATE_PROCEDURE', 'TRAMITE', tramite, client);
    // sendEmail({
    //   ...tramite,
    //   codigo: tramite.codigoTramite,
    //   nombreUsuario: user.nombreUsuario,
    //   nombreCompletoUsuario: user.nombreCompleto,
    //   estado: respState.rows[0].state,
    // });

    return {
      status: 201,
      message: 'Tramite iniciado!',
      tramite,
    };
  } catch (e) {
    mainLogger.error(e);
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al realizar el tramite por interno',
    };
  }
};

export const processProcedureAnalist = async (procedure, user: Usuario, client: PoolClient) => {
  let { datos, bill } = procedure;
  let dir,
    respState,
    ordenanzas,
    costo = null;
  try {
    const resources = (await client.query(queries.GET_RESOURCES_FOR_PROCEDURE, [procedure.idTramite])).rows[0];
    procedure.tipoTramite = resources.tipoTramite;
    if (!procedure.hasOwnProperty('sufijo')) {
      procedure.sufijo = resources.sufijo;
    }

    if (procedure.sufijo === 'pd' || procedure.sufijo === 'ompu') {
      if (!bill) return { status: 400, message: 'Es necesario asignar un precio a un tramite postpago' };
      costo = bill.totalBs;
      ordenanzas = {
        items: await insertOrdinancesByProcedure(bill.items, procedure.idTramite, procedure.tipoTramite, client),
        totalBs: bill.totalBs,
        totalPetro: bill.totalPetro,
      };
    }
    const nextEvent = await getNextEventForProcedure(procedure, client);

    if (!!resources.id_ramo) {
      const ramo = (await client.query('SELECT * FROM impuesto.ramo WHERE id_ramo = $1', [resources.id_ramo])).rows[0].descripcion;
      const payload = !![39, 40].find((el) => el === resources.tipoTramite) ? datos.funcionario.vehiculo : undefined;
      await createSettlementForProcedure({ monto: +resources.costo, ramo, idTramite: procedure.idTramite, payload }, client);
    }

    if (datos) {
      const prevData = (await client.query(queries.GET_PROCEDURE_DATA, [procedure.idTramite])).rows[0];
      if (!prevData.datos.funcionario) datos = { usuario: prevData.datos.usuario, funcionario: datos };
      else if (prevData.datos.funcionario) datos = { usuario: prevData.datos.usuario, funcionario: datos };
      else datos = prevData.datos;
    }

    if (procedure.sufijo === 'ompu' || procedure.sufijo === 'rc') {
      const { aprobado } = procedure;
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, costo, null]);
      await client.query(queries.UPDATE_APPROVED_STATE_FOR_PROCEDURE, [aprobado, procedure.idTramite]);

      if (procedure.sufijo === 'rc' && aprobado) await approveContributorSignUp({ procedure: (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0], client });
    } else if (!![28, 36].find((type) => type === resources.tipoTramite)) {
      const { aprobado } = procedure;
      datos.funcionario.pago = (await pool.query(queries.GET_PAYMENT_FROM_REQ_ID, [procedure.idTramite, 'TRAMITE'])).rows.map((row) => ({
        monto: row.monto,
        formaPago: row.metodo_pago,
        banco: row.nombre,
        fecha: row.fecha_de_pago,
        nro: row.referencia,
      }));
      mainLogger.info(datos);
      mainLogger.info('creo y me parec q se rompio aki');
      respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent[aprobado], datos, costo, null]);
    } else {
      if (nextEvent.startsWith('finalizar')) {
        procedure.datos = datos;
        dir = await createCertificate(procedure, client);
        respState = await client.query(queries.COMPLETE_STATE, [procedure.idTramite, nextEvent, datos || null, dir || null, true]);
      } else {
        respState = await client.query(queries.UPDATE_STATE, [procedure.idTramite, nextEvent, datos || null, costo || null, null]);
      }
    }

    const response = (await client.query(queries.GET_PROCEDURE_BY_ID, [procedure.idTramite])).rows[0];
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
      bill: ordenanzas,
    };

    await sendNotification(user, `Se ha procesado un trámite de tipo ${tramite.nombreTramiteLargo}`, 'UPDATE_PROCEDURE', 'TRAMITE', tramite, client);
    sendEmail({
      ...tramite,
      codigo: tramite.codigoTramite,
      nombreUsuario: resources.nombreusuario,
      nombreCompletoUsuario: resources.nombrecompleto,
      estado: respState.rows[0].state,
    });
    return { status: 200, message: 'Tramite procesado', tramite };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al procesar el trámite',
    };
  }
};

const getNextEventForProcedure = async (procedure, client): Promise<any> => {
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
  const nextEvent = procedureEventHandler(procedure.sufijo, response.state);
  return nextEvent;
};

const procedureEvents = switchcase({
  pa: { iniciado: 'validar_pa', validando: 'enproceso_pa', enproceso: 'finalizar_pa' },
  pd: { iniciado: 'enproceso_pd', enproceso: 'ingresardatos_pd', ingresardatos: 'validar_pd', validando: 'finalizar_pd' },
  cr: { iniciado: 'validar_cr', validando: 'enproceso_cr', enproceso: 'revisar_cr', enrevision: { true: 'finalizar_cr', false: 'rechazar_cr' } },
  tl: { iniciado: { true: 'validar_tl', false: 'finalizar_tl' }, validando: 'finalizar_tl' },
  veh: { iniciado: 'validar_veh', validando: 'finalizar_veh' },
  ompu: {
    iniciado: 'enproceso_ompu',
    enproceso: { true: 'aprobar_ompu', false: 'rechazar_ompu' },
    enrevision: { true: 'ingresardatos_ompu', false: 'rechazar_ompu' },
    ingresardatos: 'validar_ompu',
    validando: 'finalizar_ompu',
  },
  rc: { iniciado: 'procesar_rc', enproceso: { true: 'aprobar_rc', false: 'rechazar_rc' } },
  bc: { iniciado: 'revisar_bc', enrevision: { true: 'aprobar_bc', false: 'rechazar_bc' } },
  lae: { iniciado: 'validar_lae', validando: 'enproceso_lae', ingresardatos: 'validar_lae', enproceso: { true: 'revisar_lae', false: 'rechazar_lae' }, enrevision: { true: 'aprobar_lae', false: 'rechazar_lae' } },
  lic: {
    iniciado: 'enproceso_lic',
    enproceso: 'inspeccion_lic',
    inspeccion: { true: 'ingresardatos_lic', false: 'rechazar_lic' },
    ingresardatos: 'validar_lic',
    validando: 'revisar1_lic',
    enrevision_analista: { true: 'revisar2_lic', false: 'rechazar_lic' },
    enrevision_gerente: { true: 'revisar3_lic', false: 'rechazar_lic', rebotar: 'rebotar_lic' },
    enrevision: { true: 'aprobar_lic', false: 'rechazar_lic', rebotar: 'rebotar_lic' },
  },
  lict: {
    iniciado: 'enproceso_lict',
    enproceso: 'ingresardatos_lict',
    ingresardatos: 'validar_lict',
    validando: 'revisar1_lict',
    enrevision_analista: { true: 'revisar2_lict', false: 'rechazar_lict' },
    enrevision_gerente: { true: 'revisar3_lict', false: 'rechazar_lict', rebotar: 'rebotar_lict' },
    enrevision: { true: 'aprobar_lict', false: 'rechazar_lict', rebotar: 'rebotar_lict' },
  },
  sup: { iniciado: 'enproceso_sup', enproceso: { finalizado: 'finalizar_sup', true: 'revisar_sup', false: 'rechazar_sup' }, enrevision: { true: 'aprobar_sup', false: 'rechazar_sup' } },
})(null);

const procedureEventHandler = (suffix, state) => {
  return procedureEvents(suffix)[state];
};

const isSuperuser = ({ tipoUsuario }) => {
  return tipoUsuario === 1;
};

const isAdmin = ({ tipoUsuario }) => {
  return tipoUsuario === 2;
};

const isOfficial = ({ tipoUsuario }) => {
  return tipoUsuario === 3;
};

const isDirector = ({ tipoUsuario }) => {
  return tipoUsuario === 5;
};

const isExternalUser = ({ tipoUsuario }) => {
  return tipoUsuario === 4;
};

const belongsToAnInstitution = ({ institucion }) => {
  return institucion !== undefined;
};

const handlesSocialCases = ({ institucion }) => {
  return institucion.id === 0;
};

const belongsToSedetama = ({ institucion }) => {
  return institucion.nombreCorto === 'SEDETAMA';
};

const procedureInstances = switchcase({
  0: queries.GET_SOCIAL_CASES_STATE,
  1: queries.GET_ALL_PROCEDURE_INSTANCES,
  2: queries.GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID,
  3: queries.GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION,
  4: queries.GET_PROCEDURE_INSTANCES_FOR_USER,
  5: queries.GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID,
  6: queries.GET_ALL_PROCEDURES_EXCEPT_VALIDATING_ONES,
  7: "SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
      nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, \
      tipo_tramite.pago_previo AS \"pagoPrevio\"  FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
      tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
      tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND tipoTramite = 37 AND tramites_state.state IN ('enproceso', 'enrevision', 'finalizado') ORDER BY tramites_state.fechacreacion DESC;",
  8: 'SELECT * FROM tramites_state_with_resources WHERE usuario = $1 AND tipotramite = 37 ORDER BY fechacreacion DESC LIMIT 500;',
})(null);

const procedureInstanceHandler = (user, client, support) => {
  let query;
  let payload;
  if (isSuperuser(user)) {
    query = 1;
  } else {
    if (belongsToAnInstitution(user)) {
      if (support) {
        mainLogger.info(user);
        query = 7;
        payload = user.institucion.id;
      } else if (handlesSocialCases(user)) {
        query = 0;
        payload = 0;
      } else if (belongsToSedetama(user)) {
        query = 6;
        payload = user.institucion.id;
      } else {
        query = user.tipoUsuario;
        payload = user.institucion.id;
      }
    }

    if (isExternalUser(user)) {
      if (support) {
        query = 8;
        payload = user.id;
      } else {
        query = 4;
        payload = user.id;
      }
    }
  }

  if (query === 1) {
    return client.query(procedureInstances(query));
  }
  return client.query(procedureInstances(query), [payload]);
};

const procedureInstanceHandlerByInstitution = (tipoUsuario, idInstitucion, client) => {
  let query;
  query = tipoUsuario;

  if (query === 1) {
    return client.query(procedureInstances(query));
  } else {
    return client.query(procedureInstances(query), [idInstitucion]);
  }
};

const fineInstances = switchcase({
  1: queries.GET_ALL_FINES,
  2: queries.GET_FINES_DIRECTOR_OR_ADMIN,
  3: queries.GET_FINES_OFFICIAL,
  4: queries.GET_FINES_EXTERNAL_USER,
})(null);

const fineInstanceHandler = (user, client) => {
  let query;
  let payload;
  if (isSuperuser(user)) {
    query = 1;
  } else {
    if (belongsToAnInstitution(user)) {
      if (isAdmin(user) || isDirector(user)) {
        query = 2;
        payload = [user.institucion.nombreCompleto];
      } else if (isOfficial(user)) {
        query = 3;
        payload = [user.institucion.nombreCompleto];
      }
    } else {
      if (isExternalUser(user)) {
        query = 4;
        payload = [user.cedula, user.nacionalidad];
      }
    }
  }
  return query !== 1 ? client.query(fineInstances(query), payload) : client.query(fineInstances(query));
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
  inspeccion: inspectProcedure,
  enrevision_analista: reviseProcedure,
  enrevision_gerente: reviseProcedure,
  enrevision: reviseProcedure,
  ingresardatos: addPaymentProcedure,
  finalizado: null,
})(null);

export const updateProcedureHandler = async (procedure, user) => {
  const client = await pool.connect();
  const response = (await client.query(queries.GET_PROCEDURE_STATE, [procedure.idTramite])).rows[0];
  client.release();
  const newProcedureState = updateProcedure(response.state);
  return newProcedureState ? await newProcedureState(procedure, user) : { status: 500, message: 'No es posible actualizar el trámite' };
};
