import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { compare } from 'bcryptjs';
import { Usuario, Payloads, Nacionalidad, IDsTipoUsuario, Institucion } from '@interfaces/sigt';
import { fulfill } from '@utils/resolver';
import { stringify } from 'flatted/cjs';
import { errorMessageGenerator } from './errors';
import { generateToken } from '@utils/Strategies';

const pool = Pool.getInstance();

export const getUserByUsername = async (username: string): Promise<Usuario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_BY_USERNAME, [username]);
    const typeResult = await client.query(queries.GET_USER_TYPE_FROM_USERNAME, [username]);
    const googleData = await client.query(queries.GET_GOOGLE_DATA_FROM_USERNAME, [username]);
    const officialData = await client.query(queries.GET_OFFICIAL_DATA_FROM_USERNAME, [username]);
    const resBase = result.rows[0];
    const resType = typeResult.rows[0];
    const resGoogle = googleData.rows[0];
    const resOfficial = officialData.rows[0];
    const user: Usuario = {
      id: resBase.id_usuario,
      nombreCompleto: resBase.nombre_completo,
      nombreUsuario: resBase.nombre_de_usuario,
      password: resBase.password,
      direccion: resBase.direccion,
      cedula: resBase.cedula,
      telefono: resBase.telefono,
      nacionalidad: Nacionalidad[resBase.nacionalidad],
      rif: resBase.rif,
      tipoUsuario: resType.id_tipo_usuario,
      datosGoogle: resGoogle,
      cuentaFuncionario: resOfficial,
    };
    return user;
  } catch (e) {
    return null;
  } finally {
    client.release();
  }
};

export const createSuperuser = async (user: Payloads.CrearSuperuser): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = (
      await client.query(queries.CREATE_USER, [
        user.nombreCompleto,
        user.nombreUsuario,
        user.direccion,
        user.cedula,
        user.nacionalidad,
        IDsTipoUsuario.Superuser,
        user.password,
        user.telefono,
      ])
    ).rows[0];
    const res2 = await client.query(queries.ADD_OFFICIAL_DATA, [res.id_usuario, user.institucion]);
    client.query('COMMIT');
    const usuario: Partial<Usuario> = {
      id: res.id_usuario,
      nombreUsuario: res.nombre_de_usuario,
      nombreCompleto: res.nombre_completo,
      direccion: res.direccion,
      cedula: res.cedula,
      nacionalidad: Nacionalidad[res.nacionalidad],
    };
    return usuario;
  } catch (e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const createAdmin = async (user: Payloads.CrearAdmin): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const adminExists = user.cargo === 0 ? false : (await client.query(queries.ADMIN_EXISTS, [user.cargo])).rowCount > 0;
    if (adminExists) throw new Error('Ya existe un administrador para esta institucion');
    const res = (
      await client.query(queries.CREATE_USER, [
        user.nombreCompleto,
        user.nombreUsuario,
        user.direccion,
        user.cedula,
        user.nacionalidad,
        IDsTipoUsuario.Administrador,
        user.password,
        user.telefono,
      ])
    ).rows[0];
    const res2 = await client.query(queries.ADD_OFFICIAL_DATA, [res.id_usuario, user.cargo]);

    client.query('COMMIT');
    const usuario: Partial<Usuario> = {
      id: res.id_usuario,
      nombreUsuario: res.nombre_de_usuario,
      nombreCompleto: res.nombre_completo,
      direccion: res.direccion,
      cedula: res.cedula,
      nacionalidad: Nacionalidad[res.nacionalidad],
      telefono: res.telefono,
      tipoUsuario: res.id_tipo_usuario,
    };
    return usuario;
  } catch (e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const addInstitute = async (user: Partial<Usuario>): Promise<Partial<Usuario> & { institucion: Institucion }> => {
  const client = await pool.connect();
  try {
    const res = (await client.query(queries.GET_ADMIN_INSTITUTE, [user.id])).rows;
    return {
      ...user,
      institucion: {
        id: res[0].id_institucion,
        nombreCompleto: res[0].nombre_completo,
        nombreCorto: res[0].nombre_corto,
      },
    };
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const addPermissions = async (user: Partial<Usuario>): Promise<Partial<Usuario> & { permisos: number[] }> => {
  const client = await pool.connect();
  try {
    const res = (await client.query(queries.GET_USER_PERMISSIONS, [user.id])).rows;
    return {
      ...user,
      permisos: res.map((row) => +row.id_tipo_tramite),
    };
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const comparePassword = (candidate: string, hash: string): Promise<boolean> => {
  return new Promise((res, rej) => {
    compare(candidate, hash, (err, isMatch) => {
      if (err) rej(err);
      res(isMatch);
    });
  });
};

export const getByOAuthID = async (id) => {
  const client = await pool.connect();
  const [err, data] = await fulfill(client.query(queries.GET_OAUTH_USER, [id]));
  client.release();
  if (err) return err;
  if (data) return { data: data.rows };
};

export const verifyExternalUser = async (id) => {
  const client = await pool.connect();
  const [err, data] = await fulfill(client.query(queries.GET_EXTERNAL_USER, [id]));
  client.release();
  if (err) return err;
  if (data)
    return {
      id: data.rows[0].id_usuario,
      nombreCompleto: data.rows[0].nombre_completo,
      nombreUsuario: data.rows[0].nombre_de_usuario,
      direccion: data.rows[0].direccion,
      rif: data.rows[0].rif,
      nacionalidad: data.rows[0].nacionalidad,
      tipoUsuario: data.rows[0].id_tipo_usuario,
      cedula: data.rows[0].cedula,
      telefono: data.rows[0].telefono,
    };
};

export const initialExtUserSignUp = async (user) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.EXTERNAL_USER_INIT, [user.name])).rows[0];
    client.query(user.provider === 'facebook' ? queries.INSERT_FACEBOOK_USER : queries.INSERT_GOOGLE_USER, [response.id_usuario, user.OAuthID]);
    client.query('COMMIT');
    return {
      id: response.id_usuario,
      nombreCompleto: response.nombre_completo,
      nombreUsuario: response.nombre_de_usuario,
      direccion: response.direccion,
      nacionalidad: response.nacionalidad,
      tipoUsuario: response.id_tipo_usuario,
      cedula: response.cedula,
      telefono: response.telefono,
    };
  } catch (e) {
    client.query('ROLLBACK');
    return e;
  } finally {
    client.release();
  }
};

export const completeExtUserSignUp = async (user, id) => {
  const { nombreCompleto, nombreUsuario, password, direccion, cedula, nacionalidad, telefono } = user;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = await client.query(queries.EXTERNAL_USER_COMPLETE, [
      direccion,
      cedula,
      nacionalidad,
      nombreUsuario,
      password,
      nombreCompleto,
      telefono,
      id,
    ]);
    client.query('COMMIT');
    const data = response.rows[0];
    const usuario: Usuario = {
      id: data.id_usuario,
      nombreCompleto: data.nombre_completo,
      nombreUsuario: data.nombre_de_usuario,
      direccion: data.direccion,
      nacionalidad: data.nacionalidad,
      tipoUsuario: data.id_tipo_usuario,
      cedula: data.cedula,
      telefono: data.telefono,
    };
    return { status: 201, user: usuario, token: generateToken(user) };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error en la creación del usuario',
    };
  } finally {
    client.release();
  }
};

export const signUpUser = async (user) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, password, telefono } = user;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = await client.query(queries.SIGN_UP_WITH_LOCAL_STRATEGY, [
      nombreCompleto,
      nombreUsuario,
      direccion,
      cedula,
      nacionalidad,
      password,
      telefono,
    ]);
    client.query('COMMIT');
    const data = response.rows[0];
    const usuario: Usuario = {
      id: data.id_usuario,
      nombreCompleto: data.nombre_completo,
      nombreUsuario: data.nombre_de_usuario,
      direccion: data.direccion,
      nacionalidad: data.nacionalidad,
      tipoUsuario: data.id_tipo_usuario,
      cedula: data.cedula,
      telefono: data.telefono,
    };
    return {
      status: 201,
      user: usuario,
      message: 'Usuario registrado',
      token: generateToken(usuario),
    };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      error,
      status: 500,
      message: errorMessageGenerator(error) || 'Error en la creación del usuario',
    };
  } finally {
    client.release();
  }
};

export const updateUser = async (user) => {
  const { id, direccion, nombreCompleto, telefono } = user;
  const client = await pool.connect();
  try {
    const res = await client.query(queries.UPDATE_USER, [direccion, nombreCompleto, telefono, id]);
    if (res.rowCount > 0) {
      return {
        status: 200,
        user: res.rows[0],
        message: 'Usuario actualizado',
      };
    } else {
      return {
        status: 400,
        message: 'Usuario no encontrado',
      };
    }
  } catch (e) {
    throw {
      status: 500,
      message: errorMessageGenerator(e) || 'Error en la actualizacion del usuario',
    };
  } finally {
    client.release();
  }
};

export const hasNotifications = async (cedula) => {
  const client = await pool.connect();
  try {
    return (await client.query(queries.GET_USER_HAS_NOTIFICATIONS, [cedula])).rows[0].hasNotifications;
  } catch (e) {
    throw {
      status: 500,
      e,
      message: errorMessageGenerator(e) || 'Error al obtener estado de notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};
