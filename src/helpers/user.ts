import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { compare } from 'bcryptjs';
import { Usuario, Payloads, Nacionalidad, IDsTipoUsuario, Institucion } from '@interfaces/sigt';
import { fulfill } from '@utils/resolver';
import { stringify } from 'flatted/cjs';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { generateToken } from '@utils/Strategies';
import { blockUserEvent } from './notification';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

//middleware
/**
 *
 */
export const isBlocked = () => async (req, res, next) => {
  const client = await pool.connect();
  const { nombreUsuario: usuario } = req.body;
  try {
    const user = (await client.query('SELECT usr.bloqueado, cf.bloqueado AS bloqueadof FROM usuario usr LEFT JOIN cuenta_funcionario cf USING (id_usuario) WHERE usr.nombre_de_usuario = $1', [usuario])).rows[0];
    if (user?.bloqueado || user?.bloqueadof) {
      res.send({
        status: 401,
        message: 'El usuario de SUT suministrado se encuentra bloqueado',
      });
    } else {
      next();
    }
  } catch (error) {
    mainLogger.error(error);
    res.send({
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al obtener la informacion del usuario',
    });
  } finally {
    client.release();
  }
};

/**
 *
 * @param username
 */
export const getUserByUsername = async (username: string): Promise<Usuario | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_BY_USERNAME, [username]);
    const typeResult = await client.query(queries.GET_USER_TYPE_FROM_USERNAME, [username]);
    const googleData = await client.query(queries.GET_GOOGLE_DATA_FROM_USERNAME, [username]);
    const officialData = await client.query(queries.GET_OFFICIAL_DATA_FROM_USERNAME, [username]);
    if (result.rowCount === 0) {
      return null;
    }
    const resBase = result.rows[0];
    const resType = typeResult.rows[0];
    const resGoogle = googleData.rows[0];
    const resOfficial = officialData.rows[0];
    const user: Usuario & { verificado: Boolean } = {
      id: resBase.id_usuario,
      nombreCompleto: resBase.nombre_completo,
      nombreUsuario: resBase.nombre_de_usuario,
      verificado: resBase.verificado,
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
    mainLogger.error(e);
    return e;
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const createSuperuser = async (user: Payloads.CrearSuperuser): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = (await client.query(queries.CREATE_USER, [user.nombreCompleto, user.nombreUsuario, user.direccion, user.cedula, user.nacionalidad, IDsTipoUsuario.Superuser, user.password, user.telefono])).rows[0];
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
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const createAdmin = async (user: Payloads.CrearAdmin): Promise<Partial<Usuario>> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const adminExists = user.cargo === 0 ? false : (await client.query(queries.ADMIN_EXISTS, [user.cargo])).rowCount > 0;
    if (adminExists) throw new Error('Ya existe un administrador para esta institucion');
    const res = (await client.query(queries.CREATE_USER, [user.nombreCompleto, user.nombreUsuario, user.direccion, user.cedula, user.nacionalidad, IDsTipoUsuario.Administrador, user.password, user.telefono])).rows[0];
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
    mainLogger.error(`Error createAdmin ${e.message}`)
    client.query('ROLLBACK');
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const addInstitute = async (user: Partial<Usuario>): Promise<Partial<Usuario> & { institucion: Institucion & { cargo: object; bloqueado: boolean } }> => {
  const client = await pool.connect();
  try {
    const res = (await client.query(queries.GET_ADMIN_INSTITUTE, [user.id])).rows;
    if (!res.length) throw { status: 403, message: 'Un funcionario debe poseer una institucion' };
    return {
      ...user,
      institucion: {
        bloqueado: res[0].bloqueado,
        id: res[0].id_institucion,
        nombreCompleto: res[0].nombre_completo,
        nombreCorto: res[0].nombre_corto,
        cargo: {
          id: res[0].idCargo,
          descripcion: res[0].cargo,
        },
      },
    };
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const addPermissions = async (user: Partial<Usuario>): Promise<Partial<Usuario> & { permisos: number[] }> => {
  const client = await pool.connect();
  try {
    const res = (await client.query(queries.GET_USER_PERMISSIONS, [user.id])).rows;
    return {
      ...user,
      permisos: res.map((row) => +row.id_tipo_tramite),
    };
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

/**
 *
 * @param candidate
 * @param hash
 */
export const comparePassword = (candidate: string, hash: string): Promise<boolean> => {
  return new Promise((res, rej) => {
    compare(candidate, hash, (err, isMatch) => {
      if (err) rej(err);
      res(isMatch);
    });
  });
};

/**
 *
 * @param id
 */
export const getByOAuthID = async (id) => {
  const client = await pool.connect();
  const [err, data] = await fulfill(client.query(queries.GET_OAUTH_USER, [id]));
  client.release();
  if (err) return err;
  if (data) return { data: data.rows };
};

/**
 *
 * @param id
 */
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

/**
 *
 * @param user
 */
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
    return errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 * @param id
 */
export const completeExtUserSignUp = async (user, id) => {
  const { nombreCompleto, nombreUsuario, password, direccion, cedula, nacionalidad, telefono } = user;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = await client.query(queries.EXTERNAL_USER_COMPLETE, [direccion, cedula, nacionalidad, nombreUsuario, password, nombreCompleto, telefono, id]);
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
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error en la creaci??n del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const signUpUser = async (user) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, password, telefono } = user;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = await client.query(queries.SIGN_UP_WITH_LOCAL_STRATEGY, [nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, password, telefono]);
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
      error: errorMessageExtractor(error),
      status: 500,
      message: errorMessageGenerator(error) || 'Error en la creaci??n del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
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
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error en la actualizacion del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param cedula
 */
export const hasNotifications = async (cedula) => {
  const client = await pool.connect();
  try {
    return (await client.query(queries.GET_USER_HAS_NOTIFICATIONS, [cedula])).rows[0].hasNotifications;
  } catch (e) {
    throw {
      status: 500,
      e: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener estado de notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const hasLinkedContributor = async (user) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query('SELECT c.* FROM impuesto.CONTRIBUYENTE c INNER JOIN USUARIO u ON c.id_contribuyente = u.id_contribuyente WHERE u.id_usuario = $1', [user])).rows[0];
    if (!contributor) return null;
    const verificacionTelefono = (await client.query('SELECT * FROM impuesto.verificacion_telefono v INNER JOIN usuario u ON v.id_usuario = u.id_usuario WHERE u.id_usuario = $1', [user])).rows[0];
    // const isRetentionAgent = (await client.query("SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = $1 AND referencia_municipal ILIKE 'AR%'", [contributor.id_contribuyente])).rows.length > 0;
    const contribuyente = {
      id: contributor.id_contribuyente,
      tipoDocumento: contributor.tipo_documento,
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      razonSocial: contributor.razon_social,
      denomComercial: contributor.denominacion_comercial || undefined,
      siglas: contributor.siglas || undefined,
      parroquia: contributor.parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      puntoReferencia: contributor.punto_referencia,
      verificado: contributor.verificado,
      verificacionTelefono: (verificacionTelefono && verificacionTelefono.verificado) || false,
      esAgenteRetencion: contributor.es_agente_retencion,
    };
    return contribuyente;
  } catch (e) {
    mainLogger.error(e);
    throw {
      status: 500,
      e: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener estado de notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param contributor
 */
export const getUsersByContributor = async (contributor) => {
  const client = await pool.connect();
  try {
    const users = await client.query('SELECT id_usuario as id, nombre_de_usuario as correo FROM usuario WHERE id_contribuyente = $1 ORDER BY id_usuario', [contributor]);
    return users.rows;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const userSearch = async ({ document, docType, email }) => {
  const client = await pool.connect();
  let usuarios: any[] = [];
  try {
    if (!document && !email) throw { status: 406, message: 'Debe aportar algun parametro para la busqueda' };
    if (document && document.length < 6 && email && email.length < 4) throw { status: 406, message: 'Debe aportar mas datos para la busqueda' };
    usuarios =
      email && email.length >= 4 ? (await client.query('SELECT * FROM usuario WHERE nombre_de_usuario ILIKE $1', [`%${email}%`])).rows : (await client.query('SELECT * FROM usuario WHERE nacionalidad = $1 AND cedula = $2', [docType, document])).rows;
    const contributorExists = usuarios.length > 0;
    if (!contributorExists) return { status: 404, message: 'No existen coincidencias con el correo o documento proporcionado' };
    usuarios = await Promise.all(
      usuarios.map(async (el) => ({
        id: el.id_usuario,
        bloqueado: el.bloqueado,
        nombreCompleto: el.nombre_completo,
        nombreUsuario: el.nombre_de_usuario,
        direccion: el.direccion,
        documento: el.cedula,
        tipoDocumento: el.nacionalidad,
        telefono: el.telefono,
        contribuyente: await hasLinkedContributor(el.id_usuario),
      }))
    );
    // contribuyentes = await Promise.all(contribuyentes.map(async (el) => await formatContributor(el, client)));
    return { status: 200, message: 'Usuarios obtenidos', usuarios };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener contribuyentes en busqueda',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 */
export const unlinkContributorFromUser = async (id) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE usuario SET id_contribuyente = null WHERE id_usuario = $1', [id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Contribuyente desenlazado del usuario SUT' };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al desenlazar contribuyente',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 * @param blockStatus
 * @param user
 */
export const blockUser = async (id, blockStatus, user: Usuario) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE usuario SET bloqueado = $1 WHERE id_usuario = $2', [!blockStatus, id]);
    await client.query('COMMIT');
    await blockUserEvent(id, !blockStatus, user, client);
    return { status: 200, message: 'Estatus bloqueado del usuario SUT modificado' };
  } catch (error) {
    mainLogger.error(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al cambiar estatus de bloqueado del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const updateUserInformation = async ({ user, id }) => {
  const client = await pool.connect();
  const { nombreCompleto, nombreUsuario, direccion, documento, tipoDocumento, telefono } = user;
  try {
    await client.query('BEGIN');
    const user = (
      await client.query('UPDATE usuario SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3, cedula=$4, nacionalidad = $5, telefono = $6 WHERE id_usuario = $7 RETURNING *', [
        nombreCompleto,
        nombreUsuario,
        direccion,
        documento,
        tipoDocumento,
        telefono,
        id,
      ])
    ).rows[0];
    await client.query('COMMIT');
    const usuario = {
      id: user.id_usuario,
      nombreCompleto: user.nombre_completo,
      nombreUsuario: user.nombre_de_usuario,
      direccion: user.direccion,
      documento: user.cedula,
      tipoDocumento: user.nacionalidad,
      telefono: user.telefono,
      contribuyente: await hasLinkedContributor(user.id_usuario),
    };
    return { status: 200, message: 'Datos del usuario actualizados', usuario };
  } catch (error) {
    mainLogger.error(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al actualizar datos de usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const addUserVerification = async ({ cellphone, id }) => {
  const client = await pool.connect();
  try {
    const isVerified = (await client.query('SELECT * FROM impuesto.verificacion_telefono WHERE id_usuario = $1', [id])).rows[0]?.id_verificacion_telefono;
    if (isVerified) throw { status: 403, message: 'El usuario ya se encuentra verificado' };
    await client.query('BEGIN');
    const verifiedId = (await client.query(queries.ADD_VERIFIED_CONTRIBUTOR, [id])).rows[0].id_verificacion_telefono;
    await client.query('UPDATE impuesto.verificacion_telefono SET telefono = $1 WHERE id_verificacion_telefono = $2', [cellphone, verifiedId]);
    await client.query('COMMIT');
    return { status: 200, message: 'Usuario verificado' };
  } catch (error) {
    mainLogger.error(error);
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al a??adir verificaci??n de usuario',
    };
  } finally {
    client.release();
  }
};
