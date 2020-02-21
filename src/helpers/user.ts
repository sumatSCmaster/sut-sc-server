import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { compare } from "bcryptjs";
import {
  Usuario,
  Payloads,
  Nacionalidad,
  IDsTipoUsuario
} from "@interfaces/sigt";
import { fulfill } from "@utils/resolver";
import { stringify } from "flatted/cjs";

const pool = Pool.getInstance();

export const getUserByUsername = async (
  username: string
): Promise<Usuario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_BY_USERNAME, [username]);
    const phoneResults = await client.query(queries.GET_PHONES_FROM_USERNAME, [
      username
    ]);
    const typeResult = await client.query(queries.GET_USER_TYPE_FROM_USERNAME, [
      username
    ]);
    const googleData = await client.query(
      queries.GET_GOOGLE_DATA_FROM_USERNAME,
      [username]
    );
    const officialData = await client.query(
      queries.GET_OFFICIAL_DATA_FROM_USERNAME,
      [username]
    );
    const resBase = result.rows[0];
    const resPhones = phoneResults.rows;
    const resType = typeResult.rows[0];
    const resGoogle = googleData.rows[0];
    const resOfficial = officialData.rows[0];
    const user: Usuario = {
      id_usuario: resBase.id_usuario,
      nombre_completo: resBase.nombre_completo,
      nombre_de_usuario: resBase.nombre_de_usuario,
      direccion: resBase.direccion,
      cedula: resBase.cedula,
      telefonos: resPhones.map(obj => obj.numero),
      nacionalidad: Nacionalidad[resBase.nacionalidad],
      rif: resBase.rif,
      tipo_usuario: resType,
      datos_google: resGoogle,
      cuenta_funcionario: resOfficial
    };
    return user;
  } catch (e) {
    return null;
  } finally {
    client.release();
  }
};

export const createSuperuser = async (
  user: Payloads.CrearSuperuser
): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const res = (
      await client.query(queries.CREATE_USER, [
        user.nombre_completo,
        user.nombre_de_usuario,
        user.direccion,
        user.cedula,
        user.nacionalidad,
        user.rif,
        IDsTipoUsuario.Superuser
      ])
    ).rows[0];
    const res2 = await client.query(queries.ADD_PASSWORD, [
      res.id_usuario,
      user.cuenta_funcionario?.password
    ]);
    client.query("COMMIT");
    const usuario: Partial<Usuario> = {
      id_usuario: res.id_usuario,
      nombre_de_usuario: res.nombre_de_usuario,
      nombre_completo: res.nombre_completo,
      direccion: res.direccion,
      cedula: res.cedula,
      nacionalidad: Nacionalidad[res.nacionalidad]
    };
    return usuario;
  } catch (e) {
    client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
};

export const createAdmin = async (
  user: Payloads.CrearAdmin
): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const res = (
      await client.query(queries.CREATE_USER, [
        user.nombre_completo,
        user.nombre_de_usuario,
        user.direccion,
        user.cedula,
        user.nacionalidad,
        user.rif,
        IDsTipoUsuario.Administrador
      ])
    ).rows[0];
    console.log(IDsTipoUsuario.Administrador);
    console.log("res", res);
    const res2 = await client.query(queries.ADD_PASSWORD, [
      res.id_usuario,
      user.cuenta_funcionario?.password
    ]);
    const res3 = await Promise.all(
      user.telefonos.map(tlf =>
        client.query(queries.ADD_PHONE, [res.id_usuario, tlf])
      )
    );
    console.log(res3);
    client.query("COMMIT");
    const usuario: Partial<Usuario> = {
      id_usuario: res.id_usuario,
      nombre_de_usuario: res.nombre_de_usuario,
      nombre_completo: res.nombre_completo,
      direccion: res.direccion,
      cedula: res.cedula,
      nacionalidad: Nacionalidad[res.nacionalidad],
      telefonos: res3.map(result => result.rows[0])
    };
    return usuario;
  } catch (e) {
    client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
};

export const comparePassword = (
  candidate: string,
  hash: string
): Promise<boolean> => {
  return new Promise((res, rej) => {
    compare(candidate, hash, (err, isMatch) => {
      if (err) rej(err);
      res(isMatch);
    });
  });
};

export const getByGoogleID = async id => {
  const client = await pool.connect();
  const [err, data] = await fulfill(
    client.query(queries.GET_BY_GOOGLE_ID, [id])
  );
  if (err) return err;
  if (data) return { data: data.rows };
};

export const verifyExternalUser = async id => {
  const client = await pool.connect();
  const [err, data] = await fulfill(
    client.query(queries.GET_EXTERNAL_USER, [id])
  );
  if (err) return err;
  if (data) return { data: data.rows[0] };
};

export const initialExtUserSignUp = async user => {
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const response = await client.query(queries.EXTERNAL_USER_INIT, [
      user.name,
      user.username
    ]);
    client.query(queries.INSERT_GOOGLE_USER, [
      response.rows[0].id_usuario,
      user.googleID
    ]);
    client.query("COMMIT");
    return response.rows[0];
  } catch (e) {
    client.query("ROLLBACK");
    return e;
  } finally {
    client.release();
  }
};

export const completeExtUserSignUp = async (user, id) => {
  const { direccion, cedula, nacionalidad, rif } = user;
  const client = await pool.connect();
  try {
    client.query("BEGIN");
    const response = await client.query(queries.EXTERNAL_USER_COMPLETE, [
      direccion,
      cedula,
      nacionalidad,
      rif,
      id
    ]);
    client.query("COMMIT");
    return { status: 201, message: "hola", user: response.rows[0] };
  } catch (error) {
    client.query("ROLLBACK");
    throw { status: 500, error };
  } finally {
    client.release();
  }
};

// export const hasNotifications = async (id: string): Promise<boolean> => {
//   const client = await pool.connect();
//   try {
//     const result = await client.query(queries.HAS_UNREAD_NOTIF, [id]);
//     return result.rowCount > 0;
//   } catch (e) {
//     throw e;
//   } finally {
//     client.release();
//   }
// };
