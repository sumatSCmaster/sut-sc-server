import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Institucion, TramitesDisponibles, Campos } from "@interfaces/sigt";
import { errorMessageGenerator } from "./errors";
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

const getFieldsBySection = async (
  section,
  tramiteId,
  client
): Promise<Campos[] | any> => {
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
): Promise<TramitesDisponibles[] | any> => {
  return await Promise.all(
    procedure.map(async al => {
      const tramite: TramitesDisponibles = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base
      };
      const secciones = (
        await client.query(queries.GET_SECTIONS_BY_PROCEDURE, [tramite.id])
      ).rows;
      tramite.secciones = await getFieldsBySection(
        secciones,
        tramite.id,
        client
      );
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
  const { tipoTramite, datos } = procedure;
  try {
    const response = await client.query(queries.PROCEDURE_INIT, [
      tipoTramite,
      JSON.stringify(datos),
      user
    ]);
    return { status: 201, message: "Tramite iniciado!" };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al iniciar el tramite"
    };
  } finally {
    client.release();
  }
};
