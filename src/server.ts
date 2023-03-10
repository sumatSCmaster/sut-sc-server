import './tracer';
import app from './index';
import { Server } from 'socket.io';
import { init } from './config/socket';
import { createServer } from 'http';
import { mainLogger } from '@utils/logger';

const trueServer = createServer(app);

// const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

// const client = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

// client.messages.create({
//     body: 'Prueba',
//     from: process.env.TWILIO_NUMBER,
//     to: '+584146053291'
// }).then(message => console.log(message));

const socket: Server = require('socket.io')(trueServer);
trueServer.listen(process.env.PORT || 5000, () => mainLogger.info(`Listening on port ${process.env.PORT || 5000}`));
init(socket);

/* async function xd() {
  await createChargings()
}

xd(); */
// const dev = process.env.NODE_ENV !== 'production';
// if (dev) {
//   executeReport();
// }
