import Pool from '@utils/Pool';
import queries from '@utils/queries';

const pool = Pool.getInstance();

export const getTimeFunctionary = async (date_from, date_to) => {
  const client = await pool.connect();
  const response = (await client.query(queries.GET_CPU_TIME_FUNCTIONARY, [date_from, date_to])).rows;
  client.release();
  return response;
};
