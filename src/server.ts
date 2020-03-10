import app from './index';
import { Socket } from 'socket.io';
import { init } from './config/socket';
import { createForm } from './helpers/formsHelper'

const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

const socket: Socket = require('socket.io')(server);
init(socket);

async function x(){
    console.log(await createForm({fecha: Date.now(), codigo: 'codigo', formato: 'otamrof', tramite: 'tarmite', institucion: 'SAGAS', datos: {}}))
}
// x()