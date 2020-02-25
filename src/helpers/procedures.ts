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

const getFieldsBySection = async (section, client): Promise<Campos[] | any> => {
  return Promise.all(
    section.map(async el => {
      el.campos = (
        await client.query(queries.GET_FIELDS_BY_SECTION, [el.id])
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
      tramite.secciones = await getFieldsBySection(secciones, client);
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
