import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { Usuario } from "@interfaces/sigt";
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async (institution: string) => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_OFFICIAlS_BY_INSTITUTION, [
      institution
    ]);
    console.log(response);
    return response;
    // const officials: Usuario[] = response.rows.map(el => {

    // });
    // if (response.rowCount > 0) {
    // }
  } catch (e) {
    throw { error: e, status: 500 };
  } finally {
    client.release();
  }
};

// export const createOfficial = async (official: any) => {
//   const client = await pool.connect();
//   try {
//     return null;
//   } catch (e) {
//     return { status: 500, error: e };
//   } finally {
//     client.release();
//   }
// };

// export const updateOfficial = async (official: any, id: string) => {
//   const client = await pool.connect();

//   try {
//   } catch (e) {
//   } finally {
//     client.release();
//   }
// };

// export const deleteOfficial = async (officialID: string) => {
//   const client = await pool.connect();

//   try {
//   } catch (e) {
//   } finally {
//     client.release();
//   }
// };
