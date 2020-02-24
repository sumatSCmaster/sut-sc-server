import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Usuario } from "@interfaces/sigt";
import { Client } from "pg";
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async (institution: string) => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_OFFICIALS_BY_INSTITUTION, [
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
    nombreUsuario,
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
      nombreUsuario,
      direccion,
      cedula,
      nacionalidad,
      rif,
      password,
      institution
    ]);
    const off = await client.query(queries.GET_OFFICIAL, [
      insert.rows[0].id_usuario,
      insert.rows[0].id_institucion
    ]);
    client.query("COMMIT");
    return { status: 201, official: off.rows[0] };
  } catch (e) {
    client.query("ROLLBACK");
    throw {
      status: 500,
      error: e,
      message:
        e.code === "23505"
          ? "La cedula seleccionada ya está en uso"
          : "Error en la petición"
    };
  } finally {
    client.release();
  }
};

//TODO: verificar que el usuario pertenece a mi institucion
export const updateOfficial = async (official: any, id: string) => {
  const {
    nombre,
    nombreUsuario,
    direccion,
    cedula,
    nacionalidad,
    rif,
    password
  } = official;
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    await client.query(queries.UPDATE_OFFICIAL, [
      nombre,
      nombreUsuario,
      direccion,
      cedula,
      nacionalidad,
      rif,
      id,
      password
    ]);
    client.query("COMMIT");
    return { status: 200, message: "OK" };
  } catch (e) {
    client.query("ROLLBACK");
    throw { status: 500, error: e };
  } finally {
    client.release();
  }
};

export const deleteOfficial = async (
  officialID: string,
  institution: number
) => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    await client.query(queries.DELETE_OFFICIAL, [officialID, institution]);
    client.query("COMMIT");
    return { status: 200, message: "OK" };
  } catch (e) {
    client.query("ROLLBACK");
    throw { error: e, status: 500 };
  } finally {
    client.release();
  }
};
