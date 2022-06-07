import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { initProcedureAnalistAB } from "./procedures";

const pool = Pool.getInstance();

export const getSolvencyBCandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    try {
        const solvencyRIMInfo = (await client.query(queries.GET_SOLVENCY_B_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows;
        const solvencyContrInfo = await (await client.query(queries.GET_SOLVENCY_B_RIF_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows[0];
        const result = {contribuyente: solvencyContrInfo, sucursales: [...solvencyRIMInfo]}
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}

export const createSolvencyB = async ({pagos, contribuyente}, user) => {
    try {const pool = Pool.getInstance();
    const client = await pool.connect();
    const tipo = 'b';
    return await initProcedureAnalistAB({pagos, contribuyente, tipo}, user, client, user.id)
    } catch(e) {
        throw {status: 500, message: e.message}
    }
};