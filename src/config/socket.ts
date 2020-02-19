import { Socket } from 'socket.io';
import { decode } from 'jwt-simple';

let io: Socket;
const users = new Map<string, Socket>();

const connection = (socket: Socket) => {
  try {
    const user = decode(socket.handshake.query.token, process.env.JWT_SECRET || 'not a secret').sub;
    users.set(user.id, socket);
    console.log(`User connected: ${user.id}`);
    socket.on('disconnect', () => {
      users.delete(user.id);
    })
  } catch(e) {
    throw e;
  }
};

export const init = (instance: Socket): Socket => {
  io = instance;
  io.on('connection', connection);
  return io;
};

export const getIo = (): Socket => {
  if(io) {
    return io;
  }
  throw new Error('Socket.io not initialized!');
};

export const getUsers = (): Map<string, Socket> => users;