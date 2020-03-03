import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Payloads } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const updateProcedureInstanceCost = async (body: Payloads.UpdateProcedureInstanceCost) => {
    const client = await pool.connect();
    try {
        await client.query(queries.UPDATE_PROCEDURE_INSTANCE_COST, [body.costo, body.id]);

        return { message: "Costo actualizado"};
    } catch (e) {
        throw {
            status: 500,
            e,
            message: errorMessageGenerator(e) || 'Error al actualizar el costo del tramite',
        };
    } finally {
        client.release();
    }
}