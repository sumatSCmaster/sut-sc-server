import queries from '@utils/queries';
import { errorMessageExtractor } from './errors';
import { renderFile } from 'pug';
import { resolve } from 'path';
import Pool from '@utils/Pool';

const pool = Pool.getInstance();

export const createRepotRMP = async () =>{
  const client = await pool.connect();
  try {

    let transferDiffNow = (await client.query(queries.GET_ALL_TRANSFERS_DIFF_NOW_TOTAL)).rows;
    let cash = (await client.query(queries.GET_ALL_CASH_TOTAL)).rows;
    let payDiffCash = (await client.query(queries.GET_ALL_PAY_DIFF_CASH_TOTAL)).rows;

    const html = renderFile(resolve(__dirname, `../views/planillas/hacienda-RMP.pug`), {
      cash,
      transferDiffNow,
      payDiffCash
    });

    return pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' })
    
  }  catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: error,
    };
  } finally {
    client.release();
  }

}