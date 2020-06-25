import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { ActividadEconomica, Ramo } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getContributorExonerations = async({ typeDoc, doc }) => {
    const client = await pool.connect()
    try{
        const contributorExonerations = await client.query(queries.GET_CONTRIBUTOR_EXONERATIONS, [typeDoc, doc]);
        const activeExonerations = contributorExonerations.rows.filter((row) => row.active);
        
        let generalExoneration = activeExonerations.find(row => !row.id_actividad_economica);
        let activityExonerations = activeExonerations.filter(row => row.id_actividad_economica);
        
        return {
            exoneracionGeneral: generalExoneration ? {
                id: generalExoneration.id_plazo_exoneracion,
                fechaInicio: generalExoneration.fecha_inicio,
            } : {},
            exoneracionesDeActividadesEconomicas: activityExonerations.map((row) => {
                return {
                    id: row.id_plazo_exoneracion,
                    fechaInicio: row.fecha_inicio,
                    numeroReferencia: row.numeroReferencia,
                    descripcion: row.descripcion
                }
            })
        }

    } catch (e) {
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}

export const getActivityExonerations = async() => {
    const client = await pool.connect()
    try{
        const activityExonerations = await client.query(queries.GET_ACTIVITY_EXONERATIONS);
        const activeExonerations = activityExonerations.rows.filter((row) => row.active);
        
        
        return {
            exoneracionesGeneralesDeActividadesEconomicas: activeExonerations.map((row) => {
                return {
                    id: row.id_plazo_exoneracion,
                    fechaInicio: row.fecha_inicio,
                    numeroReferencia: row.numeroReferencia,
                    descripcion: row.descripcion
                }
            })
        }

    } catch (e) {
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}

export const getBranchExonerations = async () => {
    const client = await pool.connect()
    try{
        const branchExonerations = await client.query(queries.GET_BRANCH_EXONERATIONS);
        const activeExonerations = branchExonerations.rows.filter((row) => row.active);
        
        
        return {
            exoneracionesGeneralesDeRamos: activeExonerations.map((row) => {
                return {
                    id: row.id_plazo_exoneracion,
                    fechaInicio: row.fecha_inicio,
                    codigo: row.codigo,
                    descripcion: row.descripcion
                }
            })
        }

    } catch (e) {
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}

export const createContributorExoneration = async ({typeDoc, doc, from, activities}: { typeDoc: string, doc: string, from: Date, activities: ActividadEconomica[]  }) => {
    const client = await pool.connect()
    try{
        await client.query('BEGIN');
        const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
        const contributor = (await client.query(queries.GET_CONTRIBUTOR,[typeDoc, doc]))
        const idContributor = contributor.rows[0].id_contribuyente;
        if(activities){
            await Promise.all(activities.map(async (row) => {
                if((await client.query(queries.GET_EXONERATED_ACTIVITY_BY_CONTRIBUTOR, [idContributor, row.id])).rowCount > 0){
                    throw new Error(`La actividad ${row.nombreActividad} ya esta exonerada para este contribuyente`)
                }else if(!((await client.query(queries.GET_CONTRIBUTOR_HAS_ACTIVITY, [idContributor, row.id])).rowCount > 0)) {
                    throw new Error(`El contribuyente no tiene esa actividad economica.`)
                } else {
                    return client.query(queries.INSERT_CONTRIBUTOR_EXONERATED_ACTIVITY, [exoneration.id_plazo_exoneracion, idContributor, row.id]);
                }
            }))
        }else {
            if((await client.query(queries.GET_EXONERATED_CONTRIBUTOR_STATUS, [idContributor])).rowCount > 0){
                throw new Error('El contribuyente ya está exonerado')
            }else {
                await client.query(queries.INSERT_EXONERATION_CONTRIBUTOR, [exoneration.id_plazo_exoneracion ,idContributor])
            }
        }
        
        await client.query('COMMIT');
        return {
            message: 'Exoneracion creada'   
        }

    } catch (e) {
        await client.query('ROLLBACK');
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}

export const createActivityExoneration = async ({ from, activities }: { from: Date, activities: ActividadEconomica[] }) => {
    const client = await pool.connect()
    try{
        await client.query('BEGIN');
        const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
        
        await Promise.all(activities.map(async (row) => {
            if((await client.query(queries.GET_ACTIVITY_IS_EXONERATED, [row.id])).rowCount > 0){
                throw new Error(`La actividad economica ${row.nombreActividad} ya está exonerada`)
            }else {
                return client.query(queries.INSERT_EXONERATION_ACTIVITY, [exoneration.id_plazo_exoneracion, row.id])
            }
        }));

        await client.query('COMMIT');
        return {
            message: 'Exoneraciones creadas'   
        }

    } catch (e) {
        await client.query('ROLLBACK');
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}

export const createBranchExoneration = async ({ from, branches }: { from: Date, branches: Ramo[] }) => {
    const client = await pool.connect()
    try{
        await client.query('BEGIN');
        const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
        
        await Promise.all(branches.map(async (row) => {
            if((await client.query(queries.GET_BRANCH_IS_EXONERATED, [row.id])).rowCount > 0){
                throw new Error(`El ramo ${row.descripcion} ya está exonerado`)
            }else {
                return client.query(queries.INSERT_EXONERATION_BRANCH, [exoneration.id_plazo_exoneracion, row.id])
            }
        }));

        await client.query('COMMIT');
        return {
            message: 'Exoneraciones creadas'   
        }

    } catch (e) {
        await client.query('ROLLBACK');
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
};

export const updateEndTimeExoneration = async (id, to) => {
    const client = await pool.connect()
    try{
        await client.query('BEGIN');
        
        await client.query(queries.UPDATE_EXONERATION_END_TIME, [to, id]);

        await client.query('COMMIT');
        return {
            message: 'Exoneracion actualizada'   
        }

    } catch (e) {
        await client.query('ROLLBACK');
        console.error(e)
        throw e;
    } finally {
        client.release()
    }
}