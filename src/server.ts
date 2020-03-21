import app from './index';
import { Socket } from 'socket.io';
import { init } from './config/socket';

const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

const socket: Socket = require('socket.io')(server);
init(socket);
