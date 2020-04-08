import Pool from '@utils/Pool';
import queries from '../utils/queries';
import { getUsers } from '@config/socket';
import twilio from 'twilio';
import { Notificacion, Tramite } from '@root/interfaces/sigt';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';

const pool = Pool.getInstance();
const users = getUsers();

export const getNotifications = async (id: string): Promise<Notificacion[] | any> => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_NOTIFICATIONS_FOR_USER, [id])).rows;
    const notificaciones = await Promise.all(
      response.map(async (el) => {
        // const ordinances = (await client.query(queries.ORDINANCES_PROCEDURE_INSTANCES, [el.idTramite])).rows;
        const tramite: Partial<Tramite> = {
          id: el.idTramite,
          tipoTramite: el.tipoTramite,
          codigoTramite: el.codigoTramite,
          costo: el.costo,
          nombreCorto: el.nombreCorto,
          nombreLargo: el.nombreLargo,
          nombreTramiteCorto: el.nombreTramiteCorto,
          nombreTramiteLargo: el.nombreTramiteLargo,
          datos: el.datos,
          fechaCreacion: el.fechaCreacionTramite,
          usuario: el.usuario,
          planilla: el.planilla,
          certificado: el.certificado,
          estado: el.estadoNotificacion,
          aprobado: el.aprobado,
        };
        const notificacion = {
          id: el.id,
          status: el.status,
          fechaCreacion: el.fechaCreacion,
        };
        return formatNotification(el.emisor, el.receptor, el.descripcion, tramite, notificacion);
      })
    );
    return { status: 200, message: 'Notificaciones retornadas de manera satisfactoria', notificaciones };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

export const markAllAsRead = async (id: string): Promise<object> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.MARK_ALL_AS_READ, [id]);
    return { status: 201, message: 'Todas las notificaciones han sido leidas', result: !!result };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al marcar como leidas las notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

//TODO: validar el estado para ver a quien le van a llegar las notificaciones.
//      Ademas, verificar por que no estan llegando todas las notificaciones
export const sendNotification = async (sender: string, description: string, type: string, payload: Partial<Tramite>) => {
  const client = await pool.connect();
  try {
    type === 'CREATE' ? broadcastByExternalUser(sender, description, payload, client) : broadcastByOfficial(sender, description, payload, client);
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

const broadcastByExternalUser = async (sender: string, description: string, payload: Partial<Tramite>, client: PoolClient) => {
  const socket = users.get(sender);
  try {
    client.query('BEGIN');
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;

    const notification = await Promise.all(
      superuser.map(async (el) => {
        const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0];
        const notification = (await client.query(queries.GET_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
        const formattedNotif = formatNotification(sender, notification.receptor, description, payload, notification);
        return formattedNotif;
      })
    );

    await Promise.all(
      admins.map(async (el) => (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0])
    );

    await Promise.all(
      permittedOfficials.map(
        async (el) => (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0]
      )
    );

    socket?.in(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.in(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.in(`tram:${payload.tipoTramite}`).emit('CREATE_PROCEDURE', payload);
    socket?.in(`inst:${payload.nombreCorto}`).emit('CREATE_PROCEDURE', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw error;
  }
};

const broadcastByOfficial = async (sender: string, description: string, payload: Partial<Tramite>, client: PoolClient) => {
  const socket = users.get(sender);
  try {
    client.query('BEGIN');
    const user = (await client.query(queries.GET_PROCEDURE_CREATOR, [payload.usuario])).rows;
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;

    const notification = await Promise.all(
      user.map(async (el) => {
        const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0];
        const notification = (await client.query(queries.GET_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
        const formattedNotif = formatNotification(sender, notification.receptor, description, payload, notification);
        users.get(el.cedula)?.emit('SEND_NOTIFICATION', formattedNotif);
        users.get(el.cedula)?.emit('UPDATE_PROCEDURE', payload);
        return formattedNotif;
      })
    );

    await Promise.all(
      superuser.map(async (el) => (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0])
    );

    await Promise.all(
      admins.map(async (el) => (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0])
    );

    await Promise.all(
      permittedOfficials.map(
        async (el) => (await client.query(queries.CREATE_NOTIFICATION, [payload.id, sender, el.cedula, description, payload.estado])).rows[0]
      )
    );

    socket?.in(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.in(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.in(`tram:${payload.tipoTramite}`).emit('UPDATE_PROCEDURE', payload);
    socket?.in(`inst:${payload.nombreCorto}`).emit('UPDATE_PROCEDURE', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw error;
  }
};

const formatNotification = (sender: string, receiver: string | null, description: string, payload: Partial<Tramite>, notification: any): Notificacion => {
  return {
    id: notification.id,
    emisor: sender,
    receptor: receiver,
    tramite: payload,
    descripcion: description,
    status: notification.status,
    fechaCreacion: notification.fechaCreacion,
  };
};

// export const sendWhatsAppNotification = async (body: string) => {
//   const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
//   const message = await client.messages
//     .create({
//       to: 'whatsapp:+584127645681',
//       body,
//       from: 'whatsapp:+584127645682',
//     })
//     .catch(console.log);
//   console.log(message);
// };

// const formatNotification = (n: any, target: Tarea | null): Notificacion => ({
//   id: n.id,
//   descripcion: n.descripcion,
//   target: target,
//   tipo: n.tipo === 1 ? 'Tarea' : n.tipo === 2 ? 'Invitacion' : 'Proyecto',
//   status: n.status,
//   fecha: n.fecha,
//   emisor: {
//     cedula: n.cedula_emisor as string,
//     nombre: n.nombre_emisor as string,
//     correo: n.correo_emisor as string,
//     telefono: n.telefono_emisor as string,
//     institucion: {
//       id: n.id_inst_emisor,
//       descripcion: n.inst_desc_emisor as string,
//     },
//     oficina: {
//       id: n.id_oficina_emisor as number,
//       descripcion: n.oficina_desc_emisor as string,
//     },
//     cargo: n.cargo_emisor,
//     indexIzq: n.index_izq_emisor as number,
//     indexDer: n.index_der_emisor as number,
//     username: n.username_emisor as string,
//     tareasCalificadas: n.tareas_calif_emisor as number,
//     rating: n.rating_emisor as number,
//     urlAvatar: n.url_avatar_emisor as string,
//   },
//   receptor: {
//     cedula: n.cedula_receptor as string,
//     nombre: n.nombre_receptor as string,
//     correo: n.correo_receptor as string,
//     telefono: n.telefono_receptor as string,
//     institucion: {
//       id: n.id_inst_receptor,
//       descripcion: n.inst_desc_receptor as string,
//     },
//     oficina: {
//       id: n.id_oficina_receptor as number,
//       descripcion: n.oficina_desc_receptor as string,
//     },
//     cargo: n.cargo_receptor,
//     indexIzq: n.index_izq_receptor as number,
//     indexDer: n.index_der_receptor as number,
//     username: n.username_receptor as string,
//     tareasCalificadas: n.tareas_calif_receptor as number,
//     rating: n.rating_receptor as number,
//     urlAvatar: n.url_avatar_receptor as string,
//   },
// });
