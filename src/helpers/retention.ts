import { resolve } from 'path';

import moment, { Moment } from 'moment';
import S3Client from '@utils/s3';
import ExcelJs from 'exceljs';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { renderFile } from 'pug';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { Usuario } from '@root/interfaces/sigt';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

const codigosRamo = {
  AE: 112,
  SM: 122,
  PP: 114,
  IU: 111,
  RD0: 915,
};

export const processRetentionFile = async (file) => {
  return {};
};

export const getRetentionMonths = async ({ document, reference, docType, user }: { document: string; reference: string; docType: string; user: Usuario }) => {
  const client = await pool.connect();
  let debtRD;
  try {
    if (!reference) throw { status: 403, message: 'Debe incluir un RIM de Agente de Retención' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'No existe un contribuyente registrado en SEDEMAT' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'No existe el RIM de Agente de Retención proporcionado' };
    const RD0ApplicationExists = (await client.query(queries.CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM, [codigosRamo.RD0, reference])).rows[0];
    if (!!RD0ApplicationExists) throw { status: 409, message: 'Ya existe una declaración de retenciones para este mes' };
    const now = moment(new Date());

    let lastRD = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM, [codigosRamo.AE, branch.referencia_municipal])).rows[0];
    const lastRDPayment = (lastRD && moment(lastRD.fecha_liquidacion)) || moment().month(0);
    const RDDate = moment([lastRDPayment.year(), lastRDPayment.month(), 1]);
    const dateInterpolation = Math.floor(now.diff(RDDate, 'M'));
    if (dateInterpolation > 0) {
      debtRD = await Promise.all(
        new Array(dateInterpolation).fill({ month: null, year: null }).map(async (value, index) => {
          const date = addMonths(new Date(lastRDPayment.toDate()), index);
          const momentDate = moment(date);
          const exonerado = await isExonerated({ branch: codigosRamo.RD0, contributor: branch?.id_registro_municipal, activity: null, startingDate: momentDate.startOf('month') });
          return { month: date.toLocaleString('es-ES', { month: 'long' }), year: date.getFullYear(), exonerado };
        })
      );
    }
    return { status: 200, message: 'Deuda de retención obtenida satisfactoriamente', retencion: debtRD };
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

const addMonths = (date: Date, months): Date => {
  const d = date.getDate();
  date.setMonth(date.getMonth() + +months);
  if (date.getDate() != d) {
    date.setDate(0);
  }
  return date;
};

const isExonerated = async ({ branch, contributor, activity, startingDate }): Promise<boolean> => {
  const client = await pool.connect();
  try {
    if (branch === codigosRamo.AE) {
      const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
      if (branchIsExonerated) return !!branchIsExonerated;
      const activityIsExonerated = (await client.query(queries.ECONOMIC_ACTIVITY_IS_EXONERATED, [activity, startingDate])).rows[0];
      if (activityIsExonerated) return !!activityIsExonerated;
      const contributorIsExonerated = (await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
      if (contributorIsExonerated) return !!contributorIsExonerated;
      return !!(await client.query(queries.CONTRIBUTOR_ECONOMIC_ACTIVIES_IS_EXONERATED, [contributor, activity, startingDate])).rows[0];
    } else {
      const branchIsExonerated = (await client.query(queries.BRANCH_IS_EXONERATED, [branch, startingDate])).rows[0];
      if (branchIsExonerated) return !!branchIsExonerated;
      return !!(await client.query(queries.CONTRIBUTOR_IS_EXONERATED, [contributor, startingDate])).rows[0];
    }
    return false;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};
