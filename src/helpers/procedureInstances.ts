import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { Payloads } from '@interfaces/sigt';
import { errorMessageGenerator } from './errors';
const pool = Pool.getInstance();

export const updateProcedureInstanceCost = async (body: Payloads.UpdateProcedureInstanceCost) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(queries.UPDATE_PROCEDURE_INSTANCE_COST, [body.costo, body.id]);
    const facturaId = (await client.query(queries.CREATE_RECEIPT, [body.id])).rows[0].id_factura;
    await Promise.all(body.items.map((item) => client.query(queries.ADD_ITEM_TO_RECEIPT, [facturaId, item.nombre, item.costo])));
    await client.query('COMMIT');
    return { message: 'Costo actualizado' };
  } catch (e) {
    await client.query('ROLLBACK');
    throw {
      status: 500,
      e: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al actualizar el costo del tramite',
    };
  } finally {
    client.release();
  }
};
