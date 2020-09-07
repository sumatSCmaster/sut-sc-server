import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { validateProcedure, getProcedureById } from './procedures';
import { validateFining } from './fines';
import { PoolClient } from 'pg';
import switchcase from '@utils/switch';
import { validateApplication, validateAgreementFraction, getApplicationsAndSettlementsById, getAgreementFractionById, getApplicationsAndSettlementsByIdNots } from './settlement';
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

const typeProcess = switchcase({
  TRAMITE: async ({ id, client }: { id: number; client: PoolClient }) => {
    try {
      return await getProcedureById({ id, client });
    } catch (e) {
      throw e;
    }
  },
  IMPUESTO: async ({ id, client }: { id: number; client: PoolClient }) => {
    try {
      return await getApplicationsAndSettlementsByIdNots({ id, user: null }, client);
    } catch (e) {
      throw e;
    }
  },
  CONVENIO: async ({ id, client }: { id: number; client: PoolClient }) => {
    try {
      const fractionInstance = await getAgreementFractionById({ id });
      return await getApplicationsAndSettlementsByIdNots({ id: (await client.query('SELECT id_solicitud FROM impuesto.convenio WHERE id_convenio = $1', [fractionInstance.idConvenio])).rows[0].id_solicitud, user: null }, client);
    } catch (e) {
      throw e;
    }
  },
})(null);

export const paymentReferenceSearch = async ({ reference, bank }) => {
  const client = await pool.connect();
  console.log(reference, bank);
  try {
    if (!reference) throw { status: 400, message: 'Debe proporcionar la referencia a ser buscada' };
    if (!bank) throw { status: 400, message: 'Debe proporcionar el banco correspondiente a la referencia' };
    const pagos = (
      await client.query(
        'SELECT id_pago AS id, referencia, id_procedimiento AS "idProcedimiento", monto, fecha_de_pago AS "fechaDePago", aprobado, id_banco AS banco, fecha_de_aprobacion AS "fechaAprobacion", concepto, metodo_pago AS "metodoPago", id_usuario AS usuario, id_banco_destino AS "bancoDestino" FROM pago WHERE referencia = $1 AND id_banco_destino = $2',
        [reference, bank]
      )
    ).rows;
    await Promise.all(
      pagos.map(async (pago) => {
        console.log(pago);
        const action = typeProcess(pago.concepto);
        // console.log('if -> action', action);
        pago.procedimiento = await action({ id: pago.idProcedimiento, client });
        delete pago.idProcedimiento;
      })
    );
    if (!pagos.length) throw { status: 404, message: 'No existe la referencia suministrada en el banco suministrado' };
    return { status: 200, pagos, message: 'Datos de referencia obtenidos' };
  } catch (e) {
    console.log('if -> e', e);
    throw {
      status: e.status || 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || e.message || 'Error al obtener las referencias de pago',
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
          nacionalidad: el.nacionalidad || el.tipo_documento,
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
  const { referencia, banco, costo, fecha, concepto, user, destino } = payment;
  try {
    return await client.query(queries.INSERT_PAYMENT, [procedure, referencia, costo, banco, fecha, concepto, destino || banco, user]);
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

export const insertPaymentCashier = async (payment: any, procedure: number, client: PoolClient) => {
  const { referencia, banco, costo, fecha, concepto, metodoPago, user, destino } = payment;
  try {
    return await client.query(queries.INSERT_PAYMENT_CASHIER, [procedure, referencia || null, costo, banco || null, fecha, concepto, metodoPago, user, destino || banco]);
  } catch (e) {
    throw errorMessageExtractor(e);
  }
};

const validateCases = switchcase({ IMPUESTO: validateApplication, TRAMITE: validateProcedure, MULTA: validateFining })(null);

const validationHandler = async ({ concept, body, user, client }) => {
  const executedMethod = switchcase({ IMPUESTO: validateApplication, RETENCION: validateApplication, CONVENIO: validateAgreementFraction, TRAMITE: validateProcedure, MULTA: validateFining })(null)(concept);
  return executedMethod ? await executedMethod(body, user, client) : { status: 400, message: 'No existe un caso de validacion definido con este concepto' };
};

export const listTaxPayments = async () => {
  const client = await pool.connect();
  try {
    let data = await client.query(`
    SELECT s.*, p.*, b.id_banco, c.documento, c.tipo_documento AS "tipoDocumento" 
    FROM impuesto.solicitud_state s 
    INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = s.id_contribuyente 
    INNER JOIN pago p ON p.id_procedimiento = s.id 
    INNER JOIN banco b ON b.id_banco = p.id_banco AND b.id_banco = p.id_banco_destino 
    WHERE s."tipoSolicitud" IN ('IMPUESTO', 'RETENCION') AND s.state = 'validando' ORDER BY id_procedimiento, id_pago;`);
    let montosSolicitud = (
      await client.query(`
    SELECT l.id_solicitud, SUM(monto) as monto
    FROM impuesto.solicitud_state s 
    INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id 
    WHERE s.state = 'validando' 
    GROUP BY l.id_solicitud;`)
    ).rows;
    data =
      data.rowCount > 0
        ? data.rows.reduce((prev, next) => {
            let index = prev.findIndex((row) => row.id === next.id);
            if (index === -1) {
              prev.push({
                id: next.id,
                fechaSolicitud: next.fecha,
                estado: next.state,
                tipoDocumento: next.tipoDocumento,
                documento: next.documento,
                monto: montosSolicitud.find((montoRow) => next.id === montoRow.id_solicitud)?.monto,
                pagos: [
                  {
                    id: next.id_pago,
                    referencia: next.referencia,
                    monto: next.monto,
                    fechaDePago: next.fecha_de_pago,
                    banco: next.id_banco,
                    aprobado: next.aprobado,
                  },
                ],
              });
            } else {
              prev[index].pagos.push({
                id: next.id_pago,
                referencia: next.referencia,
                monto: next.monto,
                fechaDePago: next.fecha_de_pago,
                banco: next.id_banco,
                aprobado: next.aprobado,
              });
            }
            return prev;
          }, [])
        : [];
    return { status: 200, data };
  } catch (e) {
    console.log(e);
    throw e;
  } finally {
    client.release();
  }
};

export const updatePayment = async ({ id, solicitud, fechaDePago, referencia, monto, banco }) => {
  const client = await pool.connect();
  try {
    let paymentsWithOutUpdatee = (
      await client.query(
        `
      SELECT * FROM pago 
      WHERE concepto =  'IMPUESTO' AND  id_procedimiento = $1 AND id_pago != $2`,
        [solicitud, id]
      )
    ).rows;

    let sum = (
      await client.query(
        `
      SELECT l.id_solicitud, SUM(monto) as monto
      FROM impuesto.solicitud_state s 
      INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id 
      WHERE s.state = 'validando' AND l.id_solicitud = $1
      GROUP BY l.id_solicitud;`,
        [solicitud]
      )
    ).rows[0].monto;

    if (sum > paymentsWithOutUpdatee.reduce((prev, next) => prev + +next.monto, 0) + +monto) {
      throw {
        status: 400,
        message: 'El monto indicado no es suficiente para cubrir la solicitud',
      };
    }
    let res = await client.query(
      'UPDATE pago SET fecha_de_pago = $1, referencia = $2, monto = $3, id_banco = $5, id_banco_destino = $5 WHERE id_pago = $4 AND aprobado = false RETURNING id_pago AS id, referencia, monto, fecha_de_pago AS "fechaDePago", id_banco as banco, aprobado;',
      [fechaDePago, referencia, monto, id, banco]
    );
    return { status: 200, data: res.rows };
  } catch (e) {
    console.log(e);
    throw e;
  } finally {
    client.release();
  }
};

export const addPayment = async ({ id, fechaDePago, referencia, monto, banco }) => {
  const client = await pool.connect();
  try {
    const id_usuario = (await client.query(`SELECT id_usuario FROM pago WHERE id_procedimiento = $1 AND concepto = 'IMPUESTO';`, [id])).rows[0].id_usuario;
    let res = await client.query(
      `INSERT INTO pago (id_procedimiento, referencia, monto, fecha_de_pago, id_banco, id_banco_destino, concepto, id_usuario)
                  VALUES ($1, $2, $3, $4, $5, $5, $6, $7) RETURNING id_pago AS id, referencia, monto, fecha_de_pago AS "fechaDePago", id_banco as banco, aprobado;`,
      [id, referencia, monto, fechaDePago, banco, 'IMPUESTO', id_usuario]
    );
    return { status: 200, data: res.rows };
  } catch (e) {
    console.log(e);
    throw e;
  } finally {
    client.release();
  }
};
