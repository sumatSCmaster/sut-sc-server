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
    const funcionarios = response.rows.map(el => {
      const official = {
        ...el,
        nombreCompleto: el.nombrecompleto,
        nombreUsuario: el.nombreusuario,
        tipoUsuario: el.tipousuario
      };
      delete official.nombrecompleto;
      delete official.nombreusuario;
      delete official.tipousuario;
      return official;
    });
    return { status: 200, funcionarios };
  } catch (e) {
    throw { error: e, status: 500 };
  } finally {
    client.release();
  }
};

export const createOfficial = async (official: any, institution: number) => {
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
    const funcionario = {
      id: off.rows[0].id_usuario,
      nombreCompleto: off.rows[0].nombre_completo,
      nombreUsuario: off.rows[0].nombre_de_usuario,
      tipoUsuario: off.rows[0].id_tipo_usuario,
      direccion: off.rows[0].direccion,
      cedula: off.rows[0].cedula,
      nacionalidad: off.rows[0].nacionalidad,
      rif: off.rows[0].rif,
      password: off.rows[0].password
    };
    return { status: 201, funcionario };
  } catch (e) {
    client.query("ROLLBACK");
    console.log(e);
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
