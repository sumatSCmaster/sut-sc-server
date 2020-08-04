import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { createTransport, createTestAccount } from 'nodemailer';
import { v4 as uuidv4 } from 'uuid';
import { genSalt, hash } from 'bcryptjs';
import transporter from '@utils/mail';
import { addInstitute, addPermissions, hasLinkedContributor } from './user';
import { Usuario } from '@root/interfaces/sigt';
const pool = Pool.getInstance();

export const forgotPassword = async (email) => {
  const client = await pool.connect();
  try {
    const emailExists = (await client.query(queries.EMAIL_EXISTS, [email])).rowCount > 0;
    if (emailExists) {
      const recuperacion = (await client.query(queries.ADD_PASSWORD_RECOVERY, [email, uuidv4()])).rows[0];
      console.log(await transporter.sendMail({
        from: process.env.MAIL_ADDRESS || 'info@sutmaracaibo.com',
        to: email,
        subject: 'Recuperación de contraseña',
        text: `Enlace de recuperacion: ${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}`,
        html: `Enlace de recuperacion: <a>${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}</a>`,
      }));
      return { status: 200, message: 'Revise su bandeja de correo' };
    } else {
      return { status: 404, message: 'Información inválida' };
    }
  } catch (e) {
    console.log(e)
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al iniciar proceso de recuperación',
    };
  } finally {
    client.release();
  }
};

export const recoverPassword = async (recoverToken, password) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const validToken = (await client.query(queries.VALIDATE_TOKEN, [recoverToken])).rowCount > 0;
    await client.query(queries.DISABLE_TOKEN, [recoverToken]);
    if (validToken) {
      const salt = await genSalt(10);
      const newPassword = await hash(password, salt);
      const result = await client.query(queries.UPDATE_PASSWORD, [recoverToken, newPassword]);
      client.query('COMMIT');
      return { status: 200, message: 'Contraseña actualizada' };
    } else {
      return { status: 409, message: 'El enlace utilizado ya es invalido' };
    }
  } catch (e) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al iniciar proceso de recuperación',
    };
  } finally {
    client.release();
  }
};

export async function getUserData(id, tipoUsuario) {
  const client = await pool.connect();
  try {
    const userData = (await client.query(queries.GET_USER_INFO_BY_ID, [id])).rows[0];

    let user: Partial<Usuario & { contribuyente: any }> = {
      id,
      tipoUsuario,
      nombreCompleto: userData.nombreCompleto,
      nombreUsuario: userData.nombreUsuario,
      direccion: userData.direccion,
      cedula: userData.cedula,
      nacionalidad: userData.nacionalidad,
      telefono: userData.telefono,
      contribuyente: await hasLinkedContributor(id),
    };
    if (tipoUsuario !== 4 && tipoUsuario !== 1) {
      const officialData = await client.query(queries.GET_OFFICIAL_DATA_FROM_USERNAME, [user.nombreUsuario]);
      user = await addInstitute(user);
      user.cuentaFuncionario = officialData.rows[0];
      if (tipoUsuario === 3) {
        user = await addPermissions(user);
      }
    }
    return user;
  } catch (e) {
    throw {
      error: e,
      status: 500,
    };
  } finally {
    client.release();
  }
}

async function ola() {
  console.log(await transporter.verify());
  await transporter.sendMail({
    from: 'waku@wakusoftware.com',
    to: 'marcia22@ethereal.mail',
    subject: 'contrasena',
    text: 'hola',
    html: '<h1>OLA</h1>',
  });
}
