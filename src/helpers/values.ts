import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const updateUtmmValue = async (value) => {
    const client = await pool.connect();
    try{
        await client.query('BEGIN');
        const result = (await client.query(queries.UPDATE_UTMM_VALUE, [value])).rows[0];
        await client.query('COMMIT');
        return {
            status: 200,
            message: 'Se ha actualizado el valor de la UTMM',
            utmm: result.valor_en_bs
        }
    } catch (e) {
        client.query('ROLLBACK');
        console.log(e)
        throw {
            status: 500,
            error: errorMessageGenerator(e) || 'Error en actualizacion del valor de la UTMM'
        }
    } finally {
        client.release();
    }
}

export const getUtmmValue = async () => {
    const client = await pool.connect();
    try{
        const result = (await client.query(queries.GET_UTMM_VALUE)).rows[0];
        return {
            status: 200,
            message: 'Se ha obtenido el valor de la UTMM',
            utmm: result.valor_en_bs
        }
    } catch (e) {
        console.log(e)
        throw {
            status: 500,
            error: errorMessageGenerator(e) || 'Error en obtencion del valor de la UTMM'
        }
    } finally {
        client.release();
    }
}