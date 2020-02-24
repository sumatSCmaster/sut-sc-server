import Pool from "./Pool";
import queries from "./queries";

const pool = Pool.getInstance();

export const checkIfAdmin = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_ADMIN, [id]);
    return result.rowCount > 0;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const checkIfSuperuser = async (id: string) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CHECK_IF_SUPERUSER, [id]);
    return result.rowCount > 0;
  }catch(e){
    throw e;
  } finally {
    client.release();
  }
}
