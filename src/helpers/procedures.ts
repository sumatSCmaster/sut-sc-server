import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Institucion, TramitesDisponibles, Campos } from "@interfaces/sigt";
const pool = Pool.getInstance();

export const getAvailableProcedures = async (): Promise<Institucion[]> => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const response = await client.query(queries.GET_ALL_INSTITUTION);
    const institution: Institucion[] = response.rows.map(el => {
      return {
        id: el.id_institucion,
        nombreCompleto: el.nombre_completo,
        nombreCorto: el.nombre_corto
      };
    });
    const options = getProcedureByInstitution(institution, client);
    client.query("COMMIT");
    return options;
  } catch (error) {
    client.query("ROLLBACK");
    throw { status: 500, error };
  } finally {
    client.release();
  }
};

const getFieldsByProcedure = async (
  procedure,
  client
): Promise<TramitesDisponibles[]> => {
  return Promise.all(
    procedure.map(async al => {
      const tramite: TramitesDisponibles = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base
      };
      tramite.campos = (
        await client.query(queries.GET_FIELDS_BY_PROCEDURE, [tramite.id])
      ).rows.map(ul => {
        const id = ul.id_campo;
        delete ul.id_tipo_tramite;
        delete ul.id_campo;
        return { id, ...ul };
      });

      return tramite;
    })
  );
};

const getProcedureByInstitution = async (
  institution,
  client
): Promise<Institucion[]> => {
  return Promise.all(
    institution.map(async institucion => {
      const procedures = (
        await client.query(queries.GET_PROCEDURE_BY_INSTITUTION, [
          institucion.id
        ])
      ).rows;

      institucion.tramitesDisponibles = await getFieldsByProcedure(
        procedures,
        client
      );

      return institucion;
    })
  );
};
