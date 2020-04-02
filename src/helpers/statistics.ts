import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

export const getStatisticsForInstitution = async id => {
  const client = await pool.connect();
  const date = new Date();
  const dateObject = { day: date.getDate(), month: date.getMonth(), year: date.getFullYear() };
  try {
    let estadistica;
    const dateArray = getMonthDateArray(dateObject);
    await Promise.all(
      dateArray.map(async el => {
        const nroTramites = await client.query(queries.GET_DAILY_STARTED_PROCEDURES);
      })
    );
    return { status: 200, message: 'Estadisticas obtenidas para la institucion', estadistica };
  } catch (error) {
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al actualizar el valor fiscal de la construccion',
    };
  } finally {
    client.release();
  }
};

const getMonthDateArray = date => {
  const arr: {}[] = [];
  for (let i = 1; i <= date.day; i++) arr.push({ initial: new Date(date.year, date.month, i), final: new Date(date.year, date.month, i, 23, 59, 59) });
  return arr;
};
