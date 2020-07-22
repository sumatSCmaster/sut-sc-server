import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor, errorMessageGenerator } from './errors';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const processRetentionFile = async (file) => {
  return {};
};

export const getRetentionMonths = async ({ referenceAR, user }) => {
  const client = await pool.connect();
  try {
    return;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener deuda de retención',
    };
  } finally {
    client.release();
  }
};
