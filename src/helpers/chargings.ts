import * as fs from 'fs';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import moment from 'moment';
import ExcelJs from 'exceljs';
import S3Client from '@utils/s3';
import { getUsers, getIo } from '@config/socket';
import { groupBy, take, slice } from 'lodash';

const users = getUsers();

const pool = Pool.getInstance();

const dev = process.env.NODE_ENV !== 'production';
const WALLET_AMOUNT = 20;
const WALLET_AMOUNT_AR = 5;

const extractGroupedCounts = (grouped) => {
    let res = {};
    console.log('grouped', grouped)
    for(let i in grouped){
        res[i] = +grouped[i][0].count;
    }
    return res;
}

const getRatings: (stars: number) => (AR: boolean) =>  (chargings: any[], WALLET_AMOUNT?: number, WALLET_AMOUNT_AR?: number) => [(n?: number) => [any[], number], () => number]  = (stars) => (AR) => (chargings, WALLET_AMOUNT = 20, WALLET_AMOUNT_AR = 5) => {
    let chargingsClosure = chargings.filter((el) => +el.rating === stars)
    let amount = Math.floor(chargingsClosure.length / (!AR ? WALLET_AMOUNT : WALLET_AMOUNT_AR));
    console.log(chargingsClosure.length)
    console.log(`rating ${stars} amount`, amount)
    return [(n = amount) => {
        let res = take(chargingsClosure, n);
        chargingsClosure = slice(chargingsClosure, n)
        return [res, amount]
    } , () => chargingsClosure.length]
}

export const createAllChargings = async (WALLET_AMOUNT = 20, WALLET_AMOUNT_AR = 5) => {
    await createChargings(WALLET_AMOUNT);
    return await createChargingsAR(WALLET_AMOUNT_AR);
}

export const createChargings = async (WALLET_AMOUNT) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const today = moment();
        const declMonth = today.clone().subtract(2, 'month').locale('es')
        const firstOfLastMonth = declMonth.clone().startOf('month').add(1, 'month');
        
        if((await client.query("SELECT (EXTRACT('month' FROM created) = EXTRACT('month' FROM (NOW() - interval '4 hours'))) AS chek FROM impuesto.cobranza LIMIT 1")).rows[0]?.chek){
            throw new Error('Cobranzas del mes ya creadas')
        }
        await client.query('DELETE FROM impuesto.cobranza');
        await client.query('DELETE FROM impuesto.cartera');
        console.log(declMonth.format('MMMM').toLowerCase())
        console.log(today.year())
        console.log(firstOfLastMonth.toISOString())
        const chargings = (await client.query(queries.CREATE_CHARGINGS, [declMonth.format('MMMM').toLowerCase(), declMonth.year(), firstOfLastMonth.toISOString(), WALLET_AMOUNT * 100])).rows;
        const [rating1Remover, rating1len] = getRatings(1)(false)(chargings, WALLET_AMOUNT);
        const [rating2Remover, rating2len] = getRatings(2)(false)(chargings, WALLET_AMOUNT);
        const [rating3Remover, rating3len] = getRatings(3)(false)(chargings, WALLET_AMOUNT);
        const [rating4Remover, rating4len] = getRatings(4)(false)(chargings, WALLET_AMOUNT);
        const [rating5Remover, rating5len] = getRatings(5)(false)(chargings, WALLET_AMOUNT);
        let chargingsGrouped: any = (await client.query(queries.CHARGINGS_GROUPED)).rows;
        chargingsGrouped = extractGroupedCounts(groupBy(chargingsGrouped, (el) => el.rating))
        console.log(rating1len())
        console.log(rating2len())
        console.log(rating3len())
        console.log(rating4len())
        console.log(rating5len())
        const wallets: any[] = [];
        for(let i = 0; i < WALLET_AMOUNT; i++){
            let wallet = (await client.query(queries.CREATE_WALLET, [false])).rows[0];
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
        await client.query('COMMIT');
        return { message: 'Carteras y cobranzas creadas', status: 200 }
    } catch (err) {
        console.log(err)
        throw err;
    } finally {
        client.release();
    }
}


export const createChargingsAR = async (WALLET_AMOUNT_AR) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const today = moment();
        const declMonth = today.clone().subtract(2, 'month').locale('es')
        const firstOfLastMonth = declMonth.clone().startOf('month').add(1, 'month');
        
        console.log(declMonth.format('MMMM').toLowerCase())
        console.log(today.year())
        console.log(firstOfLastMonth.toISOString())
        const chargings = (await client.query(queries.CREATE_CHARGINGS_AR, [declMonth.format('MMMM').toLowerCase(), declMonth.year(), firstOfLastMonth.toISOString(), WALLET_AMOUNT_AR * 100])).rows;
        const [rating1Remover, rating1len] = getRatings(1)(true)(chargings, undefined, WALLET_AMOUNT_AR);
        const [rating2Remover, rating2len] = getRatings(2)(true)(chargings, undefined, WALLET_AMOUNT_AR);
        const [rating3Remover, rating3len] = getRatings(3)(true)(chargings, undefined, WALLET_AMOUNT_AR);
        const [rating4Remover, rating4len] = getRatings(4)(true)(chargings, undefined, WALLET_AMOUNT_AR);
        const [rating5Remover, rating5len] = getRatings(5)(true)(chargings, undefined, WALLET_AMOUNT_AR);
        let chargingsGrouped: any = (await client.query(queries.CHARGINGS_GROUPED)).rows;
        chargingsGrouped = extractGroupedCounts(groupBy(chargingsGrouped, (el) => el.rating))
        console.log(rating1len())
        console.log(rating2len())
        console.log(rating3len())
        console.log(rating4len())
        console.log(rating5len())
        const wallets: any[] = [];
        for(let i = 0; i < WALLET_AMOUNT_AR; i++){
            let wallet = (await client.query(queries.CREATE_WALLET, [true])).rows[0];
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
        let remainingChargings = [...rating1Remover(WALLET_AMOUNT_AR)[0], ...rating2Remover(WALLET_AMOUNT_AR)[0], ...rating3Remover(WALLET_AMOUNT_AR)[0], ...rating4Remover(WALLET_AMOUNT_AR)[0], ...rating5Remover(WALLET_AMOUNT_AR)[0]];
        console.log(remainingChargings.length)
        let amountPerWallet = remainingChargings.length / WALLET_AMOUNT_AR;
        console.log('amountPerWallet', amountPerWallet)
        for(let i = 0; i < WALLET_AMOUNT_AR; i++){
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
        await client.query('COMMIT');
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
            return { status: 400, message: 'No se encontro la cobranza deseada' }
        }
        return { status: 200, cobranzas: chargings.rows, message: 'Cartera actualizada' };
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
 
export const getChargingsByWallet = async (id) => {
    try {
        const chargings = await getChargingsByWalletId(id)
        return { status: 200, cobranzas: chargings.rows, message: 'Cobranzas obtenidas' };
    } catch (err) {
        throw err;
    } finally {
    }
}

const getChargingsByWalletId = async (id) => {
    const client = await pool.connect();
    try {
        const charging = await client.query('SELECT * FROM impuesto.cartera where id_cartera = $1', [id]);
        const chargings = await client.query(charging.rows[0].es_ar ? queries.GET_CHARGINGS_BY_WALLET_AR :  queries.GET_CHARGINGS_BY_WALLET, [id]);
        return chargings
    } catch (err) {
        throw err;
    } finally {
        client.release();
    }
}


export const getChargingsByWalletExcel = async (id) => {
    return new Promise(async (res, rej) => {
        const workbook = new ExcelJs.Workbook();
        workbook.creator = 'SUT';
        workbook.created = new Date();
        workbook.views = [
          {
            x: 0,
            y: 0,
            width: 10000,
            height: 20000,
            firstSheet: 0,
            activeTab: 1,
            visibility: 'visible',
          },
        ];
  
        const sheet = workbook.addWorksheet();
        console.log('sil');
        const result = await getChargingsByWalletId(id)
        console.log('si2');
  
        //   console.log(result);
  
        sheet.columns = result.fields.map((row) => {
          return { header: row.name, key: row.name, width: 32 };
        });
        sheet.addRows(result.rows, 'i');
  
        if (dev) {
          const dir = `../../archivos/${id}.xlsx`;
          const stream = fs.createWriteStream(require('path').resolve(`./archivos/${id}.xlsx`));
          await workbook.xlsx.write(stream);
          res(dir);
        } else {
          try {
            const bucketParams = {
              Bucket: 'sut-maracaibo',
              Key: `/sedemat/reportes/carteras/${id}.xlsx`,
            };
            await S3Client.putObject({
              ...bucketParams,
              Body: await workbook.xlsx.writeBuffer(),
              ACL: 'public-read',
              ContentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            }).promise();
            res(`${process.env.AWS_ACCESS_URL}/${bucketParams.Key}`);
          } catch (e) {
            rej(e);
          } finally {
          }
        }
      });
}

export const updateOneCharging = async (user: any, { idCobranza, contactado, estatusTelefonico, observaciones, convenio, fiscalizar, estimacionPago }) => {
    const client = await pool.connect();
    console.log(`${user?.nacionalidad}-${user?.cedula}`)
    const socket = users.get(`${user?.nacionalidad}-${user?.cedula}`);
    console.log(users)
    console.log(socket)
    try {
        await client.query('BEGIN');
        const oldCharging = (await client.query('SELECT fiscalizar FROM impuesto.cobranza WHERE id_cobranza = $1', [idCobranza])).rows[0];
        const newCharging = (await client.query(queries.UPDATE_CHARGING, [idCobranza, contactado, estatusTelefonico, observaciones, convenio, fiscalizar, estimacionPago])).rows[0]
        if (!newCharging){
            throw new Error('No se hallo esa cobranza');
        }
        if(oldCharging.fiscalizar === false && newCharging.fiscalizar === true){
            const fiscalization = (await client.query('SELECT * FROM impuesto.fiscalizacion WHERE id_registro_municipal = $1', [newCharging.id_registro_municipal] ));
            if(fiscalization.rowCount === 0){
               const fisc = await client.query(queries.INSERT_FISCALIZATION, [newCharging.id_registro_municipal, 'COBRANZA']) 
               const newFisc = (await client.query(queries.GET_FISCALIZATIONS_ID, [fisc.rows[0].idFiscalizacion])).rows[0];
               socket?.broadcast.to('tabla-fiscalizacion').emit('NEW_FISCALIZATION', newFisc)
            }
        }

        
        console.log(socket?.broadcast.to('tabla-cobranza').emit('UPDATE_CHARGING', newCharging))   
        await client.query('COMMIT;')
        return { status: 200, cobranza: newCharging, message: 'Cobranza actualizada.' }
    } catch (err) {
        await client.query('ROLLBACK;')
        throw err;
    } finally {
        client.release();
    }
}