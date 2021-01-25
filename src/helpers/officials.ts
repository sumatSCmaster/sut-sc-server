import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Usuario } from '@interfaces/sigt';
import { Client, PoolClient } from 'pg';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { genSaltSync, hashSync } from 'bcryptjs';
import { blockUserEvent } from './notification';
const pool = Pool.getInstance();

/**
 *
 * @param institution
 * @param id
 */
export const getOfficialsByInstitution = async (institution: string, id: number) => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_OFFICIALS_BY_INSTITUTION, [institution, id]);
    const funcionarios = await Promise.all(
      response.rows.map(async (el) => {
        const inst = (await client.query(queries.GET_ADMIN_INSTITUTE, [el.id])).rows;
        if (!inst.length) throw { status: 403, message: 'Un funcionario debe poseer una institucion' };
        const official = {
          ...el,
          nombreCompleto: el.nombrecompleto,
          nombreUsuario: el.nombreusuario,
          tipoUsuario: el.tipousuario,
          institucion: {
            bloqueado: inst[0].bloqueado,
            id: inst[0].id_institucion,
            nombreCompleto: inst[0].nombre_completo,
            nombreCorto: inst[0].nombre_corto,
            cargo: {
              id: inst[0].idCargo,
              descripcion: inst[0].cargo,
            },
          },
          permisos: (await client.query(queries.GET_USER_PERMISSIONS, [el.id])).rows.map((row) => +row.id_tipo_tramite) || [],
        };
        delete official.nombrecompleto;
        delete official.nombreusuario;
        delete official.tipousuario;
        return official;
      })
    );
    return {
      status: 200,
      funcionarios,
      message: 'Funcionarios obtenidos satisfactoriamente',
    };
  } catch (e) {
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al obtener los funcionarios',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getAllOfficials = async () => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_OFFICIALS);
    const funcionarios = await Promise.all(
      response.rows.map(async (el) => {
        const inst = (await client.query(queries.GET_ADMIN_INSTITUTE, [el.id])).rows;
        if (!inst.length) throw { status: 403, message: 'Un funcionario debe poseer una institucion' };
        const official = {
          ...el,
          nombreCompleto: el.nombrecompleto,
          nombreUsuario: el.nombreusuario,
          tipoUsuario: el.tipousuario,
          institucion: {
            bloqueado: inst[0].bloqueado,
            id: inst[0].id_institucion,
            nombreCompleto: inst[0].nombre_completo,
            nombreCorto: inst[0].nombre_corto,
            cargo: {
              id: inst[0].idCargo,
              descripcion: inst[0].cargo,
            },
          },
        };
        delete official.nombrecompleto;
        delete official.nombreusuario;
        delete official.tipousuario;
        return official;
      })
    );
    return {
      status: 200,
      funcionarios,
      message: 'Funcionarios obtenidos satisfactoriamente',
    };
  } catch (e) {
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al obtener los funcionarios',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 * @param client
 */
async function dropPermissions(id, client: PoolClient) {
  return client.query(queries.DROP_OFFICIAL_PERMISSIONS, [id]);
}

/**
 *
 * @param id
 * @param permisos
 * @param client
 */
async function addPermissions(id, permisos, client: PoolClient) {
  return Promise.all(permisos.map((perm) => client.query(queries.ADD_OFFICIAL_PERMISSIONS, [id, perm])));
}

/**
 *
 * @param official
 */
export const createOfficial = async (official: any) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, telefono, password, permisos, tipoUsuario, cargo } = official;
  const client = await pool.connect();
  const salt = genSaltSync(10);
  try {
    client.query('BEGIN');
    const insert = await client.query(queries.CREATE_OFFICIAL, [nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, hashSync(password, salt), telefono, cargo, tipoUsuario]);
    const off = await client.query(queries.GET_OFFICIAL, [insert.rows[0].id_usuario, insert.rows[0].id_cargo]);
    const id = off.rows[0].id_usuario;
    await addPermissions(id, permisos || [], client);
    client.query('COMMIT');
    const inst = (await client.query(queries.GET_ADMIN_INSTITUTE, [id])).rows;
    if (!inst.length) throw { status: 403, message: 'Un funcionario debe poseer una institucion' };
    const usuario = {
      id,
      nombreCompleto: off.rows[0].nombre_completo,
      nombreUsuario: off.rows[0].nombre_de_usuario,
      tipoUsuario: off.rows[0].id_tipo_usuario,
      direccion: off.rows[0].direccion,
      cedula: off.rows[0].cedula,
      nacionalidad: off.rows[0].nacionalidad,
      password: off.rows[0].password,
      telefono: off.rows[0].telefono,
      institucion: {
        bloqueado: inst[0].bloqueado,
        id: inst[0].id_institucion,
        nombreCompleto: inst[0].nombre_completo,
        nombreCorto: inst[0].nombre_corto,
        cargo: {
          id: inst[0].idCargo,
          descripcion: inst[0].cargo,
        },
      },
    };
    return { status: 201, usuario, message: 'Funcionario creado' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al crear un funcionario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param official
 * @param id
 */
//TODO: verificar que el usuario pertenece a mi institucion
export const updateOfficial = async (official: any, id: string) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, telefono, permisos, tipoUsuario, cargo } = official;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_OFFICIAL, [nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, telefono, id, tipoUsuario])).rows[0];
    if (permisos) {
      await dropPermissions(id, client);
      await addPermissions(id, permisos, client);
    }
    if (cargo) {
      await client.query('UPDATE cuenta_funcionario SET id_cargo = $1 WHERE id_usuario = $2', [cargo, id]);
    }
    client.query('COMMIT');
    const inst = (await client.query(queries.GET_ADMIN_INSTITUTE, [id])).rows;
    if (!inst.length) throw { status: 403, message: 'Un funcionario debe poseer una institucion' };
    const usuario = {
      id: response.id_usuario,
      nombreCompleto: response.nombre_completo,
      nombreUsuario: response.nombre_de_usuario,
      tipoUsuario: response.id_tipo_usuario,
      direccion: response.direccion,
      cedula: response.cedula,
      nacionalidad: response.nacionalidad,
      password: response.password,
      cargo,
      telefono: response.telefono,
      permisos: (await client.query(queries.GET_USER_PERMISSIONS, [response.id_usuario])).rows.map((row) => +row.id_tipo_tramite) || [],
      institucion: {
        bloqueado: inst[0].bloqueado,
        id: inst[0].id_institucion,
        nombreCompleto: inst[0].nombre_completo,
        nombreCorto: inst[0].nombre_corto,
        cargo: {
          id: inst[0].idCargo,
          descripcion: inst[0].cargo,
        },
      },
    };
    return { status: 200, usuario, message: 'Funcionario actualizado' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al actualizar datos del funcionario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param officialID
 * @param institution
 */
export const deleteOfficial = async (officialID: string, institution: number) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = await client.query('UPDATE cuenta_funcionario SET bloqueado = true WHERE id_usuario = $1', [officialID]);
    // const res = await client.query(queries.DELETE_OFFICIAL, [officialID, institution]);
    client.query('COMMIT');
    return { status: 200, message: res.rowCount > 0 ? 'Funcionario eliminado' : 'No se encontro el funcionario' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al eliminar funcionario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param officialID
 */
export const deleteOfficialSuperuser = async (officialID: string) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = await client.query('UPDATE cuenta_funcionario SET bloqueado = true WHERE id_usuario = $1', [officialID]);
    // const res = await client.query(queries.DELETE_OFFICIAL_AS_SUPERUSER, [officialID]);
    client.query('COMMIT');
    return { status: 200, message: res.rowCount > 0 ? 'Funcionario eliminado' : 'No se encontro el funcionario' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al eliminar funcionario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param officialID
 * @param blockStatus
 * @param user
 */
export const blockOfficial = async (officialID: string, blockStatus: boolean, user: Usuario) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const res = await client.query('UPDATE cuenta_funcionario SET bloqueado = $1 WHERE id_usuario = $2', [!blockStatus, officialID]);
    // const res = await client.query(queries.DELETE_OFFICIAL_AS_SUPERUSER, [officialID]);
    await client.query('COMMIT');
    await blockUserEvent(+officialID, !blockStatus, user, client);
    return { status: 200, message: res.rowCount > 0 ? 'Estatus del funcionario modificado' : 'No se encontro el funcionario' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al bloquear funcionario',
    };
  } finally {
    client.release();
  }
};
