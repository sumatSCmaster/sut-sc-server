import { Socket, Server } from 'socket.io';
import { decode } from 'jwt-simple';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from '@helpers/errors';

const pool = Pool.getInstance();

let io: Server;
const users = new Map<string, Socket>();

const connection = (socket: Socket) => {
  try {
    const user = decode(socket.handshake.query.token, process.env.JWT_SECRET || 'not a secret').sub;
    if (user.tipoUsuario === 3 && user.permisos && user.permisos.length > 0) {
      user.permisos.map((el) => socket.join(`tram:${el}`));
    } else if (user.institucion && user.tipoUsuario !== 3) {
      socket.join(`inst:${user.institucion.nombreCorto}`);
    }

    if (user.tipoUsuario === 1) {
      pool.connect().then((r) => {
        r.query(queries.GET_ALL_INSTITUTION).then((institucion) => {
          institucion.rows.map((el) => socket.join(`inst:${el.nombre_corto}`));
        });
        r.release();
      });
    }

    users.set(`${user.nacionalidad}-${user.cedula}`, socket);
    socket.join(`${user.nacionalidad}-${user.cedula}`);
    console.log(`User connected: ${user.nacionalidad}-${user.cedula}`);
    socket.on('disconnect', () => {
      users.delete(`${user.nacionalidad}-${user.cedula}`);
      socket.leaveAll();
    });
  } catch (e) {
    throw errorMessageExtractor(e);
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
