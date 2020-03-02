import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Parroquia } from "@interfaces/sigt";
import { errorMessageGenerator } from "./errors";
const pool = Pool.getInstance();

export const getAllParishes = async (): Promise<{
  parroquias: Parroquia[];
  status: number;
  message: string;
}> => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_PARROQUIAS);
    const parroquias: Parroquia[] = response.rows;
    return { parroquias, status: 200, message: "Parroquias obtenidas" };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || "Error al obtener las parroquias"
    };
  } finally {
    client.release();
  }
};
