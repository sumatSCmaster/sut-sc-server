import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const getContributorExonerations = async({ contributorId }) => {
    const client = await pool.connect()
    try{
        const contributorExonerations = await client.query(queries.GET_CONTRIBUTOR_EXONERATIONS, [contributorId]);
        const activeExonerations = contributorExonerations.rows.filter((row) => row.active);
        
        let generalExoneration = activeExonerations.find(row => !row.id_actividad_economica);
        let activityExonerations = activeExonerations.filter(row => row.id_actividad_economica);
        
        return {
            exoneracionGeneral: {
                fechaInicio: generalExoneration.fecha_inicio,
            },
            exoneracionesDeActividadesEconomicas: activityExonerations.map((row) => {
                return {
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

export const createContributorExoneration = async ({idContributor, from, activities}: { idContributor: number, from: Date, activities: any[]  }) => {
    const client = await pool.connect()
    try{
        await client.query('BEGIN');
        const exoneration = (await client.query(queries.CREATE_EXONERATION, [from])).rows[0];
        if(activities){
            await Promise.all(activities.map(async (row) => {
                if((await client.query(queries.GET_EXONERATED_ACTIVITY_BY_CONTRIBUTOR, [idContributor, row.idActividadEconomica])).rowCount > 0){
                    throw new Error(`La actividad ${row.descripcion} ya esta exonerada para este contribuyente`)
                }else if(!((await client.query(queries.GET_CONTRIBUTOR_HAS_ACTIVITY, [idContributor, row.idActividadEconomica])).rowCount > 0)) {
                    throw new Error(`El contribuyente no tiene esa actividad economica.`)
                } else {
                    return client.query(queries.INSERT_CONTRIBUTOR_EXONERATED_ACTIVITY, [exoneration.id_plazo_exoneracion, idContributor, row.idActividadEconomica]);
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

export const createActivityExoneration = async () => {

}

export const createBranchExoneration = async () => {

}