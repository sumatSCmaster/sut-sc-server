import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';

const pool = Pool.getInstance();

export const getOrdinancesByInstitution = async (idInstitucion) => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.ORDINANCES_BY_INSTITUTION, [idInstitucion]);
        return {
            status: 200,
            ordenanzas: res.rows
        }
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al obtener ordenanzs'
        }
    } finally {
        client.release();
    }
}

export const getOrdinancesByProcedure = async (id) => {
    const client = await pool.connect();
    try{
        const ordenanzasByProcedure = await client.query(queries.ORDINANCES_WITHOUT_CODCAT_PROCEDURE, [id]);
        let total = 0;
        let costo;
        const calculated = ordenanzasByProcedure.rows.map((row) => {
            console.log(row);
            costo = row.formula === null ? (row.tarifaOrdenanza * row.valorEnBs) : (new Function(`use strict; return ${row.formula.replace(/\$\$TARIFA\$\$/g, row.tarifa)}`));
            total += costo;
            return {
                id: row.id,
                idTarifa: row.idTarifa,
                descripcionOrdenanza: row.descripcionOrdenanza,
                tarifa: row.tarifaOrdenanza + ` ${row.valorDescripcion}`,
                costoOrdenanza: row.idVariable !== null ? +costo : +costo,
                utilizaCodCat: row.utilizaCodcat,
                utilizaVariable: row.idVariable !== null,
                variable: row.nombreVariable ? row.nombreVariable : undefined
            }
        } );
        return {
            status: 200,
            ordenanzas: calculated,
            total: total + 'Bs.'
        }
    } catch(e) {
        throw {
            error: e,
            status: 500,
            message: errorMessageGenerator(e) || 'Error al obtener ordenanzas'
        }
    } finally {
        client.release();
    }
}

export const getOrdinancesByProcedureWithCodCat = async (id, cod) => {
    const client = await pool.connect();
    try{
        const ordenanzasByProcedure = await client.query(queries.ORDINANCES_WITH_CODCAT_PROCEDURE, [id]);
        const inmueble = await client.query(queries.GET_ONE_PROPERTY_BY_COD, [cod]);
        if(inmueble.rowCount === 0){
            return {
                status: 401,
                message: 'Inmueble no encontrado'
            }
        }
        let total = 0;
        let costo;
        let { metrosConstruccion } = inmueble.rows[0];
        const calculated = ordenanzasByProcedure.rows.map((row) => {
            costo = row.formula === null ? (+row.tarifaOrdenanza * +row.valorEnBs * +metrosConstruccion) : (new Function(`use strict; return ${row.formula.replace(/\$\$TARIFA\$\$/g, row.tarifa)}`));
            total += costo;
            return {
                id: row.id,
                idTarifa: row.idTarifa,
                descripcionOrdenanza: row.descripcionOrdenanza,
                tarifa: row.tarifaOrdenanza + ` ${row.valorDescripcion}`,
                costoOrdenanza: (+row.tarifaOrdenanza * +row.valorEnBs),
                valorCalc: +costo ,
                utilizaCodCat: row.utilizaCodcat,
                utilizaVariable: row.idVariable !== null,
                variable: row.nombreVariable ? row.nombreVariable : undefined
            }
        })
        return {
            status: 200,
            ordenanzas: calculated,
            total: total + 'Bs.',
            metrosConstruccion
        }
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al obtener ordenanzas'
        }
    } finally {
        client.release();
    }
}

export const disableOrdinance = async (idOrdenanza) => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.DISABLE_ORDINANCE, [idOrdenanza]);
        return res.rowCount > 0 ? {
            status: 200,
            message: 'Ordenanza eliminada',
            ordenanza: res.rows[0]
        } : {
            status: 400,
            message: 'No se halló la ordenanza deseada'
        }
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al eliminar ordenanza'
        }
    } finally {
        client.release();
    }
}

export const updateOrdinance = async (idOrdenanza, newUtmm) => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.UPDATE_ORDINANCE, [idOrdenanza, newUtmm]);
        return res.rowCount > 0 ? {
            status: 200,
            message: 'Ordenanza actualizada',
            ordenanza: res.rows[0]
        } : {
            status: 400,
            message: 'No se halló la ordenanza deseada'
        }
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al actualizar ordenanza'
        }
    } finally {
        client.release();
    }
}

export const getVariables = async () => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.GET_ORDINANCE_VARIABLES);
        return {
            status: 200,
            message: 'Variables obtenidas',
            variables: res.rows
        } 
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al obtener variables'
        }
    } finally {
        client.release();
    }
}
 
export const createOrdinance = async (ordinance) => {
    const client = await pool.connect();
    try{
        const res = await client.query(queries.CREATE_ORDINANCE, [ordinance.nombreOrdenanza, ordinance.precioUtmm, ordinance.idTipoTramite, ordinance.utilizaCodcat ? ordinance.utilizaCodCat : false, ordinance.utilizaVariable ? ordinance.idVariable : null]);
        return {
            status: 200,
            message: 'Ordenanza creada',
            ordenanza: res.rows[0]
        }
    } catch(e) {
        throw {
            status: 500,
            message: errorMessageGenerator(e) || 'Error al eliminar ordenanza'
        }
    } finally {
        client.release();
    }
}