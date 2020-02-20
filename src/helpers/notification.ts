import Pool from "@utils/Pool";
import queries from "../utils/queries";
import { getUsers } from "@config/socket";
import { Notificacion, Tarea } from "sge";
import twilio from "twilio";

const pool = Pool.getInstance();
const users = getUsers();

export const getNotifications = async (id: string): Promise<Notificacion[]> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_USER_NOTIFICATIONS, [id]);
    return await Promise.all(
      result.rows.map(
        async r =>
          //   formatNotification(r, r.tipo === 1 ?
          //     // formatTask((await client.query(queries.GET_TASK_BY_ID, [r.target])).rows[0], []) : null))
          r
      )
    );
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const markAllAsRead = async (id: string): Promise<boolean> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.MARK_ALL_AS_READ, [id]);
    return !!result;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const sendNotification = async (
  sender: string,
  receiver: string,
  description: string,
  target: Tarea | null,
  type: number
) => {
  const client = await pool.connect();
  try {
    const result = (
      await client.query(queries.CREATE_NOTIFICATION, [
        sender,
        receiver,
        description,
        target ? target.id : 0,
        type
      ])
    ).rows[0];
    const notif = await client.query(queries.GET_NOTIFICATION_BY_ID, [
      result.id
    ]);
    const notification = formatNotification(notif.rows[0], target);
    users
      .get(notification.receptor.cedula)
      ?.emit("SEND_NOTIFICATION", notification);
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const sendWhatsAppNotification = async (body: string) => {
  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );
  const message = await client.messages
    .create({
      to: "whatsapp:+584127645681",
      body,
      from: "whatsapp:+584127645682"
    })
    .catch(console.log);
  console.log(message);
};

const formatNotification = (n: any, target: Tarea | null): Notificacion => ({
  id: n.id,
  descripcion: n.descripcion,
  target: target,
  tipo: n.tipo === 1 ? "Tarea" : n.tipo === 2 ? "Invitacion" : "Proyecto",
  status: n.status,
  fecha: n.fecha,
  emisor: {
    cedula: n.cedula_emisor as string,
    nombre: n.nombre_emisor as string,
    correo: n.correo_emisor as string,
    telefono: n.telefono_emisor as string,
    institucion: {
      id: n.id_inst_emisor,
      descripcion: n.inst_desc_emisor as string
    },
    oficina: {
      id: n.id_oficina_emisor as number,
      descripcion: n.oficina_desc_emisor as string
    },
    cargo: n.cargo_emisor,
    indexIzq: n.index_izq_emisor as number,
    indexDer: n.index_der_emisor as number,
    username: n.username_emisor as string,
    tareasCalificadas: n.tareas_calif_emisor as number,
    rating: n.rating_emisor as number,
    urlAvatar: n.url_avatar_emisor as string
  },
  receptor: {
    cedula: n.cedula_receptor as string,
    nombre: n.nombre_receptor as string,
    correo: n.correo_receptor as string,
    telefono: n.telefono_receptor as string,
    institucion: {
      id: n.id_inst_receptor,
      descripcion: n.inst_desc_receptor as string
    },
    oficina: {
      id: n.id_oficina_receptor as number,
      descripcion: n.oficina_desc_receptor as string
    },
    cargo: n.cargo_receptor,
    indexIzq: n.index_izq_receptor as number,
    indexDer: n.index_der_receptor as number,
    username: n.username_receptor as string,
    tareasCalificadas: n.tareas_calif_receptor as number,
    rating: n.rating_receptor as number,
    urlAvatar: n.url_avatar_receptor as string
  }
});
