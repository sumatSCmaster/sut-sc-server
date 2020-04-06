import { Socket } from 'socket.io';
import { decode } from 'jwt-simple';
import Pool from '@utils/Pool';
import queries from '@utils/queries';

const pool = Pool.getInstance();

let io: Socket;
const users = new Map<string, Socket>();

const connection = (socket: Socket) => {
  try {
    const user = decode(socket.handshake.query.token, process.env.JWT_SECRET || 'not a secret').sub;
    users.set(user.cedula, socket);
    if (user.tipoUsuario === 3 && user.recaudos && user.recaudos.length > 0) user.recaudos.map(el => socket.join(`tram:${el}`));
    else if (user.institucion && user.tipoUsuario !== 3) socket.join(`inst:${user.institucion.id}`);

    if (user.tipoUsuario === 1) {
      pool.connect().then(r => {
        r.query(queries.GET_ALL_INSTITUTION).then(institucion => {
          institucion.rows.map(el => socket.join(`inst:${el.id}`));
        });
      });
    }

    console.log(`User connected: ${user.cedula}`);
    socket.on('disconnect', () => {
      users.delete(user.cedula);
      socket.leaveAll();
    });
  } catch (e) {
    throw e;
  }
};

export const init = (instance: Socket): Socket => {
  io = instance;
  io.on('connection', connection);
  return io;
};

export const getIo = (): Socket => {
  if (io) {
    return io;
  }
  throw new Error('Socket.io not initialized!');
};

export const getUsers = (): Map<string, Socket> => users;
