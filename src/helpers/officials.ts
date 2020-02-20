import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { fulfill } from "@utils/resolver";
const pool = Pool.getInstance();

export const getOfficialsByInstitution = async institution => {
  const client = await pool.connect();
  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const createOfficial = async official => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const updateOfficial = async official => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};

export const deleteOfficial = async officialID => {
  const client = await pool.connect();

  try {
  } catch (e) {
  } finally {
    client.release();
  }
};
