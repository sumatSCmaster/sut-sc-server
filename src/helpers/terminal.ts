import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const getDestinations = async () => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.TERMINAL_DESTINATIONS);
        return {
            status: 200,
            destinos: res.rows
        }
    } catch(e) {
        throw {
            status: 500,
            error: errorMessageExtractor(e),
            message: errorMessageGenerator(e) || 'Error al obtener destinos'
        }
    } finally {
        client.release();
    }
}

export const createDestination = async (dest) => {
    const client = await pool.connect();
    const { destino, tipo, monto, tasa } = dest
    try{
        const res = await client.query(queries.CREATE_TERMINAL_DESTINATION, [destino, tipo, monto, tasa]);
        return {
            status: 200,
            destino: res.rows[0]
        }
    } catch(e) {
        throw {
            status: 500,
            error: errorMessageExtractor(e),
            message: errorMessageGenerator(e) || 'Error al crear destino'
        }
    } finally {
        client.release();
    }
}

export const updateDestination = async (dest) => {
    const client = await pool.connect();
    const { destino, tipo, monto, tasa, id, habilitado } = dest
    try{
        const res = await client.query(queries.UPDATE_TERMINAL_DESTINATION, [destino, tipo, monto, tasa, habilitado, id]);
        return {
            status: 200,
            destino: res.rows[0]
        }
    } catch(e) {
        throw {
            status: 500,
            error: errorMessageExtractor(e),
            message: errorMessageGenerator(e) || 'Error al actualizar destino'
        }
    } finally {
        client.release();
    }
}

export const disableDestination = async (id) => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.DISABLE_TERMINAL_DESTINATION, [id]);
        return {
            status: 200,
            destino: res.rows[0]
        }
    } catch(e) {
        throw {
            status: 500,
            error: errorMessageExtractor(e),
            message: errorMessageGenerator(e) || 'Error al deshabilitar destino'
        }
    } finally {
        client.release();
    }
}

export const increaseCostAll = async (rate) => {
    const client = await pool.connect();
    try{
        rate = rate >= 1.0 ? rate : rate + 1.0;
        const res = await client.query(queries.INCREASE_TERMINAL_DESTINATION_COSTS, [rate]);
        return {
            status: 200,
            destino: res.rows
        }
    } catch(e) {
        throw {
            status: 500,
            error: errorMessageExtractor(e),
            message: errorMessageGenerator(e) || 'Error al incrementar costos de destinos'
        }
    } finally {
        client.release();
    }
} 