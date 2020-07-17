import { resolve } from 'path';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import * as pdf from 'html-pdf';
import { errorMessageExtractor, errorMessageGenerator } from './errors';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getActivities = async () => {
  const client = await pool.connect();
  try {
    const activities = (await client.query(queries.GET_ALL_ACTIVITIES)).rows;
    return activities;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getMunicipalReferenceActivities = async ({ docType, document, reference }) => {
  const client = await pool.connect();
  try {
    return;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || '',
    };
  } finally {
    client.release();
  }
};
