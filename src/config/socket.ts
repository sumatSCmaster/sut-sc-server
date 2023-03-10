import { Socket, Server } from 'socket.io';
import { decode } from 'jwt-simple';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from '@helpers/errors';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

let io: Server;
const users = new Map<string, Socket>();

const connection = async (socket: Socket) => {
  const client = await pool.connect();
  try {
    const user = decode(socket.handshake.query.token, process.env.JWT_SECRET || 'not a secret').sub;
    if (user.tipoUsuario === 3 && user.permisos && user.permisos.length > 0) {
      user.permisos.map((el) => socket.join(`tram:${el}`));
    } else if (user.institucion && user.tipoUsuario !== 3) {
      socket.join(`inst:${user.institucion.nombreCorto}`);
    }

    if (user.tipoUsuario === 1) {
      const insts = (await client.query(queries.GET_ALL_INSTITUTION)).rows;
      insts.map((el) => socket.join(`inst:${el.nombre_corto}`));
    }
    if ([33, 26].includes(user.institucion?.cargo?.id)) {
      socket.join('tabla-cobranza');
    }

    if ([39, 24].includes(user.institucion?.cargo?.id)) {
      socket.join('tabla-fiscalizacion');
    }

    users.set(`${user.nacionalidad}-${user.cedula}`, socket);

    socket.join(`${user.nacionalidad}-${user.cedula}`);
    mainLogger.info(`User connected: ${user.nacionalidad}-${user.cedula}`);
    socket.on('disconnect', () => {
      users.delete(`${user.nacionalidad}-${user.cedula}`);
      socket.leaveAll();
    });
  } catch (e) {
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const init = (instance: Server): Server => {
  io = instance;
  io.on('connection', connection);
  return io;
};

export const getIo = (): Server => {
  if (io) {
    return io;
  }
  throw new Error('Socket.io not initialized!');
};

export const getUsers = (): Map<string, Socket> => users;
