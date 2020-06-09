import app from './index';
import { Socket, Server } from 'socket.io';
import { init } from './config/socket';
//import Pool from '@utils/GticPool';

const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

// const client = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

// client.messages.create({
//     body: 'Prueba',
//     from: process.env.TWILIO_NUMBER,
//     to: '+584146053291'
// }).then(message => console.log(message));

const socket: Server = require('socket.io')(server);
init(socket);

/*
async function xd(){
    const xd = Pool.getInstance();

    const client = await xd.connect();

    const res = await client.query('SELECT * FROM tb032_tarifa_gas_residencial;');

    console.log(res.rows);

    client.release();

}

xd()

*/