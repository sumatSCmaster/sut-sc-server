import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { ActividadEconomica, Ramo } from '@root/interfaces/sigt';
import moment from 'moment';

const pool = Pool.getInstance();

// ? DE ULTIMO
export const getContributorDiscounts = async ({ typeDoc, doc, ref }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref])).rows[0];
    console.log('getContributorDiscounts -> contributor', contributor);
    if (!contributor) {
      throw { status: 404, message: 'No se ha hallado el contribuyente' };
    }

    const idContributor = +contributor.idRegistroMunicipal;
    const contributorDiscounts = await Promise.all(
      (await client.query(queries.GET_CONTRIBUTOR_DISCOUNTS, [typeDoc, doc, ref])).rows.map(async (discount) => {
        const branchDiscount = (await client.query(queries.GET_DISCOUNTED_BRANCH_BY_CONTRIBUTOR, [idContributor, discount.id_ramo])).rows;
        const response = {
          id: discount.id_ramo,
          descripcion: branchDiscount[0]?.descripcion,
          descuentos: branchDiscount.map((row) => ({
            id: row.id_plazo_descuento,
            fechaInicio: moment(row.fecha_inicio).format('MM-DD-YYYY'),
            fechaFin: (row.fecha_fin && moment(row.fecha_fin).format('MM-DD-YYYY')) || null,
            porcentajeDescuento: +row.porcentaje_descuento,
          })),
        };
        return response;
      })
    );

    const contribuyente = {
      ...contributor,
      tipoDocumento: typeDoc,
      documento: doc,
      referenciaMunicipal: ref,
      ramos: contributorDiscounts,
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

// * DONE
export const getActivityBranchDiscounts = async () => {
  const client = await pool.connect();
  try {
    const activityDiscounts = await client.query(queries.GET_ACTIVITY_DISCOUNTS);
    const activeDiscounts = activityDiscounts.rows;

    const descuentos = await Promise.all(
      activeDiscounts.map(async (row) => {
        return {
          id: row.id_plazo_descuento,
          fechaInicio: row.fecha_inicio,
          fechaFin: row.fecha_fin,
          numeroReferencia: row.numero_referencia,
          descripcion: row.descripcion,
          ramos: (await client.query(queries.GET_BRANCH_INFO_FOR_DISCOUNT_BY_ACTIVITY, [row.id_plazo_descuento, row.id_actividad_economica])).rows,
        };
      })
    );

    return { status: 200, message: 'Descuentos de Ramo por Aforo obtenidos satisfactoriamente', descuentos };
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

// * DONE
export const createActivityDiscount = async ({ from, activities }: { from: Date; activities: Partial<ActividadEconomica & { ramos: any[] }>[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const actividades = await Promise.all(
      activities.map(async (row) => {
        const discount = (await client.query(queries.CREATE_DISCOUNT, [from])).rows[0];
        await Promise.all(
          row.ramos!.map(async (ramo) => {
            if ((await client.query(queries.GET_ACTIVITY_IS_DISCOUNTED, [row.id, ramo.id])).rowCount > 0) throw { status: 409, message: `La actividad economica ${row.nombreActividad} ya posee un descuento para el ramo ${ramo.descripcion}` };
            return (await client.query(queries.INSERT_DISCOUNT_ACTIVITY, [discount.id_plazo_descuento, row.id, ramo.id, ramo.porcDescuento])).rows[0];
          })
        );
        const descuentoAforo = (await client.query(queries.GET_ACTIVITY_DISCOUNT_BY_ID, [discount.id_plazo_descuento, row.id])).rows[0];
        const response = {
          ...descuentoAforo,
          fechaInicio: discount.fecha_inicio,
          ramos: (await client.query(queries.GET_BRANCH_INFO_FOR_DISCOUNT_BY_ACTIVITY, [discount.id_plazo_descuento, row.id])).rows,
        };
        return response;
      })
    );

    await client.query('COMMIT');
    return {
      message: 'Descuentos creados',
      actividades,
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

// * DONE
export const createContributorDiscount = async ({ typeDoc, doc, ref, from, branches }: { typeDoc: string; doc: string; ref: string; from: Date; branches: any[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const contributor = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref])).rows[0];
    console.log(contributor.rows);
    if (!contributor) {
      throw { status: 404, message: 'El contribuyente no existe' };
    }
    const idContributor = +contributor.idRegistroMunicipal;
    console.log('aki');
    const ramos = await Promise.all(
      branches.map(async (branch) => {
        console.log('a');
        const discount = (await client.query(queries.CREATE_DISCOUNT, [from])).rows[0];
        if ((await client.query(queries.GET_BRANCH_IS_DISCOUNTED_FOR_CONTRIBUTOR, [idContributor, branch.id, from])).rowCount > 0) throw { message: `El ramo ${branch.descripcion} posee un descuento vigente para este contribuyente` };
        await client.query(queries.INSERT_CONTRIBUTOR_DISCOUNT_FOR_BRANCH, [discount.id_plazo_descuento, idContributor, branch.id, branch.porcDescuento]);
        const response = {
          id: branch.id,
          descripcion: branch.descripcion,
          descuentos: (await client.query(queries.GET_DISCOUNTED_BRANCH_BY_CONTRIBUTOR, [idContributor, branch.id])).rows.map((row) => ({
            id: row.id_plazo_descuento,
            fechaInicio: moment(row.fecha_inicio).format('MM-DD-YYYY'),
            fechaFin: (row.fecha_fin && moment(row.fecha_fin).format('MM-DD-YYYY')) || null,
            porcentajeDescuento: +row.porcentaje_descuento,
          })),
        };
        return response;
      })
    );
    console.log('q');
    await client.query('COMMIT');
    const contribuyente = {
      ...contributor,
      tipoDocumento: typeDoc,
      documento: doc,
      referenciaMunicipal: ref,
      ramos,
    };
    console.log('wtf');
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

    return {
      status: 200,
      message: 'Descuento de ramo por contribuyente creado',
      contribuyente,
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

// * DONE
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
