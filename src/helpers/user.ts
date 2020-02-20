import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { compare } from 'bcryptjs';
import { Usuario, Payloads, Nacionalidad, IDsTipoUsuario } from '@interfaces/sigt'

const pool = Pool.getInstance();

export const getUserByUsername = async (username: string): Promise<Usuario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_BY_USERNAME, [username]);
    const phoneResults = await client.query(queries.GET_PHONES_FROM_USERNAME, [username]);
    const typeResult = await client.query(queries.GET_USER_TYPE_FROM_USERNAME, [username]);
    const googleData = await client.query(queries.GET_GOOGLE_DATA_FROM_USERNAME, [username]);
    const officialData = await client.query(queries.GET_OFFICIAL_DATA_FROM_USERNAME, [username]);
    const resBase = result.rows[0];
    const resPhones = phoneResults.rows;
    const resType = typeResult.rows[0]
    const resGoogle = googleData.rows[0];
    const resOfficial = officialData.rows[0];
    const user: Usuario = {
      id_usuario: resBase.id_usuario,
      nombre_completo: resBase.nombre_completo,
      nombre_de_usuario: resBase.nombre_de_usuario,
      direccion: resBase.direccion,
      cedula: resBase.cedula,
      telefonos: resPhones.map((obj) => obj.numero),
      nacionalidad: Nacionalidad[resBase.nacionalidad],
      rif: resBase.rif,
      tipo_usuario: resType,
      datos_google: resGoogle,
      cuenta_funcionario: resOfficial
    };
    return user;
  } catch(e) {
    return null;
  } finally {
    client.release();
  }
};

export const createSuperuser = async (user: Payloads.CrearSuperuser): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = (await client.query(queries.CREATE_SUPERUSER, 
      [user.nombre_completo, user.nombre_de_usuario, user.direccion, user.cedula, user.nacionalidad, user.rif, IDsTipoUsuario.Superuser])).rows[0];
    client.query('COMMIT');
    const usuario: Partial<Usuario> = {
      id_usuario: res.id_usuario,
      nombre_de_usuario: res.nombre_de_usuario,
      nombre_completo: res.nombre_completo,
      direccion: res.direccion,
      cedula: res.cedula,
      nacionalidad: Nacionalidad[res.nacionalidad],

    };
    return usuario;
  } catch(e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}; 


export const comparePassword = (candidate: string, hash: string): Promise<boolean> => {
  return new Promise((res, rej) => {
    compare(candidate, hash, (err, isMatch) => {
      if(err) rej(err);
      res(isMatch);
    });
  });
};

export const hasNotifications = async (id: string): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.HAS_UNREAD_NOTIF, [id]);
    return result.rowCount > 0;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};