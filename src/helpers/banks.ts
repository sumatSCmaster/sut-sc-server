import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { validateProcedure } from './procedures';
import { validateFining } from './fines';
import { PoolClient } from 'pg';
import switchcase from '@utils/switch';
import { validateApplication, validateAgreementFraction } from './settlement';
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
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error al obtener los tramites',
    };
  } finally {
    client.release();
  }
};

export const validatePayments = async (body, user) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    console.log('a');
    const res = await client.query(queries.VALIDATE_PAYMENTS, [body]);
    console.log(res.rows);
    console.log(res.rows[0]);
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
          codigoTramite: el.codigotramite,
          codigoMulta: el.codigomulta,
          fechaDeAprobacion: el.fechadeaprobacion,
          tipoTramite: el.tipotramite,
          documento: el.documento,
          nacionalidad: el.nacionalidad,
          solicitudAprobada: el.solicitudAprobada || undefined,
          concepto: el.concepto,
        };
        await validationHandler({ concept: el.concepto, body: pagoValidado, user, client });
        return pagoValidado;
      })
    );
    await client.query('COMMIT');
    return {
      validatePayments: { data },
      message: 'Pago validado satisfactoriamente',
      status: 201,
    };
  } catch (e) {
    client.query('ROLLBACK');
    console.log('error ep', e);
    throw errorMessageExtractor(e);
  } finally {
    client.release();
  }
};

export const insertPaymentReference = async (payment: any, procedure: number, client: PoolClient) => {
  const { referencia, banco, costo, fecha, concepto } = payment;
  try {
    return await client.query(queries.INSERT_PAYMENT, [procedure, referencia, costo, banco, fecha, concepto]);
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

export const insertPaymentCashier = async (payment: any, procedure: number, client: PoolClient) => {
  const { referencia, banco, costo, fecha, concepto, metodoPago } = payment;
  try {
    return await client.query(queries.INSERT_PAYMENT_CASHIER, [procedure, referencia || null, costo, banco || null, fecha, concepto, metodoPago]);
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

const validateCases = switchcase({ IMPUESTO: validateApplication, TRAMITE: validateProcedure, MULTA: validateFining })(null);

const validationHandler = async ({ concept, body, user, client }) => {
  const executedMethod = switchcase({ IMPUESTO: validateApplication, CONVENIO: validateAgreementFraction, TRAMITE: validateProcedure, MULTA: validateFining })(null)(concept);
  return executedMethod ? await executedMethod(body, user, client) : { status: 400, message: 'No existe un caso de validacion definido con este concepto' };
};
