import Pool from '@utils/Pool';
import { Invitacion, Payloads } from 'sge';
import queries from '@utils/queries';
import { randomBytes } from 'crypto';
import { createTestAccount, createTransport, getTestMessageUrl } from 'nodemailer';
import { sendNotification } from './notification';
import { getUsers } from '@config/socket';
import { getTemplate } from '../templates/invitation';

const pool = Pool.getInstance();
const users = getUsers();

export const getInvites = async (): Promise<Invitacion[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_ALL_INVITATIONS);
    return result.rows.map((i) => ({
      id: i.id,
      correo: i.correo,
      nombre: i.nombre_completo
    }));
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createInvite = async (user: Payloads.CrearInvitacion): Promise<Invitacion | null> => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    let registered = false;
    const buffer = randomBytes(32);
    const result = await client.query(queries.CREATE_INVITATION, [user.correo, buffer.toString('hex')]);
    const exists = result.rowCount === 0;
    if(!exists) {
      registered = (await client.query(queries.REGISTER_USER, [user.cedula, user.nombre, user.correo, user.institucion, user.oficina, user.rol, user.cargo])).rowCount > 0; 
    };
    !exists ? client.query('COMMIT') : client.query('ROLLBACK');
    if(!exists && registered) sendEmail(result.rows[0].id, user.correo, buffer.toString('hex'));
    return !exists && registered ? {
      id: result.rows[0].id,
      correo: user.correo,
      nombre: user.nombre
    } : null;
  } catch(e) {
    client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const resendInvitation = async (id: number): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const buffer = randomBytes(32);
    const result = await client.query(queries.REFRESH_TOKEN, [buffer.toString('hex'), id]);
    if(result.rowCount > 0) {
      sendEmail(result.rows[0].id, result.rows[0].correo, buffer.toString('hex'));
    } 
    return result.rowCount > 0;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const deleteInvite = async (id: number): Promise<number | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.DELETE_INVITATION, [id]);
    return result.rowCount > 0 ? id : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

export const acceptInvite = async (id: number, inv: Payloads.AceptarInvitacion): Promise<string | null> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.ACCEPT_INVITATION, [id, inv.token, inv.telefono, inv.username, inv.password]);
    if(result.rowCount > 0) {
      const user = (await client.query(queries.GET_INVITATION_DATA, [result.rows[0].id_usuario])).rows[0]
      const admin = (await client.query(queries.GET_ADMIN)).rows[0];
      sendNotification(user.cedula, admin.cedula, `${user.nombre} acepto tu invitacion para unirse al SGE.`, null, 2);
    }
    return result.rowCount > 0 ? result.rows[0].id_usuario : null;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
}; 

export const checkToken = async (id: number, token: string): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_TOKEN, [token, id]);
    return result.rowCount > 0;
  } catch(e) {
    throw e;
  } finally {
    client.release();
  }
};

const sendEmail = async (id: number, to: string, token: string) => {
  const link = `${process.env.SERVER_URL}/invite/${id}/check?token=${token}`;
  const testAccount = await createTestAccount();
  const transporter = createTransport({
    host: 'smtp.ethereal.email',
    port: 587,
    secure: false,
    auth: {
      user: testAccount.user,
      pass: testAccount.pass
    }
  });
  const info = await transporter.sendMail({
    from: '"SGE" <no-reply@sge.com>',
    to,
    subject: 'Te han invitado a ser parte del Sistema de Gestión Estratégica',
    text: 'Crea tu cuenta en el Sistema de Gestión Estratégica haciendo click en el siguiente botón.',
    html: getTemplate(link)
  });
  return info;
};