import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { createTransport, createTestAccount } from 'nodemailer';
import { v4 as uuidv4 } from 'uuid';
import { genSalt, hash } from 'bcryptjs';
import transporter from '@utils/mail';
import { addInstitute, addPermissions, hasLinkedContributor } from './user';
import { Usuario } from '@root/interfaces/sigt';
import { mainLogger } from '@utils/logger';
const pool = Pool.getInstance();

export const forgotPassword = async (email) => {
  const client = await pool.connect();
  try {
    const emailExists = (await client.query(queries.EMAIL_EXISTS, [email])).rowCount > 0;
    if (emailExists) {
      const recuperacion = (await client.query(queries.ADD_PASSWORD_RECOVERY, [email, uuidv4()])).rows[0];
      mainLogger.info(
        await transporter.sendMail({
          from: process.env.MAIL_ADDRESS || 'info@sutmaracaibo.com',
          to: email,
          subject: 'Recuperación de contraseña',
          text: `Enlace de recuperacion: ${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}`,
          html: generateHtmlMail(`${process.env.CLIENT_URL}/olvidoContraseña?recvId=${recuperacion.token_recuperacion}`, email),
        })
      );
      return { status: 200, message: 'Revise su bandeja de correo' };
    } else {
      return { status: 404, message: 'Información inválida' };
    }
  } catch (e) {
    mainLogger.error(e);
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
    mainLogger.error(e);
    throw {
      error: e,
      status: 500,
    };
  } finally {
    client.release();
  }
}

const generateHtmlMail = (link, username) => `<center>
  <style>
    .btn {
      color: #fff;
      background-color: #4285f5;
      border: none;
      border-radius: 15px;
      padding: 5px 15px;
      font-size: 20px;
      margin-top: 10px;
    }
    .btn:hover {
      background-color: #2374ff;
      cursor: pointer;
    }
    .btn:focus {
      background-color: #2374ff;
      outline: none;
    }
  </style>
  <table border="0" cellspacing="0" cellpadding="0" align="center" width="520" bgcolor="#ffffff" style="background: #ffffff; min-width: 520px;">
    <tbody>
      <tr>
        <td width="20" bgcolor="#4285f5" style="background: #4285f5;"></td>
        <td width="480">
          <table border="0" cellspacing="0" cellpadding="0" width="100%">
            <tbody>
              <tr>
                <td height="20" bgcolor="#4285f5" style="background: #4285f5;"></td>
              </tr>
              <tr>
                <td>
                  <table border="0" cellspacing="0" cellpadding="0" align="center" width="100%" style="border-bottom: 1px solid #4285f5;">
                    <tbody>
                      <tr>
                        <td height="49"></td>
                      </tr>
                      <tr>
                        <td
                          align="center"
                          class="m_-8834691710559868579whom"
                          style="color: #4285f4; font-family: 'Roboto', OpenSans, 'Open Sans', Arial, sans-serif; font-size: 32px; font-weight: normal; line-height: 46px; margin: 0; padding: 0 25px 0 25px; text-align: center;"
                        >
                          Hola, <span style="text-decoration: none;">${username}</span>
                        </td>
                      </tr>

                      <tr>
                        <td height="20"></td>
                      </tr>
                      <tr>
                        <td
                          align="center"
                          class="m_-8834691710559868579parasec"
                          style="color: #757575; font-family: 'Roboto', OpenSans, 'Open Sans', Arial, sans-serif; font-size: 17px; font-weight: normal; line-height: 24px; margin: 0; padding: 0 25px 0 25px; text-align: center;"
                        >
                          Para completar el proceso de recuperación de contraseña, presione recuperar
                        </td>
                      </tr>
                      <tr>
                        <td
                          align="center"
                          class="m_-8834691710559868579device_txt"
                          style="color: #757575; font-family: 'Roboto', OpenSans, 'Open Sans', Arial, sans-serif; font-size: 24px; font-weight: normal; line-height: 33px; margin: 0; padding: 0 25px 0 25px; text-align: center;"
                        >
                          <a style="
                          color: #4285f5;
                          padding: 5px 15px;
                          font-size: 20px;
                          margin-top: 10px;" target='_blank' href="${link}">Recuperar</a>
                        </td>
                      </tr>
                      <tr>
                        <td
                          align="center"
                          class="m_-8834691710559868579parasec"
                          style="color: #757575; font-family: 'Roboto', OpenSans, 'Open Sans', Arial, sans-serif; font-size: 12px; font-weight: normal; line-height: 24px; margin: 0; padding:10px 25px; text-align: center;"
                        >
                          Si usted no inició un proceso de recuperación de contraseña ignore este correo
                        </td>
                      </tr>                 
                      <tr>
                        <td height="30"></td>
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
              <tr>
                <td height="19" bgcolor="#4285f5" style="background: #4285f5;"></td>
              </tr>
            </tbody>
          </table>
        </td>
        <td width="20" bgcolor="#4285f5" style="background: #4285f5;"></td>
      </tr>
    </tbody>
  </table>
  <div style="display: none; white-space: nowrap; font: 15px courier; line-height: 0;">
    &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
  </div>
</center>
`;
