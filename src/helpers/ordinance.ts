import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';

const pool = Pool.getInstance();

export const getOrdinancesByProcedure = async (id) => {
    const client = await pool.connect();
    try{
        const ordenanzasByProcedure = await client.query(queries.ORDINANCES_WITHOUT_CODCAT_PROCEDURE, [id]);
        let total = 0;
        let costo;
        const calculated = ordenanzasByProcedure.rows.map((row) => {
            console.log(row);
            costo = row.formula === null ? (row.tarifaOrdenanza * row.valorEnBs * row.tasa) : (new Function(`use strict; return ${row.formula.replace(/\$\$TASA\$\$/g, row.tasa).replace(/\$\$TARIFA\$\$/g, row.tarifa)}`));
            total += costo;
            return {
                descripcionOrdananza: row.descripcionOrdenanza,
                tarifa: row.tarifaOrdenanza + ` ${row.valorDescripcion}`,
                costoOrdenanza: row.idVariable !== null ? costo + `Bs. por ${row.nombreVariable.toLowerCase()}`: costo + ' Bs.',
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
            costo = row.formula === null ? (row.tarifaOrdenanza * row.valorEnBs * row.tasa * metrosConstruccion) : (new Function(`use strict; return ${row.formula.replace(/\$\$TASA\$\$/g, row.tasa).replace(/\$\$TARIFA\$\$/g, row.tarifa)}`));
            total += costo;
            return {
                descripcionOrdananza: row.descripcionOrdenanza,
                tarifa: row.tarifaOrdenanza + ` ${row.valorDescripcion}`,
                costoOrdenanza: row.idVariable !== null ? costo + `Bs. por ${row.nombreVariable.toLowerCase()}`: costo + ' Bs.',
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