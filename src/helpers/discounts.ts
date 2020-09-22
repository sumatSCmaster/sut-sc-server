import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { ActividadEconomica, Ramo } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getActivityDiscounts = async () => {
  const client = await pool.connect();
  try {
    const activityDiscounts = await client.query(queries.GET_ACTIVITY_EXONERATIONS);
    const activeDiscounts = activityDiscounts.rows;

    return {
      descuentosGeneralesDeActividadesEconomicas: activeDiscounts.map((row) => {
        return {
          id: row.id_plazo_exoneracion,
          fechaInicio: row.fecha_inicio,
          fechaFin: row.fecha_fin,
          numeroReferencia: row.numero_referencia,
          descripcion: row.descripcion,
        };
      }),
    };
  } catch (e) {
    console.error(e);
    throw e;
  } finally {
    client.release();
  }
};

export const createActivityDiscount = async ({ from, activities }: { from: Date; activities: ActividadEconomica[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const discount = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];

    await Promise.all(
      activities.map(async (row) => {
        if ((await client.query(queries.GET_ACTIVITY_IS_EXONERATED, [row.id])).rowCount > 0) {
          throw new Error(`La actividad economica ${row.nombreActividad} ya está descontada`);
        } else {
          return client.query(queries.INSERT_EXONERATION_ACTIVITY, [discount.id_plazo_exoneracion, row.id]);
        }
      })
    );

    await client.query('COMMIT');
    return {
      message: 'Descuentos creados',
      descuentos: await Promise.all(
        activities.map(async (row) => {
          return (await client.query(queries.GET_ACTIVITY_IS_EXONERATED, [row.id])).rows[0];
        })
      ),
    };
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    throw e;
  } finally {
    client.release();
  }
};

export const updateEndTimeDiscount = async (id, to) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(queries.UPDATE_EXONERATION_END_TIME, [to, id]);

    await client.query('COMMIT');
    return {
      message: 'Descuento actualizado',
    };
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    throw e;
  } finally {
    client.release();
  }
};
