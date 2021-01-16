import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { ActividadEconomica, Ramo } from '@root/interfaces/sigt';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

export const getContributorExonerations = async ({ typeDoc, doc, ref }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref])).rows[0];
    if (!contributor) {
      throw new Error('No se ha hallado el contribuyente');
    }
    const contributorEconomicActivities = await client.query(queries.GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR, [contributor.idRegistroMunicipal]);
    const contributorExonerations = await client.query(queries.GET_CONTRIBUTOR_EXONERATIONS, [typeDoc, doc, ref]);
    const activeExonerations = contributorExonerations.rows;

    let generalExoneration = activeExonerations.find((row) => !row.id_actividad_economica);
    let activityExonerations = activeExonerations.filter((row) => row.id_actividad_economica);

    return {
      contribuyente: {
        ...contributor,
        tipoDocumento: typeDoc,
        documento: doc,
        actividades: contributorEconomicActivities.rows,
      },
      exoneracionGeneral: generalExoneration
        ? {
            id: generalExoneration.id_plazo_exoneracion,
            fechaInicio: generalExoneration.fecha_inicio,
            fechaFin: generalExoneration.fecha_fin,
          }
        : {},
      exoneracionesDeActividadesEconomicas: activityExonerations.map((row) => {
        return {
          id: row.id_plazo_exoneracion,
          fechaInicio: row.fecha_inicio,
          fechaFin: row.fecha_fin,
          numeroReferencia: row.numeroReferencia,
          descripcion: row.descripcion,
        };
      }),
    };
  } catch (e) {
    console.error(e);
    throw { message: errorMessageExtractor(e) };
  } finally {
    client.release();
  }
};

export const getActivityExonerations = async () => {
  const client = await pool.connect();
  try {
    const activityExonerations = await client.query(queries.GET_ACTIVITY_EXONERATIONS);
    const activeExonerations = activityExonerations.rows;

    return {
      exoneracionesGeneralesDeActividadesEconomicas: activeExonerations.map((row) => {
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

export const getBranchExonerations = async () => {
  const client = await pool.connect();
  try {
    const branchExonerations = await client.query(queries.GET_BRANCH_EXONERATIONS);
    const activeExonerations = branchExonerations.rows;

    return {
      exoneracionesGeneralesDeRamos: activeExonerations.map((row) => {
        return {
          id: row.id_plazo_exoneracion,
          fechaInicio: row.fecha_inicio,
          fechaFin: row.fecha_fin,
          codigo: row.codigo,
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

export const createContributorExoneration = async ({ typeDoc, doc, ref, from, activities }: { typeDoc: string; doc: string; ref: string; from: Date; activities: ActividadEconomica[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
    mainLogger.info(exoneration);
    const contributor = await client.query(queries.GET_CONTRIBUTOR, [typeDoc, doc, ref]);
    mainLogger.info(contributor.rows);
    if (!contributor.rows[0]) {
      throw new Error('No se ha hallado el contribuyente');
    }
    const idContributor = +contributor.rows[0].idRegistroMunicipal;
    if (activities) {
      await Promise.all(
        activities.map(async (row) => {
          if ((await client.query(queries.GET_EXONERATED_ACTIVITY_BY_CONTRIBUTOR, [idContributor, row.id])).rowCount > 0) {
            throw new Error(`La actividad ${row.nombreActividad} ya esta exonerada para este contribuyente`);
          } else if (!((await client.query(queries.GET_CONTRIBUTOR_HAS_ACTIVITY, [idContributor, row.id])).rowCount > 0)) {
            throw new Error(`El contribuyente no tiene esa actividad economica.`);
          } else {
            mainLogger.info('bc');
            return client.query(queries.INSERT_CONTRIBUTOR_EXONERATED_ACTIVITY, [exoneration.id_plazo_exoneracion, idContributor, row.id]);
          }
        })
      );
    } else {
      if ((await client.query(queries.GET_EXONERATED_CONTRIBUTOR_STATUS, [idContributor])).rowCount > 0) {
        throw new Error('El contribuyente ya está exonerado');
      } else {
        await client.query(queries.INSERT_EXONERATION_CONTRIBUTOR, [exoneration.id_plazo_exoneracion, idContributor]);
      }
    }

    await client.query('COMMIT');
    return {
      message: 'Exoneracion creada',
    };
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    throw {
      e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const createActivityExoneration = async ({ from, activities }: { from: Date; activities: ActividadEconomica[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];

    await Promise.all(
      activities.map(async (row) => {
        if ((await client.query(queries.GET_ACTIVITY_IS_EXONERATED, [row.id])).rowCount > 0) {
          throw new Error(`La actividad economica ${row.nombreActividad} ya está exonerada`);
        } else {
          return client.query(queries.INSERT_EXONERATION_ACTIVITY, [exoneration.id_plazo_exoneracion, row.id]);
        }
      })
    );

    await client.query('COMMIT');
    return {
      message: 'Exoneraciones creadas',
      exoneraciones: await Promise.all(
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

export const createBranchExoneration = async ({ from, branches }: { from: Date; branches: Ramo[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];

    await Promise.all(
      branches.map(async (row) => {
        if ((await client.query(queries.GET_BRANCH_IS_EXONERATED, [row.id])).rowCount > 0) {
          throw new Error(`El ramo ${row.descripcion} ya está exonerado`);
        } else {
          return client.query(queries.INSERT_EXONERATION_BRANCH, [exoneration.id_plazo_exoneracion, row.id]);
        }
      })
    );

    await client.query('COMMIT');
    return {
      message: 'Exoneraciones creadas',
      exoneraciones: await Promise.all(
        branches.map(async (row) => {
          return (await client.query(queries.GET_BRANCH_IS_EXONERATED, [row.id])).rows[0];
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

export const updateEndTimeExoneration = async (id, to) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(queries.UPDATE_EXONERATION_END_TIME, [to, id]);

    await client.query('COMMIT');
    return {
      message: 'Exoneracion actualizada',
    };
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    throw e;
  } finally {
    client.release();
  }
};
