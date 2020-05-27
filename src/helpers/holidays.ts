import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { DiaFeriado } from '@root/interfaces/sigt';

const pool = Pool.getInstance();


export const getHolidays = async (): Promise<DiaFeriado[]> => {
    const client = await pool.connect();
    try{
        const result = (await client.query(queries.GET_HOLIDAYS)).rows as DiaFeriado[];
        return result;
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al obtener dias feriados'
        }
    } finally {
        client.release();
    }
}

export const createHolidays = async(data: DiaFeriado[]): Promise<DiaFeriado[]> => {
    const client = await pool.connect();
    try{
        const queryResult = await Promise.all(data.map((diaFeriado) => client.query(queries.CREATE_HOLIDAY, [diaFeriado.dia, diaFeriado.descripcion])));
        const result = queryResult.map((q) => q.rows[0]) as DiaFeriado[];
        console.log(result);
        return result;
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al crearr dias feriados'
        }
    } finally {
        client.release();
    }
}


export const deleteHoliday = async (id): Promise<DiaFeriado> => {
    const client = await pool.connect();
    try{
        const result = (await client.query(queries.DELETE_HOLIDAY, [id])).rows[0] as DiaFeriado;
        return result;
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al eliminar dias feriados'
        }
    } finally {
        client.release();
    }
}