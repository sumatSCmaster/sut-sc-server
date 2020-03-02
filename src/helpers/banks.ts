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
    return {
      validatePayments: res.rows[0].validate_payments,
      message: "Pago validado satisfactoriamente",
      status: 201
    };
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const insertPaymentReference = async (payment, procedureId, client) => {
  const { referencia, banco, costo, fecha } = payment;
  return await client
    .query(queries.INSERT_PAYMENT, [
      procedureId,
      referencia,
      costo,
      banco,
      fecha
    ])
    .catch(error => {
      console.log(error);
      throw {
        error,
        message: errorMessageGenerator(error) || "Error al insertar el pago"
      };
    });
};
