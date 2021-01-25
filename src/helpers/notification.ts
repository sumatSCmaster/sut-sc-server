import Pool from '@utils/Pool';
import queries from '../utils/queries';
import { getUsers, getIo } from '@config/socket';
import twilio from 'twilio';
import { Notificacion, Tramite, Multa, Usuario, Solicitud } from '@root/interfaces/sigt';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import switchcase from '@utils/switch';
import { getApplicationsAndSettlementsById, getApplicationsAndSettlementsByIdNots } from './settlement';

const pool = Pool.getInstance();
const users = getUsers();

/**
 *
 * @param id
 * @param blocked
 * @param emitter
 * @param client
 */
export const blockUserEvent = async (id: number, blocked: boolean, emitter: Usuario, client: PoolClient) => {
  try {
    const usuario = (await client.query('SELECT * FROM usuario WHERE id_usuario = $1', [id])).rows[0];
    const socket = `${usuario.nacionalidad}-${usuario.cedula}`;
    const emitSocket = `${emitter.nacionalidad}-${emitter.cedula}`;
    if (blocked) {
      users.get(socket)?.emit('BLOCKED_USER', { id });
      users.get(emitSocket)?.to(socket).emit('BLOCKED_USER', { id });
    }
    return true;
  } catch (e) {
    throw {
      error: errorMessageExtractor(e),
      status: 500,
      message: errorMessageGenerator(e) || 'Error al emitir evento de bloqueo',
    };
  }
};

/**
 *
 * @param user
 */
export const getNotifications = async (user: Usuario): Promise<Notificacion[] | any> => {
  const client = await pool.connect();
  try {
    const id = `${user.nacionalidad}-${user.cedula}`;
    const respTramites = (await client.query(queries.GET_PROCEDURE_NOTIFICATIONS_FOR_USER, [id])).rows;
    const respMultas = (await client.query(queries.GET_FINING_NOTIFICATIONS_FOR_USER, [id])).rows;
    const respImpuesto = (await client.query(queries.GET_SETTLEMENT_NOTIFICATIONS_FOR_USER, [id])).rows;
    const tramites = await Promise.all(
      respTramites.map(async (el) => {
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
          concepto: el.concepto,
        };
        return formatNotification(el.emisor, el.receptor, el.descripcion, tramite, notificacion);
      })
    );

    const multas = await Promise.all(
      respMultas.map(async (el) => {
        const multa: Partial<Multa> = {
          id: el.idMulta,
          tipoTramite: el.tipoTramite,
          codigoMulta: el.codigoMulta,
          costo: el.costo,
          nombreCorto: el.nombreCorto,
          nombreLargo: el.nombreLargo,
          nombreTramiteCorto: el.nombreTramiteCorto,
          nombreTramiteLargo: el.nombreTramiteLargo,
          datos: el.datos,
          fechaCreacion: el.fechaCreacionTramite,
          usuario: el.usuario,
          boleta: el.boleta,
          certificado: el.certificado,
          estado: el.estadoNotificacion,
          aprobado: el.aprobado,
        };
        const notificacion = {
          id: el.id,
          status: el.status,
          fechaCreacion: el.fechaCreacion,
          concepto: el.concepto,
        };
        return formatNotification(el.emisor, el.receptor, el.descripcion, multa, notificacion);
      })
    );
    const impuestos = await Promise.all(
      respImpuesto.map(async (el) => {
        const impuesto: Solicitud = await getApplicationsAndSettlementsByIdNots({ id: el.idSolicitud, user }, client);
        const solicitud: Solicitud & { estado: string; nombreCorto: string } = {
          ...impuesto,
          estado: el.estadoNotificacion,
          nombreCorto: 'SEDEMAT',
        };
        const notificacion = {
          id: el.id,
          status: el.status,
          fechaCreacion: el.fechaCreacion,
          concepto: el.concepto,
        };
        return formatNotification(el.emisor, el.receptor, el.descripcion, solicitud, notificacion);
      })
    );
    const notificaciones = [...tramites, ...multas, ...impuestos].sort((a, b) => (a.fechaCreacion === b.fechaCreacion ? 0 : a.fechaCreacion > b.fechaCreacion ? -1 : 1));
    return { status: 200, message: 'Notificaciones retornadas de manera satisfactoria', notificaciones };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param user
 */
export const markAllAsRead = async (user: Usuario): Promise<object> => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.MARK_ALL_AS_READ, [`${user.nacionalidad}-${user.cedula}`]);
    return { status: 201, message: 'Todas las notificaciones han sido leidas', result: !!result };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al marcar como leidas las notificaciones del usuario',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param sender
 * @param description
 * @param type
 * @param concept
 * @param payload
 * @param client
 * @param isValidating
 */
export const sendNotification = async (sender: Usuario, description: string, type: string, concept: string, payload: Partial<Tramite | Multa>, client: PoolClient, isValidating: boolean = false) => {
  try {
    notificationHandler(sender, description, type, payload, concept, client, isValidating);
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForProcedureInit = async (sender: Usuario, description: string, payload: Partial<Tramite>, concept: string, client: PoolClient, isValidating: boolean) => {
  const socket = users.get(`${sender.nacionalidad}-${sender.cedula}`);
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = (payload.estado === 'enproceso' ? superuser.concat(admins).concat(permittedOfficials) : superuser.concat(admins)).filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`);

    const notification = await Promise.all(
      officials
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_PROCEDURE_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    if (payload.estado === 'enproceso') {
      socket?.to(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
      socket?.to(`tram:${payload.tipoTramite}`).emit('CREATE_PROCEDURE', payload);
    }

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.to(`inst:${payload.nombreCorto}`).emit('CREATE_PROCEDURE', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForProcedureUpdate = async (sender: Usuario, description: string, payload: Partial<Tramite>, concept: string, client: PoolClient, isValidating: boolean) => {
  const io = getIo();
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;
  const socket = users.get(emisor);

  try {
    !isValidating && (await client.query('BEGIN'));
    const user = (await client.query(queries.GET_PROCEDURE_CREATOR, [payload.usuario])).rows;
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = payload.estado === 'enproceso' ? superuser.concat(admins).concat(permittedOfficials) : superuser.concat(admins);

    if (payload.estado !== 'ingresardatos') {
      await Promise.all(
        user
          .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
          .map(async (el) => {
            if (!el) return null;
            const userDesc = description.replace('un', 'su');
            const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, userDesc, payload.estado, concept])).rows[0];
            const notification = (await client.query(queries.GET_PROCEDURE_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
            const formattedNotif = formatNotification(emisor, notification.receptor, userDesc, payload, notification);
            const userSocket = users.get(`${el.nacionalidad}-${el.cedula}`);
            userSocket?.emit('SEND_NOTIFICATION', formattedNotif);
            userSocket?.emit('UPDATE_PROCEDURE', payload);
            return formattedNotif;
          })
      );
    }

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_PROCEDURE_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    if (payload.estado === 'enproceso') {
      socket?.to(`tram:${payload.tipoTramite}`).emit('UPDATE_PROCEDURE', payload);
      socket?.to(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
    }

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    io?.in(`inst:${payload.nombreCorto}`).emit('UPDATE_PROCEDURE', payload);

    !isValidating && (await client.query('COMMIT'));
  } catch (error) {
    !isValidating && client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForAffairInit = async (sender: Usuario, description: string, payload: Partial<Tramite>, concept: string, client: PoolClient, isValidating: boolean) => {
  const io = getIo();
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = superuser.concat(admins).concat(permittedOfficials);

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_PROCEDURE_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    io.in(`tram:${payload.tipoTramite}`).emit('CREATE_PROCEDURE', payload);
    io.in(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);

    io.in(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    io.in(`inst:${payload.nombreCorto}`).emit('CREATE_PROCEDURE', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

//DONE
/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForAffairUpdate = async (sender: Usuario, description: string, payload: Partial<Tramite>, concept: string, client: PoolClient, isValidating: boolean) => {
  const io = getIo();
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = superuser.concat(admins).concat(permittedOfficials);

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_PROCEDURE_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    io.in(`tram:${payload.tipoTramite}`).emit('UPDATE_PROCEDURE', payload);
    io.in(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);

    io.in(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    io.in(`inst:${payload.nombreCorto}`).emit('UPDATE_PROCEDURE', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

//DONE
/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForFiningInit = async (sender: Usuario, description: string, payload: Partial<Multa>, concept: string, client: PoolClient, isValidating: boolean) => {
  const socket = users.get(`${sender.nacionalidad}-${sender.cedula}`);
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;
  try {
    client.query('BEGIN');
    const user = [{ nacionalidad: payload.nacionalidad, cedula: payload.cedula }];
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = payload.estado !== 'validando' ? superuser.concat(admins).concat(permittedOfficials) : superuser.concat(admins);

    await Promise.all(
      user.map(async (el) => {
        const userDesc = `Se le ha asignado una multa por parte de ${payload.nombreLargo}`;
        const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, userDesc, payload.estado, concept])).rows[0];
        const notification = (await client.query(queries.GET_FINING_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
        const formattedNotif = formatNotification(emisor, notification.receptor, userDesc, payload, notification);
        const userSocket = users.get(`${el.nacionalidad}-${el.cedula}`);
        userSocket?.emit('SEND_NOTIFICATION', formattedNotif);
        userSocket?.emit('CREATE_FINING', payload);
        return formattedNotif;
      })
    );

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_FINING_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    if (payload.estado !== 'validando') {
      socket?.to(`tram:${payload.tipoTramite}`).emit('CREATE_FINING', payload);
      socket?.to(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
    }

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.to(`inst:${payload.nombreCorto}`).emit('CREATE_FINING', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

//DONE
/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForFiningUpdate = async (sender: Usuario, description: string, payload: Partial<Multa>, concept: string, client: PoolClient, isValidating: boolean) => {
  const socket = users.get(`${sender.nacionalidad}-${sender.cedula}`);
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const user = (await client.query(queries.GET_FINING_TARGET, [payload.id])).rows;
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    const permittedOfficials = (await client.query(queries.GET_OFFICIALS_FOR_PROCEDURE, [payload.nombreCorto, payload.tipoTramite])).rows;
    const officials = payload.estado !== 'validando' ? superuser.concat(admins).concat(permittedOfficials) : superuser.concat(admins);

    if (payload.estado !== 'ingresardatos' && emisor !== `${user[0].nacionalidad}-${user[0].cedula}`) {
      await Promise.all(
        user.map(async (el) => {
          const userDesc = `${description} por la institucion ${payload.nombreLargo}`;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, userDesc, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_FINING_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, userDesc, payload, notification);
          const userSocket = users.get(`${el.nacionalidad}-${el.cedula}`);
          userSocket?.emit('SEND_NOTIFICATION', formattedNotif);
          userSocket?.emit('UPDATE_FINING', payload);
          return formattedNotif;
        })
      );
    }

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_FINING_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    if (payload.estado !== 'validando') {
      socket?.to(`tram:${payload.tipoTramite}`).emit('UPDATE_FINING', payload);
      socket?.to(`tram:${payload.tipoTramite}`).emit('SEND_NOTIFICATION', notification[0]);
    }

    if (payload.estado === 'finalizado') {
      socket?.emit('SEND_NOTIFICATION', notification[0]);
      socket?.emit('UPDATE_FINING', payload);
    }

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.to(`inst:${payload.nombreCorto}`).emit('UPDATE_FINING', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

//FIXME: esto se va a descontrolaaaaarrrrrrr, el que se quedo pegao se quedo pegao
/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForApplicationInit = async (sender: Usuario, description: string, payload: Partial<Solicitud & { nombreCorto: string; estado: string }>, concept: string, client: PoolClient, isValidating: boolean) => {
  const socket = users.get(`${sender.nacionalidad}-${sender.cedula}`);
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    // const permittedOfficials = (
    //   await client.query(
    //     'SELECT * FROM USUARIO usr INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario INNER JOIN institucion i ON cf.id_institucion = i.id_institucion WHERE usr.id_tipo_usuario = 3 AND i.id_institucion = 9;'
    //   )
    // ).rows;
    const officials = superuser.concat(admins).filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`);

    const notification = await Promise.all(
      officials
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_SETTLEMENT_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.to(`inst:${payload.nombreCorto}`).emit('CREATE_APPLICATION', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

/**
 *
 * @param sender
 * @param description
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const broadcastForApplicationUpdate = async (sender: Usuario, description: string, payload: Partial<Solicitud & { nombreCorto: string; estado: string }>, concept: string, client: PoolClient, isValidating: boolean) => {
  const socket = users.get(`${sender.nacionalidad}-${sender.cedula}`);
  const emisor = `${sender.nacionalidad}-${sender.cedula}`;

  try {
    client.query('BEGIN');
    const user = (await client.query(queries.GET_APPLICATION_CREATOR, [payload.usuario?.id])).rows;
    const admins = (await client.query(queries.GET_NON_NORMAL_OFFICIALS, [payload.nombreCorto])).rows;
    const superuser = (await client.query(queries.GET_SUPER_USER)).rows;
    // const permittedOfficials = (
    //   await client.query(
    //     'SELECT * FROM USUARIO usr INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario INNER JOIN institucion i ON cf.id_institucion = i.id_institucion WHERE usr.id_tipo_usuario = 3 AND i.id_institucion = 9;'
    //   )
    // ).rows;
    const officials = superuser.concat(admins);

    if (payload.estado === 'finalizado' && emisor !== `${user[0].nacionalidad}-${user[0].cedula}`) {
      await Promise.all(
        user.map(async (el) => {
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_SETTLEMENT_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          const userSocket = users.get(`${el.nacionalidad}-${el.cedula}`);
          userSocket?.emit('SEND_NOTIFICATION', formattedNotif);
          userSocket?.emit('UPDATE_APPLICATION', payload);
          return formattedNotif;
        })
      );
    }

    const notification = await Promise.all(
      officials
        .filter((el) => emisor !== `${el.nacionalidad}-${el.cedula}`)
        .map(async (el) => {
          if (!el) return null;
          const result = (await client.query(queries.CREATE_NOTIFICATION, [payload.id, emisor, `${el.nacionalidad}-${el.cedula}`, description, payload.estado, concept])).rows[0];
          const notification = (await client.query(queries.GET_SETTLEMENT_NOTIFICATION_BY_ID, [result.id_notificacion])).rows[0];
          const formattedNotif = formatNotification(emisor, notification.receptor, description, payload, notification);
          return formattedNotif;
        })
        .filter((el) => el)
    );

    if (payload.estado === 'finalizado') {
      socket?.emit('SEND_NOTIFICATION', notification[0]);
      socket?.emit('UPDATE_APPLICATION', payload);
    }

    socket?.to(`inst:${payload.nombreCorto}`).emit('SEND_NOTIFICATION', notification[0]);
    socket?.to(`inst:${payload.nombreCorto}`).emit('UPDATE_APPLICATION', payload);

    client.query('COMMIT');
  } catch (error) {
    client.query('ROLLBACK');
    throw errorMessageExtractor(error);
  }
};

/**
 *
 * @param sender
 * @param receiver
 * @param description
 * @param payload
 * @param notification
 */
const formatNotification = (sender: string, receiver: string | null, description: string, payload: Partial<Tramite | Multa | (Solicitud & { estado: string; nombreCorto: string })>, notification: any): Notificacion => {
  return {
    id: notification.id,
    emisor: sender,
    receptor: receiver,
    tramite: payload,
    descripcion: description,
    status: notification.status,
    fechaCreacion: notification.fechaCreacion,
    concepto: notification.concepto,
  };
};

/**
 *
 */
const notificationTypes = switchcase({
  CREATE_PROCEDURE: broadcastForProcedureInit,
  UPDATE_PROCEDURE: broadcastForProcedureUpdate,
  CREATE_SOCIAL_AFFAIR: broadcastForAffairInit,
  UPDATE_SOCIAL_AFFAIR: broadcastForAffairUpdate,
  CREATE_FINING: broadcastForFiningInit,
  UPDATE_FINING: broadcastForFiningUpdate,
  CREATE_APPLICATION: broadcastForApplicationInit,
  UPDATE_APPLICATION: broadcastForApplicationUpdate,
})(null);

/**
 *
 * @param sender
 * @param description
 * @param type
 * @param payload
 * @param concept
 * @param client
 * @param isValidating
 */
const notificationHandler = async (sender: Usuario, description: string, type: string, payload: Partial<Tramite | Multa>, concept: string, client: PoolClient, isValidating: boolean) => {
  const notificationSender = notificationTypes(type);
  try {
    if (notificationSender) return await notificationSender(sender, description, payload, concept, client, isValidating);
  } catch (error) {
    throw errorMessageExtractor(error);
  }
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
