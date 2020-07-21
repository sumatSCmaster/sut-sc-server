import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor } from './errors';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const processRetentionFile = async (file) => {
    
    return {};
}