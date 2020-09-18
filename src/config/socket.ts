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
    console.time('decode');
    const user = decode(socket.handshake.query.token, process.env.JWT_SECRET || 'not a secret').sub;
    console.timeEnd('decode');
    console.time('if')
    if (user.tipoUsuario === 3 && user.permisos && user.permisos.length > 0) {
      user.permisos.map((el) => socket.join(`tram:${el}`));
      console.timeLog('if')
    } else if (user.institucion && user.tipoUsuario !== 3) {
      console.timeLog('if')
      console.log('else')
      socket.join(`inst:${user.institucion.nombreCorto}`);
    }
    console.timeEnd('if')
    if (user.tipoUsuario === 1) {
      pool.connect().then((r) => {
        r.query(queries.GET_ALL_INSTITUTION).then((institucion) => {
          institucion.rows.map((el) => socket.join(`inst:${el.nombre_corto}`));
        });
        r.release();
      });
    }

    users.set(`${user.nacionalidad}-${user.cedula}`, socket);
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
