import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Institucion, TipoTramite, Campo, Tramite } from "@interfaces/sigt";
import { errorMessageGenerator } from "./errors";
import { insertPaymentReference } from "./banks";
const pool = Pool.getInstance();

export const getAvailableProcedures = async (): Promise<Institucion[]> => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_INSTITUTION);
    const institution: Institucion[] = response.rows.map(el => {
      return {
        id: el.id_institucion,
        nombreCompleto: el.nombre_completo,
        nombreCorto: el.nombre_corto
      };
    });
    const options = getProcedureByInstitution(institution, client);
    return options;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al obtener los tramites"
    };
  } finally {
    client.release();
  }
};

export const getAvailableProceduresOfInstitution = async (
  id: string
): Promise<Institucion> => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_ONE_INSTITUTION, [id]))
      .rows[0];
    const institution: Institucion = {
      id: response.id_institucion,
      nombreCompleto: response.nombre_completo,
      nombreCorto: response.nombre_corto
    };
    const options = await getProcedureByInstitution([institution], client);
    return options[0];
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al obtener los tramites"
    };
  } finally {
    client.release();
  }
};

export const updateProcedureCost = async (
  id: string,
  newCost: string
): Promise<Partial<TipoTramite>> => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const response = (
      await client.query(queries.UPDATE_PROCEDURE_COST, [id, newCost])
    ).rows[0];
    const newProcedure = (await client.query(queries.GET_ONE_PROCEDURE, [id]))
      .rows[0];
    const procedure: Partial<TipoTramite> = {
      id: newProcedure.id_tipo_tramite,
      titulo: newProcedure.nombre_tramite,
      costo: newProcedure.costo_base,
      pagoPrevio: newProcedure.pago_previo
    };
    client.query("COMMIT");
    return procedure;
  } catch (error) {
    client.query("ROLLBACK");
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al obtener los tramites"
    };
  } finally {
    client.release();
  }
};

const getFieldsBySection = async (
  section,
  tramiteId,
  client
): Promise<Campo[] | any> => {
  return Promise.all(
    section.map(async el => {
      el.campos = (
        await client.query(queries.GET_FIELDS_BY_SECTION, [el.id, tramiteId])
      ).rows.map(ul => {
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
      message:
        errorMessageGenerator(error) ||
        error.message ||
        "Error al obtener los campos"
    };
  });
};

const getSectionByProcedure = async (
  procedure,
  client
): Promise<TipoTramite[] | any> => {
  return await Promise.all(
    procedure.map(async al => {
      const tramite: Partial<TipoTramite> = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base,
        pagoPrevio: al.pago_previo
      };
      const secciones = (
        await client.query(queries.GET_SECTIONS_BY_PROCEDURE, [tramite.id])
      ).rows;
      tramite.secciones = await getFieldsBySection(
        secciones,
        tramite.id,
        client
      );
      tramite.recaudos = (
        await client.query(queries.GET_TAKINGS_BY_PROCEDURE, [tramite.id])
      ).rows.map(el => {
        return {
          nombreCompleto: el.nombrecompleto,
          nombreCorto: el.nombrecorto,
          id: el.id
        };
      });
      return tramite;
    })
  ).catch(error => {
    throw {
      message:
        errorMessageGenerator(error) ||
        error.message ||
        "Error al obtener las secciones"
    };
  });
};

const getProcedureByInstitution = async (
  institution,
  client
): Promise<Institucion[] | any> => {
  return Promise.all(
    institution.map(async institucion => {
      const procedures = (
        await client.query(queries.GET_PROCEDURE_BY_INSTITUTION, [
          institucion.id
        ])
      ).rows;

      institucion.tramitesDisponibles = await getSectionByProcedure(
        procedures,
        client
      );

      return institucion;
    })
  ).catch(error => {
    throw errorMessageGenerator(error) ||
      error.message ||
      "Error al obtener las instituciones";
  });
};

export const getFieldsForValidations = async idProcedure => {
  const client = await pool.connect();
  try {
    const response = (
      await client.query(queries.VALIDATE_FIELDS_FROM_PROCEDURE, [idProcedure])
    ).rows;
    return { fields: response };
  } catch (error) {
    throw {
      status: 400,
      error,
      message: errorMessageGenerator(error) || "Error en los campos"
    };
  } finally {
    client.release();
  }
};

export const procedureInit = async (procedure, user) => {
  const client = await pool.connect();
  const { tipoTramite, datos, pago } = procedure;
  try {
    client.query("BEGIN");
    const response = (
      await client.query(queries.PROCEDURE_INIT, [
        tipoTramite,
        JSON.stringify(datos),
        user
      ])
    ).rows[0];
    response.pago_previo = (
      await client.query(queries.GET_PREPAID_STATUS_FOR_PROCEDURE, [
        response.id_tipo_tramite
      ])
    ).rows[0].pago_previo;
    const nextState = await getNextEventForProcedure(response, client);
    const respState = await client.query(queries.UPDATE_STATE, [
      response.id_tramite,
      nextState
    ]);
    if (pago) {
      await insertPaymentReference(pago, response.id_tramite, client);
    }
    const tramite: Partial<Tramite & {
      tipoTramite: number;
      consecutivo: number;
    }> = {
      id: response.id_tramite,
      tipoTramite: response.id_tipo_tramite,
      estado: respState.rows[0].state,
      datos: response.datos,
      costo: response.costo,
      fechaCreacion: response.fecha_creacion,
      codigoTramite: response.codigo_tramite,
      consecutivo: response.consecutivo,
      usuario: response.id_usuario
    };
    client.query("COMMIT");
    return {
      status: 201,
      message: "Tramite iniciado!",
      tramite
    };
  } catch (error) {
    client.query("ROLLBACK");
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al iniciar el tramite"
    };
  } finally {
    client.release();
  }
};

export const updateProcedure = async procedure => {
  const client = await pool.connect();
  try {
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al actualizar el tramite"
    };
  } finally {
    client.release();
  }
};

const getNextEventForProcedure = async (procedure, client) => {
  const response = (
    await client.query(queries.GET_PROCEDURE_STATE, [procedure.id_tramite])
  ).rows[0];
  const nextEvent = eventHandler(response.state, procedure.pago_previo);
  return nextEvent;
};

const switchcase = cases => defaultCase => key =>
  cases.hasOwnProperty(key) ? cases[key] : defaultCase;

const procedureEvents = switchcase({
  iniciado: { 0: "validar_pa", 1: "enproceso_pd" },
  validando: { 0: "enproceso_pa", 1: "finalizar" },
  enproceso: { 0: "finalizar", 1: "ingresar_datos" },
  datosingresados: { 0: null, 1: "validar_pd" },
  finalizado: { 0: "completado", 1: "completado" }
})({ 0: null, 1: null });

const eventHandler = (prevState, isPrepaid) => {
  const nextState = procedureEvents(prevState);
  return isPrepaid ? nextState[0] : nextState[1];
};
