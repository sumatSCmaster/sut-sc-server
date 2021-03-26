import Pool from "@utils/Pool";
import queries from "@utils/queries";
import { fixatedAmount } from "@helpers/settlement";

const pool = Pool.getInstance();

const validateKey = async (key, client): Promise<[boolean, number]> => {
  const keyQuery = await client.query(`SELECT * FROM bank_api_keys WHERE api_key = $1`, [key]);
  return [keyQuery.rowCount > 0, keyQuery.rows[0].id_banco];
}

export const getSettlementsByRifAndRim = async (rif, rim, apiKey) => {
  const client = await pool.connect();
  try {
    const [valid, bankId] = await validateKey(apiKey, client);
    if(!valid){
      throw new Error('No autorizado')
    }
    const validateDocuments = (await client.query(`
      SELECT c.id_contribuyente, rm.id_registro_municipal
      FROM impuesto.registro_municipal rm
      INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = rm.id_contribuyente
      WHERE CONCAT(c.tipo_documento, '-', c.documento) = $1 AND rm.referencia_municipal = $2; 
    `, [rif, rim]));
    if(validateDocuments.rowCount > 0){
      throw new Error('Documento no encontrado.')
    }
    const debts = (await client.query(`
    WITH solicitud_cte AS (
      SELECT * FROM impuesto.solicitud WHERE id_contribuyente = $1 AND tipo_solicitud = 'IMPUESTO'
    )  
    SELECT s.id_solicitud as id, SUM( ROUND(monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO') ) ) as monto,
      STRING_AGG(DISTINCT r.descripcion_corta, ',' ORDER BY r.descripcion_corta) as ramos
    FROM solicitud_cte s
    INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state 
                FROM impuesto.evento_solicitud es 
                INNER JOIN solicitud_cte s ON s.id_solicitud = es.id_solicitud WHERE id_contribuyente = $1 GROUP BY es.id_solicitud
                ) ev ON s.id_solicitud = ev.id_solicitud
    INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id_solicitud AND l.id_solicitud = ev.id_solicitud
    INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
    INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_subramo
    WHERE ev.state = 'ingresardatos'
    GROUP BY s.id_solicitud
    `, [validateDocuments.rows[0].id_contribuyente]));

    return debts.rows;
  } finally {
    client.release();
  }
}

// id: id de la solicitud, referencia: referencia de pago, monto: monto de la referencia
export const payApplications = async (pagos: {id: number, referencia: string, monto: number}[], apiKey: string) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const [valid, idBanco] = await validateKey(apiKey, client);
    if(!valid){
      throw new Error('No autorizado')
    }
    for(let pago of pagos){
      await client.query(queries.SET_AMOUNT_IN_BS_BASED_ON_PETRO, [pago.id]);
      const solicitud = (await client.query(queries.APPLICATION_TOTAL_AMOUNT_BY_ID, [pago.id])).rows[0];
      if (pago.monto < fixatedAmount(+solicitud.monto_total)) {
        throw new Error(`Error de monto`)
      };
      await client.query(`
        INSERT INTO pago (id_procedimiento, referencia, monto, 
          fecha_de_pago, aprobado, 
          id_banco, id_banco_destino, 
          fecha_de_aprobacion, concepto, metodo_pago, id_usuario) 
        VALUES ($1, $2, $3, 
          (now() - interval '4 hours')::date, true, 
          $4, $4, 
          (now() - interval '4 hours'), 'IMPUESTO', 'PAGO POR BANCO', null);
      `, [pago.id, pago.referencia, pago.monto, idBanco]);
      
      (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [pago.id, 'aprobacionbanco_pi']))
        
    }

    
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
}