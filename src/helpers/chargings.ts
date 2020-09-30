import Pool from '@utils/Pool';
import queries from '@utils/queries';
import moment from 'moment';

import { getUsers, getIo } from '@config/socket';
import { groupBy, take, slice } from 'lodash';

const users = getUsers();

const pool = Pool.getInstance();

const WALLET_AMOUNT = 20;

const extractGroupedCounts = (grouped) => {
    let res = {};
    console.log('grouped', grouped)
    for(let i in grouped){
        res[i] = +grouped[i][0].count;
    }
    return res;
}

const getRatings: (stars: number) => (chargings: any[]) => [(n?: number) => [any[], number], () => number]  = (stars) => (chargings) => {
    let chargingsClosure = chargings.filter((el) => +el.rating === stars)
    let amount = Math.floor(chargingsClosure.length / WALLET_AMOUNT);
    console.log(chargingsClosure.length)
    console.log(`rating ${stars} amount`, amount)
    return [(n = amount) => {
        let res = take(chargingsClosure, n);
        chargingsClosure = slice(chargingsClosure, n)
        return [res, amount]
    } , () => chargingsClosure.length]
}

export const createChargings = async () => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        /* descomentar mañana
        const today = moment();
        const lastMonth = today.clone().subtract(2, 'month').locale('es')
        const firstOfLastMonth = lastMonth.clone().startOf('month').add(1, 'month');
        */
        const today = moment();
        const declMonth = today.clone().subtract(1, 'month').locale('es')
        const firstOfLastMonth = declMonth.clone().startOf('month').add(1, 'month');
        console.log(declMonth.format('MMMM').toLowerCase())
        console.log(today.year())
        console.log(firstOfLastMonth.toISOString())
        const chargings = (await client.query(queries.CREATE_CHARGINGS, [declMonth.format('MMMM').toLowerCase(), declMonth.year(), firstOfLastMonth.toISOString()])).rows;
        const [rating1Remover, rating1len] = getRatings(1)(chargings);
        const [rating2Remover, rating2len] = getRatings(2)(chargings);
        const [rating3Remover, rating3len] = getRatings(3)(chargings);
        const [rating4Remover, rating4len] = getRatings(4)(chargings);
        const [rating5Remover, rating5len] = getRatings(5)(chargings);
        let chargingsGrouped: any = (await client.query(queries.CHARGINGS_GROUPED)).rows;
        chargingsGrouped = extractGroupedCounts(groupBy(chargingsGrouped, (el) => el.rating))
        console.log(rating1len())
        console.log(rating2len())
        console.log(rating3len())
        console.log(rating4len())
        console.log(rating5len())
        const wallets: any[] = [];
        for(let i = 0; i < WALLET_AMOUNT; i++){
            let wallet = (await client.query(queries.CREATE_WALLET)).rows[0];
            let allWalletChargings = [...rating1Remover()[0], ...rating2Remover()[0], ...rating3Remover()[0], ...rating4Remover()[0], ...rating5Remover()[0]];
            console.log('allwalletchargings', allWalletChargings.length)
            await Promise.all(allWalletChargings.map(async (charging) => client.query(queries.SET_WALLET, [wallet.id_cartera, charging.id_cobranza]) ))
            
            wallets.push(wallet)
        }
        console.log(rating1len())
        console.log(rating2len())
        console.log(rating3len())
        console.log(rating4len())
        console.log(rating5len())
        console.log('b')
        let remainingChargings = [...rating1Remover(WALLET_AMOUNT)[0], ...rating2Remover(WALLET_AMOUNT)[0], ...rating3Remover(WALLET_AMOUNT)[0], ...rating4Remover(WALLET_AMOUNT)[0], ...rating5Remover(WALLET_AMOUNT)[0]];
        console.log(remainingChargings.length)
        let amountPerWallet = remainingChargings.length / WALLET_AMOUNT;
        console.log('amountPerWallet', amountPerWallet)
        for(let i = 0; i < WALLET_AMOUNT; i++){
            let res = take(remainingChargings, amountPerWallet);
            console.log('res', res.length)
            remainingChargings = slice(remainingChargings, amountPerWallet)
            await Promise.all(res.map(async (charging) => client.query(queries.SET_WALLET, [wallets[i].id_cartera, charging.id_cobranza]) ))
        }
        console.log('a')
        console.log(rating1len())
        console.log(rating2len())
        console.log(rating3len())
        console.log(rating4len())
        console.log(rating5len())
        await client.query('ROLLBACK');
        return { message: 'Carteras y cobranzas creadas', status: 200 }
    } catch (err) {
        console.log(err)
        throw err;
    } finally {
        client.release();
    }
}


export const getAllWallets = async () => {
    const client = await pool.connect();
    try {
        const chargings = await client.query(queries.GET_WALLETS);
        return { status: 200, cobranzas: chargings.rows, message: 'Carteras obtenidas' };
    } catch (err) {
        throw err;
    } finally {
        client.release();
    }
}

export const linkWallet = async (id, idUser) => {
    const client = await pool.connect();
    try {
        const chargings = await client.query(queries.LINK_WALLET_TO_USER, [id, idUser]);
        if(chargings.rowCount === 0){
            return { status: 400, message: 'No se encontro la cobranza deseada ' }
        }
        return { status: 200, cobranzas: chargings.rows, message: 'Carteras obtenidas' };
    } catch (err) {
        throw err;
    } finally {
        client.release();
    }
}

export const getAllChargings = async () => {
    const client = await pool.connect();
    try {
        const chargings = await client.query(queries.GET_CHARGINGS);
        return { status: 200, cobranzas: chargings.rows, message: 'Cobranzas obtenidas' };
    } catch (err) {
        throw err;
    } finally {
        client.release();
    }
}

export const updateOneCharging = async ({ nacionalidad, cedula }: any, { idCobranza, contactado, estatus_telefonico, observaciones, convenio, fiscalizar, estimacion_de_pago }) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const newCharging = (await client.query(queries.UPDATE_CHARGING, [idCobranza, contactado, estatus_telefonico, observaciones, convenio, fiscalizar, estimacion_de_pago])).rows[0]
        if (!newCharging){
            throw new Error('No se hallo esa cobranza');
        }
        const socket = users.get(`${nacionalidad}-${cedula}`);
        socket?.to('tabla-cobranza').emit('ACTUALIZAR_TABLA_COBRANZA', newCharging)        
        await client.query('COMMIT;')
    } catch (err) {
        await client.query('ROLLBACK;')
        throw err;
    } finally {
        client.release();
    }
}