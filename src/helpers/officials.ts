import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Usuario } from '@interfaces/sigt';
import { Client } from 'pg';
import { errorMessageGenerator } from './errors';
import { genSaltSync, hashSync } from 'bcryptjs';
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async (institution: string, id: number) => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_OFFICIALS_BY_INSTITUTION, [institution, id]);
    const funcionarios = response.rows.map(el => {
      const official = {
        ...el,
        nombreCompleto: el.nombrecompleto,
        nombreUsuario: el.nombreusuario,
        tipoUsuario: el.tipousuario,
      };
      delete official.nombrecompleto;
      delete official.nombreusuario;
      delete official.tipousuario;
      return official;
    });
    return {
      status: 200,
      funcionarios,
      message: 'Funcionarios obtenidos satisfactoriamente',
    };
  } catch (e) {
    throw {
      error: e,
      status: 500,
      message: errorMessageGenerator(e) || 'Error al obtener los funcionarios',
    };
  } finally {
    client.release();
  }
};

export const getAllOfficials = async () => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_OFFICIALS);
    const funcionarios = response.rows.map(el => {
      const official = {
        ...el,
        nombreCompleto: el.nombrecompleto,
        nombreUsuario: el.nombreusuario,
        tipoUsuario: el.tipousuario,
      };
      delete official.nombrecompleto;
      delete official.nombreusuario;
      delete official.tipousuario;
      return official;
    });
    return {
      status: 200,
      funcionarios,
      message: 'Funcionarios obtenidos satisfactoriamente',
    };
  } catch (e) {
    throw {
      error: e,
      status: 500,
      message: errorMessageGenerator(e) || 'Error al obtener los funcionarios',
    };
  } finally {
    client.release();
  }
};

export const createOfficial = async (official: any, institution: number) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, rif, telefono, password } = official;
  const client = await pool.connect();
  const salt = genSaltSync(10);
  try {
    client.query('BEGIN');
    const insert = await client.query(queries.CREATE_OFFICIAL, [
      nombreCompleto,
      nombreUsuario,
      direccion,
      cedula,
      nacionalidad,
      hashSync(password, salt),
      telefono,
      institution,
    ]);
    const off = await client.query(queries.GET_OFFICIAL, [insert.rows[0].id_usuario, insert.rows[0].id_institucion]);
    client.query('COMMIT');
    const funcionario = {
      id: off.rows[0].id_usuario,
      nombreCompleto: off.rows[0].nombre_completo,
      nombreUsuario: off.rows[0].nombre_de_usuario,
      tipoUsuario: off.rows[0].id_tipo_usuario,
      direccion: off.rows[0].direccion,
      cedula: off.rows[0].cedula,
      nacionalidad: off.rows[0].nacionalidad,
      password: off.rows[0].password,
      telefono: off.rows[0].telefono,
    };
    return { status: 201, funcionario, message: 'Funcionario creado' };
  } catch (e) {
    client.query('ROLLBACK');
    console.log(e);
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || 'Error al crear un funcionario',
    };
  } finally {
    client.release();
  }
};

//TODO: verificar que el usuario pertenece a mi institucion
export const updateOfficial = async (official: any, id: string) => {
  const { nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, rif, telefono } = official;
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_OFFICIAL, [nombreCompleto, nombreUsuario, direccion, cedula, nacionalidad, rif, telefono, id])).rows[0];
    client.query('COMMIT');
    const funcionario = {
      id: response.id_usuario,
      nombreCompleto: response.nombre_completo,
      nombreUsuario: response.nombre_de_usuario,
      tipoUsuario: response.id_tipo_usuario,
      direccion: response.direccion,
      cedula: response.cedula,
      nacionalidad: response.nacionalidad,
      password: response.password,
      telefono: response.telefono,
    };
    return { status: 200, funcionario, message: 'Funcionario actualizado' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || 'Error al actualizar datos del funcionario',
    };
  } finally {
    client.release();
  }
};

export const deleteOfficial = async (officialID: string, institution: number) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = await client.query(queries.DELETE_OFFICIAL, [officialID, institution]);
    client.query('COMMIT');
    return { status: 200, message: res.rowCount > 0 ? 'Funcionario eliminado' : 'No se encontro el funcionario' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      error: e,
      status: 500,
      message: errorMessageGenerator(e) || 'Error al eliminar funcionario',
    };
  } finally {
    client.release();
  }
};

export const deleteOfficialSuperuser = async (officialID: string) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = await client.query(queries.DELETE_OFFICIAL_AS_SUPERUSER, [officialID]);
    client.query('COMMIT');
    return { status: 200, message: res.rowCount > 0 ? 'Funcionario eliminado' : 'No se encontro el funcionario' };
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      error: e,
      status: 500,
      message: errorMessageGenerator(e) || 'Error al eliminar funcionario',
    };
  } finally {
    client.release();
  }
};
