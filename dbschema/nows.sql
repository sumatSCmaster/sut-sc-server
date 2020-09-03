
-- cambiar NOWs

CREATE OR REPLACE FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, (NOW() - interval '4 hours'));
    
    RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.fraccion SET aprobado = _aprobado WHERE id_fraccion = _id_fraccion;
                UPDATE impuesto.fraccion SET fecha_aprobado = (NOW() - interval '4 hours') WHERE id_fraccion = _id_fraccion;
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, (NOW() - interval '4 hours'));
    
    RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.fraccion SET aprobado = _aprobado WHERE id_fraccion = _id_fraccion;
                UPDATE impuesto.fraccion SET fecha_aprobado = (NOW() - interval '4 hours') WHERE id_fraccion = _id_fraccion;
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION impuesto.complete_solicitud_state(_id_solicitud integer, event text, _datos json DEFAULT NULL::json, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_solicitud values (default, _id_solicitud, event, (NOW() - interval '4 hours'));
    
    RETURN QUERY SELECT ss.state FROM impuesto.solicitud_state ss WHERE id = _id_solicitud;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.solicitud SET aprobado = _aprobado WHERE id_solicitud = _id_solicitud;
                UPDATE impuesto.solicitud SET fecha_aprobado = (NOW() - interval '4 hours')  WHERE id_solicitud = _id_solicitud;
    END IF;
  END;
$$;

ALTER TABLE impuesto.liquidacion ALTER COLUMN fecha_liquidacion SET DEFAULT (NOW() - interval '4 hours');

ALTER TABLE impuesto.contribuyente ALTER COLUMN fecha_ultima_actualizacion SET DEFAULT (NOW() - interval '4 hours');

ALTER TABLE impuesto.credito_fiscal ALTER COLUMN fecha_creacion SET DEFAULT (NOW() - interval '4 hours');

CREATE OR REPLACE FUNCTION impuesto.insert_fraccion(_id_convenio integer, _monto numeric, _porcion integer, _fecha date) RETURNS SETOF impuesto.fraccion
    LANGUAGE plpgsql
    AS $$
DECLARE
    fraccionRow impuesto.fraccion%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.fraccion (id_convenio, monto, porcion, fecha) VALUES (_id_convenio,  _monto, _porcion, _fecha) RETURNING * into fraccionRow;
        
        INSERT INTO impuesto.evento_fraccion values (default, fraccionRow.id_fraccion, 'iniciar', (NOW() - interval '4 hours'));
            
        RETURN QUERY SELECT * FROM impuesto.fraccion WHERE id_fraccion=fraccionRow.id_fraccion;
                
        RETURN;
    END;
$$;

CREATE OR REPLACE FUNCTION impuesto.insert_solicitud(_id_usuario integer, _id_tipo_tramite integer, _id_contribuyente integer) RETURNS SETOF impuesto.solicitud
    LANGUAGE plpgsql
    AS $$
DECLARE
    solicitudRow impuesto.solicitud%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.solicitud (id_usuario, aprobado, fecha, id_tipo_tramite, id_contribuyente) VALUES (_id_usuario, false, (NOW() - interval '4 hours'), _id_tipo_tramite, _id_contribuyente) RETURNING * INTO solicitudRow;

        INSERT INTO impuesto.evento_solicitud values (default, solicitudRow.id_solicitud, 'iniciar', (NOW() - interval '4 hours'));   

        RETURN QUERY SELECT * FROM impuesto.solicitud WHERE id_solicitud=solicitudRow.id_solicitud;

        RETURN;
    END;
$$;

CREATE OR REPLACE FUNCTION impuesto.update_fraccion_state(_id_fraccion integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, (NOW() - interval '4 hours'));
          
        RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;
                  
			
    END;
$$;

CREATE OR REPLACE FUNCTION impuesto.update_solicitud_state(_id_solicitud integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_solicitud values (default, _id_solicitud, event, (NOW() - interval '4 hours'));
          
        RETURN QUERY SELECT ss.state FROM impuesto.solicitud_state ss WHERE id = _id_solicitud;
                  
			
    END;
$$;

CREATE OR REPLACE FUNCTION public.complete_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json, _url_certificado character varying DEFAULT NULL::character varying, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, (NOW() - interval '4 hours'));
        RETURN QUERY SELECT multa_state.state FROM multa_state WHERE id = _id_multa;
        IF _datos IS NOT NULL THEN
                    UPDATE multa SET datos = _datos WHERE id_multa = _id_multa;
                            END IF;
        IF _url_certificado IS NOT NULL THEN
                    UPDATE multa SET url_certificado = _url_certificado WHERE id_multa = _id_multa;
                            END IF;
        IF _aprobado IS NOT NULL THEN
                    UPDATE multa SET aprobado = _aprobado WHERE id_multa = _id_multa;
                            END IF;
    END;
$$;

CREATE OR REPLACE FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _url_certificado character varying DEFAULT NULL::character varying, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_tramite values (default, _id_tramite, event, (NOW() - interval '4 hours'));
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramite SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _url_certificado IS NOT NULL THEN
                                      UPDATE tramite SET url_certificado = _url_certificado WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _aprobado IS NOT NULL THEN
                                      UPDATE tramite SET aprobado = _aprobado WHERE id_tramite = _id_tramite;
									  UPDATE tramite SET fecha_culminacion = (NOW() - interval '4 hours') WHERE id_tramite = _id_tramite;
                                              END IF;
                                                      END;
                                                              $$;

CREATE OR REPLACE FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.casos_sociales_state
    LANGUAGE plpgsql
    AS $$
DECLARE
    caso caso_social%ROWTYPE;
	response casos_sociales_state%ROWTYPE;
    BEGIN
        INSERT INTO caso_social (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into caso;
        
            INSERT INTO evento_caso_social values (default, caso.id_caso, 'iniciar', (NOW() - interval '4 hours'));
            
                RETURN QUERY SELECT * FROM casos_sociales_state WHERE id=caso.id_caso ORDER BY casos_sociales_state.fechacreacion;
                
                    RETURN;
                    END;
                    $$;

CREATE OR REPLACE FUNCTION public.insert_multa(_id_tipo_tramite integer, datos json, _nacionalidad character varying, _cedula bigint, _id_usuario integer) RETURNS SETOF public.multa_state
    LANGUAGE plpgsql
    AS $$
DECLARE
    multa multa%ROWTYPE;
	response multa_state%ROWTYPE;
    BEGIN
        INSERT INTO multa (id_tipo_tramite, datos, nacionalidad, cedula, id_usuario) VALUES (_id_tipo_tramite, datos, _nacionalidad, _cedula, _id_usuario) RETURNING * into multa;
        
        INSERT INTO evento_multa values (default, multa.id_multa, 'iniciar', (NOW() - interval '4 hours'));
            
        RETURN QUERY SELECT * FROM multa_state WHERE id=multa.id_multa ORDER BY multa_state.fechacreacion;
                
        RETURN;
    END;
$$;

ALTER TABLE evento_tramite ALTER COLUMN "time" SET DEFAULT (NOW() - interval '4 hours');

CREATE OR REPLACE FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.tramites_state_with_resources
    LANGUAGE plpgsql
    AS $$
DECLARE
    tramite tramite%ROWTYPE;
	response tramites_state_with_resources%ROWTYPE;
    BEGIN
        INSERT INTO tramite (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into tramite;
        
            INSERT INTO evento_tramite values (default, tramite.id_tramite, 'iniciar', (NOW() - interval '4 hours'));
            
                RETURN QUERY SELECT * FROM tramites_state_with_resources WHERE id=tramite.id_tramite ORDER BY tramites_state_with_resources.fechacreacion;
                
                    RETURN;
                    END;
                    $$;


CREATE OR REPLACE FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_caso_social values (default, _id_caso, event, (NOW() - interval '4 hours'));
          
                  RETURN QUERY SELECT caso_social_state.state FROM caso_social_state WHERE id = _id_caso;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE caso_social SET datos = _datos WHERE id_caso = _id_caso;
                                              END IF;
                                                      END;
                                                              $$;

CREATE OR REPLACE FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, (NOW() - interval '4 hours'));
          
        RETURN QUERY SELECT multa_state.state FROM multa_state WHERE id = _id_multa;
                  
        IF _datos IS NOT NULL THEN
            UPDATE multa SET datos = _datos WHERE id_multa = _id_multa;
        END IF;
    END;
$$;

CREATE or replace FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json, _costo numeric DEFAULT NULL::numeric, _url_boleta character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, (NOW() - interval '4 hours'));
          
        RETURN QUERY SELECT multa_state.state FROM multa_state WHERE id = _id_multa;
                  
        IF _datos IS NOT NULL THEN
            UPDATE multa SET datos = _datos WHERE id_multa = _id_multa;
        END IF;
        IF _costo IS NOT NULL THEN
            UPDATE multa SET costo = _costo WHERE id_multa = _id_multa;
        END IF;
        IF _url_boleta IS NOT NULL THEN
            UPDATE multa SET url_boleta = _url_boleta WHERE id_multa = _id_multa;
        END IF;
    END;
$$;

CREATE or replace FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _costo numeric DEFAULT NULL::numeric, _url_planilla character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_tramite values (default, _id_tramite, event, (NOW() - interval '4 hours'));
          
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramite SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
						  IF _costo IS NOT NULL THEN
                                      UPDATE tramite SET costo = _costo WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _url_planilla IS NOT NULL THEN
                                      UPDATE tramite SET url_planilla = _url_planilla WHERE id_tramite = _id_tramite;
                                              END IF;
                                                      END;
                                                              $$;


CREATE OR REPLACE FUNCTION public.validate_payments(inputcsvjson jsonb, OUT outputjson jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    inputData jsonb;
    inputRow jsonb;
    inputBanco int;
    idPago int;
    dataPago jsonb;
    jsonArray jsonb[];
BEGIN
    inputData := inputCsvJson->'data';
    inputBanco := (inputCsvJson->>'bank')::int;

    jsonArray := ARRAY[]::jsonb[];

    --Iterar json
    FOR inputRow IN
        SELECT jsonb_array_elements FROM jsonb_array_elements(inputData)
    LOOP
    --Validacion de pago por banco,fecha,monto,fecha_de_pago,aprobado
    --Obtiene el id del pago

        SELECT id_pago::int into idPago FROM pago
        WHERE aprobado = false
        AND id_banco = inputBanco
        AND referencia = (inputRow ->> 'Referencia')
        AND monto <= (inputRow ->> 'Monto')::numeric
        AND fecha_de_pago = (inputRow ->> 'Fecha')::date;

        IF idPago IS NOT NULL THEN

            --aprueba el pago, guarda el momento en que se aprobo el pago y actualiza el monto al real
            UPDATE pago SET aprobado = true, fecha_de_aprobacion = (SELECT (NOW() - interval '4 hours')::timestamptz), monto = (inputRow ->> 'Monto')::numeric WHERE id_pago = idPago;

            --obtiene el resultado del row y lo convierte en json
            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'TRAMITE' THEN
                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, tramite.codigo_tramite AS "codigoTramite", tipo_tramite.sufijo AS sufijo, tipo_tramite.id_tipo_tramite AS tipotramite, pago.concepto  from pago
                INNER JOIN tramite ON pago.id_procedimiento = tramite.id_tramite
                INNER JOIN tipo_tramite ON tipo_tramite.id_tipo_tramite = tramite.id_tipo_tramite where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'MULTA' THEN
                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, multa.codigo_multa AS "codigoMulta", tipo_tramite.sufijo AS sufijo, tipo_tramite.id_tipo_tramite AS tipotramite, pago.concepto  from pago
                INNER JOIN multa ON pago.id_procedimiento = multa.id_multa
                INNER JOIN tipo_tramite ON tipo_tramite.id_tipo_tramite = multa.id_tipo_tramite where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'IMPUESTO' THEN

                IF (SELECT true = ALL(SELECT aprobado FROM pago WHERE id_procedimiento = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago))) THEN
                    UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = (NOW() - interval '4 hours') WHERE id_solicitud = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);
                END IF;

                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento from pago
                INNER JOIN impuesto.solicitud ON pago.id_procedimiento = solicitud.id_solicitud
                INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'CONVENIO' THEN
                UPDATE impuesto.fraccion SET aprobado = true, fecha_aprobado = (NOW() - interval '4 hours') WHERE id_fraccion = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);

                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, (SELECT id_procedimiento FROM pago WHERE id_pago = idPago) AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento,
    (SELECT true = ALL(SELECT aprobado FROM impuesto.fraccion WHERE id_convenio = (SELECT id_convenio FROM impuesto.fraccion WHERE id_fraccion = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago) ))) AS "solicitudAprobada"

            from pago
                        INNER JOIN impuesto.fraccion ON fraccion.id_fraccion = pago.id_procedimiento
            INNER JOIN impuesto.convenio ON fraccion.id_convenio = convenio.id_convenio
            INNER JOIN impuesto.solicitud ON solicitud.id_solicitud = convenio.id_solicitud
            INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                        where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'RETENCION' THEN

                IF (SELECT true = ALL(SELECT aprobado FROM pago WHERE id_procedimiento = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago))) THEN
                    UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = (NOW() - interval '4 hours') WHERE id_solicitud = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);
                END IF;

                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento from pago
                INNER JOIN impuesto.solicitud ON pago.id_procedimiento = solicitud.id_solicitud
                INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                where pago.id_pago = idPago) row;
            END IF;

            --agrega el json de la row y lo almacena en el array
            jsonArray := array_append(jsonArray, dataPago);
        END IF;



    END LOOP;
    --devuelve el array de json
    outputJson := jsonb_build_object('data', jsonArray);
    RETURN;
END;
$$;

ALTER TABLE impuesto.registro_recibo ALTER COLUMN fecha SET DEFAULT (NOW() - interval '4 hours');

ALTER TABLE impuesto.retencion ALTER COLUMN fecha SET DEFAULT (NOW() - interval '4 hours');