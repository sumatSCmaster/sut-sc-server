import Pool from '@utils/Pool';
import queries from '@utils/queries';
import moment from 'moment';
import { getUsers } from '@config/socket';
import { mainLogger } from '@utils/logger';


const pool = Pool.getInstance();

const users = getUsers();

export const getFiscalizations = async () => {
    const client = await pool.connect();
    try {
        
        const fiscalization = await client.query(queries.GET_FISCALIZATIONS)
        return { message: 'Fiscalizacion creada.', fiscalizaciones: fiscalization.rows, status: 200 }
    } catch (err) {
        throw err
    } finally {
        client.release()
    }
}

export const createFiscalization = async (user ,{typeDoc, doc, rim}) => {
    const client = await pool.connect();
    try {
        const taxPayer = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, rim]));
        if(taxPayer.rowCount === 0){
            throw new Error('No se encontrĂ³ el contribuyente');
        }
        const exists = (await client.query(`SELECT * FROM impuesto.fiscalizacion WHERE id_registro_municipal = $1`, [taxPayer.rows[0].idRegistroMunicipal]));
        if(exists.rowCount > 0){
            throw new Error('Ya se ha creado una fiscalizacion para este contribuyente');
        }
        const fiscalization = await client.query(queries.INSERT_FISCALIZATION, [taxPayer.rows[0].idRegistroMunicipal, 'FISCALIZACION'])

        const newFisc = (await client.query(queries.GET_FISCALIZATIONS_ID, [fiscalization.rows[0].idFiscalizacion])).rows[0]

        const socket = users.get(`${user?.nacionalidad}-${user?.cedula}`);
        socket?.broadcast.to('tabla-fiscalizacion').emit('NEW_FISCALIZATION', newFisc) 

        return { message: 'Fiscalizacion creada.', fiscalizacion: newFisc, status: 200 }
    } catch (err) {
        mainLogger.error(err.message);
        throw err
    } finally {
        client.release()
    }
}


export const updateOneFiscalization = async (user: any, { idFiscalizacion, idUsuario, medida, estado, auditoria, comparecio }) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const newFisc = (await client.query(queries.UPDATE_FISCALIZATION, [idFiscalizacion, idUsuario, medida, estado, auditoria, comparecio])).rows[0]
        

        const socket = users.get(`${user?.nacionalidad}-${user?.cedula}`);
        socket?.broadcast.to('tabla-fiscalizacion').broadcast.emit('UPDATE_FISCALIZATION', newFisc)        
        await client.query('COMMIT;')
        return { status: 200, fiscalizacion: newFisc, message: 'Cobranza actualizada.' }
    } catch (err) {
        await client.query('ROLLBACK;')
        throw err;
    } finally {
        client.release();
    }
}