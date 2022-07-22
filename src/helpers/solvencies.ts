import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { initProcedureAnalistAB } from "./procedures";
import moment from "moment";
import { sendRimVerification } from "./verification";
import { createSolvencyABSettlement } from "./settlement";

const pool = Pool.getInstance();

export const getSolvencyBCandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    const now = moment();
    const months = {january: 'enero', february: 'febrero', march: 'marzo', april: 'abril', may: 'mayo', june: 'junio', july: 'julio', august: 'agosto', september: 'septiembre', october: 'octubre', november: 'noviembre', december: 'diciembre'};
    try {
        const pastMonth = months[now.subtract(1, 'months').format('MMMM').toLowerCase()];
        const year = now.year();
        // console.log(pastMonth, now.subtract(1, 'months').format('MMMM'), 'MASTER SOLVENCY');
        const contribHasUser = (await client.query('SELECT EXISTS(SELECT DISTINCT(id_usuario) FROM usuario JOIN impuesto.contribuyente USING(id_contribuyente) WHERE tipo_documento = $1 AND documento = $2)', [tipoDocumento, documento])).rows[0];
        if (!contribHasUser) throw {status: 401, message: 'El contribuyente no posee un usuario asociado'};
        //Validacion si tiene liquidaciones sin pagar
        let solvencyRIMInfo = (await client.query(`SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2 LIMIT 1)`, [tipoDocumento, documento])).rows;
        //Validacion si tiene liquidaciones sin pagar el contribuyente sin rim
        let solvencyContrInfo = (await client.query(`SELECT * FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2 LIMIT 1`, [tipoDocumento, documento])).rows[0];
        //Validacion si el contribuyente sin rim tiene vehiculos al dia
    //     const hasVehicles = (await client.query('SELECT impuesto.vehiculo.* FROM impuesto.vehiculo JOIN impuesto.vehiculo_contribuyente USING (id_vehiculo) WHERE id_contribuyente = $1', [solvencyContrInfo?.id_contribuyente || 0])).rows;
    //     if (hasVehicles.length > 0) {
    //         const solvencyContrVehicleValidation = await client.query(`SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING (id_solicitud) WHERE id_subramo = 804 AND aprobado = true AND id_registro_municipal IS NULL AND (datos#>>'{fecha, year}')::INT = $1 ORDER BY (datos#>>'{fecha, year}')::INT`, [year]);
    //         if (!(solvencyContrVehicleValidation.rowCount > 0)) solvencyContrInfo = undefined;
    //     }
    //     //Validacion que los rim esten al dia con actividad economica
    //     const pastMonthAE = months[now.subtract(2, 'months').format('MMMM').toLowerCase()];
    //     if (solvencyRIMInfo.length > 0) {
    //     await Promise.all(solvencyRIMInfo.map(async rim => {
    //         const upToDate = await client.query(`SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE aprobado = true AND id_registro_municipal = $1 AND id_subramo = 10 AND datos#>>'{fecha, month}' = $2 AND datos#>>'{fecha, year}' = $3`, [rim.id_registro_municipal, pastMonthAE, year]);
    //         console.log(upToDate.rows, 'MASTER SOLVENCY')
    //         if (!(upToDate.rowCount > 0)) return undefined;
    //         return rim;
    //     }));
    //     console.log(solvencyRIMInfo, 'MASTER SOLVENCY 2')
    //     solvencyRIMInfo = solvencyRIMInfo.filter(rim => rim);
    //     //Validacion que los rim esten al dia con servicios municipales
    //     await Promise.all(solvencyRIMInfo.map(async rim => {
    //         const upToDate = await client.query(`SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE aprobado = true AND id_registro_municipal = $1 AND id_subramo = 108 AND datos#>>'{fecha, month}' = $2 AND datos#>>'{fecha, year}' = $3`, [rim.id_registro_municipal, pastMonth, year]);
    //         if (!(upToDate.rowCount > 0)) return undefined;
    //         return rim;
    //     }));
    //     solvencyRIMInfo = solvencyRIMInfo.filter(rim => rim);
    //     //Validacion que los rim esten al dia con inmuebles urbanos
    //     await Promise.all(solvencyRIMInfo.map(async rim => {
    //         const rimHasEstate = await client.query('SELECT * FROM inmueble_urbano WHERE id_registro_municipal = $1', [rim.id_registro_municipal]);
    //         if (rimHasEstate.rowCount > 0) {
    //             const upToDate = await client.query(`SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE aprobado = true AND id_registro_municipal = $1 AND id_subramo = 9 AND datos#>>'{fecha, month}' = $2 AND datos#>>'{fecha, year}' = $3`, [rim.id_registro_municipal, pastMonth, year]);
    //             if (!(upToDate.rowCount > 0)) return undefined;
    //         }
    //         return rim;
    //     }));
    //     solvencyRIMInfo = solvencyRIMInfo.filter(rim => rim);
    //     //Validacion que los rim esten al dia con vehiculos
    //     await Promise.all(solvencyRIMInfo.map(async rim => {
    //         const rimHasVehicles = await client.query('SELECT * FROM impuesto.vehiculo WHERE id_registro_municipal = $1', [rim.id_registro_municipal]);
    //         if (rimHasVehicles.rowCount > 0) {
    //             const upToDate = await client.query(`SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE aprobado = true AND id_registro_municipal = $1 AND id_subramo = 804 AND datos#>>'{fecha, month}' = $2 AND datos#>>'{fecha, year}' = $3`, [rim.id_registro_municipal, pastMonth, year]);
    //             if (!(upToDate.rowCount > 0)) return undefined;
    //         }
    //         return rim;
    //     }));
    //     solvencyRIMInfo = solvencyRIMInfo.filter(rim => rim);
    // }
        const result = {contribuyente: solvencyContrInfo, sucursales: [...solvencyRIMInfo]}
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}

export const getSolvencyACandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    try {
        const contribHasUser = (await client.query('SELECT EXISTS(SELECT DISTINCT(id_usuario) FROM usuario JOIN impuesto.contribuyente USING(id_contribuyente) WHERE tipo_documento = $1 AND documento = $2)', [tipoDocumento, documento])).rows[0];
        if (!contribHasUser) throw {status: 401, message: 'El contribuyente no posee un usuario asociado'};
        //Logica para el contribuyente
        const contribHasSolvencyB = (await client.query(queries.GET_SOLVENCY_A_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento, moment().format('YYYY-MM-DD')])).rows[0].exists;
        console.log(moment().format('YYYY-MM-DD'), 'MASTER')
        const solvencyContrInfo = (await client.query(`SELECT * FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2`, [tipoDocumento, documento])).rows[0];
        if (!solvencyContrInfo) throw {status: 401, message: 'El contribuyente no existe o no está registrado en el sistema SUT'};
        solvencyContrInfo.hasSolvencyB = contribHasSolvencyB;
        solvencyContrInfo.inmuebles = (await client.query('SELECT inmueble_urbano.*, avaluo FROM inmueble_urbano JOIN (SELECT * FROM impuesto.avaluo_inmueble WHERE anio = (SELECT anio FROM impuesto.avaluo_inmueble GROUP BY anio ORDER BY anio DESC LIMIT 1)) a USING(id_inmueble) WHERE id_inmueble IN (SELECT id_inmueble FROM impuesto.inmueble_contribuyente WHERE id_contribuyente = $1) ORDER BY anio DESC', [solvencyContrInfo.id_contribuyente])).rows;
        //logica para las sucursales
        const solvencyRIMInfo = (await client.query('SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2)', [tipoDocumento, documento])).rows;
        const newSolvencyRIMInfo = (solvencyRIMInfo.length > 0) ? (await Promise.all(solvencyRIMInfo.map(async rim => {
            const rimHasSolvencyB = (await client.query(`SELECT EXISTS(SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE id_registro_municipal = (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $1) AND id_subramo = 824 AND aprobado = true AND fecha_vencimiento > $2)`, [rim.referencia_municipal, moment().format('YYYY-MM-DD')])).rows[0].exists;
            if (rimHasSolvencyB) return {...rim, inmuebles: (await client.query('SELECT inmueble_urbano.*, avaluo FROM inmueble_urbano JOIN (SELECT * FROM impuesto.avaluo_inmueble WHERE anio = (SELECT anio FROM impuesto.avaluo_inmueble GROUP BY anio ORDER BY anio DESC LIMIT 1)) a USING(id_inmueble) WHERE id_registro_municipal = $1 ORDER BY anio DESC', [rim.id_registro_municipal])).rows}
            return {...rim}
        }))) : [];
        const newestSolvencyRIMInfo = newSolvencyRIMInfo.filter(rim => rim.inmuebles);
        const result = {contribuyente: solvencyContrInfo || undefined, sucursales: [...newestSolvencyRIMInfo]}
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}

export const createSolvencyAB = async ({contribuyente, sucursal}, user, tipo) => {
    try {
    // const pool = Pool.getInstance();
    // const client = await pool.connect();
    return await createSolvencyABSettlement({contribuyente, sucursal}, tipo, user)
    // return await initProcedureAnalistAB({pago, contribuyente, tipo}, user, client, user.id)
    } catch(e) {
        throw {status: 500, message: e.message}
    }
};