import app from './index';
import { Socket, Server } from 'socket.io';
import { init } from './config/socket';

const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

const socket: Server = require('socket.io')(server);
init(socket);
