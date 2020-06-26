import { resolve } from 'path';


import Pool from '@utils/Pool';
import queries from '@utils/queries';
import * as pdf from 'html-pdf';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getActivities = async () => {
    const client = await pool.connect();
    try{
        const activities = (await client.query(queries.GET_ALL_ACTIVITIES)).rows;
        return activities;
    } catch (e) {
        throw e;
    } finally {
        client.release();
    }
}