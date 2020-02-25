import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { errorMessageGenerator } from "./errors";
const pool = Pool.getInstance();

export const getAllBanks = async () => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_BANKS);
    return {
      status: 200,
      banks: response.rows,
      message: "Bancos obtenidos satisfactoriamente"
    };
  } catch (e) {
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || "Error al obtener los tramites"
    };
  } finally {
    client.release();
  }
};

export const validatePayments = async body => {
  const client = await pool.connect();
  try {
    const res = await client.query(queries.VALIDATE_PAYMENTS, [body]);
    return { data: res.rows, message: "Pago validado satisfactoriamente" };
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};
