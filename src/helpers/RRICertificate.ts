import Pool from '@utils/Pool';
import queries from '@utils/queries';

const pool = Pool.getInstance();

export const getRRICertificates = async (ids: []) => {
  const client = await pool.connect();
  const response = (await client.query(queries.GET_RRI_CERTIFICATES_BY_IDS, [ids])).rows;
  return { certificates: response };
};
