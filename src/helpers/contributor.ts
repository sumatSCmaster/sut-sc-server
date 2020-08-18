import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();


export const updateContributor = async ({ id, tipoDocumento, documento, razonSocial, denominacionComercial, siglas, idParroquia, sector, direccion, puntoReferencia }) => {
    const client = await pool.connect();
    try{
        await client.query('BEGIN');
        await client.query(queries.UPDATE_TAXPAYER, [id, tipoDocumento, documento, razonSocial, denominacionComercial, siglas, idParroquia, sector, direccion, puntoReferencia]);
        await client.query('COMMIT');
        return { status: 200, message: 'Contribuyente actualizado' }
    } catch (e){
        await client.query('ROLLBACK');
        console.log(e)
        throw e
    }finally {
        client.release()
    }
}

export const updateRIM = async ({ id, telefonoCelular, email, denominacionComercial, nombreRepresentante, capitalSuscrito, tipoSociedad, telefonoHabitacion}) => {
    const client = await pool.connect();
    try{
        await client.query('BEGIN');
        await client.query(queries.UPDATE_RIM, [id, telefonoCelular, email, denominacionComercial, nombreRepresentante, capitalSuscrito, tipoSociedad,  telefonoHabitacion]);
        await client.query('COMMIT');
        return { status: 200, message: 'RIM actualizado' }
    } catch (e){
        await client.query('ROLLBACK');
        console.log(e)
        throw e
    }finally {
        client.release()
    }
}