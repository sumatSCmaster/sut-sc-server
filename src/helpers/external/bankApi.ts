import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { fixatedAmount } from "@helpers/settlement";
import { mainLogger } from "@utils/logger";

const pool = Pool.getInstance();

const validateKey = async (key, client): Promise<[boolean, number]> => {
  const keyQuery = await client.query(`SELECT * FROM impuesto.bank_api_keys WHERE api_key = $1`, [key]);
  return [keyQuery.rowCount > 0, keyQuery.rows[0].id_banco];
}

export const getSettlementsByRifAndRim = async (rif, rim, apiKey) => {
  const client = await pool.connect();
  try {
    mainLogger.info(`Rif ${rif} rim ${rim}`)
    const [valid, bankId] = await validateKey(apiKey, client);
    mainLogger.info(`Valid ${valid} Bankid ${bankId}`)
    if(!valid){
      throw new Error('No autorizado')
    }
    const validateDocuments = (await client.query(`
      SELECT c.id_contribuyente, rm.id_registro_municipal
      FROM impuesto.registro_municipal rm
      INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = rm.id_contribuyente
      WHERE CONCAT(c.tipo_documento, '-', c.documento) = $1 AND rm.referencia_municipal = $2;
    `, [rif, rim]));
    mainLogger.info(`Validate docs ${JSON.stringify(validateDocuments.rows[0])}`)
    if(validateDocuments.rowCount === 0){
      throw new Error('Error de parámetros')
    }
    const debts = (await client.query(`
    WITH solicitud_cte AS (
      SELECT * FROM impuesto.solicitud WHERE id_contribuyente = $1 AND tipo_solicitud = 'IMPUESTO'
    )  
    SELECT s.id_solicitud as id, c.razon_social AS "razonSocial", SUM( ROUND(monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO') ) ) as monto,
      STRING_AGG(DISTINCT r.descripcion_corta, ',' ORDER BY r.descripcion_corta) as ramos
    FROM solicitud_cte s
    INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state 
                FROM impuesto.evento_solicitud es 
                INNER JOIN solicitud_cte s ON s.id_solicitud = es.id_solicitud WHERE id_contribuyente = $1 GROUP BY es.id_solicitud
                ) ev ON s.id_solicitud = ev.id_solicitud
    INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id_solicitud AND l.id_solicitud = ev.id_solicitud
    INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = l.id_registro_municipal
    INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = s.id_contribuyente AND c.id_contribuyente = rm.id_contribuyente
    INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
    INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo
    WHERE ev.state = 'ingresardatos'
    GROUP BY s.id_solicitud, c.razon_social
    `, [validateDocuments.rows[0].id_contribuyente]));
    
    return debts.rows;
  } finally {
    client.release();
  }
}
export const payApplications = async (pagos: {id: number, referencia: string, monto: number}[], apiKey: string) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const [valid, idBanco] = await validateKey(apiKey, client);
    mainLogger.info(`${valid} ${idBanco}`)
    if(!valid){
      throw new Error('No autorizado')
    }
    for(let pago of Array.from(pagos)){
      

      await client.query(queries.SET_AMOUNT_IN_BS_BASED_ON_PETRO, [pago.id]);
      const solicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [pago.id])).rows[0];
      mainLogger.info(`${JSON.stringify(solicitud)}`)
      if (pago.monto < fixatedAmount(+solicitud.monto_total)) {
        throw new Error(`Error de monto`)
      };
      const pagos = await client.query(`
        INSERT INTO pago (id_procedimiento, referencia, monto, 
          fecha_de_pago, aprobado, 
          id_banco, id_banco_destino, 
          fecha_de_aprobacion, concepto, metodo_pago, id_usuario) 
        VALUES ($1, $2, $3, 
          (now() - interval '4 hours')::date, true, 
          $4, $4, 
          (now() - interval '4 hours'), 'IMPUESTO', 'PAGO POR BANCO', null) RETURNING *;
      `, [pago.id, pago.referencia, pago.monto, idBanco]);
      
      (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [pago.id, 'aprobacionbanco_pi']))
      mainLogger.info(`Complete ${JSON.stringify(pagos.rows)}`)
    }
    await client.query('COMMIT');
    return true;
  } catch(e) {
    await client.query('ROLLBACK');
    throw new Error(e.message || 'Error de servidor');
  } finally {
    client.release();
  }
}

export const checkBankPayment = async (referencia: string, apiKey: string) => {
  const client = await pool.connect();
  mainLogger.info('checkBankPayment')
  try {
    await client.query('BEGIN');
    mainLogger.info('checkBankPayment BEGIN')
    const [valid, idBanco] = await validateKey(apiKey, client);
    mainLogger.info(`${valid} ${idBanco}`)
    if(!valid){
      throw new Error('No autorizado')
    }
    const pago = await client.query(`SELECT * FROM pago WHERE referencia = $1 AND id_banco = $2;`, [referencia, idBanco])
    mainLogger.info('checkBankPayment PAGO')
    await client.query('COMMIT');
    return pago.rowCount > 0;
  } catch(e) {
    mainLogger.error(e.message)
    await client.query('ROLLBACK');
    throw new Error(e.message || 'Error de servidor');
  } finally {
    client.release();
  }
}

export const rollbackPayment = async (referencia: string, apiKey: string) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const [valid, idBanco] = await validateKey(apiKey, client);
    mainLogger.info(`${valid} ${idBanco}`)
    if(!valid){
      throw new Error('No autorizado')
    }
    const pago = await client.query(`SELECT * FROM pago WHERE referencia = $1 AND id_banco = $2;`, [referencia, idBanco]);
    if(!pago.rows[0]) throw new Error('Referencia no encontrada')
    await client.query(`UPDATE impuesto.solicitud SET aprobado = false, fecha_aprobado = NULL WHERE id_solicitud = $1`, [pago.rows[0].id_procedimiento]);
    await client.query(`DELETE FROM impuesto.evento_solicitud WHERE id_solicitud = $1 AND event = 'aprobacionbanco_pi'`, [pago.rows[0].id_procedimiento]);
    await client.query(`DELETE FROM pago WHERE id_pago = $1`, [pago.rows[0].id_pago])
    await client.query('COMMIT');
    return true;
  } catch(e) {
    await client.query('ROLLBACK');
    throw new Error(e.message || 'Error de servidor');
  } finally {
    client.release();
  }
}