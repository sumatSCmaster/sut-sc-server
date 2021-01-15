import Pool from '@utils/Pool';
import { errorMessageGenerator, errorMessageExtractor } from './errors';

const pool = Pool.getInstance();

export const getSurvey = async (id_contribuyente) => {
  const client = await pool.connect();
  try {
    const res = await client.query(`SELECT * FROM encuesta WHERE id_contribuyente = $1;`, [id_contribuyente]);
    return {
      status: 200,
      encuestado: res.rowCount > 0,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e),
    };
  } finally {
    client.release();
  }
};

export const addSurvey = async ({ id_contribuyente, respuesta1, respuesta2, respuesta3, respuesta4, respuesta5, respuesta6 }) => {
  const client = await pool.connect();
  try {
    const res = await client.query(`INSERT INTO encuesta (respuesta1, respuesta2, respuesta3, respuesta4, respuesta5, respuesta6, id_contribuyente) VALUES ($1,$2,$3,$4,$5,$6,$7) returning *`, [
      respuesta1,
      respuesta2,
      respuesta3,
      respuesta4,
      respuesta5,
      respuesta6,
      id_contribuyente,
    ]);
    return {
      status: 200,
      encuesta: res.rows,
    };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e),
    };
  } finally {
    client.release();
  }
};
