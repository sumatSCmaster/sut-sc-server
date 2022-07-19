import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { initProcedureAnalistAB } from "./procedures";
import moment from "moment";
import { sendRimVerification } from "./verification";
import { createSolvencyABSettlement } from "./settlement";

const pool = Pool.getInstance();

export const getSolvencyBCandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    try {
        const contribHasUser = (await client.query('SELECT EXISTS(SELECT DISTINCT(id_usuario) FROM usuario JOIN impuesto.contribuyente USING(id_contribuyente) WHERE tipo_documento = $1 AND documento = $2)', [tipoDocumento, documento])).rows[0];
        if (!contribHasUser) throw {status: 401, message: 'El contribuyente no posee un usuario asociado'};
        const solvencyRIMInfo = (await client.query(queries.GET_SOLVENCY_B_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows;
        const solvencyContrInfo = await (await client.query(queries.GET_SOLVENCY_B_RIF_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows[0];
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
        const contribHasSolvencyB = (await client.query(queries.GET_SOLVENCY_A_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento, moment().subtract(3, 'month').format('YYYY-MM-DD')])).rows[0].exists;
        const solvencyContrInfo = (await client.query(`SELECT * FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2`, [tipoDocumento, documento])).rows[0];
        solvencyContrInfo.hasSolvencyB = contribHasSolvencyB;
        solvencyContrInfo.inmuebles = (await client.query('SELECT inmueble_urbano.*, avaluo FROM inmueble_urbano JOIN impuesto.avaluo_inmueble USING(id_inmueble) WHERE id_inmueble IN (SELECT id_inmueble FROM impuesto.inmueble_contribuyente WHERE id_contribuyente = $1) ORDER BY anio DESC LIMIT 1', [solvencyContrInfo.id_contribuyente])).rows;
        //logica para las sucursales
        const solvencyRIMInfo = (await client.query('SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2)', [tipoDocumento, documento])).rows;
        const newSolvencyRIMInfo = (solvencyRIMInfo.length > 0) ? (await Promise.all(solvencyRIMInfo.map(async rim => {
            const rimHasSolvencyB = (await client.query(`SELECT EXISTS(SELECT * FROM tramite WHERE datos#>>'{usuario, sucursal, referencia_municipal}' = $1 AND id_tipo_tramite = 113 AND fecha_culminacion > $2)`, [rim.referencia_municipal, moment().subtract(3, 'month').format('YYYY-MM-DD')])).rows[0].exists;
            if (rimHasSolvencyB) return {...rim, inmuebles: (await client.query('SELECT inmueble_urbano.*, avaluo FROM inmueble_urbano JOIN impuesto.avaluo_inmueble USING(id_inmueble) WHERE id_registro_municipal = $1 ORDER BY anio DESC LIMIT 1', [rim.id_registro_municipal])).rows}
            return {...rim}
        }))) : [];
        const newestSolvencyRIMInfo = newSolvencyRIMInfo.filter(rim => rim.inmuebles);
        const result = {contribuyente: solvencyContrInfo || undefined, sucursales: [...newestSolvencyRIMInfo]}
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}

export const createSolvencyAB = async ({contribuyente, sucursal}, user, tipo) => {
    try {const pool = Pool.getInstance();
    const client = await pool.connect();
    return await createSolvencyABSettlement({contribuyente, sucursal}, tipo, user)
    // return await initProcedureAnalistAB({pago, contribuyente, tipo}, user, client, user.id)
    } catch(e) {
        throw {status: 500, message: e.message}
    }
};