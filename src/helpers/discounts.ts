import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { ActividadEconomica, Ramo } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getContributorDiscounts = async ({ typeDoc, doc, ref }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref])).rows[0];
    if (!contributor) {
      throw new Error('No se ha hallado el contribuyente');
    }
    const contributorDiscounts = await client.query(queries.GET_CONTRIBUTOR_DISCOUNTS, [typeDoc, doc, ref]);
    const contribuyente = {
      ...contributor,
      tipoDocumento: typeDoc,
      documento: doc,
      descuentosAforo: {},
    };
    return { status: 200, message: 'Descuentos de ramo por contribuyente obtenidos', contribuyente };
  } catch (error) {
    console.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener descuentos de ramo por contribuyente',
    };
  } finally {
    client.release();
  }
};

export const getActivityBranchDiscounts = async () => {
  const client = await pool.connect();
  try {
    const activityDiscounts = await client.query(queries.GET_ACTIVITY_DISCOUNTS);
    const activeDiscounts = activityDiscounts.rows;

    const descuentosAforo = activeDiscounts.map((row) => {
      return {
        id: row.id_plazo_,
        fechaInicio: row.fecha_inicio,
        fechaFin: row.fecha_fin,
        numeroReferencia: row.numero_referencia,
        descripcion: row.descripcion,
      };
    });

    return { status: 200, message: 'Descuentos de Ramo por Aforo obtenidos satisfactoriamente', descuentosAforo };
  } catch (error) {
    console.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener descuentos de ramo por aforo',
    };
  } finally {
    client.release();
  }
};

export const createActivityDiscount = async ({ from, activities }: { from: Date; activities: ActividadEconomica[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const discount = (await client.query(queries.CREATE_DISCOUNT, [from])).rows[0];

    await Promise.all(
      activities.map(async (row) => {
        if ((await client.query(queries.GET_ACTIVITY_IS_DISCOUNTED, [row.id])).rowCount > 0) {
          throw new Error(`La actividad economica ${row.nombreActividad} ya está descontada`);
        } else {
          return client.query(queries.INSERT_DISCOUNT_ACTIVITY, [discount.id_plazo_exoneracion, row.id]);
        }
      })
    );

    const descuentos = await Promise.all(
      activities.map(async (row) => {
        return (await client.query(queries.GET_ACTIVITY_IS_DISCOUNTED, [row.id])).rows[0];
      })
    );

    await client.query('COMMIT');
    return {
      message: 'Descuentos creados',
      descuentos,
      status: 201,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear un descuento',
    };
  } finally {
    client.release();
  }
};

export const createContributorDiscount = async ({ typeDoc, doc, ref, from, activities }: { typeDoc: string; doc: string; ref: string; from: Date; activities: ActividadEconomica[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
    console.log(exoneration);
    const contributor = await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref]);
    console.log(contributor.rows);
    if (!contributor.rows[0]) {
      throw new Error('No se ha hallado el contribuyente');
    }
    const idContributor = +contributor.rows[0].idRegistroMunicipal;
    // if (activities) {
    //   await Promise.all(
    //     activities.map(async (row) => {
    //       if ((await client.query(queries.GET_DISCOUNTED_BRANCH_BY_CONTRIBUTOR, [idContributor, row.id])).rowCount > 0) {
    //         throw new Error(`La actividad ${row.nombreActividad} ya esta exonerada para este contribuyente`);
    //       } else {
    //         console.log('bc');
    //         return client.query(queries.INSERT_CONTRIBUTOR_DISCOUNTED_BRANCH, [exoneration.id_plazo_exoneracion, idContributor, row.id]);
    //       }
    //     })
    //   );
    // } else {
    //   if ((await client.query(queries.GET_DISCOUNTED_CONTRIBUTOR_STATUS, [idContributor])).rowCount > 0) {
    //     throw new Error('El contribuyente ya está exonerado');
    //   } else {
    //     await client.query(queries.INSERT_DISCOUNT_CONTRIBUTOR, [exoneration.id_plazo_exoneracion, idContributor]);
    //   }
    // }

    await client.query('COMMIT');
    return {
      status: 200,
      message: 'Descuento de ramo por contribuyente creado',
    };
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear descuento de ramo por contribuyente',
    };
  } finally {
    client.release();
  }
};

export const updateEndTimeDiscount = async (id, to) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(queries.UPDATE_DISCOUNT_END_TIME, [to, id]);

    await client.query('COMMIT');
    return {
      message: 'Descuento actualizado',
      status: 200,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al finalizar el plazo del descuento',
    };
  } finally {
    client.release();
  }
};
