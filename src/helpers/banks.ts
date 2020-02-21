import Pool from "@utils/Pool";
import queries from "@utils/queries";
const pool = Pool.getInstance();

export const getAllBanks = async () => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_BANKS);
    return { banks: response.rows };
  } catch (e) {
    return e;
  }
};
