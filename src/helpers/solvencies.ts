import Pool from "@utils/Pool";
import queries from "@utils/queries";

const pool = Pool.getInstance();

export const getSolvencyBCandidates = async ({tipoDocumento, documento}) => {
    const client = await pool.connect();
    try {
        const solvencyRIMInfo = (await client.query(queries.GET_SOLVENCY_B_RIM_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows;
        const solvencyContrInfo = await (await client.query(queries.GET_SOLVENCY_B_RIF_CANDIDATES_BY_RIF, [tipoDocumento, documento])).rows;
        const result = [...solvencyContrInfo, ...solvencyRIMInfo]
        return {status: 200, data: result};
    } catch(e) {throw {status: 500, message: e.message}}
}