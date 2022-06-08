import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { initProcedureAnalistAB } from "./procedures";
import { sendRimVerification } from "./verification";

const pool = Pool.getInstance();

export const getSolvencyBCandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    try {
        const contribHasUser = (await client.query('SELECT EXISTS(SELECT DISTINCT(id_usuario) FROM usuario JOIN impuesto.contribuyente USING(id_contribuyente) WHERE tipo_documento = $1 AND documento = $2)')).rows[0];
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
        const contribHasUser = (await client.query('SELECT EXISTS(SELECT DISTINCT(id_usuario) FROM usuario JOIN impuesto.contribuyente USING(id_contribuyente) WHERE tipo_documento = $1 AND documento = $2)')).rows[0];
        if (!contribHasUser) throw {status: 401, message: 'El contribuyente no posee un usuario asociado'};
        const contribHasSolvencyB = (await client.query(queries.GET_SOLVENCY_A_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows[0];
        const solvencyRIMInfo = contribHasSolvencyB ? (await client.query('SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2)')).rows : [];
        const newSolvencyRIMInfo = (solvencyRIMInfo.length > 0) ? (await Promise.all(solvencyRIMInfo.map(async rim => ({...rim, inmuebles: (await client.query('SELECT * FROM inmueble_urbano WHERE id_registro_municipal = $1', [rim.id_registro_municipal])).rows})))) : [];
        const solvencyContrInfo = (await client.query(queries.GET_SOLVENCY_B_RIF_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows[0];
        solvencyContrInfo.inmuebles = (await client.query('SELECT * FROM inmueble_urbano WHERE id_inmueble IN (SELECT id_inmueble FROM inmueble_contribuyente WHERE id_contribuyente = $1)', [solvencyContrInfo.id_contribuyente])).rows;
        const result = {contribuyente: solvencyContrInfo, sucursales: [...newSolvencyRIMInfo]}
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}

export const createSolvencyB = async ({pago, contribuyente}, user) => {
    try {const pool = Pool.getInstance();
    const client = await pool.connect();
    const tipo = 'b';
    return await initProcedureAnalistAB({pago, contribuyente, tipo}, user, client, user.id)
    } catch(e) {
        throw {status: 500, message: e.message}
    }
};