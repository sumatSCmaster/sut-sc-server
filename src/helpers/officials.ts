import Pool from "@utils/Pool";
import queries from "@utils/queries";
// import { Official } from "sigt";
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async (institution: string) => {
  const client = await pool.connect();
  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const createOfficial = async (official: any) => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const updateOfficial = async (official: any, id: string) => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const deleteOfficial = async (officialID: string) => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};
