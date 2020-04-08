import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { validateProcedure } from './procedures';
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
      res.rows[0].validate_payments.data.map(async el => {
        const pagoValidado = {
          id: el.id,
          monto: el.monto,
          idBanco: el.idbanco,
          aprobado: el.aprobado,
          idTramite: el.idtramite,
          pagoPrevio: el.pagoprevio,
          referencia: el.referencia,
          fechaDePago: el.fechadepago,
          codigoTramite: el.codigotramite,
          fechaDeAprobacion: el.fechadeaprobacion,
          tipoTramite: el.tipotramite,
        };
        await validateProcedure(pagoValidado, user);
        return pagoValidado;
      })
    );
    console.log(data);
    client.query('COMMIT');
    return {
      validatePayments: { data },
      message: 'Pago validado satisfactoriamente',
      status: 201,
    };
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const insertPaymentReference = async (payment, procedureId, client) => {
  const { referencia, banco, costo, fecha } = payment;
  return await client.query(queries.INSERT_PAYMENT, [procedureId, referencia, costo, banco, fecha]).catch(error => {
    console.log(error);
    throw {
      error,
      message: errorMessageGenerator(error) || 'Error al insertar el pago',
    };
  });
};
