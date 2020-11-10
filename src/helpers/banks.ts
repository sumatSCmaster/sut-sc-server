import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { validateProcedure, getProcedureById } from './procedures';
import { validateFining } from './fines';
import { PoolClient } from 'pg';
import switchcase from '@utils/switch';
import { validateApplication, validateAgreementFraction, getApplicationsAndSettlementsById, getAgreementFractionById, getApplicationsAndSettlementsByIdNots, fixatedAmount } from './settlement';
import moment from 'moment';
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
      const process: any = await getProcedureById({ id, client });
      const fecha = (await client.query(`SELECT time AS "fechaInsercion" FROM evento_tramite WHERE id_tramite = $1 AND event ILIKE 'validar%' ORDER BY id_evento_tramite DESC LIMIT 1`, [id])).rows[0]?.fechaInsercion;
      process.fechaInsercion = moment(fecha).format('MM-DD-YYYY');
      return process;
    } catch (e) {
      throw e;
    }
  },
  IMPUESTO: async ({ id, client }: { id: number; client: PoolClient }) => {
    try {
      const process: any = await getApplicationsAndSettlementsByIdNots({ id, user: null }, client);
      const fecha = (await client.query(`SELECT time AS "fechaInsercion" FROM impuesto.evento_solicitud WHERE id_solicitud = $1 AND (event ILIKE 'aprobacion%' OR event ILIKE 'validar%') ORDER BY id_evento_solicitud DESC LIMIT 1`, [id])).rows[0]
        ?.fechaInsercion;
      process.fechaInsercion = moment(fecha).format('MM-DD-YYYY');
      return process;
    } catch (e) {
      throw e;
    }
  },
  CONVENIO: async ({ id, client }: { id: number; client: PoolClient }) => {
    try {
      const process: any = await getAgreementFractionById({ id });
      const fecha = (await client.query(`SELECT time AS "fechaInsercion" FROM impuesto.evento_fraccion WHERE id_fraccion = $1 AND (event ILIKE 'aprobacion%' OR event ILIKE 'validar%') ORDER BY id_evento_fraccion DESC LIMIT 1`, [id])).rows[0]
        ?.fechaInsercion;
      process.fechaInsercion = moment(fecha).format('MM-DD-YYYY');
      return process;
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
    if (!pagos.length) throw { status: 404, message: 'No existe la referencia suministrada en el banco suministrado' };
    await Promise.all(
      pagos.map(async (pago) => {
        console.log(pago);
        const action = typeProcess(pago.concepto);
        // console.log('if -> action', action);
        pago.procedimiento = await action({ id: pago.idProcedimiento, client });
        pago.procedimiento.pagos = await getPaymentsByProcessId({ id: pago.idProcedimiento, concept: pago.concepto, client });
        if (pago.concepto !== 'TRAMITE') {
          const targetId = pago.concepto === 'CONVENIO' ? (await client.query('SELECT id_solicitud FROM impuesto.convenio WHERE id_convenio = $1', [pago.procedimiento.idConvenio])).rows[0].id_solicitud : pago.procedimiento.id;
          pago.procedimiento.creditoFiscalGenerado = await getProcessFiscalCredit({ id: targetId, client });
        }
        delete pago.idProcedimiento;
      })
    );
    return { status: 200, pagos, message: 'Datos de referencia obtenidos' };
  } catch (e) {
    throw {
      status: e.status || 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || e.message || 'Error al obtener las referencias de pago',
    };
  } finally {
    client.release();
  }
};

const reversePaymentCase = switchcase({
  TRAMITE: async ({ id, client }: { id: number; client: PoolClient }) => {
    const REVERSARPAGO = 'reversarpago_tramite';
    try {
      await client.query(queries.DELETE_PAYMENT_REFERENCES_BY_PROCESS_AND_CONCEPT, [id, 'TRAMITE']);
      await client.query(queries.UPDATE_STATE, [id, REVERSARPAGO, null, null, null]);
      await client.query(queries.SET_NON_APPROVED_STATE_FOR_PROCEDURE, [id]);
      return await getProcedureById({ id, client });
    } catch (e) {
      throw e;
    }
  },
  IMPUESTO: async ({ id, client }: { id: number; client: PoolClient }) => {
    const REVERSARPAGO = 'reversarpago_solicitud';
    try {
      await client.query(queries.DELETE_PAYMENT_REFERENCES_BY_PROCESS_AND_CONCEPT, [id, 'IMPUESTO']);
      await client.query(queries.DELETE_FISCAL_CREDIT_BY_APPLICATION_ID, [id]);
      await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [id, REVERSARPAGO]);
      await client.query(queries.SET_NON_APPROVED_STATE_FOR_APPLICATION, [id]);
      await client.query(queries.NULLIFY_AMOUNT_IN_REVERSED_APPLICATION, [id]);
      return await getApplicationsAndSettlementsByIdNots({ id, user: null }, client);
    } catch (e) {
      throw e;
    }
  },
  CONVENIO: async ({ id, client }: { id: number; client: PoolClient }) => {
    const REVERSARPAGO = 'reversarpago_fraccion';
    const REVERSARPAGO_SOLICITUD = 'reversarpago_solicitud';
    try {
      await client.query(queries.DELETE_PAYMENT_REFERENCES_BY_PROCESS_AND_CONCEPT, [id, 'CONVENIO']);
      await client.query(queries.UPDATE_FRACTION_STATE, [id, REVERSARPAGO]);
      await client.query(queries.SET_NON_APPROVED_STATE_FOR_AGREEMENT_FRACTION, [id]);
      await client.query(queries.NULLIFY_AMOUNT_IN_REVERSED_FRACTION, [id]);

      const application = await getApplicationsAndSettlementsByIdNots(
        { id: (await client.query('SELECT id_solicitud FROM impuesto.fraccion INNER JOIN impuesto.convenio USING (id_convenio) WHERE id_fraccion = $1', [id])).rows[0].id_solicitud, user: null },
        client
      );
      await client.query(queries.DELETE_FISCAL_CREDIT_BY_APPLICATION_ID, [id]);
      if (application.estado === 'finalizado') {
        await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id, REVERSARPAGO_SOLICITUD]);
        await client.query(queries.SET_NON_APPROVED_STATE_FOR_APPLICATION, [application.id]);
        await client.query(queries.NULLIFY_AMOUNT_IN_REVERSED_APPLICATION, [application.id]);
      }
      return await getAgreementFractionById({ id });
    } catch (e) {
      throw e;
    }
  },
})(null);

export const reversePaymentForProcess = async ({ id, concept }: { id: number; concept: string }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const action = reversePaymentCase(concept);
    const procedimiento = await action({ id, client });
    await client.query('COMMIT');
    return { status: 200, message: 'Pagos reversados correctamente', procedimiento };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al reversar pago de procedimiento',
    };
  } finally {
    client.release();
  }
};

const getPaymentsByProcessId = async ({ id, concept, client }: { id: number; concept: string; client: PoolClient }) => {
  try {
    const pagos = (
      await client.query(
        'SELECT id_pago AS id, referencia, id_procedimiento AS "idProcedimiento", monto, fecha_de_pago AS "fechaDePago", aprobado, id_banco AS banco, fecha_de_aprobacion AS "fechaAprobacion", concepto, metodo_pago AS "metodoPago", id_usuario AS usuario, id_banco_destino AS "bancoDestino" FROM pago WHERE id_procedimiento = $1 AND concepto = $2',
        [id, concept]
      )
    ).rows;
    return pagos;
  } catch (e) {
    throw e;
  }
};

const getProcessFiscalCredit = async ({ id, client }: { id: number; client: PoolClient }) => {
  try {
    const creditoGenerado = (await client.query('SELECT id_credito_fiscal AS id, credito, fecha_creacion AS "fechaCreacion" FROM impuesto.credito_fiscal WHERE id_solicitud = $1', [id])).rows;
    return creditoGenerado;
  } catch (e) {
    throw e;
  }
};

export const approveSinglePayment = async (id, user) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const res = await client.query(queries.APPROVE_PAYMENT, [id]);
    if (res.rowCount > 0) {
      const pago = res.rows[0];
      console.log(pago);
      const tramiteInfo = pago.concepto === 'TRAMITE' ? (await client.query(queries.PAYMENT_PROCEDURE_INFO, [id])).rows[0] : null;
      const multaInfo = pago.concepto === 'MULTA' ? (await client.query(queries.PAYMENT_FINE_INFO, [id])).rows[0] : null;

      if (pago.concepto === 'IMPUESTO') {
        if ((await client.query(queries.PAYMENTS_ALL_APPROVED, [id])).rows[0].alltrue === true) {
          await client.query(queries.UPDATE_PAYMENT_SETTLEMENT, [id]);
        }
      }

      const solicitudInfo = pago.concepto === 'IMPUESTO' ? (await client.query(queries.PAYMENT_SETTLEMENT_INFO, [id])).rows[0] : null;

      if (pago.concepto === 'CONVENIO') {
        await client.query(queries.PAYMENT_CONV_UPDATE, [id]);
      }
      const convenioInfo = pago.concepto === 'CONVENIO' ? (await client.query(queries.PAYMENT_CONV_INFO, [id])).rows[0] : null;
      if (pago.concepto === 'RETENCION') {
        if ((await client.query(queries.PAYMENTS_ALL_APPROVED, [id])).rows[0].alltrue === true) {
          await client.query(queries.UPDATE_PAYMENT_SETTLEMENT, [id]);
        }
      }

      const retencionInfo =
        pago.concepto === 'RETENCION'
          ? (
              await client.query(
                `select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento from pago
                      INNER JOIN impuesto.solicitud ON pago.id_procedimiento = solicitud.id_solicitud
                      INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                      where pago.id_pago = $1`,
                [id]
              )
            ).rows[0]
          : null;
      const body = {
        id: pago.id,
        monto: pago.monto,
        idBanco: pago.id_banco,
        aprobado: pago.aprobado,
        idTramite: pago.id_procedimiento,
        pagoPrevio: tramiteInfo?.pago_previo,
        referencia: pago.referencia,
        fechaDePago: pago.fecha_de_pago,
        codigoTramite: tramiteInfo?.codigoTramite,
        codigoMulta: multaInfo?.codigo_multa,
        fechaDeAprobacion: pago.fecha_de_aprobacion,
        tipoTramite: tramiteInfo?.tipotramite || multaInfo?.id_tipo_tramite,
        documento: solicitudInfo?.documento || convenioInfo?.documento || retencionInfo?.documento,
        nacionalidad: solicitudInfo?.nacionalidad || convenioInfo?.nacionalidad || retencionInfo?.nacionalidad,
        solicitudAprobada: solicitudInfo?.solicitudAprobada || convenioInfo?.solicitudAprobada || retencionInfo?.solicitudAprobada || undefined,
        concepto: pago.concepto,
      };
      await validationHandler({ concept: pago.concepto, body: body, user, client });
      await client.query('COMMIT');
      return { body, status: 200 };
    } else {
      await client.query('ROLLBACK');
      return { message: 'Pago no hallado', status: 404 };
    }
  } catch (e) {
    await client.query('ROLLBACK');
    throw { e, status: 500 };
  } finally {
    client.release();
  }
};

export const validatePayments = async (body, user) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
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
    INNER JOIN banco b ON b.id_banco = p.id_banco
    WHERE s."tipoSolicitud" IN ('IMPUESTO', 'RETENCION') AND s.state = 'validando' ORDER BY id_procedimiento, id_pago;`);
    let convData = await client.query(`
    SELECT s.id, s.fecha, fs.state, c.documento, c.tipo_documento AS "tipoDocumento", s."tipoSolicitud", p.id_pago, p.referencia, p.monto, p.fecha_de_pago, b.id_banco, p.aprobado
    FROM impuesto.solicitud_state s
    INNER JOIN impuesto.convenio conv ON conv.id_solicitud = s.id
    INNER JOIN impuesto.fraccion_state fs ON fs.idconvenio = conv.id_convenio
    INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = s.id_contribuyente
    INNER JOIN pago p ON p.id_procedimiento = s.id
    INNER JOIN banco b ON b.id_banco = p.id_banco
    WHERE s."tipoSolicitud" IN ('CONVENIO') AND s.state = 'ingresardatos' ORDER BY id_procedimiento, id_pago;
    `)
    data.rows = data.rows.concat(convData.rows)
    let montosSolicitud = (
      await client.query(`
    SELECT l.id_solicitud, SUM(monto) as monto
    FROM impuesto.solicitud_state s 
    INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id 
    WHERE s.state = 'validando' OR s.state = 'ingresardatos'
    GROUP BY l.id_solicitud;`)
    ).rows;
    data =
      data.rowCount > 0
        ? data.rows.reduce((prev, next) => {
            let index = prev.findIndex((row) => row.id === next.id);
            let montoSolicitud = montosSolicitud.find((montoRow) => next.id === montoRow.id_solicitud)?.monto;
            if (index === -1) {
              prev.push({
                id: next.id,
                fechaSolicitud: next.fecha,
                estado: next.state,
                tipoDocumento: next.tipoDocumento,
                documento: next.documento,
                tipoSolicitud: next.tipoSolicitud,
                monto: montoSolicitud ? montoSolicitud : next.monto ,
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

    if (fixatedAmount(sum) > fixatedAmount(fixatedAmount(paymentsWithOutUpdatee.reduce((prev, next) => prev + +next.monto, 0)) + fixatedAmount(+monto))) {
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
