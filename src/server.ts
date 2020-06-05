import app from './index';
import { Socket, Server } from 'socket.io';
import { init } from './config/socket';
//import Pool from '@utils/GticPool';

const server = app.listen(process.env.PORT || 5000, () => console.log(`Listening on port ${process.env.PORT || 5000}`));

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