import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Usuario } from "@interfaces/sigt";
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async (institution: string) => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_OFFICIAlS_BY_INSTITUTION, [
      institution
    ]);
    return { status: 200, officials: response.rows };
  } catch (e) {
    throw { error: e, status: 500 };
  } finally {
    client.release();
  }
};

export const createOfficial = async (official: any) => {
  const {
    nombre,
    username,
    direccion,
    cedula,
    nacionalidad,
    rif,
    password,
    institution
  } = official;
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const insert = await client.query(queries.CREATE_OFFICIAL, [
      nombre,
      username,
      direccion,
      cedula,
      nacionalidad,
      rif,
      password,
      institution
    ]);
    console.log("uegue");
    const off = await client.query(queries.GET_OFFICIAL, [
      insert.rows[0].id_usuario,
      insert.rows[0].id_institucion
    ]);
    client.query("COMMIT");
    return { status: 201, official: off.rows[0] };
  } catch (e) {
    client.query("ROLLBACK");
    throw { status: 500, error: e };
  } finally {
    client.release();
  }
};

// export const updateOfficial = async (official: any, id: string) => {
//   const client = await pool.connect();

//   try {
//   } catch (e) {
//   } finally {
//     client.release();
//   }
// };

// export const deleteOfficial = async (officialID: string) => {
//   const client = await pool.connect();

//   try {
//   } catch (e) {
//   } finally {
//     client.release();
//   }
// };
