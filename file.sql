WITH liquidaciones AS (
    SELECT DISTINCT
        l.id_solicitud
    FROM (( SELECT DISTINCT
                l.id_liquidacion,
                l.id_solicitud,
                l.id_subramo,
                l.monto
            FROM
                impuesto.liquidacion l
            WHERE
                id_solicitud IS NOT NULL
                AND id_solicitud IN (
                    SELECT
                        id_solicitud
                    FROM
                        impuesto.solicitud
                    WHERE
                        fecha_aprobado BETWEEN $1
                        AND $2
                        AND tipo_solicitud != 'CONVENIO')
                UNION
                SELECT
                    l.id_liquidacion,
                    l.id_solicitud,
                    l.id_subramo,
                    l.monto
                FROM
                    impuesto.liquidacion l
                WHERE
                    id_solicitud IS NULL
                    AND fecha_liquidacion BETWEEN $3
                    AND $4
                ORDER BY
                    id_solicitud)) l
        LEFT JOIN (
            SELECT
                *,
                s.id_solicitud AS id_solicitud_q
            FROM
                impuesto.solicitud s
                INNER JOIN (
                    SELECT
                        es.id_solicitud,
                        impuesto.solicitud_fsm (es.event::text ORDER BY es.id_evento_solicitud) AS state
                    FROM
                        impuesto.evento_solicitud es
                    GROUP BY
                        es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
                WHERE
                    fecha_aprobado BETWEEN $5
                    AND $6) se ON l.id_solicitud = se.id_solicitud_q
)
    SELECT
        id_banco,
        banco,
        SUM(monto) AS monto
FROM (
    SELECT
        p.id_banco_destino AS "id_banco",
        b.nombre AS banco,
        SUM(p.monto) AS monto
    FROM
        pago p
        INNER JOIN banco b ON b.id_banco = p.id_banco_destino
    WHERE
        p.concepto IN ('IMPUESTO', 'RETENCION')
        AND p.aprobado = TRUE
        AND p.metodo_pago = 'TRANSFERENCIA'
        AND p.id_procedimiento IN (
            SELECT
                *
            FROM
                liquidaciones)
        GROUP BY
            p.id_banco_destino,
            b.nombre
        UNION
        SELECT
            p.id_banco_destino AS "id_banco",
            b.nombre AS banco,
            SUM(ROUND(p.monto)) AS monto
        FROM (
            SELECT
                *
            FROM
                pago p
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
            WHERE
                p.concepto = 'TRAMITE'
                AND p.aprobado = TRUE
                AND tt.id_institucion = 9
                AND p.metodo_pago = 'TRANSFERENCIA'
                AND p.fecha_de_aprobacion BETWEEN $7
                AND $8) p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
        GROUP BY
            p.id_banco_destino,
            b.nombre
        UNION
        SELECT
            p.id_banco_destino AS "id_banco",
            b.nombre AS banco,
            SUM(p.monto) AS monto
        FROM
            pago p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            INNER JOIN impuesto.fraccion f ON f.id_fraccion = p.id_procedimiento
        WHERE
            p.concepto = 'CONVENIO'
            AND P.metodo_pago = 'TRANSFERENCIA'
            AND p.fecha_de_aprobacion BETWEEN $9
            AND $10
        GROUP BY
            p.id_banco_destino,
            b.nombre) x
GROUP BY
    id_banco,
    banco;

