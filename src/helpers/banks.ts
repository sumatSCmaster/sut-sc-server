import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { validateProcedure } from './procedures';
import { validateFining } from './fines';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

export const getAllBanks = async () => {
  const client = await pool.connect();
  try {
    const response = await client.query(queries.GET_ALL_BANKS);
    return {
      status: 200,
      banks: response.rows,
      message: 'Bancos obtenidos satisfactoriamente',
    };
  } catch (e) {
    throw {
      status: 500,
      error: e,
      message: errorMessageGenerator(e) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

//TODO: enviar state actual de cada tramite que se valido
export const validatePayments = async (body, user) => {
  const client = await pool.connect();
  try {
    client.query('BEGIN');
    const res = await client.query(queries.VALIDATE_PAYMENTS, [body]);
    const data = await Promise.all(
      res.rows[0].validate_payments.data.map(async (el) => {
        const pagoValidado = {
          id: el.id,
          monto: el.monto,
          idBanco: el.idbanco,
          aprobado: el.aprobado,
          idTramite: el.idprocedimiento,
          pagoPrevio: el.pagoprevio,
          referencia: el.referencia,
          fechaDePago: el.fechadepago,
          codigoTramite: el.codigotramite || el.codigomulta,
          fechaDeAprobacion: el.fechadeaprobacion,
          tipoTramite: el.tipotramite,
        };
        console.log('ajajajaja puta');
        el.sufijo !== 'ml' ? await validateProcedure(pagoValidado, user) : await validateFining(pagoValidado, user);
        return pagoValidado;
      })
    );
    console.log('ola jaja');
    client.query('COMMIT');
    return {
      validatePayments: { data },
      message: 'Pago validado satisfactoriamente',
      status: 201,
    };
  } catch (e) {
    console.log(e);
    throw e;
  } finally {
    client.release();
  }
};

export const insertPaymentReference = async (payment: any, procedure: number, client: PoolClient) => {
  const { referencia, banco, costo, fecha, concepto } = payment;
  return await client.query(queries.INSERT_PAYMENT, [procedure, referencia, costo, banco, fecha, concepto]).catch((error) => {
    throw error;
  });
};
