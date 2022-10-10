--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3 (Ubuntu 12.3-1.pgdg16.04+1)
-- Dumped by pg_dump version 12.3 (Ubuntu 12.3-1.pgdg20.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: impuesto; Type: SCHEMA; Schema: -; Owner: pooijyzcnnfrso
--

CREATE SCHEMA impuesto;


ALTER SCHEMA impuesto OWNER TO pooijyzcnnfrso;

--
-- Name: timetable; Type: SCHEMA; Schema: -; Owner: pooijyzcnnfrso
--

CREATE SCHEMA timetable;


ALTER SCHEMA timetable OWNER TO pooijyzcnnfrso;

--
-- Name: valores_fiscales; Type: SCHEMA; Schema: -; Owner: pooijyzcnnfrso
--

CREATE SCHEMA valores_fiscales;


ALTER SCHEMA valores_fiscales OWNER TO pooijyzcnnfrso;

--
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK ((((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR (VALUE = '@reboot'::text) OR (VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text)));


ALTER DOMAIN timetable.cron OWNER TO pooijyzcnnfrso;

--
-- Name: execution_status; Type: TYPE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TYPE timetable.execution_status AS ENUM (
    'STARTED',
    'CHAIN_FAILED',
    'CHAIN_DONE',
    'DEAD'
);


ALTER TYPE timetable.execution_status OWNER TO pooijyzcnnfrso;

--
-- Name: log_type; Type: TYPE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TYPE timetable.log_type AS ENUM (
    'DEBUG',
    'NOTICE',
    'LOG',
    'ERROR',
    'PANIC',
    'USER'
);


ALTER TYPE timetable.log_type OWNER TO pooijyzcnnfrso;

--
-- Name: task_kind; Type: TYPE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TYPE timetable.task_kind AS ENUM (
    'SQL',
    'SHELL',
    'BUILTIN'
);


ALTER TYPE timetable.task_kind OWNER TO pooijyzcnnfrso;

--
-- Name: complete_fraccion_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, now());
    
    RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.fraccion SET aprobado = _aprobado WHERE id_fraccion = _id_fraccion;
                UPDATE impuesto.fraccion SET fecha_aprobado = now() WHERE id_fraccion = _id_fraccion;
    END IF;
  END;
$$;


ALTER FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: complete_fraccion_state(integer, text, boolean); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, now());
    
    RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.fraccion SET aprobado = _aprobado WHERE id_fraccion = _id_fraccion;
                UPDATE impuesto.fraccion SET fecha_aprobado = now() WHERE id_fraccion = _id_fraccion;
    END IF;
  END;
$$;


ALTER FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text, _aprobado boolean) OWNER TO pooijyzcnnfrso;

--
-- Name: complete_solicitud_state(integer, text, json, boolean); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.complete_solicitud_state(_id_solicitud integer, event text, _datos json DEFAULT NULL::json, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
    INSERT INTO impuesto.evento_solicitud values (default, _id_solicitud, event, now());
    
    RETURN QUERY SELECT ss.state FROM impuesto.solicitud_state ss WHERE id = _id_solicitud;

    IF _aprobado IS NOT NULL THEN
                UPDATE impuesto.solicitud SET aprobado = _aprobado WHERE id_solicitud = _id_solicitud;
                UPDATE impuesto.solicitud SET fecha_aprobado = now() WHERE id_solicitud = _id_solicitud;
    END IF;
  END;
$$;


ALTER FUNCTION impuesto.complete_solicitud_state(_id_solicitud integer, event text, _datos json, _aprobado boolean) OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_fraccion_trigger_func(); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.eventos_fraccion_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
BEGIN
  SELECT impuesto.fraccion_fsm(event ORDER BY id_evento_fraccion)
  FROM (
    SELECT id_evento_fraccion, event FROM impuesto.evento_fraccion WHERE id_fraccion = new.id_fraccion
    UNION
    SELECT new.id_evento_fraccion, new.event
  ) s
  INTO new_state;

  IF new_state = 'error' THEN
    RAISE EXCEPTION 'evento invalido';
  END IF;

  RETURN new;
END
$$;


ALTER FUNCTION impuesto.eventos_fraccion_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_solicitud_trigger_func(); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.eventos_solicitud_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
BEGIN
  SELECT impuesto.solicitud_fsm(event ORDER BY id_evento_solicitud)
  FROM (
    SELECT id_evento_solicitud, event FROM impuesto.evento_solicitud WHERE id_solicitud = new.id_solicitud
    UNION
    SELECT new.id_evento_solicitud, new.event
  ) s
  INTO new_state;

  IF new_state = 'error' THEN
    RAISE EXCEPTION 'evento invalido';
  END IF;

  RETURN new;
END
$$;


ALTER FUNCTION impuesto.eventos_solicitud_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: fraccion_transicion(text, text); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.fraccion_transicion(state text, event text) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT CASE state
        WHEN 'creado' THEN
            CASE event
                WHEN 'iniciar' THEN 'iniciado' 
                ELSE 'error' -- siuuuu
            END 
        WHEN 'iniciado' THEN
            CASE event
                WHEN 'ingresardatos_pi' THEN 'ingresardatos'
                WHEN 'aprobacioncajero_pi' THEN 'finalizado'
                ELSE 'error'
            END
        WHEN 'ingresardatos' THEN
            CASE event
                WHEN 'validar_pi' THEN 'validando'
                WHEN 'aprobacioncajero_pi' THEN 'finalizado'

                ELSE 'error'
            END
        WHEN 'validando' THEN
            CASE event
                WHEN 'finalizar_pi' THEN 'finalizado'
                WHEN 'rebotado_pi' THEN 'ingresardatos'
                ELSE 'error'
            END
        ELSE 'error' -- ausilio
    END -- yaaaaaaaaaaaaaaaaaaa
$$;


ALTER FUNCTION impuesto.fraccion_transicion(state text, event text) OWNER TO pooijyzcnnfrso;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: liquidacion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.liquidacion (
    id_liquidacion integer NOT NULL,
    id_solicitud integer,
    monto numeric,
    certificado character varying,
    recibo character varying,
    fecha_liquidacion date DEFAULT now(),
    id_subramo integer,
    datos json,
    fecha_vencimiento date,
    id_registro_municipal integer,
    remitido boolean DEFAULT false
);


ALTER TABLE impuesto.liquidacion OWNER TO pooijyzcnnfrso;

--
-- Name: get_last_settlement_by_ae(integer, integer); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.get_last_settlement_by_ae(_aforo integer, _id_registro_municipal integer) RETURNS SETOF impuesto.liquidacion
    LANGUAGE plpgsql
    AS $$
DECLARE
    liquidacion impuesto.liquidacion%ROWTYPE;
	x impuesto.liquidacion%ROWTYPE;
	id integer;
BEGIN
    FOR x IN (SELECT * FROM impuesto.liquidacion WHERE id_registro_municipal = _id_registro_municipal AND id_subramo = 10 ORDER BY fecha_liquidacion DESC)
    LOOP 
	IF EXISTS(SELECT * FROM json_to_recordset((x.datos #> '{desglose}')) AS x(aforo int, "montoDeclarado" numeric, "montoPagado" numeric) WHERE aforo = _aforo)
	THEN RETURN QUERY SELECT * FROM impuesto.liquidacion WHERE id_liquidacion = x.id_liquidacion;
	RETURN;
	END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION impuesto.get_last_settlement_by_ae(_aforo integer, _id_registro_municipal integer) OWNER TO pooijyzcnnfrso;

--
-- Name: get_last_settlement_by_estate(integer, integer); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.get_last_settlement_by_estate(_estate integer, _id_registro_municipal integer) RETURNS SETOF impuesto.liquidacion
    LANGUAGE plpgsql
    AS $$
DECLARE
    liquidacion impuesto.liquidacion%ROWTYPE;
	x impuesto.liquidacion%ROWTYPE;
	id integer;
BEGIN
    FOR x IN (SELECT * FROM impuesto.liquidacion WHERE id_registro_municipal = _id_registro_municipal AND id_subramo = 9 ORDER BY fecha_liquidacion DESC)
    LOOP 
	IF EXISTS(SELECT * FROM json_to_recordset((x.datos #> '{desglose}')) AS x(inmueble int, monto numeric) WHERE inmueble = _estate)
	THEN RETURN QUERY SELECT * FROM impuesto.liquidacion WHERE id_liquidacion = x.id_liquidacion;
	RETURN;	
	END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION impuesto.get_last_settlement_by_estate(_estate integer, _id_registro_municipal integer) OWNER TO pooijyzcnnfrso;

--
-- Name: contribuyente; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.contribuyente (
    id_contribuyente integer NOT NULL,
    tipo_documento character(1) NOT NULL,
    documento character varying NOT NULL,
    razon_social character varying NOT NULL,
    denominacion_comercial character varying NOT NULL,
    siglas character varying NOT NULL,
    id_parroquia integer,
    sector character varying,
    direccion character varying,
    punto_referencia character varying,
    verificado boolean,
    tipo_contribuyente character varying,
    es_agente_retencion boolean DEFAULT false
);


ALTER TABLE impuesto.contribuyente OWNER TO pooijyzcnnfrso;

--
-- Name: registro_municipal_referencia_municipal_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.registro_municipal_referencia_municipal_seq
    START WITH 8000000000
    INCREMENT BY 1
    MINVALUE 8000000000
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.registro_municipal_referencia_municipal_seq OWNER TO pooijyzcnnfrso;

--
-- Name: registro_municipal; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.registro_municipal (
    id_registro_municipal bigint NOT NULL,
    id_contribuyente integer NOT NULL,
    referencia_municipal character varying DEFAULT nextval('impuesto.registro_municipal_referencia_municipal_seq'::regclass),
    fecha_aprobacion date,
    telefono_celular character varying,
    telefono_habitacion character varying,
    email character varying,
    denominacion_comercial character varying,
    nombre_representante character varying,
    actualizado boolean DEFAULT false,
    capital_suscrito numeric,
    tipo_sociedad character varying,
    estado_licencia character varying
);


ALTER TABLE impuesto.registro_municipal OWNER TO pooijyzcnnfrso;

--
-- Name: contribuyente_registro; Type: VIEW; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE VIEW impuesto.contribuyente_registro AS
 SELECT c.id_contribuyente,
    c.tipo_documento,
    c.documento,
    c.razon_social,
    c.denominacion_comercial,
    c.siglas,
    c.id_parroquia,
    c.sector,
    c.direccion,
    c.punto_referencia,
    c.verificado,
    c.tipo_contribuyente,
    c.es_agente_retencion,
    rm.id_registro_municipal,
    rm.referencia_municipal,
    rm.fecha_aprobacion,
    rm.telefono_celular,
    rm.telefono_habitacion,
    rm.email,
    rm.nombre_representante,
    rm.actualizado,
    rm.capital_suscrito,
    rm.tipo_sociedad,
    rm.estado_licencia
   FROM (impuesto.contribuyente c
     JOIN impuesto.registro_municipal rm USING (id_contribuyente));


ALTER TABLE impuesto.contribuyente_registro OWNER TO pooijyzcnnfrso;

--
-- Name: insert_agente_retencion(character varying, character varying); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.insert_agente_retencion(_tipodoc character varying, _rif character varying) RETURNS SETOF impuesto.contribuyente_registro
    LANGUAGE plpgsql
    AS $$
DECLARE
    cont impuesto.contribuyente%ROWTYPE;
BEGIN

    IF EXISTS (SELECT * FROM impuesto.registro_municipal rm INNER JOIN impuesto.contribuyente c USING (id_contribuyente) WHERE c.tipo_documento = _tipoDoc AND c.documento = _rif AND rm.referencia_municipal LIKE 'AR%') THEN
        SELECT * INTO cont FROM Impuesto.contribuyente c WHERE c.tipo_documento = _tipoDoc AND c.documento = _rif;

        UPDATE impuesto.contribuyente SET es_agente_retencion = true WHERE id_contribuyente = cont.id_contribuyente;

    ELSE
        SELECT * INTO cont FROM Impuesto.contribuyente c WHERE c.tipo_documento = _tipoDoc AND c.documento = _rif;

        INSERT INTO impuesto.registro_municipal (referencia_municipal, denominacion_comercial) VALUES (CONCAT('AR', LPAD( nextval('impuesto.rim_retencion')::text, 6, '0'::text ) ), cont.denominacion_comercial);

        UPDATE impuesto.contribuyente SET es_agente_retencion = true WHERE id_contribuyente = cont.id_contribuyente;
    END IF;

    
    RETURN;
END;
$$;


ALTER FUNCTION impuesto.insert_agente_retencion(_tipodoc character varying, _rif character varying) OWNER TO pooijyzcnnfrso;

--
-- Name: credito_fiscal; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.credito_fiscal (
    id_credito_fiscal integer NOT NULL,
    id_persona integer NOT NULL,
    concepto character varying NOT NULL,
    credito numeric NOT NULL,
    fecha_creacion date DEFAULT now(),
    CONSTRAINT credito_fiscal_concepto_check CHECK (((concepto)::text = ANY (ARRAY['NATURAL'::text, 'JURIDICO'::text])))
);


ALTER TABLE impuesto.credito_fiscal OWNER TO pooijyzcnnfrso;

--
-- Name: insert_credito(integer, character varying, numeric); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.insert_credito(_id_persona integer, _concepto character varying, _credito numeric) RETURNS SETOF impuesto.credito_fiscal
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.credito_fiscal AS cf (id_persona, concepto, credito) VALUES (_id_persona, _concepto, _credito);
        
        RETURN QUERY SELECT * FROM impuesto.credito_fiscal WHERE id_persona = _id_persona AND concepto = _concepto;
        
                
    RETURN;
    END;
$$;


ALTER FUNCTION impuesto.insert_credito(_id_persona integer, _concepto character varying, _credito numeric) OWNER TO pooijyzcnnfrso;

--
-- Name: fraccion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.fraccion (
    id_fraccion integer NOT NULL,
    id_convenio integer NOT NULL,
    monto numeric NOT NULL,
    porcion integer NOT NULL,
    fecha date,
    aprobado boolean DEFAULT false,
    fecha_aprobado date
);


ALTER TABLE impuesto.fraccion OWNER TO pooijyzcnnfrso;

--
-- Name: insert_fraccion(integer, numeric, integer, date); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.insert_fraccion(_id_convenio integer, _monto numeric, _porcion integer, _fecha date) RETURNS SETOF impuesto.fraccion
    LANGUAGE plpgsql
    AS $$
DECLARE
    fraccionRow impuesto.fraccion%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.fraccion (id_convenio, monto, porcion, fecha) VALUES (_id_convenio,  _monto, _porcion, _fecha) RETURNING * into fraccionRow;
        
        INSERT INTO impuesto.evento_fraccion values (default, fraccionRow.id_fraccion, 'iniciar', now());
            
        RETURN QUERY SELECT * FROM impuesto.fraccion WHERE id_fraccion=fraccionRow.id_fraccion;
                
        RETURN;
    END;
$$;


ALTER FUNCTION impuesto.insert_fraccion(_id_convenio integer, _monto numeric, _porcion integer, _fecha date) OWNER TO pooijyzcnnfrso;

--
-- Name: detalle_retencion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.detalle_retencion (
    id_detalle_retencion integer NOT NULL,
    rif character varying,
    numero_referencia character varying,
    razon_social character varying,
    tipo_retencion character varying,
    fecha_retencion date,
    base_imponible numeric,
    monto_retenido numeric,
    codigo_actividad character varying,
    porcentaje numeric,
    numero_factura character varying,
    id_liquidacion integer
);


ALTER TABLE impuesto.detalle_retencion OWNER TO pooijyzcnnfrso;

--
-- Name: insert_retencion(integer, character varying, character varying, character varying, character varying, date, numeric, numeric, numeric, character varying, character varying); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.insert_retencion(_id_liquidacion integer, _rif character varying, _numero_referencia character varying, _razon_social character varying, _tipo_retencion character varying, _fecha_retencion date, _base_imponible numeric, _monto_retenido numeric, _porcentaje numeric, _codigo_actividad character varying, _numero_factura character varying) RETURNS SETOF impuesto.detalle_retencion
    LANGUAGE plpgsql
    AS $$
DECLARE
    cont impuesto.contribuyente%ROWTYPE;
BEGIN

    IF EXISTS (SELECT * FROM impuesto.contribuyente WHERE TRIM(LOWER(CONCAT(tipo_documento, documento))) = LOWER(_rif) ) THEN
        SELECT * INTO cont FROM impuesto.contribuyente WHERE TRIM(LOWER(CONCAT(tipo_documento, documento))) = LOWER(_rif);

        IF EXISTS (SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = cont.id_contribuyente) AND _numero_referencia = 0 THEN
            RAISE EXCEPTION 'ERROR';
        END IF;

    END IF;

    RETURN QUERY INSERT INTO impuesto.detalle_retencion (rif, numero_referencia, razon_social, tipo_retencion, fecha_retencion, base_imponible, monto_retenido, codigo_actividad, porcentaje, numero_factura, id_liquidacion ) 
        VALUES (_rif, _numero_referencia, _razon_social, _tipo_retencion, _fecha_retencion, _base_imponible, _monto_retenido, _codigo_actividad, _porcentaje, _numero_factura, _id_liquidacion ) RETURNING *;

    RETURN;
END;
$$;


ALTER FUNCTION impuesto.insert_retencion(_id_liquidacion integer, _rif character varying, _numero_referencia character varying, _razon_social character varying, _tipo_retencion character varying, _fecha_retencion date, _base_imponible numeric, _monto_retenido numeric, _porcentaje numeric, _codigo_actividad character varying, _numero_factura character varying) OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.solicitud (
    id_solicitud integer NOT NULL,
    id_usuario integer,
    aprobado boolean DEFAULT false,
    fecha date,
    fecha_aprobado date,
    id_tipo_tramite integer,
    id_contribuyente integer,
    tipo_solicitud character varying DEFAULT 'IMPUESTO'::character varying
);


ALTER TABLE impuesto.solicitud OWNER TO pooijyzcnnfrso;

--
-- Name: insert_solicitud(integer, integer, integer); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.insert_solicitud(_id_usuario integer, _id_tipo_tramite integer, _id_contribuyente integer) RETURNS SETOF impuesto.solicitud
    LANGUAGE plpgsql
    AS $$
DECLARE
    solicitudRow impuesto.solicitud%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.solicitud (id_usuario, aprobado, fecha, id_tipo_tramite, id_contribuyente) VALUES (_id_usuario, false, now(), _id_tipo_tramite, _id_contribuyente) RETURNING * INTO solicitudRow;

        INSERT INTO impuesto.evento_solicitud values (default, solicitudRow.id_solicitud, 'iniciar', now());   

        RETURN QUERY SELECT * FROM impuesto.solicitud WHERE id_solicitud=solicitudRow.id_solicitud;

        RETURN;
    END;
$$;


ALTER FUNCTION impuesto.insert_solicitud(_id_usuario integer, _id_tipo_tramite integer, _id_contribuyente integer) OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud_transicion(text, text); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.solicitud_transicion(state text, event text) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT CASE state
        WHEN 'creado' THEN
            CASE event
                WHEN 'iniciar' THEN 'iniciado' 
                ELSE 'error' -- siuuuu
            END 
        WHEN 'iniciado' THEN
            CASE event
                WHEN 'ingresardatos_pi' THEN 'ingresardatos'
                WHEN 'aprobacioncajero_pi' THEN 'finalizado'
                ELSE 'error'
            END
        WHEN 'ingresardatos' THEN
            CASE event
                WHEN 'validar_pi' THEN 'validando'
				WHEN 'aprobacioncajero_pi' THEN 'finalizado'
                ELSE 'error'
            END
        WHEN 'validando' THEN
            CASE event
                WHEN 'finalizar_pi' THEN 'finalizado'
                WHEN 'rebotado_pi' THEN 'ingresardatos'
                ELSE 'error'
            END
        ELSE 'error' -- ausilio
    END -- yaaaaaaaaaaaaaaaaaaa
$$;


ALTER FUNCTION impuesto.solicitud_transicion(state text, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: update_fraccion_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.update_fraccion_state(_id_fraccion integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, now());
          
        RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;
                  
			
    END;
$$;


ALTER FUNCTION impuesto.update_fraccion_state(_id_fraccion integer, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: update_solicitud_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE FUNCTION impuesto.update_solicitud_state(_id_solicitud integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_solicitud values (default, _id_solicitud, event, now());
          
        RETURN QUERY SELECT ss.state FROM impuesto.solicitud_state ss WHERE id = _id_solicitud;
                  
			
    END;
$$;


ALTER FUNCTION impuesto.update_solicitud_state(_id_solicitud integer, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: casos_sociales_transicion(text, text); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.casos_sociales_transicion(state text, event text) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT CASE state
        WHEN 'creado' THEN
            CASE event
                WHEN 'iniciar' THEN 'iniciado'
                ELSE 'error'
            END
        WHEN 'iniciado' THEN
            CASE event
                WHEN 'visto' THEN 'visto'
                WHEN 'aprobado' THEN 'aprobado'
                WHEN 'negado' THEN 'negado'
                WHEN 'porrevisar' THEN 'porrevisar'
                ELSE 'error'
            END
        WHEN 'porrevisar' THEN
            CASE event
                WHEN 'visto' THEN 'visto'
                WHEN 'aprobado' THEN 'aprobado'
                WHEN 'negado' THEN 'negado'
                ELSE 'error'
            END
        WHEN 'visto' THEN
            CASE event
                WHEN 'aprobado' THEN 'aprobado'
                WHEN 'negado' THEN 'negado'
                ELSE 'error'
            END
        WHEN 'aprobado' THEN
            CASE event
                WHEN 'atendido' THEN 'atendido'
                ELSE 'error'
            END
        ELSE 'error'
    END
$$;


ALTER FUNCTION public.casos_sociales_transicion(state text, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: codigo_caso(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.codigo_caso() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 DECLARE
     valor int;
     nombre_inst text;
BEGIN
     SELECT COALESCE(MAX(consecutivo) + 1, 1) INTO NEW.consecutivo
     FROM public.caso_social t
     WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
     AND CURRENT_DATE = DATE(t.fecha_creacion);

     SELECT i.nombre_corto INTO nombre_inst
     FROM public.institucion i
     INNER JOIN public.tipo_tramite tt ON tt.id_institucion = i.id_institucion
     WHERE tt.id_tipo_tramite = NEW.id_tipo_tramite;

     NEW.codigo_tramite = nombre_inst || '-'
     || to_char(current_date, 'DDMMYYYY') || '-'
     || (NEW.id_tipo_tramite)::TEXT || '-'
     || lpad((NEW.consecutivo)::text, 4, '0');

     RAISE NOTICE '% % % %', nombre_inst, to_char(current_date, 'DDMMYYYY'), (NEW.id_tipo_tramite)::TEXT, lpad((NEW.consecutivo)::text, 4, '0'); 
     RETURN NEW;                                                                                                                                 


 END;
 $$;


ALTER FUNCTION public.codigo_caso() OWNER TO pooijyzcnnfrso;

--
-- Name: codigo_multa(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.codigo_multa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 DECLARE
     valor int;
     nombre_inst text;
BEGIN
     SELECT COALESCE(MAX(consecutivo) + 1, 1) INTO NEW.consecutivo
     FROM public.multa t
     WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
     AND CURRENT_DATE = DATE(t.fecha_creacion);

     SELECT i.nombre_corto INTO nombre_inst
     FROM public.institucion i -- mirmachiti
     INNER JOIN public.tipo_tramite tt ON tt.id_institucion = i.id_institucion
     WHERE tt.id_tipo_tramite = NEW.id_tipo_tramite;

     NEW.codigo_multa = nombre_inst || '-'
     || to_char(current_date, 'DDMMYYYY') || '-'
     || (NEW.id_tipo_tramite)::TEXT || '-'
     || lpad((NEW.consecutivo)::text, 4, '0');

     RAISE NOTICE '% % % %', nombre_inst, to_char(current_date, 'DDMMYYYY'), (NEW.id_tipo_tramite)::TEXT, lpad((NEW.consecutivo)::text, 4, '0'); 
     RETURN NEW;                                                                                                                                 


 END;
$$;


ALTER FUNCTION public.codigo_multa() OWNER TO pooijyzcnnfrso;

--
-- Name: codigo_tramite(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.codigo_tramite() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    valor int;
    nombre_inst text;
BEGIN
    SELECT COALESCE(MAX(consecutivo) + 1, 1) INTO NEW.consecutivo
    FROM public.tramite t
    WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
    AND CURRENT_DATE = DATE(t.fecha_creacion);

    SELECT i.nombre_corto INTO nombre_inst 
    FROM public.institucion i
    INNER JOIN public.tipo_tramite tt ON tt.id_institucion = i.id_institucion
    WHERE tt.id_tipo_tramite = NEW.id_tipo_tramite;

    NEW.codigo_tramite = nombre_inst || '-' 
    || to_char(current_date, 'DDMMYYYY') || '-' 
    || (NEW.id_tipo_tramite)::TEXT || '-'
    || lpad((NEW.consecutivo)::text, 4, '0');

    RAISE NOTICE '% % % %', nombre_inst, to_char(current_date, 'DDMMYYYY'), (NEW.id_tipo_tramite)::TEXT, lpad((NEW.consecutivo)::text, 4, '0');

    RETURN NEW;
    

END;
$$;


ALTER FUNCTION public.codigo_tramite() OWNER TO pooijyzcnnfrso;

--
-- Name: complete_multa_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.complete_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json, _url_certificado character varying DEFAULT NULL::character varying, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, now());
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


ALTER FUNCTION public.complete_multa_state(_id_multa integer, event text, _datos json, _url_certificado character varying, _aprobado boolean) OWNER TO pooijyzcnnfrso;

--
-- Name: complete_tramite_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _url_certificado character varying DEFAULT NULL::character varying, _aprobado boolean DEFAULT NULL::boolean) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_tramite values (default, _id_tramite, event, now());
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramite SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _url_certificado IS NOT NULL THEN
                                      UPDATE tramite SET url_certificado = _url_certificado WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _aprobado IS NOT NULL THEN
                                      UPDATE tramite SET aprobado = _aprobado WHERE id_tramite = _id_tramite;
									  UPDATE tramite SET fecha_culminacion = now() WHERE id_tramite = _id_tramite;
                                              END IF;
                                                      END;
                                                              $$;


ALTER FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json, _url_certificado character varying, _aprobado boolean) OWNER TO pooijyzcnnfrso;

--
-- Name: evento_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.evento_tramite_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT public.tramite_evento_fsm(event ORDER BY id_evento_tramite)
      FROM (
          SELECT id_evento_tramite, event FROM public.evento_tramite WHERE id_tramite = new.id_tramite
              UNION
                  SELECT new.id_evento_tramite, new.event
                    ) s
                      INTO new_state;
                      
                        IF new_state = 'error' THEN
                            RAISE EXCEPTION 'evento invalido';
                              END IF;
                              
                                RETURN new;
                                END
                                $$;


ALTER FUNCTION public.evento_tramite_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_casos_sociales_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.eventos_casos_sociales_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
BEGIN
  SELECT caso_social_fsm(event ORDER BY id_evento_caso)
  FROM (
    SELECT id_evento_caso, event FROM evento_caso_social WHERE id_caso = new.id_caso
    UNION
    SELECT new.id_evento_caso, new.event
  ) s
  INTO new_state;

  IF new_state = 'error' THEN
    RAISE EXCEPTION 'evento invalido';
  END IF;

  RETURN new;
END
$$;


ALTER FUNCTION public.eventos_casos_sociales_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_multa_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.eventos_multa_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
BEGIN
  SELECT public.multa_fsm(event ORDER BY id_evento_multa)
  FROM (
    SELECT id_evento_multa, event FROM evento_multa WHERE id_multa = new.id_multa
    UNION
    SELECT new.id_evento_multa, new.event
  ) s
  INTO new_state;

  IF new_state = 'error' THEN
    RAISE EXCEPTION 'evento invalido';
  END IF;

  RETURN new;
END
$$;


ALTER FUNCTION public.eventos_multa_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.eventos_tramite_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT public.tramite_evento_fsm(event ORDER BY id_evento_tramite)
      FROM (
          SELECT id_evento_tramite, event FROM public.evento_tramite WHERE id_tramite = new.id_tramite
              UNION
                  SELECT new.id_evento_tramite, new.event
                    ) s
                      INTO new_state;
                      
                        IF new_state = 'error' THEN
                            RAISE EXCEPTION 'evento invalido';
                              END IF;
                              
                                RETURN new;
                                END
                                $$;


ALTER FUNCTION public.eventos_tramite_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: caso_social_fsm(text); Type: AGGREGATE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE AGGREGATE public.caso_social_fsm(text) (
    SFUNC = public.casos_sociales_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.caso_social_fsm(text) OWNER TO pooijyzcnnfrso;

--
-- Name: caso_social; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.caso_social (
    id_caso integer NOT NULL,
    id_tipo_tramite integer,
    costo numeric,
    datos json,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    codigo_tramite character varying,
    consecutivo integer,
    id_usuario integer,
    url_planilla character varying
);


ALTER TABLE public.caso_social OWNER TO pooijyzcnnfrso;

--
-- Name: evento_caso_social; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.evento_caso_social (
    id_evento_caso integer NOT NULL,
    id_caso integer NOT NULL,
    event text,
    "time" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.evento_caso_social OWNER TO pooijyzcnnfrso;

--
-- Name: institucion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.institucion (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


ALTER TABLE public.institucion OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tipo_tramite (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo_base numeric,
    sufijo character varying,
    nombre_corto character varying,
    formato character varying,
    planilla character varying,
    certificado character varying,
    utiliza_informacion_catastral boolean,
    pago_previo boolean,
    costo_petro numeric,
    planilla_rechazo text
);


ALTER TABLE public.tipo_tramite OWNER TO pooijyzcnnfrso;

--
-- Name: casos_sociales_state; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.casos_sociales_state AS
 SELECT cs.id_caso AS id,
    cs.datos,
    cs.id_tipo_tramite AS tipotramite,
    cs.costo,
    cs.fecha_creacion AS fechacreacion,
    cs.codigo_tramite AS codigotramite,
    cs.id_usuario AS usuario,
    cs.url_planilla AS planilla,
    tt.nombre_tramite AS nombretramitelargo,
    tt.nombre_corto AS nombretramitecorto,
    ev.state,
    i.nombre_completo AS nombrelargo,
    i.nombre_corto AS nombrecorto
   FROM (((public.caso_social cs
     JOIN public.tipo_tramite tt ON ((cs.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.institucion i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT evento_caso_social.id_caso,
            public.caso_social_fsm(evento_caso_social.event ORDER BY evento_caso_social.id_evento_caso) AS state
           FROM public.evento_caso_social
          GROUP BY evento_caso_social.id_caso) ev ON ((cs.id_caso = ev.id_caso)));


ALTER TABLE public.casos_sociales_state OWNER TO pooijyzcnnfrso;

--
-- Name: insert_caso(integer, json, integer); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.casos_sociales_state
    LANGUAGE plpgsql
    AS $$
DECLARE
    caso caso_social%ROWTYPE;
	response casos_sociales_state%ROWTYPE;
    BEGIN
        INSERT INTO caso_social (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into caso;
        
            INSERT INTO evento_caso_social values (default, caso.id_caso, 'iniciar', now());
            
                RETURN QUERY SELECT * FROM casos_sociales_state WHERE id=caso.id_caso ORDER BY casos_sociales_state.fechacreacion;
                
                    RETURN;
                    END;
                    $$;


ALTER FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO pooijyzcnnfrso;

--
-- Name: insert_liquidacion(integer, numeric, character varying, json, date, integer); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.insert_liquidacion(_id_solicitud integer, _monto numeric DEFAULT NULL::numeric, _ramo character varying DEFAULT NULL::character varying, _datos json DEFAULT NULL::json, _fecha date DEFAULT NULL::date, _id_registro_municipal integer DEFAULT NULL::integer) RETURNS SETOF impuesto.liquidacion
    LANGUAGE plpgsql
    AS $$
DECLARE
    liquidacionRow impuesto.liquidacion%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.liquidacion (id_solicitud, monto, id_subramo, datos, fecha_vencimiento) VALUES (_id_solicitud, _monto, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE (r.descripcion = _ramo OR r.descripcion_corta = _ramo) AND sr.descripcion = 'Pago ordinario'), _datos, _fecha) RETURNING * INTO liquidacionRow;

        IF _id_registro_municipal IS NOT NULL THEN
            UPDATE impuesto.liquidacion SET id_registro_municipal = _id_registro_municipal WHERE id_liquidacion = liquidacionRow.id_liquidacion;
        END IF;
   

        RETURN QUERY SELECT * FROM impuesto.liquidacion WHERE id_liquidacion=liquidacionRow.id_liquidacion;

        RETURN;
    END;
$$;


ALTER FUNCTION public.insert_liquidacion(_id_solicitud integer, _monto numeric, _ramo character varying, _datos json, _fecha date, _id_registro_municipal integer) OWNER TO pooijyzcnnfrso;

--
-- Name: multa_transicion(text, text); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.multa_transicion(state text, event text) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT CASE state
        WHEN 'creado' THEN
            CASE event
                WHEN 'iniciar' THEN 'iniciado' 
                ELSE 'error' -- siuuuu
            END 
        WHEN 'iniciado' THEN
            CASE event
                WHEN 'ingresardatos_ml' THEN 'ingresardatos'
                ELSE 'error'
            END
        WHEN 'ingresardatos' THEN
            CASE event
                WHEN 'validar_ml' THEN 'validando'
                ELSE 'error'
            END
        WHEN 'validando' THEN
            CASE event
                WHEN 'finalizar_ml' THEN 'finalizado'
                ELSE 'error'
            END
        ELSE 'error' -- hmmmmmm
    END -- yaaaaaaaaaaaaaaaaaaa
$$;


ALTER FUNCTION public.multa_transicion(state text, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: multa_fsm(text); Type: AGGREGATE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE AGGREGATE public.multa_fsm(text) (
    SFUNC = public.multa_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.multa_fsm(text) OWNER TO pooijyzcnnfrso;

--
-- Name: evento_multa; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.evento_multa (
    id_evento_multa integer NOT NULL,
    id_multa integer NOT NULL,
    event character varying NOT NULL,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.evento_multa OWNER TO pooijyzcnnfrso;

--
-- Name: multa; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.multa (
    id_multa integer NOT NULL,
    id_tipo_tramite integer NOT NULL,
    datos json,
    costo numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    codigo_multa character varying,
    consecutivo integer,
    id_usuario integer,
    cedula bigint,
    nacionalidad character(1),
    url_certificado character varying,
    aprobado boolean DEFAULT false,
    url_boleta character varying,
    CONSTRAINT multa_nacionalidad_check CHECK ((nacionalidad = ANY (ARRAY['V'::bpchar, 'E'::bpchar])))
);


ALTER TABLE public.multa OWNER TO pooijyzcnnfrso;

--
-- Name: multa_state; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.multa_state AS
 SELECT m.id_multa AS id,
    m.datos,
    m.id_tipo_tramite AS tipotramite,
    m.costo,
    m.fecha_creacion AS fechacreacion,
    m.codigo_multa AS codigomulta,
    m.url_certificado AS urlcertificado,
    m.url_boleta AS urlboleta,
    m.id_usuario AS usuario,
    m.cedula,
    m.nacionalidad,
    m.aprobado,
    tt.nombre_tramite AS nombretramitelargo,
    tt.nombre_corto AS nombretramitecorto,
    ev.state,
    i.nombre_completo AS nombrelargo,
    i.nombre_corto AS nombrecorto
   FROM (((public.multa m
     JOIN public.tipo_tramite tt ON ((m.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.institucion i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT evento_multa.id_multa,
            public.multa_fsm((evento_multa.event)::text ORDER BY evento_multa.id_evento_multa) AS state
           FROM public.evento_multa
          GROUP BY evento_multa.id_multa) ev ON ((m.id_multa = ev.id_multa)));


ALTER TABLE public.multa_state OWNER TO pooijyzcnnfrso;

--
-- Name: insert_multa(integer, json, character varying, bigint, integer); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.insert_multa(_id_tipo_tramite integer, datos json, _nacionalidad character varying, _cedula bigint, _id_usuario integer) RETURNS SETOF public.multa_state
    LANGUAGE plpgsql
    AS $$
DECLARE
    multa multa%ROWTYPE;
	response multa_state%ROWTYPE;
    BEGIN
        INSERT INTO multa (id_tipo_tramite, datos, nacionalidad, cedula, id_usuario) VALUES (_id_tipo_tramite, datos, _nacionalidad, _cedula, _id_usuario) RETURNING * into multa;
        
        INSERT INTO evento_multa values (default, multa.id_multa, 'iniciar', now());
            
        RETURN QUERY SELECT * FROM multa_state WHERE id=multa.id_multa ORDER BY multa_state.fechacreacion;
                
        RETURN;
    END;
$$;


ALTER FUNCTION public.insert_multa(_id_tipo_tramite integer, datos json, _nacionalidad character varying, _cedula bigint, _id_usuario integer) OWNER TO pooijyzcnnfrso;

--
-- Name: insert_notificacion_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.insert_notificacion_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.receptor = NEW.emisor THEN
    RETURN NULL;
  ELSE
    RETURN NEW;
  END IF;
  
END
$$;


ALTER FUNCTION public.insert_notificacion_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: tramites_eventos_transicion(text, text); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.tramites_eventos_transicion(state text, event text) RETURNS text
    LANGUAGE sql
    AS $$
SELECT CASE state
    WHEN 'creado' THEN
        CASE event
            WHEN 'iniciar' THEN 'iniciado'
            ELSE 'error'
        END
    WHEN 'iniciado' THEN
        CASE event
            WHEN 'validar_pa' THEN 'validando'
            WHEN 'validar_cr' THEN 'validando'
            WHEN 'validar_tl' THEN 'validando'
			WHEN 'validar_lae' THEN 'validando'
            WHEN 'enproceso_pd' THEN 'enproceso'
            WHEN 'enproceso_ompu' THEN 'enproceso' 
            WHEN 'finalizar_tl' THEN 'finalizado'
            WHEN 'procesar_rc' THEN 'enproceso'
            WHEN 'revisar_bc' THEN 'enrevision'
            ELSE 'error'
        END
    WHEN 'validando' THEN
        CASE event
            WHEN 'enproceso_pa' THEN 'enproceso'
            WHEN 'enproceso_cr' THEN 'enproceso'
			WHEN 'enproceso_lae' THEN 'enproceso'
            WHEN 'finalizar_pd' THEN 'finalizado'
            WHEN 'finalizar_tl' THEN 'finalizado'
            WHEN 'finalizar_ompu' THEN 'finalizado'
            ELSE 'error'
        END
    WHEN 'ingresardatos' THEN
        CASE event
            WHEN 'validar_pd' THEN 'validando'
            WHEN 'validar_ompu' THEN 'validando'
            ELSE 'error'
        END
    WHEN 'enproceso' THEN
        CASE event
            WHEN 'ingresardatos_pd' THEN 'ingresardatos'
            WHEN 'finalizar_pa' THEN 'finalizado'
            WHEN 'revisar_cr' THEN 'enrevision'
			WHEN 'revisar_lae' THEN 'enrevision'
            WHEN 'rechazar_lae' THEN 'finalizado'
            WHEN 'aprobar_rc' THEN 'finalizado'
            WHEN 'rechazar_rc' THEN 'finalizado'
            WHEN 'rechazar_ompu' THEN 'enrevision'
            WHEN 'aprobar_ompu' THEN 'enrevision'
            ELSE 'error'
        END
    WHEN 'enrevision' THEN
        CASE event
            WHEN 'finalizar_cr' THEN 'finalizado'
            WHEN 'rechazar_cr' THEN 'enproceso'
			WHEN 'aprobar_lae' THEN 'finalizado'
			WHEN 'rechazar_lae' THEN 'finalizado'
            WHEN 'ingresardatos_ompu' THEN 'ingresardatos'
            WHEN 'rechazar_ompu' THEN 'enproceso'
            WHEN 'aprobar_bc' THEN 'finalizado'
            WHEN 'rechazar_bc' THEN 'finalizado'
            ELSE 'error'        
        END
    ELSE 'error'
END
$$;


ALTER FUNCTION public.tramites_eventos_transicion(state text, event text) OWNER TO pooijyzcnnfrso;

--
-- Name: tramite_evento_fsm(text); Type: AGGREGATE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE AGGREGATE public.tramite_evento_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.tramite_evento_fsm(text) OWNER TO pooijyzcnnfrso;

--
-- Name: evento_tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.evento_tramite (
    id_evento_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    event text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.evento_tramite OWNER TO pooijyzcnnfrso;

--
-- Name: tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tramite (
    id_tramite integer NOT NULL,
    id_tipo_tramite integer,
    datos json,
    costo numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    codigo_tramite character varying,
    consecutivo integer,
    id_usuario integer,
    url_planilla character varying,
    url_certificado character varying,
    aprobado boolean DEFAULT false,
    fecha_culminacion timestamp with time zone
);


ALTER TABLE public.tramite OWNER TO pooijyzcnnfrso;

--
-- Name: tramites_state_with_resources; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.tramites_state_with_resources AS
 SELECT t.id_tramite AS id,
    t.datos,
    t.id_tipo_tramite AS tipotramite,
    t.costo,
    t.fecha_creacion AS fechacreacion,
    t.codigo_tramite AS codigotramite,
    t.id_usuario AS usuario,
    t.url_planilla AS planilla,
    t.url_certificado AS certificado,
    i.nombre_completo AS nombrelargo,
    i.nombre_corto AS nombrecorto,
    tt.nombre_tramite AS nombretramitelargo,
    tt.nombre_corto AS nombretramitecorto,
    ev.state,
    t.aprobado,
    tt.pago_previo AS "pagoPrevio",
    t.fecha_culminacion AS fechaculminacion
   FROM (((public.tramite t
     JOIN public.tipo_tramite tt ON ((t.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.institucion i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT evento_tramite.id_tramite,
            public.tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
           FROM public.evento_tramite
          GROUP BY evento_tramite.id_tramite) ev ON ((t.id_tramite = ev.id_tramite)));


ALTER TABLE public.tramites_state_with_resources OWNER TO pooijyzcnnfrso;

--
-- Name: insert_tramite(integer, json, integer); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.tramites_state_with_resources
    LANGUAGE plpgsql
    AS $$
DECLARE
    tramite tramite%ROWTYPE;
	response tramites_state_with_resources%ROWTYPE;
    BEGIN
        INSERT INTO tramite (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into tramite;
        
            INSERT INTO evento_tramite values (default, tramite.id_tramite, 'iniciar', now());
            
                RETURN QUERY SELECT * FROM tramites_state_with_resources WHERE id=tramite.id_tramite ORDER BY tramites_state_with_resources.fechacreacion;
                
                    RETURN;
                    END;
                    $$;


ALTER FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO pooijyzcnnfrso;

--
-- Name: revisar_pagos_fin_de_dia(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.revisar_pagos_fin_de_dia() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    pagoImpuestoRow record;
BEGIN

    FOR pagoImpuestoRow IN SELECT DISTINCT id_procedimiento FROM pago WHERE concepto = 'IMPUESTO' AND aprobado = false 
    LOOP
        IF (false = ANY(SELECT aprobado 
                        FROM pago 
                        WHERE id_procedimiento = pagoImpuestoRow.id_procedimiento 
                        AND concepto = 'IMPUESTO' 
                        AND (NOW() - fecha_de_pago) > interval '4 days')) THEN

            UPDATE impuesto.solicitud SET pagado = false AND rebotado = true WHERE id_solicitud = pagoImpuestoRow.id_procedimiento;
        END IF;
    END LOOP;

END;
$$;


ALTER FUNCTION public.revisar_pagos_fin_de_dia() OWNER TO pooijyzcnnfrso;

--
-- Name: tipos_tramites_costo_petro_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.tipos_tramites_costo_petro_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuevoCosto numeric;
    BEGIN
        nuevoCosto = NEW.valor_en_bs;
        UPDATE tipo_tramite SET costo_base = (nuevoCosto * costo_petro) WHERE costo_petro IS NOT NULL;
        RETURN NEW;
    END
$$;


ALTER FUNCTION public.tipos_tramites_costo_petro_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: tramite_eventos_trigger_func(); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.tramite_eventos_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT tramite_evento_fsm(event ORDER BY id)
      FROM (
          SELECT id, event FROM evento_tramite WHERE id_evento_tramite = new.id_evento_tramite
              UNION
                  SELECT new.id, new.event
                    ) s
                      INTO new_state;
                      
                        IF new_state = 'error' THEN
                            RAISE EXCEPTION 'evento invalido';
                              END IF;
                              
                                RETURN new;
                                END
                                $$;


ALTER FUNCTION public.tramite_eventos_trigger_func() OWNER TO pooijyzcnnfrso;

--
-- Name: update_caso_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_caso_social values (default, _id_caso, event, now());
          
                  RETURN QUERY SELECT caso_social_state.state FROM caso_social_state WHERE id = _id_caso;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE caso_social SET datos = _datos WHERE id_caso = _id_caso;
                                              END IF;
                                                      END;
                                                              $$;


ALTER FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json) OWNER TO pooijyzcnnfrso;

--
-- Name: update_multa_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, now());
          
        RETURN QUERY SELECT multa_state.state FROM multa_state WHERE id = _id_multa;
                  
        IF _datos IS NOT NULL THEN
            UPDATE multa SET datos = _datos WHERE id_multa = _id_multa;
        END IF;
    END;
$$;


ALTER FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json) OWNER TO pooijyzcnnfrso;

--
-- Name: update_multa_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json DEFAULT NULL::json, _costo numeric DEFAULT NULL::numeric, _url_boleta character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO evento_multa values (default, _id_multa, event, now());
          
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


ALTER FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json, _costo numeric, _url_boleta character varying) OWNER TO pooijyzcnnfrso;

--
-- Name: update_tramite_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _costo numeric DEFAULT NULL::numeric, _url_planilla character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO evento_tramite values (default, _id_tramite, event, now());
          
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


ALTER FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json, _costo numeric, _url_planilla character varying) OWNER TO pooijyzcnnfrso;

--
-- Name: validate_payments(jsonb); Type: FUNCTION; Schema: public; Owner: pooijyzcnnfrso
--

CREATE FUNCTION public.validate_payments(inputcsvjson jsonb, OUT outputjson jsonb) RETURNS jsonb
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
            UPDATE pago SET aprobado = true, fecha_de_aprobacion = (SELECT NOW()::timestamptz), monto = (inputRow ->> 'Monto')::numeric WHERE id_pago = idPago;

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
                    UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = NOW() WHERE id_solicitud = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);
                END IF;

                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento from pago
                INNER JOIN impuesto.solicitud ON pago.id_procedimiento = solicitud.id_solicitud
                INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'CONVENIO' THEN
                UPDATE impuesto.fraccion SET aprobado = true, fecha_aprobado = NOW() WHERE id_fraccion = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);

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
                    UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = NOW() WHERE id_solicitud = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago);
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


ALTER FUNCTION public.validate_payments(inputcsvjson jsonb, OUT outputjson jsonb) OWNER TO pooijyzcnnfrso;

--
-- Name: _validate_json_schema_type(text, jsonb); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable._validate_json_schema_type(type text, data jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  IF type = 'integer' THEN
    IF jsonb_typeof(data) != 'number' THEN
      RETURN false;
    END IF;
    IF trunc(data::text::numeric) != data::text::numeric THEN
      RETURN false;
    END IF;
  ELSE
    IF type != jsonb_typeof(data) THEN
      RETURN false;
    END IF;
  END IF;
  RETURN true;
END;
$$;


ALTER FUNCTION timetable._validate_json_schema_type(type text, data jsonb) OWNER TO pooijyzcnnfrso;

--
-- Name: cron_element_to_array(text, text); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.cron_element_to_array(element text, element_type text) RETURNS integer[]
    LANGUAGE plpgsql
    AS $_$
DECLARE
    a_element text[];
    i_index integer;
    a_tmp text[] := '{}';
    tmp_item text;
    a_range text[];
    a_split text[];
    counter integer;
    counter_range integer[];
    a_res integer[] := '{}';
    allowed_range integer[];
    max_val integer;
    min_val integer;
BEGIN
    IF lower(element_type) = 'minute' THEN
        i_index = 1;
        allowed_range = '{0,59}';
    ELSIF lower(element_type) = 'hour' THEN
        i_index = 2;
        allowed_range = '{0,23}';
    ELSIF lower(element_type) = 'day' THEN
        i_index = 3;
        allowed_range = '{1,31}';
    ELSIF lower(element_type) = 'month' THEN
        i_index = 4;
        allowed_range = '{1,12}';
    ELSIF lower(element_type) = 'day_of_week' THEN
        i_index = 5;
        allowed_range = '{0,7}';
    ELSE
        RAISE EXCEPTION 'element_type ("%") not recognized', element_type
            USING HINT = 'Allowed values are "minute, day, hour, month, day_of_month"!';
    END IF;


    a_element := regexp_split_to_array(element, '\s+');
    a_tmp := string_to_array(a_element[i_index],',');

    FOREACH  tmp_item IN ARRAY a_tmp
        LOOP
            -- normal integer
            IF tmp_item ~ '^[0-9]+$' THEN
                a_res := array_append(a_res, tmp_item::int);

                -- '*' any value
            ELSIF tmp_item ~ '^[*]+$' THEN
                a_res := array_append(a_res, NULL);

                -- '-' range of values
            ELSIF tmp_item ~ '^[0-9]+[-][0-9]+$' THEN
                a_range := regexp_split_to_array(tmp_item, '-');
                a_range := array(select generate_series(a_range[1]::int,a_range[2]::int));
                a_res := array_cat(a_res, a_range::int[]);

                -- '/' step values
            ELSIF tmp_item ~ '^[0-9]+[\/][0-9]+$' THEN
                a_split := regexp_split_to_array(tmp_item, '/');
                counter := a_split[1]::int;
                WHILE counter+a_split[2]::int <= 59 LOOP
                    a_res := array_append(a_res, counter);
                    counter := counter + a_split[2]::int ;
                END LOOP ;

                --Heavy sh*t, combinated special chars
                -- '-' range of values and '/' step values
            ELSIF tmp_item ~ '^[0-9-]+[\/][0-9]+$' THEN
                a_split := regexp_split_to_array(tmp_item, '/');
                counter_range := regexp_split_to_array(a_split[1], '-');
                WHILE counter_range[1]::int+a_split[2]::int <= counter_range[2]::int LOOP
                    a_res := array_append(a_res, counter_range[1]);
                    counter_range[1] := counter_range[1] + a_split[2]::int ;
                END LOOP;

                -- '*' any value and '/' step values
            ELSIF tmp_item ~ '^[*]+[\/][0-9]+$' THEN
                a_split := regexp_split_to_array(tmp_item, '/');
                counter_range := allowed_range;
                WHILE counter_range[1]::int+a_split[2]::int <= counter_range[2]::int LOOP
                    counter_range[1] := counter_range[1] + a_split[2]::int ;
                    a_res := array_append(a_res, counter_range[1]);
                END LOOP;
            ELSE
                RAISE EXCEPTION 'Value ("%") not recognized', a_element[i_index]
                    USING HINT = 'fields separated by space or tab, Values allowed: numbers (value list with ","), any value with "*", range of value with "-" and step values with "/"!';
            END IF;
        END LOOP;

    --sort the array ;)
    SELECT ARRAY_AGG(x.val) INTO a_res
    FROM (SELECT UNNEST(a_res) AS val ORDER BY val) AS x;

    --check if Values in allowed ranges
    max_val :=  max(x) FROM unnest(a_res) as x;
    min_val :=  min(x) FROM unnest(a_res) as x;
    IF max_val > allowed_range[2] OR min_val < allowed_range[1] then
        RAISE EXCEPTION '%s incorrect, allowed range between % and %', INITCAP(element_type), allowed_range[1], allowed_range[2]  ;
    END IF;

    RETURN a_res;
END;
$_$;


ALTER FUNCTION timetable.cron_element_to_array(element text, element_type text) OWNER TO pooijyzcnnfrso;

--
-- Name: get_running_jobs(bigint); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.get_running_jobs(bigint) RETURNS SETOF record
    LANGUAGE sql
    AS $_$
    SELECT  chain_execution_config, start_status
        FROM    timetable.run_status
        WHERE   start_status IN ( SELECT   start_status
                FROM    timetable.run_status
                WHERE   execution_status IN ('STARTED', 'CHAIN_FAILED',
                             'CHAIN_DONE', 'DEAD')
                    AND (chain_execution_config = $1 OR chain_execution_config = 0)
                GROUP BY 1
                HAVING count(*) < 2 
                ORDER BY 1)
            AND chain_execution_config = $1 
        GROUP BY 1, 2
        ORDER BY 1, 2 DESC
$_$;


ALTER FUNCTION timetable.get_running_jobs(bigint) OWNER TO pooijyzcnnfrso;

--
-- Name: get_task_id(text); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.get_task_id(task_name text) RETURNS bigint
    LANGUAGE sql STRICT
    AS $_$
	SELECT task_id FROM timetable.base_task WHERE name = $1;
$_$;


ALTER FUNCTION timetable.get_task_id(task_name text) OWNER TO pooijyzcnnfrso;

--
-- Name: insert_base_task(text, bigint); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.insert_base_task(task_name text, parent_task_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    builtin_id BIGINT;
    result_id BIGINT;
BEGIN
    SELECT task_id FROM timetable.base_task WHERE name = task_name INTO builtin_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nonexistent builtin task --> %', task_name
        USING 
            ERRCODE = 'invalid_parameter_value',
            HINT = 'Please check your user task name parameter';
    END IF;
    INSERT INTO timetable.task_chain 
        (chain_id, parent_id, task_id, run_uid, database_connection, ignore_error)
    VALUES 
        (DEFAULT, parent_task_id, builtin_id, NULL, NULL, FALSE)
    RETURNING chain_id INTO result_id;
    RETURN result_id;
END
$$;


ALTER FUNCTION timetable.insert_base_task(task_name text, parent_task_id bigint) OWNER TO pooijyzcnnfrso;

--
-- Name: is_cron_in_time(timetable.cron, timestamp with time zone); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.is_cron_in_time(run_at timetable.cron, ts timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE 
    a_by_minute integer[];
    a_by_hour integer[];
    a_by_day integer[];
    a_by_month integer[];
    a_by_day_of_week integer[]; 
BEGIN
    IF run_at IS NULL
    THEN
        RETURN TRUE;
    END IF;
    a_by_minute := timetable.cron_element_to_array(run_at, 'minute');
    a_by_hour := timetable.cron_element_to_array(run_at, 'hour');
    a_by_day := timetable.cron_element_to_array(run_at, 'day');
    a_by_month := timetable.cron_element_to_array(run_at, 'month');
    a_by_day_of_week := timetable.cron_element_to_array(run_at, 'day_of_week'); 
    RETURN  (a_by_month[1]       IS NULL OR date_part('month', ts) = ANY(a_by_month))
        AND (a_by_day_of_week[1] IS NULL OR date_part('dow', ts) = ANY(a_by_day_of_week))
        AND (a_by_day[1]         IS NULL OR date_part('day', ts) = ANY(a_by_day))
        AND (a_by_hour[1]        IS NULL OR date_part('hour', ts) = ANY(a_by_hour))
        AND (a_by_minute[1]      IS NULL OR date_part('minute', ts) = ANY(a_by_minute));    
END;
$$;


ALTER FUNCTION timetable.is_cron_in_time(run_at timetable.cron, ts timestamp with time zone) OWNER TO pooijyzcnnfrso;

--
-- Name: job_add(text, text, text, timetable.task_kind, timetable.cron, integer, boolean, boolean); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.job_add(task_name text, task_function text, client_name text, task_type timetable.task_kind DEFAULT 'SQL'::timetable.task_kind, run_at timetable.cron DEFAULT NULL::text, max_instances integer DEFAULT NULL::integer, live boolean DEFAULT false, self_destruct boolean DEFAULT false) RETURNS bigint
    LANGUAGE sql
    AS $$WITH 
    cte_task(v_task_id) AS ( --Create task
        INSERT INTO timetable.base_task 
        VALUES (DEFAULT, task_name, task_type, task_function)
        RETURNING task_id
    ),
    cte_chain(v_chain_id) AS ( --Create chain
        INSERT INTO timetable.task_chain (task_id, ignore_error)
        SELECT v_task_id, TRUE FROM cte_task
        RETURNING chain_id
    )
INSERT INTO timetable.chain_execution_config (
    chain_id, 
    chain_name, 
    run_at, 
    max_instances, 
    live,
    self_destruct 
) SELECT 
    v_chain_id, 
    'chain_' || v_chain_id, 
    run_at,
    max_instances, 
    live, 
    self_destruct
FROM cte_chain
RETURNING chain_execution_config 
$$;


ALTER FUNCTION timetable.job_add(task_name text, task_function text, client_name text, task_type timetable.task_kind, run_at timetable.cron, max_instances integer, live boolean, self_destruct boolean) OWNER TO pooijyzcnnfrso;

--
-- Name: task_chain_delete(bigint, bigint); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.task_chain_delete(config_ bigint, chain_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
		chain_id_1st_   bigint;
		id_in_chain	 bool;
		chain_id_curs   bigint;
		chain_id_before bigint;
		chain_id_after  bigint;
		curs1 refcursor;
BEGIN
		SELECT chain_id INTO chain_id_1st_ FROM timetable.chain_execution_config WHERE chain_execution_config = config_;
		-- No such chain_execution_config
		IF NOT FOUND THEN
				RAISE NOTICE 'No such chain_execution_config';
				RETURN false;
		END IF;
		-- This head is not connected to a chain
		IF chain_id_1st_ IS NULL THEN
				RAISE NOTICE 'This head is not connected to a chain';
				RETURN false;
		END IF;

		OPEN curs1 FOR WITH RECURSIVE x (chain_id) AS (
				SELECT chain_id FROM timetable.task_chain
				WHERE chain_id = chain_id_1st_ AND parent_id IS NULL
				UNION ALL
				SELECT timetable.task_chain.chain_id FROM timetable.task_chain, x
				WHERE timetable.task_chain.parent_id = x.chain_id
		) SELECT chain_id FROM x;

		id_in_chain = false;
		chain_id_curs = NULL;
		chain_id_before = NULL;
		chain_id_after = NULL;
		LOOP
				FETCH curs1 INTO chain_id_curs;
				IF id_in_chain = false AND chain_id_curs <> chain_id_ THEN
						chain_id_before = chain_id_curs;
				END IF;
				IF chain_id_curs = chain_id_ THEN
						id_in_chain = true;
				END IF;
				EXIT WHEN id_in_chain OR NOT FOUND;
		END LOOP;

		IF id_in_chain THEN
				FETCH curs1 INTO chain_id_after;
		ELSE
				CLOSE curs1;
				RAISE NOTICE 'This chain_id is not part of chain pointed by the chain_execution_config';
				RETURN false;
		END IF;

		CLOSE curs1;

		IF chain_id_before IS NULL THEN
			UPDATE timetable.chain_execution_config SET chain_id = chain_id_after WHERE chain_execution_config = config_;
		END IF;
		UPDATE timetable.task_chain SET parent_id = NULL WHERE chain_id = chain_id_;
		UPDATE timetable.task_chain SET parent_id = chain_id_before WHERE chain_id = chain_id_after;
		DELETE FROM timetable.task_chain WHERE chain_id = chain_id_;

		RETURN true;
END
$$;


ALTER FUNCTION timetable.task_chain_delete(config_ bigint, chain_id_ bigint) OWNER TO pooijyzcnnfrso;

--
-- Name: trig_chain_fixer(); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.trig_chain_fixer() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE
		tmp_parent_id BIGINT;
		tmp_chain_id BIGINT;
		orig_chain_id BIGINT;
		tmp_chain_head_id BIGINT;
		i BIGINT;
	BEGIN
		--raise notice 'Fixing chain for deletion of base_task#%', OLD.task_id;

		FOR orig_chain_id IN
			SELECT chain_id FROM timetable.task_chain WHERE task_id = OLD.task_id
		LOOP

			--raise notice 'chain_id#%', orig_chain_id;	
			tmp_chain_id := orig_chain_id;
			i := 0;
			LOOP
				i := i + 1;
				SELECT parent_id INTO tmp_parent_id FROM timetable.task_chain
					WHERE chain_id = tmp_chain_id;
				EXIT WHEN tmp_parent_id IS NULL;
				IF i > 100 THEN
					RAISE EXCEPTION 'Infinite loop at timetable.task_chain.chain_id=%', tmp_chain_id;
					RETURN NULL;
				END IF;
				tmp_chain_id := tmp_parent_id;
			END LOOP;
			
			SELECT parent_id INTO tmp_chain_head_id FROM timetable.task_chain
				WHERE chain_id = tmp_chain_id;
				
			--raise notice 'PERFORM task_chain_delete(%,%)', tmp_chain_head_id, orig_chain_id;
			PERFORM timetable.task_chain_delete(tmp_chain_head_id, orig_chain_id);

		END LOOP;
		
		RETURN OLD;
	END;
$$;


ALTER FUNCTION timetable.trig_chain_fixer() OWNER TO pooijyzcnnfrso;

--
-- Name: validate_json_schema(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE FUNCTION timetable.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb DEFAULT NULL::jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
  prop text;
  item jsonb;
  path text[];
  types text[];
  pattern text;
  props text[];
BEGIN

  IF root_schema IS NULL THEN
    root_schema = schema;
  END IF;

  IF schema ? 'type' THEN
    IF jsonb_typeof(schema->'type') = 'array' THEN
      types = ARRAY(SELECT jsonb_array_elements_text(schema->'type'));
    ELSE
      types = ARRAY[schema->>'type'];
    END IF;
    IF (SELECT NOT bool_or(timetable._validate_json_schema_type(type, data)) FROM unnest(types) type) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'properties' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'properties') LOOP
      IF data ? prop AND NOT timetable.validate_json_schema(schema->'properties'->prop, data->prop, root_schema) THEN
        RETURN false;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'required' AND jsonb_typeof(data) = 'object' THEN
    IF NOT ARRAY(SELECT jsonb_object_keys(data)) @>
           ARRAY(SELECT jsonb_array_elements_text(schema->'required')) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'items' AND jsonb_typeof(data) = 'array' THEN
    IF jsonb_typeof(schema->'items') = 'object' THEN
      FOR item IN SELECT jsonb_array_elements(data) LOOP
        IF NOT timetable.validate_json_schema(schema->'items', item, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    ELSE
      IF NOT (
        SELECT bool_and(i > jsonb_array_length(schema->'items') OR timetable.validate_json_schema(schema->'items'->(i::int - 1), elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
      ) THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'boolean' and NOT (schema->'additionalItems')::text::boolean AND jsonb_typeof(schema->'items') = 'array' THEN
    IF jsonb_array_length(data) > jsonb_array_length(schema->'items') THEN
      RETURN false;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'object' THEN
    IF NOT (
        SELECT bool_and(timetable.validate_json_schema(schema->'additionalItems', elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
        WHERE i > jsonb_array_length(schema->'items')
      ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minimum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric < (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maximum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric > (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMinimum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMaximum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'anyOf' THEN
    IF NOT (SELECT bool_or(timetable.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'anyOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'allOf' THEN
    IF NOT (SELECT bool_and(timetable.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'allOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'oneOf' THEN
    IF 1 != (SELECT COUNT(*) FROM jsonb_array_elements(schema->'oneOf') sub_schema WHERE timetable.validate_json_schema(sub_schema, data, root_schema)) THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'uniqueItems')::text::boolean, false) THEN
    IF (SELECT COUNT(*) FROM jsonb_array_elements(data)) != (SELECT count(DISTINCT val) FROM jsonb_array_elements(data) val) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'additionalProperties' AND jsonb_typeof(data) = 'object' THEN
    props := ARRAY(
      SELECT key
      FROM jsonb_object_keys(data) key
      WHERE key NOT IN (SELECT jsonb_object_keys(schema->'properties'))
        AND NOT EXISTS (SELECT * FROM jsonb_object_keys(schema->'patternProperties') pat WHERE key ~ pat)
    );
    IF jsonb_typeof(schema->'additionalProperties') = 'boolean' THEN
      IF NOT (schema->'additionalProperties')::text::boolean AND jsonb_typeof(data) = 'object' AND NOT props <@ ARRAY(SELECT jsonb_object_keys(schema->'properties')) THEN
        RETURN false;
      END IF;
    ELSEIF NOT (
      SELECT bool_and(timetable.validate_json_schema(schema->'additionalProperties', data->key, root_schema))
      FROM unnest(props) key
    ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? '$ref' THEN
    path := ARRAY(
      SELECT regexp_replace(regexp_replace(path_part, '~1', '/'), '~0', '~')
      FROM UNNEST(regexp_split_to_array(schema->>'$ref', '/')) path_part
    );
    -- ASSERT path[1] = '#', 'only refs anchored at the root are supported';
    IF NOT timetable.validate_json_schema(root_schema #> path[2:array_length(path, 1)], data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'enum' THEN
    IF NOT EXISTS (SELECT * FROM jsonb_array_elements(schema->'enum') val WHERE val = data) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') < (schema->>'minLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') > (schema->>'maxLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'not' THEN
    IF timetable.validate_json_schema(schema->'not', data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) > (schema->>'maxProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) < (schema->>'minProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) > (schema->>'maxItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) < (schema->>'minItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'dependencies' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'dependencies') LOOP
      IF data ? prop THEN
        IF jsonb_typeof(schema->'dependencies'->prop) = 'array' THEN
          IF NOT (SELECT bool_and(data ? dep) FROM jsonb_array_elements_text(schema->'dependencies'->prop) dep) THEN
            RETURN false;
          END IF;
        ELSE
          IF NOT timetable.validate_json_schema(schema->'dependencies'->prop, data, root_schema) THEN
            RETURN false;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'pattern' AND jsonb_typeof(data) = 'string' THEN
    IF (data #>> '{}') !~ (schema->>'pattern') THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'patternProperties' AND jsonb_typeof(data) = 'object' THEN
    FOR prop IN SELECT jsonb_object_keys(data) LOOP
      FOR pattern IN SELECT jsonb_object_keys(schema->'patternProperties') LOOP
        RAISE NOTICE 'prop %s, pattern %, schema %', prop, pattern, schema->'patternProperties'->pattern;
        IF prop ~ pattern AND NOT timetable.validate_json_schema(schema->'patternProperties'->pattern, data->prop, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  IF schema ? 'multipleOf' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric % (schema->>'multipleOf')::numeric != 0 THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$_$;


ALTER FUNCTION timetable.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb) OWNER TO pooijyzcnnfrso;

--
-- Name: fraccion_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE AGGREGATE impuesto.fraccion_fsm(text) (
    SFUNC = impuesto.fraccion_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.fraccion_fsm(text) OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE AGGREGATE impuesto.solicitud_fsm(text) (
    SFUNC = impuesto.solicitud_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.solicitud_fsm(text) OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.actividad_economica (
    id_actividad_economica integer NOT NULL,
    numero_referencia integer,
    descripcion character varying,
    alicuota numeric,
    minimo_tributable integer
);


ALTER TABLE impuesto.actividad_economica OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_sucursal; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.actividad_economica_sucursal (
    id_actividad_economica_contribuyente integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    numero_referencia integer NOT NULL,
    aplicable_desde date
);


ALTER TABLE impuesto.actividad_economica_sucursal OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq OWNED BY impuesto.actividad_economica_sucursal.id_actividad_economica_contribuyente;


--
-- Name: actividad_economica_exoneracion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.actividad_economica_exoneracion (
    id_actividad_economica_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_actividad_economica integer
);


ALTER TABLE impuesto.actividad_economica_exoneracion OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq OWNED BY impuesto.actividad_economica_exoneracion.id_actividad_economica_exoneracion;


--
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.actividad_economica_id_actividad_economica_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_id_actividad_economica_seq OWNER TO pooijyzcnnfrso;

--
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.actividad_economica_id_actividad_economica_seq OWNED BY impuesto.actividad_economica.id_actividad_economica;


--
-- Name: avaluo_inmueble; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.avaluo_inmueble (
    id_avaluo_inmueble integer NOT NULL,
    id_inmueble integer NOT NULL,
    avaluo numeric NOT NULL,
    anio integer
);


ALTER TABLE impuesto.avaluo_inmueble OWNER TO pooijyzcnnfrso;

--
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq OWNER TO pooijyzcnnfrso;

--
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq OWNED BY impuesto.avaluo_inmueble.id_avaluo_inmueble;


--
-- Name: baremo_servicio_municipal; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.baremo_servicio_municipal (
    id_baremo integer NOT NULL,
    descripcion character varying,
    indicador numeric
);


ALTER TABLE impuesto.baremo_servicio_municipal OWNER TO pooijyzcnnfrso;

--
-- Name: baremo_servicio_municipal_id_baremo_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.baremo_servicio_municipal_id_baremo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.baremo_servicio_municipal_id_baremo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: baremo_servicio_municipal_id_baremo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.baremo_servicio_municipal_id_baremo_seq OWNED BY impuesto.baremo_servicio_municipal.id_baremo;


--
-- Name: categoria_propaganda; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.categoria_propaganda (
    id_categoria_propaganda integer NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE impuesto.categoria_propaganda OWNER TO pooijyzcnnfrso;

--
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.categoria_propaganda_id_categoria_propaganda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.categoria_propaganda_id_categoria_propaganda_seq OWNER TO pooijyzcnnfrso;

--
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.categoria_propaganda_id_categoria_propaganda_seq OWNED BY impuesto.categoria_propaganda.id_categoria_propaganda;


--
-- Name: contribuyente_exoneracion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.contribuyente_exoneracion (
    id_contribuyente_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    id_actividad_economica integer
);


ALTER TABLE impuesto.contribuyente_exoneracion OWNER TO pooijyzcnnfrso;

--
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq OWNED BY impuesto.contribuyente_exoneracion.id_contribuyente_exoneracion;


--
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.contribuyente_id_contribuyente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.contribuyente_id_contribuyente_seq OWNER TO pooijyzcnnfrso;

--
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.contribuyente_id_contribuyente_seq OWNED BY impuesto.contribuyente.id_contribuyente;


--
-- Name: convenio; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.convenio (
    id_convenio integer NOT NULL,
    id_solicitud integer NOT NULL,
    cantidad integer NOT NULL
);


ALTER TABLE impuesto.convenio OWNER TO pooijyzcnnfrso;

--
-- Name: convenio_id_convenio_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.convenio_id_convenio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.convenio_id_convenio_seq OWNER TO pooijyzcnnfrso;

--
-- Name: convenio_id_convenio_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.convenio_id_convenio_seq OWNED BY impuesto.convenio.id_convenio;


--
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.credito_fiscal_id_credito_fiscal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.credito_fiscal_id_credito_fiscal_seq OWNER TO pooijyzcnnfrso;

--
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.credito_fiscal_id_credito_fiscal_seq OWNED BY impuesto.credito_fiscal.id_credito_fiscal;


--
-- Name: detalle_retencion_id_detalle_retencion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.detalle_retencion_id_detalle_retencion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.detalle_retencion_id_detalle_retencion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: detalle_retencion_id_detalle_retencion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.detalle_retencion_id_detalle_retencion_seq OWNED BY impuesto.detalle_retencion.id_detalle_retencion;


--
-- Name: dias_feriados; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.dias_feriados (
    id_dia_feriado integer NOT NULL,
    dia date,
    descripcion character varying
);


ALTER TABLE impuesto.dias_feriados OWNER TO pooijyzcnnfrso;

--
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.dias_feriados_id_dia_feriado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.dias_feriados_id_dia_feriado_seq OWNER TO pooijyzcnnfrso;

--
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.dias_feriados_id_dia_feriado_seq OWNED BY impuesto.dias_feriados.id_dia_feriado;


--
-- Name: evento_fraccion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.evento_fraccion (
    id_evento_fraccion integer NOT NULL,
    id_fraccion integer NOT NULL,
    event character varying,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE impuesto.evento_fraccion OWNER TO pooijyzcnnfrso;

--
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.evento_fraccion_id_evento_fraccion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.evento_fraccion_id_evento_fraccion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.evento_fraccion_id_evento_fraccion_seq OWNED BY impuesto.evento_fraccion.id_evento_fraccion;


--
-- Name: evento_solicitud; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.evento_solicitud (
    id_evento_solicitud integer NOT NULL,
    id_solicitud integer NOT NULL,
    event character varying,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE impuesto.evento_solicitud OWNER TO pooijyzcnnfrso;

--
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.evento_solicitud_id_evento_solicitud_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.evento_solicitud_id_evento_solicitud_seq OWNER TO pooijyzcnnfrso;

--
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.evento_solicitud_id_evento_solicitud_seq OWNED BY impuesto.evento_solicitud.id_evento_solicitud;


--
-- Name: factor; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.factor (
    id_factor integer NOT NULL,
    descripcion character varying,
    valor numeric
);


ALTER TABLE impuesto.factor OWNER TO pooijyzcnnfrso;

--
-- Name: factor_id_factor_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.factor_id_factor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.factor_id_factor_seq OWNER TO pooijyzcnnfrso;

--
-- Name: factor_id_factor_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.factor_id_factor_seq OWNED BY impuesto.factor.id_factor;


--
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.fraccion_id_fraccion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.fraccion_id_fraccion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.fraccion_id_fraccion_seq OWNED BY impuesto.fraccion.id_fraccion;


--
-- Name: fraccion_state; Type: VIEW; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE VIEW impuesto.fraccion_state AS
 SELECT f.id_fraccion AS id,
    f.id_convenio AS idconvenio,
    f.monto,
    f.fecha,
    ev.state
   FROM (impuesto.fraccion f
     JOIN ( SELECT ef.id_fraccion,
            impuesto.fraccion_fsm((ef.event)::text ORDER BY ef.id_evento_fraccion) AS state
           FROM impuesto.evento_fraccion ef
          GROUP BY ef.id_fraccion) ev ON ((f.id_fraccion = ev.id_fraccion)));


ALTER TABLE impuesto.fraccion_state OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_contribuyente_natural; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.inmueble_contribuyente_natural (
    id_inmueble_contribuyente integer NOT NULL,
    id_inmueble integer NOT NULL,
    id_contribuyente integer NOT NULL
);


ALTER TABLE impuesto.inmueble_contribuyente_natural OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq OWNED BY impuesto.inmueble_contribuyente_natural.id_inmueble_contribuyente;


--
-- Name: liquidacion_descuento; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.liquidacion_descuento (
    id_liquidacion_descuento integer NOT NULL,
    id_liquidacion integer NOT NULL,
    porcentaje_descuento numeric NOT NULL
);


ALTER TABLE impuesto.liquidacion_descuento OWNER TO pooijyzcnnfrso;

--
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq OWNER TO pooijyzcnnfrso;

--
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq OWNED BY impuesto.liquidacion_descuento.id_liquidacion_descuento;


--
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.liquidacion_id_liquidacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.liquidacion_id_liquidacion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.liquidacion_id_liquidacion_seq OWNED BY impuesto.liquidacion.id_liquidacion;


--
-- Name: multa; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.multa (
    id_multa integer NOT NULL,
    id_solicitud integer NOT NULL,
    id_tipo_multa integer NOT NULL,
    monto numeric,
    mes character varying,
    anio integer
);


ALTER TABLE impuesto.multa OWNER TO pooijyzcnnfrso;

--
-- Name: multa_id_multa_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.multa_id_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.multa_id_multa_seq OWNER TO pooijyzcnnfrso;

--
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.multa_id_multa_seq OWNED BY impuesto.multa.id_multa;


--
-- Name: notificacion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.notificacion (
    id_notificacion integer NOT NULL,
    id_procedimiento integer,
    emisor character varying,
    receptor character varying,
    descripcion character varying,
    status boolean,
    fecha timestamp with time zone,
    estado character varying,
    concepto character varying DEFAULT 'TRAMITE'::character varying,
    CONSTRAINT notificacion_concepto_check CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text, 'IMPUESTO'::text])))
);


ALTER TABLE public.notificacion OWNER TO pooijyzcnnfrso;

--
-- Name: notificacion_impuesto_view; Type: VIEW; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE VIEW impuesto.notificacion_impuesto_view AS
 SELECT n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    s.id_solicitud AS "idSolicitud",
    s.id_usuario AS usuario,
    s.aprobado,
    s.fecha AS "fechaCreacionSolicitud",
    s.fecha_aprobado AS "fechaAprobacionSolicitud",
    s.id_tipo_tramite AS "idTipoTramite"
   FROM ((public.notificacion n
     JOIN impuesto.solicitud s ON ((n.id_procedimiento = s.id_solicitud)))
     JOIN public.tipo_tramite tt ON ((tt.id_tipo_tramite = s.id_tipo_tramite)));


ALTER TABLE impuesto.notificacion_impuesto_view OWNER TO pooijyzcnnfrso;

--
-- Name: plazo_exoneracion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.plazo_exoneracion (
    id_plazo_exoneracion integer NOT NULL,
    fecha_inicio date,
    fecha_fin date
);


ALTER TABLE impuesto.plazo_exoneracion OWNER TO pooijyzcnnfrso;

--
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq OWNED BY impuesto.plazo_exoneracion.id_plazo_exoneracion;


--
-- Name: ramo_exoneracion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.ramo_exoneracion (
    id_ramo_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_ramo integer
);


ALTER TABLE impuesto.ramo_exoneracion OWNER TO pooijyzcnnfrso;

--
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq OWNED BY impuesto.ramo_exoneracion.id_ramo_exoneracion;


--
-- Name: ramo; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.ramo (
    id_ramo integer NOT NULL,
    codigo character varying NOT NULL,
    descripcion character varying NOT NULL,
    descripcion_corta character varying
);


ALTER TABLE impuesto.ramo OWNER TO pooijyzcnnfrso;

--
-- Name: ramo_id_ramo_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.ramo_id_ramo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.ramo_id_ramo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: ramo_id_ramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.ramo_id_ramo_seq OWNED BY impuesto.ramo.id_ramo;


--
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.registro_municipal_id_registro_municipal_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.registro_municipal_id_registro_municipal_seq OWNER TO pooijyzcnnfrso;

--
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.registro_municipal_id_registro_municipal_seq OWNED BY impuesto.registro_municipal.id_registro_municipal;


--
-- Name: registro_municipal_verificacion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.registro_municipal_verificacion (
    id_registro_municipal integer NOT NULL,
    id_verificacion_telefono integer NOT NULL
);


ALTER TABLE impuesto.registro_municipal_verificacion OWNER TO pooijyzcnnfrso;

--
-- Name: retencion; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.retencion (
    id_retencion integer NOT NULL,
    rif character varying,
    rim character varying,
    monto numeric,
    fecha date DEFAULT now(),
    activo boolean DEFAULT false
);


ALTER TABLE impuesto.retencion OWNER TO pooijyzcnnfrso;

--
-- Name: retencion_id_retencion_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.retencion_id_retencion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.retencion_id_retencion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: retencion_id_retencion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.retencion_id_retencion_seq OWNED BY impuesto.retencion.id_retencion;


--
-- Name: rim_retencion; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.rim_retencion
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.rim_retencion OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.solicitud_id_solicitud_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.solicitud_id_solicitud_seq OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.solicitud_id_solicitud_seq OWNED BY impuesto.solicitud.id_solicitud;


--
-- Name: solicitud_state; Type: VIEW; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE VIEW impuesto.solicitud_state AS
 SELECT s.id_solicitud AS id,
    s.id_tipo_tramite AS tipotramite,
    s.aprobado,
    s.fecha,
    s.fecha_aprobado AS "fechaAprobacion",
    ev.state
   FROM (impuesto.solicitud s
     JOIN ( SELECT es.id_solicitud,
            impuesto.solicitud_fsm((es.event)::text ORDER BY es.id_evento_solicitud) AS state
           FROM impuesto.evento_solicitud es
          GROUP BY es.id_solicitud) ev ON ((s.id_solicitud = ev.id_solicitud)));


ALTER TABLE impuesto.solicitud_state OWNER TO pooijyzcnnfrso;

--
-- Name: subramo; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.subramo (
    id_subramo integer NOT NULL,
    id_ramo integer NOT NULL,
    subindice character varying,
    descripcion character varying
);


ALTER TABLE impuesto.subramo OWNER TO pooijyzcnnfrso;

--
-- Name: solicitud_view; Type: VIEW; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE VIEW impuesto.solicitud_view AS
 SELECT s.id_solicitud AS id,
    s.id_usuario AS usuario,
    s.aprobado,
    s.fecha AS "fechaCreacion",
    l.id_liquidacion AS "idLiquidacion",
    l.monto AS "montoLiquidacion",
    l.recibo,
    l.certificado,
    l.id_subramo AS "idSubramo",
    l.datos,
    sr.subindice,
    sr.descripcion AS "descripcionSubramo",
    r.codigo AS "codigoRamo",
    r.descripcion AS "descripcionRamo",
    c.id_contribuyente AS contribuyente,
    c.tipo_documento AS "tipoDocumento",
    c.documento,
    c.razon_social AS "razonSocial",
    c.denominacion_comercial AS "denominacionComercial",
    c.siglas,
    c.sector,
    c.direccion,
    c.punto_referencia AS "puntoReferencia",
    c.verificado,
    c.tipo_contribuyente AS "tipoContribuyente",
    r.descripcion_corta AS "descripcionCortaRamo"
   FROM ((((impuesto.solicitud s
     JOIN impuesto.contribuyente c ON ((s.id_contribuyente = c.id_contribuyente)))
     JOIN impuesto.liquidacion l ON ((s.id_solicitud = l.id_solicitud)))
     JOIN impuesto.subramo sr ON ((sr.id_subramo = l.id_subramo)))
     JOIN impuesto.ramo r ON ((r.id_ramo = sr.id_ramo)));


ALTER TABLE impuesto.solicitud_view OWNER TO pooijyzcnnfrso;

--
-- Name: subramo_id_subramo_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.subramo_id_subramo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.subramo_id_subramo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: subramo_id_subramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.subramo_id_subramo_seq OWNED BY impuesto.subramo.id_subramo;


--
-- Name: tabulador_aseo_actividad_economica; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tabulador_aseo_actividad_economica (
    id_tabulador_aseo_actividad_economica integer NOT NULL,
    id_usuario integer NOT NULL,
    numero_referencia integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_aseo_actividad_economica OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq OWNED BY impuesto.tabulador_aseo_actividad_economica.id_tabulador_aseo_actividad_economica;


--
-- Name: tabulador_aseo_residencial; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tabulador_aseo_residencial (
    id_tabulador_aseo_residencial integer NOT NULL,
    id_usuario integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_aseo_residencial OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq OWNED BY impuesto.tabulador_aseo_residencial.id_tabulador_aseo_residencial;


--
-- Name: tabulador_gas; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tabulador_gas (
    id_tabulador_gas integer NOT NULL,
    id_actividad_economica integer,
    monto numeric
);


ALTER TABLE impuesto.tabulador_gas OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_actividad_economica; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tabulador_gas_actividad_economica (
    id_tabulador_gas_actividad_economica integer NOT NULL,
    id_usuario integer NOT NULL,
    numero_referencia integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_gas_actividad_economica OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq OWNED BY impuesto.tabulador_gas_actividad_economica.id_tabulador_gas_actividad_economica;


--
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tabulador_gas_id_tabulador_gas_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_id_tabulador_gas_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tabulador_gas_id_tabulador_gas_seq OWNED BY impuesto.tabulador_gas.id_tabulador_gas;


--
-- Name: tabulador_gas_residencial; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tabulador_gas_residencial (
    id_tabulador_gas_residencial integer NOT NULL,
    id_usuario integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_gas_residencial OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq OWNED BY impuesto.tabulador_gas_residencial.id_tabulador_gas_residencial;


--
-- Name: tipo_aviso_propaganda; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tipo_aviso_propaganda (
    id_tipo_aviso_propaganda integer NOT NULL,
    id_categoria_propaganda integer NOT NULL,
    descripcion character varying NOT NULL,
    parametro character varying NOT NULL,
    monto numeric NOT NULL,
    id_valor integer DEFAULT 2
);


ALTER TABLE impuesto.tipo_aviso_propaganda OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq OWNED BY impuesto.tipo_aviso_propaganda.id_tipo_aviso_propaganda;


--
-- Name: tipo_multa; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.tipo_multa (
    id_tipo_multa integer NOT NULL,
    descripcion character varying
);


ALTER TABLE impuesto.tipo_multa OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.tipo_multa_id_tipo_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tipo_multa_id_tipo_multa_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.tipo_multa_id_tipo_multa_seq OWNED BY impuesto.tipo_multa.id_tipo_multa;


--
-- Name: usuario_enlazado; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.usuario_enlazado (
    id_usuario_enlazado integer NOT NULL,
    id_contribuyente integer NOT NULL,
    email character varying NOT NULL
);


ALTER TABLE impuesto.usuario_enlazado OWNER TO pooijyzcnnfrso;

--
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.usuario_enlazado_id_usuario_enlazado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.usuario_enlazado_id_usuario_enlazado_seq OWNER TO pooijyzcnnfrso;

--
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.usuario_enlazado_id_usuario_enlazado_seq OWNED BY impuesto.usuario_enlazado.id_usuario_enlazado;


--
-- Name: usuario_inmueble; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.usuario_inmueble (
    id_usuario_inmueble integer NOT NULL,
    id_usuario integer NOT NULL,
    id_inmueble integer NOT NULL
);


ALTER TABLE impuesto.usuario_inmueble OWNER TO pooijyzcnnfrso;

--
-- Name: usuario_inmueble_id_usuario_inmueble_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.usuario_inmueble_id_usuario_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.usuario_inmueble_id_usuario_inmueble_seq OWNER TO pooijyzcnnfrso;

--
-- Name: usuario_inmueble_id_usuario_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.usuario_inmueble_id_usuario_inmueble_seq OWNED BY impuesto.usuario_inmueble.id_usuario_inmueble;


--
-- Name: verificacion_email; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.verificacion_email (
    id_verificacion_email integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    codigo_recuperacion character varying,
    fecha_recuperacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    verificado boolean DEFAULT false
);


ALTER TABLE impuesto.verificacion_email OWNER TO pooijyzcnnfrso;

--
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.verificacion_email_id_verificacion_email_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.verificacion_email_id_verificacion_email_seq OWNER TO pooijyzcnnfrso;

--
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.verificacion_email_id_verificacion_email_seq OWNED BY impuesto.verificacion_email.id_verificacion_email;


--
-- Name: verificacion_telefono; Type: TABLE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TABLE impuesto.verificacion_telefono (
    id_verificacion_telefono integer NOT NULL,
    codigo_verificacion character varying,
    fecha_verificacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    verificado boolean DEFAULT false,
    id_usuario integer,
    telefono character varying
);


ALTER TABLE impuesto.verificacion_telefono OWNER TO pooijyzcnnfrso;

--
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE impuesto.verificacion_telefono_id_verificacion_telefono_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.verificacion_telefono_id_verificacion_telefono_seq OWNER TO pooijyzcnnfrso;

--
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE impuesto.verificacion_telefono_id_verificacion_telefono_seq OWNED BY impuesto.verificacion_telefono.id_verificacion_telefono;


--
-- Name: banco; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.banco (
    id_banco integer NOT NULL,
    nombre character varying,
    validador boolean DEFAULT false
);


ALTER TABLE public.banco OWNER TO pooijyzcnnfrso;

--
-- Name: bancos_id_banco_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.bancos_id_banco_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bancos_id_banco_seq OWNER TO pooijyzcnnfrso;

--
-- Name: bancos_id_banco_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.banco.id_banco;


--
-- Name: campo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.campo (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying,
    validacion character varying,
    col integer
);


ALTER TABLE public.campo OWNER TO pooijyzcnnfrso;

--
-- Name: campo_tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.campo_tramite (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado character varying,
    id_seccion integer,
    CONSTRAINT campos_tramites_estado_check CHECK (((estado)::text = ANY (ARRAY['iniciado'::text, 'validando'::text, 'enproceso'::text, 'ingresardatos'::text, 'validando'::text, 'finalizado'::text])))
);


ALTER TABLE public.campo_tramite OWNER TO pooijyzcnnfrso;

--
-- Name: campos_id_campo_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.campos_id_campo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campos_id_campo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: campos_id_campo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campo.id_campo;


--
-- Name: cargo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.cargo (
    id_cargo integer NOT NULL,
    id_tipo_usuario integer,
    id_institucion integer,
    descripcion character varying
);


ALTER TABLE public.cargo OWNER TO pooijyzcnnfrso;

--
-- Name: cargo_id_cargo_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.cargo_id_cargo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cargo_id_cargo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: cargo_id_cargo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.cargo_id_cargo_seq OWNED BY public.cargo.id_cargo;


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.casos_sociales_id_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.casos_sociales_id_caso_seq OWNER TO pooijyzcnnfrso;

--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.casos_sociales_id_caso_seq OWNED BY public.caso_social.id_caso;


--
-- Name: certificado; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.certificado (
    id_certificado integer NOT NULL,
    id_tramite integer,
    url_certificado character varying
);


ALTER TABLE public.certificado OWNER TO pooijyzcnnfrso;

--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.certificados_id_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.certificados_id_certificado_seq OWNER TO pooijyzcnnfrso;

--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.certificados_id_certificado_seq OWNED BY public.certificado.id_certificado;


--
-- Name: cuenta_funcionario; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.cuenta_funcionario (
    id_usuario integer NOT NULL,
    id_cargo integer
);


ALTER TABLE public.cuenta_funcionario OWNER TO pooijyzcnnfrso;

--
-- Name: datos_facebook; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.datos_facebook (
    id_usuario integer NOT NULL,
    id_facebook character varying NOT NULL
);


ALTER TABLE public.datos_facebook OWNER TO pooijyzcnnfrso;

--
-- Name: datos_google; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


ALTER TABLE public.datos_google OWNER TO pooijyzcnnfrso;

--
-- Name: detalle_factura; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.detalle_factura (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    nombre character varying,
    costo numeric
);


ALTER TABLE public.detalle_factura OWNER TO pooijyzcnnfrso;

--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.detalles_facturas_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.detalles_facturas_id_detalle_seq OWNER TO pooijyzcnnfrso;

--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.detalles_facturas_id_detalle_seq OWNED BY public.detalle_factura.id_detalle;


--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.evento_multa_id_evento_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evento_multa_id_evento_multa_seq OWNER TO pooijyzcnnfrso;

--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.evento_multa_id_evento_multa_seq OWNED BY public.evento_multa.id_evento_multa;


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_casos_sociales_id_evento_caso_seq OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq OWNED BY public.evento_caso_social.id_evento_caso;


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.eventos_tramite_id_evento_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_tramite_id_evento_tramite_seq OWNER TO pooijyzcnnfrso;

--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.eventos_tramite_id_evento_tramite_seq OWNED BY public.evento_tramite.id_evento_tramite;


--
-- Name: factura_tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.factura_tramite (
    id_factura integer NOT NULL,
    id_tramite integer
);


ALTER TABLE public.factura_tramite OWNER TO pooijyzcnnfrso;

--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.facturas_tramites_id_factura_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facturas_tramites_id_factura_seq OWNER TO pooijyzcnnfrso;

--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.facturas_tramites_id_factura_seq OWNED BY public.factura_tramite.id_factura;


--
-- Name: inmueble_urbano; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.inmueble_urbano (
    id_inmueble integer NOT NULL,
    cod_catastral character varying,
    direccion character varying NOT NULL,
    id_parroquia integer,
    metros_construccion numeric,
    metros_terreno numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_ultimo_avaluo timestamp with time zone,
    tipo_inmueble character varying,
    id_registro_municipal integer,
    posee_gas boolean DEFAULT true
);


ALTER TABLE public.inmueble_urbano OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.inmueble_urbano_id_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inmueble_urbano_id_inmueble_seq OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.inmueble_urbano_id_inmueble_seq OWNED BY public.inmueble_urbano.id_inmueble;


--
-- Name: parroquia; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.parroquia OWNER TO pooijyzcnnfrso;

--
-- Name: inmueble_urbano_view; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.inmueble_urbano_view AS
 SELECT inmueble_urbano.id_inmueble AS id,
    inmueble_urbano.cod_catastral AS "codCatastral",
    inmueble_urbano.direccion,
    p.nombre AS parroquia,
    inmueble_urbano.metros_construccion AS "metrosConstruccion",
    inmueble_urbano.metros_terreno AS "metrosTerreno",
    inmueble_urbano.fecha_creacion AS "fechaCreacion",
    inmueble_urbano.fecha_actualizacion AS "fechaActualizacion",
    inmueble_urbano.fecha_ultimo_avaluo AS "fechaUltimoAvaluo",
    inmueble_urbano.tipo_inmueble AS "tipoInmueble"
   FROM (public.inmueble_urbano
     JOIN public.parroquia p ON ((inmueble_urbano.id_parroquia = p.id)));


ALTER TABLE public.inmueble_urbano_view OWNER TO pooijyzcnnfrso;

--
-- Name: institucion_banco; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.institucion_banco (
    id_institucion integer NOT NULL,
    id_banco integer NOT NULL,
    numero_cuenta character varying,
    nombre_titular character varying,
    documento_de_identificacion character varying,
    id_institucion_banco numeric DEFAULT 0
);


ALTER TABLE public.institucion_banco OWNER TO pooijyzcnnfrso;

--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.instituciones_id_institucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instituciones_id_institucion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.institucion.id_institucion;


--
-- Name: multa_id_multa_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.multa_id_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.multa_id_multa_seq OWNER TO pooijyzcnnfrso;

--
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.multa_id_multa_seq OWNED BY public.multa.id_multa;


--
-- Name: notificacion_impuesto_view; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.notificacion_impuesto_view AS
 SELECT n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    s.id_solicitud AS "idSolicitud",
    s.id_usuario AS usuario,
    s.aprobado,
    s.fecha AS "fechaCreacionSolicitud",
    s.fecha_aprobado AS "fechaAprobacionSolicitud",
    s.id_tipo_tramite AS "idTipoTramite"
   FROM ((public.notificacion n
     JOIN impuesto.solicitud s ON ((n.id_procedimiento = s.id_solicitud)))
     JOIN public.tipo_tramite tt ON ((tt.id_tipo_tramite = s.id_tipo_tramite)));


ALTER TABLE public.notificacion_impuesto_view OWNER TO pooijyzcnnfrso;

--
-- Name: notificacion_multa_view; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.notificacion_multa_view AS
 SELECT n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    m.id AS "idMulta",
    m.datos,
    m.tipotramite AS "tipoTramite",
    m.costo,
    m.fechacreacion AS "fechaCreacionTramite",
    m.codigomulta AS "codigoMulta",
    m.urlcertificado AS certificado,
    m.urlboleta AS boleta,
    m.usuario,
    m.cedula,
    m.nacionalidad,
    m.nombrecorto AS "nombreCorto",
    m.nombrelargo AS "nombreLargo",
    m.nombretramitecorto AS "nombreTramiteCorto",
    m.nombretramitelargo AS "nombreTramiteLargo",
    m.state AS estado,
    m.aprobado
   FROM (public.notificacion n
     JOIN public.multa_state m ON ((n.id_procedimiento = m.id)));


ALTER TABLE public.notificacion_multa_view OWNER TO pooijyzcnnfrso;

--
-- Name: notificacion_tramite_view; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.notificacion_tramite_view AS
 SELECT n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    t.id AS "idTramite",
    t.datos,
    t.tipotramite AS "tipoTramite",
    t.costo,
    t.fechacreacion AS "fechaCreacionTramite",
    t.codigotramite AS "codigoTramite",
    t.usuario,
    t.planilla,
    t.certificado,
    t.nombrecorto AS "nombreCorto",
    t.nombrelargo AS "nombreLargo",
    t.nombretramitecorto AS "nombreTramiteCorto",
    t.nombretramitelargo AS "nombreTramiteLargo",
    t.state AS estado,
    t.aprobado,
    t."pagoPrevio"
   FROM (public.notificacion n
     JOIN public.tramites_state_with_resources t ON ((n.id_procedimiento = t.id)));


ALTER TABLE public.notificacion_tramite_view OWNER TO pooijyzcnnfrso;

--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.notificaciones_id_notificacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notificaciones_id_notificacion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificacion.id_notificacion;


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.operaciones_id_operacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operaciones_id_operacion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: operacion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.operacion (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


ALTER TABLE public.operacion OWNER TO pooijyzcnnfrso;

--
-- Name: operatividad_terminal; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.operatividad_terminal (
    id_operatividad_terminal integer NOT NULL,
    destino character varying NOT NULL,
    tipo character varying NOT NULL,
    monto numeric NOT NULL,
    tasa numeric NOT NULL,
    habilitado boolean DEFAULT true,
    monto_calculado numeric GENERATED ALWAYS AS (round((monto * tasa), 2)) STORED,
    CONSTRAINT operatividad_terminal_tipo_check CHECK (((tipo)::text = ANY (ARRAY['BUSCAMA'::text, 'BUSETA'::text, 'CARRO POR PUESTO'::text])))
);


ALTER TABLE public.operatividad_terminal OWNER TO pooijyzcnnfrso;

--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operatividad_terminal_id_operatividad_terminal_seq OWNER TO pooijyzcnnfrso;

--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq OWNED BY public.operatividad_terminal.id_operatividad_terminal;


--
-- Name: ordenanza; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.ordenanza (
    id_ordenanza integer NOT NULL,
    descripcion character varying NOT NULL,
    tarifa character varying,
    id_valor integer,
    habilitado boolean DEFAULT true
);


ALTER TABLE public.ordenanza OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanza_tramite; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.ordenanza_tramite (
    id_ordenanza_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    id_tarifa integer NOT NULL,
    petro numeric,
    valor_calc numeric,
    factor character varying,
    factor_value numeric,
    costo_ordenanza numeric
);


ALTER TABLE public.ordenanza_tramite OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.ordenanzas_id_ordenanza_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordenanzas_id_ordenanza_seq OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.ordenanzas_id_ordenanza_seq OWNED BY public.ordenanza.id_ordenanza;


--
-- Name: tarifa_inspeccion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tarifa_inspeccion (
    id_tarifa integer NOT NULL,
    id_ordenanza integer NOT NULL,
    id_tipo_tramite integer NOT NULL,
    formula character varying,
    utiliza_codcat boolean,
    id_variable integer
);


ALTER TABLE public.tarifa_inspeccion OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanzas_instancias_tramites; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.ordenanzas_instancias_tramites AS
 SELECT ot.id_ordenanza_tramite AS id,
    ot.id_tramite AS "idTramite",
    o.descripcion AS ordenanza,
    ot.factor,
    ot.factor_value AS "factorValue",
    ot.petro,
    ot.valor_calc AS "valorCalc",
    ot.costo_ordenanza AS "costoOrdenanza"
   FROM ((public.ordenanza_tramite ot
     JOIN public.tarifa_inspeccion ti ON ((ot.id_tarifa = ti.id_tarifa)))
     JOIN public.ordenanza o ON ((o.id_ordenanza = ti.id_ordenanza)));


ALTER TABLE public.ordenanzas_instancias_tramites OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNER TO pooijyzcnnfrso;

--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNED BY public.ordenanza_tramite.id_ordenanza_tramite;


--
-- Name: pago; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.pago (
    id_pago integer NOT NULL,
    id_procedimiento integer,
    referencia character varying,
    monto numeric,
    fecha_de_pago date,
    aprobado boolean DEFAULT false,
    id_banco integer,
    fecha_de_aprobacion timestamp with time zone,
    concepto character varying DEFAULT 'TRAMITE'::character varying,
    metodo_pago character varying DEFAULT 'TRANSFERENCIA'::character varying,
    id_usuario integer,
    CONSTRAINT pago_concepto_check CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text, 'IMPUESTO'::text, 'CONVENIO'::text, 'CREDITOFISCAL'::text]))),
    CONSTRAINT pago_metodo_pago_check CHECK (((metodo_pago)::text = ANY (ARRAY['TRANSFERENCIA'::text, 'EFECTIVO'::text, 'CHEQUE'::text, 'PUNTO DE VENTA'::text, 'CREDITO_FISCAL'::text])))
);


ALTER TABLE public.pago OWNER TO pooijyzcnnfrso;

--
-- Name: pago_manual; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.pago_manual (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


ALTER TABLE public.pago_manual OWNER TO pooijyzcnnfrso;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.pagos_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pagos_id_pago_seq OWNER TO pooijyzcnnfrso;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pago.id_pago;


--
-- Name: parroquias_id_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.parroquias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parroquias_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: parroquias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.parroquias_id_seq OWNED BY public.parroquia.id;


--
-- Name: permiso_de_acceso; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.permiso_de_acceso (
    id_permiso integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_tramite integer NOT NULL
);


ALTER TABLE public.permiso_de_acceso OWNER TO pooijyzcnnfrso;

--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.permiso_de_acceso_id_permiso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.permiso_de_acceso_id_permiso_seq OWNER TO pooijyzcnnfrso;

--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.permiso_de_acceso_id_permiso_seq OWNED BY public.permiso_de_acceso.id_permiso;


--
-- Name: propietario; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.propietario (
    id_propietario integer NOT NULL,
    razon_social character varying NOT NULL,
    cedula character varying,
    rif character varying,
    email character varying
);


ALTER TABLE public.propietario OWNER TO pooijyzcnnfrso;

--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.propietario_id_propietario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propietario_id_propietario_seq OWNER TO pooijyzcnnfrso;

--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.propietario_id_propietario_seq OWNED BY public.propietario.id_propietario;


--
-- Name: propietario_inmueble; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.propietario_inmueble (
    id_propietario_inmueble integer NOT NULL,
    id_propietario integer NOT NULL,
    id_inmueble integer NOT NULL
);


ALTER TABLE public.propietario_inmueble OWNER TO pooijyzcnnfrso;

--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNER TO pooijyzcnnfrso;

--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNED BY public.propietario_inmueble.id_propietario_inmueble;


--
-- Name: recaudo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.recaudo (
    id_recaudo integer NOT NULL,
    nombre_largo character varying,
    nombre_corto character varying,
    obligatorio boolean DEFAULT false,
    planilla text,
    extension text DEFAULT 'image/*'::text
);


ALTER TABLE public.recaudo OWNER TO pooijyzcnnfrso;

--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.recaudos_id_recaudo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.recaudos_id_recaudo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudo.id_recaudo;


--
-- Name: recuperacion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.recuperacion (
    id_recuperacion integer NOT NULL,
    id_usuario integer,
    token_recuperacion character varying,
    usado boolean,
    fecha_recuperacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.recuperacion OWNER TO pooijyzcnnfrso;

--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.recuperacion_id_recuperacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.recuperacion_id_recuperacion_seq OWNER TO pooijyzcnnfrso;

--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.recuperacion_id_recuperacion_seq OWNED BY public.recuperacion.id_recuperacion;


--
-- Name: seccion; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.seccion (
    id_seccion integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.seccion OWNER TO pooijyzcnnfrso;

--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.tarifas_inspeccion_id_tarifa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tarifas_inspeccion_id_tarifa_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.tarifas_inspeccion_id_tarifa_seq OWNED BY public.tarifa_inspeccion.id_tarifa;


--
-- Name: template_certificado; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.template_certificado (
    id_template_certificado integer NOT NULL,
    id_tipo_tramite integer,
    link character varying
);


ALTER TABLE public.template_certificado OWNER TO pooijyzcnnfrso;

--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.templates_certificados_id_template_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.templates_certificados_id_template_certificado_seq OWNER TO pooijyzcnnfrso;

--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.templates_certificados_id_template_certificado_seq OWNED BY public.template_certificado.id_template_certificado;


--
-- Name: tipo_tramite_recaudo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tipo_tramite_recaudo (
    id_tipo_tramite integer,
    id_recaudo integer,
    fisico boolean
);


ALTER TABLE public.tipo_tramite_recaudo OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_usuario; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tipo_usuario (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


ALTER TABLE public.tipo_usuario OWNER TO pooijyzcnnfrso;

--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.tipos_tramites_id_tipo_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_tramites_id_tipo_tramite_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipo_tramite.id_tipo_tramite;


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_usuarios_id_tipo_usuario_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipo_usuario.id_tipo_usuario;


--
-- Name: tramite_archivo_recaudo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.tramite_archivo_recaudo (
    id_tramite integer,
    url_archivo_recaudo character varying
);


ALTER TABLE public.tramite_archivo_recaudo OWNER TO pooijyzcnnfrso;

--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.tramites_id_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tramites_id_tramite_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramite.id_tramite;


--
-- Name: tramites_state; Type: VIEW; Schema: public; Owner: pooijyzcnnfrso
--

CREATE VIEW public.tramites_state AS
 SELECT t.id_tramite AS id,
    t.datos,
    t.id_tipo_tramite AS tipotramite,
    t.costo,
    t.fecha_creacion AS fechacreacion,
    t.codigo_tramite AS codigotramite,
    t.id_usuario AS usuario,
    t.url_planilla AS planilla,
    t.url_certificado AS certificado,
    ev.state,
    t.aprobado,
    t.fecha_culminacion AS fechaculminacion
   FROM (public.tramite t
     JOIN ( SELECT evento_tramite.id_tramite,
            public.tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
           FROM public.evento_tramite
          GROUP BY evento_tramite.id_tramite) ev ON ((t.id_tramite = ev.id_tramite)));


ALTER TABLE public.tramites_state OWNER TO pooijyzcnnfrso;

--
-- Name: usuario; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.usuario (
    id_usuario integer NOT NULL,
    nombre_completo character varying,
    nombre_de_usuario character varying,
    direccion character varying,
    cedula bigint,
    nacionalidad character(1),
    id_tipo_usuario integer,
    password character varying,
    telefono character varying,
    id_contribuyente integer,
    CONSTRAINT usuario_nacionalidad_check CHECK ((nacionalidad = ANY (ARRAY['V'::bpchar, 'E'::bpchar, 'J'::bpchar, 'P'::bpchar, 'G'::bpchar])))
);


ALTER TABLE public.usuario OWNER TO pooijyzcnnfrso;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuarios_id_usuario_seq OWNER TO pooijyzcnnfrso;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuario.id_usuario;


--
-- Name: valor; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.valor (
    id_valor integer NOT NULL,
    descripcion character varying NOT NULL,
    valor_en_bs numeric NOT NULL
);


ALTER TABLE public.valor OWNER TO pooijyzcnnfrso;

--
-- Name: valores_id_valor_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.valores_id_valor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.valores_id_valor_seq OWNER TO pooijyzcnnfrso;

--
-- Name: valores_id_valor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.valores_id_valor_seq OWNED BY public.valor.id_valor;


--
-- Name: variables_id_var_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.variables_id_var_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_id_var_seq OWNER TO pooijyzcnnfrso;

--
-- Name: variable; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.variable (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


ALTER TABLE public.variable OWNER TO pooijyzcnnfrso;

--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.variables_de_costo_id_variable_de_costo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_de_costo_id_variable_de_costo_seq OWNER TO pooijyzcnnfrso;

--
-- Name: variable_de_costo; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.variable_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);


ALTER TABLE public.variable_de_costo OWNER TO pooijyzcnnfrso;

--
-- Name: variable_ordenanza; Type: TABLE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TABLE public.variable_ordenanza (
    id_variable integer NOT NULL,
    nombre character varying NOT NULL,
    nombre_plural character varying NOT NULL
);


ALTER TABLE public.variable_ordenanza OWNER TO pooijyzcnnfrso;

--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE; Schema: public; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE public.variables_ordenanzas_id_variable_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_ordenanzas_id_variable_seq OWNER TO pooijyzcnnfrso;

--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE public.variables_ordenanzas_id_variable_seq OWNED BY public.variable_ordenanza.id_variable;


--
-- Name: base_task; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.base_task (
    task_id bigint NOT NULL,
    name text NOT NULL,
    kind timetable.task_kind DEFAULT 'SQL'::timetable.task_kind NOT NULL,
    script text NOT NULL,
    CONSTRAINT base_task_check CHECK (
CASE
    WHEN (kind <> 'BUILTIN'::timetable.task_kind) THEN (script IS NOT NULL)
    ELSE true
END)
);


ALTER TABLE timetable.base_task OWNER TO pooijyzcnnfrso;

--
-- Name: base_task_task_id_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.base_task_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.base_task_task_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: base_task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.base_task_task_id_seq OWNED BY timetable.base_task.task_id;


--
-- Name: chain_execution_config; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.chain_execution_config (
    chain_execution_config bigint NOT NULL,
    chain_id bigint,
    chain_name text NOT NULL,
    run_at timetable.cron,
    max_instances integer,
    live boolean DEFAULT false,
    self_destruct boolean DEFAULT false,
    exclusive_execution boolean DEFAULT false,
    excluded_execution_configs integer[],
    client_name text
);


ALTER TABLE timetable.chain_execution_config OWNER TO pooijyzcnnfrso;

--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.chain_execution_config_chain_execution_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.chain_execution_config_chain_execution_config_seq OWNER TO pooijyzcnnfrso;

--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.chain_execution_config_chain_execution_config_seq OWNED BY timetable.chain_execution_config.chain_execution_config;


--
-- Name: chain_execution_parameters; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.chain_execution_parameters (
    chain_execution_config bigint NOT NULL,
    chain_id bigint NOT NULL,
    order_id integer NOT NULL,
    value jsonb,
    CONSTRAINT chain_execution_parameters_order_id_check CHECK ((order_id > 0))
);


ALTER TABLE timetable.chain_execution_parameters OWNER TO pooijyzcnnfrso;

--
-- Name: database_connection; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.database_connection (
    database_connection bigint NOT NULL,
    connect_string text NOT NULL,
    comment text
);


ALTER TABLE timetable.database_connection OWNER TO pooijyzcnnfrso;

--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.database_connection_database_connection_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.database_connection_database_connection_seq OWNER TO pooijyzcnnfrso;

--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.database_connection_database_connection_seq OWNED BY timetable.database_connection.database_connection;


--
-- Name: execution_log; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.execution_log (
    chain_execution_config bigint,
    chain_id bigint,
    task_id bigint,
    name text NOT NULL,
    script text,
    kind text,
    last_run timestamp with time zone DEFAULT now(),
    finished timestamp with time zone,
    returncode integer,
    pid bigint
);


ALTER TABLE timetable.execution_log OWNER TO pooijyzcnnfrso;

--
-- Name: log; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now(),
    client_name text,
    pid integer NOT NULL,
    log_level timetable.log_type NOT NULL,
    message text
);


ALTER TABLE timetable.log OWNER TO pooijyzcnnfrso;

--
-- Name: log_id_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.log_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.log_id_seq OWNED BY timetable.log.id;


--
-- Name: migrations; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.migrations (
    id bigint NOT NULL,
    version text NOT NULL
);


ALTER TABLE timetable.migrations OWNER TO pooijyzcnnfrso;

--
-- Name: run_status; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.run_status (
    run_status bigint NOT NULL,
    start_status bigint,
    execution_status timetable.execution_status,
    chain_id bigint,
    current_execution_element bigint,
    started timestamp with time zone,
    last_status_update timestamp with time zone DEFAULT clock_timestamp(),
    chain_execution_config bigint
);


ALTER TABLE timetable.run_status OWNER TO pooijyzcnnfrso;

--
-- Name: run_status_run_status_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.run_status_run_status_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.run_status_run_status_seq OWNER TO pooijyzcnnfrso;

--
-- Name: run_status_run_status_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.run_status_run_status_seq OWNED BY timetable.run_status.run_status;


--
-- Name: task_chain; Type: TABLE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TABLE timetable.task_chain (
    chain_id bigint NOT NULL,
    parent_id bigint,
    task_id bigint NOT NULL,
    run_uid text,
    database_connection bigint,
    ignore_error boolean DEFAULT false
);


ALTER TABLE timetable.task_chain OWNER TO pooijyzcnnfrso;

--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE timetable.task_chain_chain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.task_chain_chain_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE timetable.task_chain_chain_id_seq OWNED BY timetable.task_chain.chain_id;


--
-- Name: ano; Type: TABLE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE TABLE valores_fiscales.ano (
    id integer NOT NULL,
    descripcion integer NOT NULL
);


ALTER TABLE valores_fiscales.ano OWNER TO pooijyzcnnfrso;

--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE valores_fiscales.ano_fiscal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.ano_fiscal_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE valores_fiscales.ano_fiscal_id_seq OWNED BY valores_fiscales.ano.id;


--
-- Name: construccion; Type: TABLE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE TABLE valores_fiscales.construccion (
    valor_fiscal numeric(14,2) NOT NULL,
    id bigint NOT NULL,
    tipo_construccion_id integer NOT NULL,
    ano_id integer NOT NULL
);


ALTER TABLE valores_fiscales.construccion OWNER TO pooijyzcnnfrso;

--
-- Name: construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE valores_fiscales.construccion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.construccion_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE valores_fiscales.construccion_id_seq OWNED BY valores_fiscales.construccion.id;


--
-- Name: tipo_construccion; Type: TABLE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE TABLE valores_fiscales.tipo_construccion (
    descripcion text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.tipo_construccion OWNER TO pooijyzcnnfrso;

--
-- Name: get_all_construcciones; Type: VIEW; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE VIEW valores_fiscales.get_all_construcciones AS
 SELECT construccion.id,
    ano.id AS ano_id,
    ano.descripcion AS ano,
    tipo_construccion.id AS tipo_construccion_id,
    tipo_construccion.descripcion AS tipo_construccion,
    construccion.valor_fiscal
   FROM ((valores_fiscales.construccion
     JOIN valores_fiscales.tipo_construccion ON ((construccion.tipo_construccion_id = tipo_construccion.id)))
     JOIN valores_fiscales.ano ON ((construccion.ano_id = ano.id)));


ALTER TABLE valores_fiscales.get_all_construcciones OWNER TO pooijyzcnnfrso;

--
-- Name: sector; Type: TABLE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE TABLE valores_fiscales.sector (
    descripcion text NOT NULL,
    parroquia_id integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.sector OWNER TO pooijyzcnnfrso;

--
-- Name: terreno; Type: TABLE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE TABLE valores_fiscales.terreno (
    valor_fiscal numeric(14,2) NOT NULL,
    sector_id integer NOT NULL,
    id bigint NOT NULL,
    ano_id integer NOT NULL
);


ALTER TABLE valores_fiscales.terreno OWNER TO pooijyzcnnfrso;

--
-- Name: get_all_terrenos; Type: VIEW; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE VIEW valores_fiscales.get_all_terrenos AS
 SELECT terreno.id,
    ano.id AS ano_id,
    ano.descripcion AS ano,
    parroquia.id AS parroquia_id,
    parroquia.nombre AS parroquia,
    sector.id AS sector_id,
    sector.descripcion AS sector,
    terreno.valor_fiscal
   FROM (((valores_fiscales.terreno
     JOIN valores_fiscales.sector ON ((terreno.sector_id = sector.id)))
     JOIN public.parroquia ON ((sector.parroquia_id = parroquia.id)))
     JOIN valores_fiscales.ano ON ((terreno.ano_id = ano.id)));


ALTER TABLE valores_fiscales.get_all_terrenos OWNER TO pooijyzcnnfrso;

--
-- Name: sector_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE valores_fiscales.sector_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.sector_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: sector_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE valores_fiscales.sector_id_seq OWNED BY valores_fiscales.sector.id;


--
-- Name: terreno_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE valores_fiscales.terreno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.terreno_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: terreno_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE valores_fiscales.terreno_id_seq OWNED BY valores_fiscales.terreno.id;


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

CREATE SEQUENCE valores_fiscales.tipo_construccion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.tipo_construccion_id_seq OWNER TO pooijyzcnnfrso;

--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER SEQUENCE valores_fiscales.tipo_construccion_id_seq OWNED BY valores_fiscales.tipo_construccion.id;


--
-- Name: actividad_economica id_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica ALTER COLUMN id_actividad_economica SET DEFAULT nextval('impuesto.actividad_economica_id_actividad_economica_seq'::regclass);


--
-- Name: actividad_economica_exoneracion id_actividad_economica_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion ALTER COLUMN id_actividad_economica_exoneracion SET DEFAULT nextval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq'::regclass);


--
-- Name: actividad_economica_sucursal id_actividad_economica_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_sucursal ALTER COLUMN id_actividad_economica_contribuyente SET DEFAULT nextval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq'::regclass);


--
-- Name: avaluo_inmueble id_avaluo_inmueble; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.avaluo_inmueble ALTER COLUMN id_avaluo_inmueble SET DEFAULT nextval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq'::regclass);


--
-- Name: baremo_servicio_municipal id_baremo; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.baremo_servicio_municipal ALTER COLUMN id_baremo SET DEFAULT nextval('impuesto.baremo_servicio_municipal_id_baremo_seq'::regclass);


--
-- Name: categoria_propaganda id_categoria_propaganda; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.categoria_propaganda ALTER COLUMN id_categoria_propaganda SET DEFAULT nextval('impuesto.categoria_propaganda_id_categoria_propaganda_seq'::regclass);


--
-- Name: contribuyente id_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente ALTER COLUMN id_contribuyente SET DEFAULT nextval('impuesto.contribuyente_id_contribuyente_seq'::regclass);


--
-- Name: contribuyente_exoneracion id_contribuyente_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion ALTER COLUMN id_contribuyente_exoneracion SET DEFAULT nextval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq'::regclass);


--
-- Name: convenio id_convenio; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.convenio ALTER COLUMN id_convenio SET DEFAULT nextval('impuesto.convenio_id_convenio_seq'::regclass);


--
-- Name: credito_fiscal id_credito_fiscal; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.credito_fiscal ALTER COLUMN id_credito_fiscal SET DEFAULT nextval('impuesto.credito_fiscal_id_credito_fiscal_seq'::regclass);


--
-- Name: detalle_retencion id_detalle_retencion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.detalle_retencion ALTER COLUMN id_detalle_retencion SET DEFAULT nextval('impuesto.detalle_retencion_id_detalle_retencion_seq'::regclass);


--
-- Name: dias_feriados id_dia_feriado; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.dias_feriados ALTER COLUMN id_dia_feriado SET DEFAULT nextval('impuesto.dias_feriados_id_dia_feriado_seq'::regclass);


--
-- Name: evento_fraccion id_evento_fraccion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_fraccion ALTER COLUMN id_evento_fraccion SET DEFAULT nextval('impuesto.evento_fraccion_id_evento_fraccion_seq'::regclass);


--
-- Name: evento_solicitud id_evento_solicitud; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_solicitud ALTER COLUMN id_evento_solicitud SET DEFAULT nextval('impuesto.evento_solicitud_id_evento_solicitud_seq'::regclass);


--
-- Name: factor id_factor; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.factor ALTER COLUMN id_factor SET DEFAULT nextval('impuesto.factor_id_factor_seq'::regclass);


--
-- Name: fraccion id_fraccion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.fraccion ALTER COLUMN id_fraccion SET DEFAULT nextval('impuesto.fraccion_id_fraccion_seq'::regclass);


--
-- Name: inmueble_contribuyente_natural id_inmueble_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural ALTER COLUMN id_inmueble_contribuyente SET DEFAULT nextval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq'::regclass);


--
-- Name: liquidacion id_liquidacion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion ALTER COLUMN id_liquidacion SET DEFAULT nextval('impuesto.liquidacion_id_liquidacion_seq'::regclass);


--
-- Name: liquidacion_descuento id_liquidacion_descuento; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion_descuento ALTER COLUMN id_liquidacion_descuento SET DEFAULT nextval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq'::regclass);


--
-- Name: multa id_multa; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.multa ALTER COLUMN id_multa SET DEFAULT nextval('impuesto.multa_id_multa_seq'::regclass);


--
-- Name: plazo_exoneracion id_plazo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.plazo_exoneracion ALTER COLUMN id_plazo_exoneracion SET DEFAULT nextval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq'::regclass);


--
-- Name: ramo id_ramo; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo ALTER COLUMN id_ramo SET DEFAULT nextval('impuesto.ramo_id_ramo_seq'::regclass);


--
-- Name: ramo_exoneracion id_ramo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo_exoneracion ALTER COLUMN id_ramo_exoneracion SET DEFAULT nextval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq'::regclass);


--
-- Name: registro_municipal id_registro_municipal; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.registro_municipal ALTER COLUMN id_registro_municipal SET DEFAULT nextval('impuesto.registro_municipal_id_registro_municipal_seq'::regclass);


--
-- Name: retencion id_retencion; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.retencion ALTER COLUMN id_retencion SET DEFAULT nextval('impuesto.retencion_id_retencion_seq'::regclass);


--
-- Name: solicitud id_solicitud; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.solicitud ALTER COLUMN id_solicitud SET DEFAULT nextval('impuesto.solicitud_id_solicitud_seq'::regclass);


--
-- Name: subramo id_subramo; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.subramo ALTER COLUMN id_subramo SET DEFAULT nextval('impuesto.subramo_id_subramo_seq'::regclass);


--
-- Name: tabulador_aseo_actividad_economica id_tabulador_aseo_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica ALTER COLUMN id_tabulador_aseo_actividad_economica SET DEFAULT nextval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq'::regclass);


--
-- Name: tabulador_aseo_residencial id_tabulador_aseo_residencial; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial ALTER COLUMN id_tabulador_aseo_residencial SET DEFAULT nextval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq'::regclass);


--
-- Name: tabulador_gas id_tabulador_gas; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas ALTER COLUMN id_tabulador_gas SET DEFAULT nextval('impuesto.tabulador_gas_id_tabulador_gas_seq'::regclass);


--
-- Name: tabulador_gas_actividad_economica id_tabulador_gas_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica ALTER COLUMN id_tabulador_gas_actividad_economica SET DEFAULT nextval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq'::regclass);


--
-- Name: tabulador_gas_residencial id_tabulador_gas_residencial; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial ALTER COLUMN id_tabulador_gas_residencial SET DEFAULT nextval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq'::regclass);


--
-- Name: tipo_aviso_propaganda id_tipo_aviso_propaganda; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda ALTER COLUMN id_tipo_aviso_propaganda SET DEFAULT nextval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq'::regclass);


--
-- Name: tipo_multa id_tipo_multa; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_multa ALTER COLUMN id_tipo_multa SET DEFAULT nextval('impuesto.tipo_multa_id_tipo_multa_seq'::regclass);


--
-- Name: usuario_enlazado id_usuario_enlazado; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_enlazado ALTER COLUMN id_usuario_enlazado SET DEFAULT nextval('impuesto.usuario_enlazado_id_usuario_enlazado_seq'::regclass);


--
-- Name: usuario_inmueble id_usuario_inmueble; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_inmueble ALTER COLUMN id_usuario_inmueble SET DEFAULT nextval('impuesto.usuario_inmueble_id_usuario_inmueble_seq'::regclass);


--
-- Name: verificacion_email id_verificacion_email; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_email ALTER COLUMN id_verificacion_email SET DEFAULT nextval('impuesto.verificacion_email_id_verificacion_email_seq'::regclass);


--
-- Name: verificacion_telefono id_verificacion_telefono; Type: DEFAULT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_telefono ALTER COLUMN id_verificacion_telefono SET DEFAULT nextval('impuesto.verificacion_telefono_id_verificacion_telefono_seq'::regclass);


--
-- Name: banco id_banco; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.banco ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- Name: campo id_campo; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.campo ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- Name: cargo id_cargo; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cargo ALTER COLUMN id_cargo SET DEFAULT nextval('public.cargo_id_cargo_seq'::regclass);


--
-- Name: caso_social id_caso; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.caso_social ALTER COLUMN id_caso SET DEFAULT nextval('public.casos_sociales_id_caso_seq'::regclass);


--
-- Name: certificado id_certificado; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.certificado ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- Name: detalle_factura id_detalle; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.detalle_factura ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- Name: evento_caso_social id_evento_caso; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_caso_social ALTER COLUMN id_evento_caso SET DEFAULT nextval('public.eventos_casos_sociales_id_evento_caso_seq'::regclass);


--
-- Name: evento_multa id_evento_multa; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_multa ALTER COLUMN id_evento_multa SET DEFAULT nextval('public.evento_multa_id_evento_multa_seq'::regclass);


--
-- Name: evento_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- Name: factura_tramite id_factura; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.factura_tramite ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


--
-- Name: inmueble_urbano id_inmueble; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.inmueble_urbano ALTER COLUMN id_inmueble SET DEFAULT nextval('public.inmueble_urbano_id_inmueble_seq'::regclass);


--
-- Name: institucion id_institucion; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.institucion ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- Name: multa id_multa; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.multa ALTER COLUMN id_multa SET DEFAULT nextval('public.multa_id_multa_seq'::regclass);


--
-- Name: notificacion id_notificacion; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.notificacion ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- Name: operatividad_terminal id_operatividad_terminal; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.operatividad_terminal ALTER COLUMN id_operatividad_terminal SET DEFAULT nextval('public.operatividad_terminal_id_operatividad_terminal_seq'::regclass);


--
-- Name: ordenanza id_ordenanza; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza ALTER COLUMN id_ordenanza SET DEFAULT nextval('public.ordenanzas_id_ordenanza_seq'::regclass);


--
-- Name: ordenanza_tramite id_ordenanza_tramite; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza_tramite ALTER COLUMN id_ordenanza_tramite SET DEFAULT nextval('public.ordenanzas_tramites_id_ordenanza_tramite_seq'::regclass);


--
-- Name: pago id_pago; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- Name: parroquia id; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.parroquia ALTER COLUMN id SET DEFAULT nextval('public.parroquias_id_seq'::regclass);


--
-- Name: permiso_de_acceso id_permiso; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.permiso_de_acceso ALTER COLUMN id_permiso SET DEFAULT nextval('public.permiso_de_acceso_id_permiso_seq'::regclass);


--
-- Name: propietario id_propietario; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietario_id_propietario_seq'::regclass);


--
-- Name: propietario_inmueble id_propietario_inmueble; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario_inmueble ALTER COLUMN id_propietario_inmueble SET DEFAULT nextval('public.propietarios_inmuebles_id_propietario_inmueble_seq'::regclass);


--
-- Name: recaudo id_recaudo; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.recaudo ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- Name: recuperacion id_recuperacion; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.recuperacion ALTER COLUMN id_recuperacion SET DEFAULT nextval('public.recuperacion_id_recuperacion_seq'::regclass);


--
-- Name: tarifa_inspeccion id_tarifa; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tarifa_inspeccion ALTER COLUMN id_tarifa SET DEFAULT nextval('public.tarifas_inspeccion_id_tarifa_seq'::regclass);


--
-- Name: template_certificado id_template_certificado; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.template_certificado ALTER COLUMN id_template_certificado SET DEFAULT nextval('public.templates_certificados_id_template_certificado_seq'::regclass);


--
-- Name: tipo_tramite id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_tramite ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- Name: tipo_usuario id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_usuario ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- Name: tramite id_tramite; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tramite ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- Name: usuario id_usuario; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Name: valor id_valor; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.valor ALTER COLUMN id_valor SET DEFAULT nextval('public.valores_id_valor_seq'::regclass);


--
-- Name: variable_ordenanza id_variable; Type: DEFAULT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable_ordenanza ALTER COLUMN id_variable SET DEFAULT nextval('public.variables_ordenanzas_id_variable_seq'::regclass);


--
-- Name: base_task task_id; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.base_task ALTER COLUMN task_id SET DEFAULT nextval('timetable.base_task_task_id_seq'::regclass);


--
-- Name: chain_execution_config chain_execution_config; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_config ALTER COLUMN chain_execution_config SET DEFAULT nextval('timetable.chain_execution_config_chain_execution_config_seq'::regclass);


--
-- Name: database_connection database_connection; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.database_connection ALTER COLUMN database_connection SET DEFAULT nextval('timetable.database_connection_database_connection_seq'::regclass);


--
-- Name: log id; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.log ALTER COLUMN id SET DEFAULT nextval('timetable.log_id_seq'::regclass);


--
-- Name: run_status run_status; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.run_status ALTER COLUMN run_status SET DEFAULT nextval('timetable.run_status_run_status_seq'::regclass);


--
-- Name: task_chain chain_id; Type: DEFAULT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.task_chain_chain_id_seq'::regclass);


--
-- Name: ano id; Type: DEFAULT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.ano ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.ano_fiscal_id_seq'::regclass);


--
-- Name: construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.construccion_id_seq'::regclass);


--
-- Name: sector id; Type: DEFAULT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.sector ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.sector_id_seq'::regclass);


--
-- Name: terreno id; Type: DEFAULT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.terreno ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.terreno_id_seq'::regclass);


--
-- Name: tipo_construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.tipo_construccion_id_seq'::regclass);


--
-- Data for Name: actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.actividad_economica (id_actividad_economica, numero_referencia, descripcion, alicuota, minimo_tributable) FROM stdin;
1	2029001	Transporte Terrestre de Carga refrigerada.	2.00	5
2	2030001	Almacenamiento de productos, materiales, insumos, equipos, maquinarias.	2.00	4
3	2031001	Almacenamiento Refrigerado.	3.50	4
4	2032001	Transporte Aéreo y Marítimo de Carga.	3.50	6
5	2033001	Servicio de encomiendas.	3.00	6
6	2034001	Transporte terrestre de pasajeros.	1.00	4
7	2035001	Transporte Lacustre o Marítimo de pasajeros.	3.00	4
8	2036001	Transporte aéreo de pasajeros.	3.00	4
9	2037001	Transporte de personal.	1.00	4
10	2038001	Empresas de transporte de valores y vigilancia.	2.50	4
11	2039001	Agencias Funerarias y Capillas Velatorias.	1.00	4
12	2040001	Reproducciones fotostáticas, heliografías y afines.	1.00	2
13	2041001	Intermediación en contratos de arrendamiento y compra- venta de inmuebles. 	5.00	6
14	2042001	Arrendamiento de inmuebles.	5.00	5
15	2043002	Arrendamiento de Fondos de Comercio.	5.00	5
16	2044001	Alquiler de Lanchas, Gabarras y Similares.	3.00	6
17	2045001	Alquiler de Vehículos.	3.00	5
18	2046001	Servicio de Estacionamiento Vehicular en Centros Comerciales y Judicial.	1.50	5
19	2047001	Venta e Implementación de Software.	2.00	4
20	30640012	Distribución y venta de vehículos y motos (usados).	4.00	4
21	1001001	Preparación y envasado de carnes, excepto embutidos y productos marinos.	2.00	5
22	1002001	Procesamiento y envasado de productos marinos.	3.00	5
23	1003001	Fabricación y procesamiento de productos lácteos y sus derivados.	2.00	3
24	1004001	Industria de bebidas alcohólicas (cerveza, ron, whisky, vino) y no alcohólicas refrescos, maltas y otras bebidas no alcohólicas, distribuidos en envases retornables o biodegradables, excepto jugos de frutas y vegetales	4.00	8
25	1005001	Industria de bebidas alcohólicas (cerveza, ron, whisky, vino) y no alcohólicas refrescos, maltas y otras bebidas no alcohólicas, distribuidos en envases no retornables o no biodegradables.	6.00	8
26	1006001	Elaboración de alimentos para consumo animal.	2.50	3
27	1007001	Elaboración y envasado de embutidos de cualquier tipo, excepto productos marinos.	3.00	5
28	1009001	Fabricación de aceites y grasas para consumo humano.	1.50	5
29	1010001	Molienda, elaboración, preparación y limpieza de productos para obtener harina y cereales.	2.50	5
30	1011001	Fabricación de pan y pastelería en todas sus formas.	2.00	4
31	1012001	Industria de pastas alimenticias en todas sus formas.	2.00	4
32	1013001	Fabricación de galletas y confitería.	2.00	5
33	1014001	Industria de sal.	1.00	5
34	1015001	Industria de azúcar, papelón, condimentos y vinagre.	1.00	3
35	1016001	Industria de productos de café, cacao, chocolate, té y similares.	2.50	5
36	1017001	Tratamiento y envasado retornable de aguas y fabricación de hielo.	2.00	5
37	1018001	Industrias de tabaco y sus derivados.	6.00	7
38	1019001	Industrias textiles.	2.00	4
39	1020001	Fabricación de colchones.	3.00	5
40	1021001	Industrias gráficas litográficas, tipográficas, de imprentas y sellos de caucho.	2.00	5
41	1022001	Fabricación y recuperación de pulpa y otras fibras para hacer papel o cartón, envases y similares de papel y cartón, mantelería, servilletas, papel sanitario y otros de pulpa, papel y cartón.	2.50	5
42	1023001	Industrias de producción de madera, Aserraderos y productos de madera.	2.50	5
43	1024001	Industrias de productos químicos.	2.00	5
44	1025001	Fabricación de productos farmacéuticos,\tlaboratorio farmacológico, medicamentos y cosméticos.	2.00	5
45	1026001	Industrias para la preparación de asfalto de cualquier tipo.	3.00	5
46	1027001	Fabricación de productos de plásticos, cauchos y goma.	3.00	4
47	1028001	Fabricación de láminas de mármol, granito, silestone y similares en cualquiera de sus formatos.	3.50	5
48	20270012	Puestos de Comida Callejera (Empanadas, Tequeños, Pastelitos, Mandocas y Similares, excluye Franquicias)	2.00	4
49	2028001	Transporte Terrestre de Carga no refrigerada.	2.00	4
50	2048001	Talleres de reparación y mantenimiento general de vehículos de cualquier tipo.	2.00	3
51	1029001	Fabricación   de   cemento,   concreto   premezclado,  placas prefabricadas y bloques de cemento. Fábrica de objetos de barro, loza y porcelana, cerámica, productos de arcilla para la construcción y alfarería, cal y yeso. Bloques de arcilla.  Productos de hormigón, granzones, granzoncillo y similares. Explotación de arcilla, arena y minerales.	2.50	4
52	1030001	Fábrica de vidrio y fibra de vidrio y manufacturas de vidrios para carros y otros vidrios en general. Fábrica de espejos. Fabricación de refractarios y similares.	2.50	5
53	1031001	Industrias de productos metalúrgicos y fundiciones en general.	2.00	5
54	1032001	Fabricación de maquinarias para la industria.	1.50	5
55	1033001	Diques y astilleros para la construcción, reparación y mantenimiento de embarcaciones.	3.50	5
56	1034001	Fabricación de producto oftalmológicos, cristales oftálmicos, lentes intraoculares.	2.00	4
57	1035001	Fabricación de placas, rótulos, letreros y anuncios, copas, trofeos, vallas, avisos y anuncios públicos.	2.00	5
58	1036001	Fabricación de productos de seguridad industrial.	2.00	5
59	1037001	Industria de la Construcción.	1.00	4
60	1038001	Plantas de procesamiento y envasado de gas de cualquier tipo.	2.00	4
61	1039001	Empresas Desarrolladoras de Software.	2.00	5
62	1040001	Industria del calzado.	2.00	3
63	1041001	Fabricación de pinturas de cualquier tipo.	2.50	5
64	1042001	Fábricas de muebles de cualquier tipo.	2.00	3
65	1043001	Fabricación de ventanas, puertas y rejas de cualquier tipo y uso.	3.00	4
66	1044001	Fabricación de helados.	2.00	4
67	1045001	Otros productos metálicos, cavas, recipientes, urnas y similares.	2.00	5
68	1046001	Fabricación de toldos, persianas, mamparas, carpas, lámparas y similares.	3.00	5
69	1047001	Fabricación de blindados para vehículos y vehículos blindados modificados.	4.00	6
70	1048001	Otras industrias no especificadas.	6.00	8
71	2001001	Bingos, casinos y demás casas o establecimientos de juegos de azar.	10.00	8
72	2002001	Empresas de espectáculos, recreación y esparcimiento.	3.00	4
73	2003001	Empresas de publicidad.	3.50	5
74	2004001	Salas de Cine.	3.00	3
75	2005001	Servicio de telecomunicaciones.	1.00	3
76	2006001	Distribución de electricidad.	1.00	3
77	2007001	Servicios para la construcción o ejecución de obras.	3.50	5
78	2008001	Arrendamiento y Servicios de mantenimiento, conservación y limpieza de naves, aeronaves y similares.	3.50	5
79	2009001	Arrendamiento de equipos y maquinarias con o sin operador.	3.50	5
80	2010001	Servicio y mantenimiento de jardines, ornatos y similares.	2.00	3
81	2011001	Servicios aduaneros y agencias de aduanales.	3.50	4
82	2012001	Servicio para el Suministro de Personal, vigilancia, mantenimiento y similares.	3.00	4
83	2013001	Servicios de clínica, incluye: hotelería, farmacia, laboratorio, imágenes, estudios, alquileres de equipos, acompañante, comidas, y similares.	1.50	4
84	2014001	Servicio de emergencia pre-pagada.	2.00	5
85	2015001	Servicios de radiografías, radioscopias, ecógramas, resonancias magnéticas, centro de diagnósticos e imágenes, laboratorios, electrocardiogramas y otros asociados a la salud.	1.50	4
86	2016001	Servicio de Alquiler de Ambulancia y alquiler de equipos médicos.	1.50	3
87	2017001	Clínicas veterinarias y spa para mascotas.	2.00	3
88	2018001	Bancos, empresas de seguros y reaseguros, casas de cambio y otras instituciones financieras.	6.00	4
89	2019001	Corretaje de Seguros	3.00	4
90	2020001	Bar, Discotecas, cervecerías, tascas, cafés.	3.00	5
91	2021001	Restaurantes, fuentes de soda, pizzerías, heladerías y similares.	2.00	4
92	2022001	Salas para fiestas y juegos infantiles, reuniones, recepciones.	2.00	4
93	2023001	Hoteles.	2.00	6
94	20230011	Hoteles 1 y 2 estrellas	2.00	3
95	20230012	Hoteles 3 y 4 estrellas	2.00	4
96	20230013	Hoteles 5 estrellas o mas 	2.00	6
97	2024002	Posadas, pensiones.	1.00	3
98	2025003	Moteles.	4.50	6
99	2026001	Restaurantes Tipo franquicia, Franquicias de Comida y Cadena de Restaurantes.	2.50	5
100	2027001	Puestos de Comida Callejera (Ventas de Parrillas, Perro calientes, Hamburguesas, Arepas, Empanadas, Tequeños, Pastelitos, Mandocas y Similares, excluye Franquicias).	3.00	5
101	20270011	Puestos de Comida Callejera (Ventas de Parrillas, Perro calientes, Hamburguesas, Arepas excluye Franquicias)	3.00	5
102	2049002	Talleres de adecuación, reparación y fabricación de productos metalúrgicos.	2.00	4
103	2050001	Servicios de mantenimiento, reconstrucción e instalación de transformadores eléctricos, tendidos eléctricos, instalación de postes, interruptores y demás implementos y equipos para el servicio eléctrico.	1.50	3
104	2051001	Servicios de reparación y mantenimiento de equipos, celulares, artefactos eléctricos y electrodomésticos.	2.00	3
105	2052001	Reparación y Mantenimiento de Equipos Tecnológicos, Calibración y o Mantenimiento de Fuentes Radioactivas y similares.	3.00	4
106	2053001	Lavado y engrase de vehículos, cambio de aceite, aútolavado y similares.	3.00	4
107	2054001	Servicio de grúas.	2.00	4
108	2055001	Tintorerías y lavanderías.	2.50	4
109	2056001	Barberías, Salones de belleza, spa, estéticas y peluquerías (sin licor)	2.00	3
110	2057001	Barberías, Salones de belleza, spa, estéticas y peluquerías (con licor)	3.00	4
111	2058001	Gimnasios.	3.00	4
112	2059001	Casa de Empeño.	6.00	4
113	2060001	Servicio de deshuese, despresado, troceado y corte de Animales.	3.00	4
114	2061001	Servicio de Mantenimiento, Limpieza y Aseo al Comercio e Industria.	3.50	5
115	2062001	Servicio de Fumigación y desinfección.	2.50	5
116	2063001	Servicio de Tapicería.	2.00	4
117	2064001	Servicio de Reparación y Mantenimiento de Equipos de Refrigeración en general.	3.00	3
118	2065001	Servicio de Rectificación de Motores.	2.50	5
119	2066001	Servicio de Montaje, Alineación, Balanceo y reparación de cauchos.	2.00	4
120	2067001	Oficinas cobranzas, administración de condominios y  similares	3.00	4
121	2068001	Servicios Petroleros, entendidos por tales, aquellos contratados para la Exploración, Explotación, Extracción, Mantenimiento, Transporte y Refinación de Hidrocarburos. Suministro de Equipos y Herramientas, excluye Servicios prestados en el Lago de Maracaibo.	4.50	5
122	2069002	Servicios a la Industria Petrolera no conexos a la Exploración, Explotación, Extracción, Mantenimiento, Transporte y Refinación de Hidrocarburos.	4.50	5
123	2070003	Servicios y construcciones ejecutados en el Lago de Maracaibo (sobre o bajo sus aguas, o en el lecho del lago).	3.00	6
124	2071001	Comisionistas y Consignatarios (Intermediario, Agentes, Representantes, Concesionarios) y similares.	8.00	5
125	2072001	Comisión por Venta de Boleto Aéreo, Terrestre y Marítimo.	3.00	5
126	2073001	Servicio de Laboratorio Medico	2.00	3
127	2074001	Servicio de Consultorio Medico Odontologico	2.00	4
128	2075001	Transporte Urbano inscrito en el Instituto Municipal de Transporte	1.00	2
129	2076001	Servicio por honorarios Profesionales	2.00	4
130	2077001	Otros servicios no especificados.	4.00	8
131	3001001	Cadenas de supermercados, hipermercados, megatiendas, multitiendas y minimarket.	1.50	6
132	3002001	Venta de materiales, equipos, herramientas e insumos para la exploración, explotación, extracción, mantenimiento, transporte y refinación de hidrocarburos.	4.00	5
133	3003002	Venta de materiales, equipos, herramientas e insumos a la industria Petrolera no conexos a la exploración, explotación, extracción, mantenimiento, transporte y refinación de Hidrocarburos.	4.00	5
134	3004001	Distribución  y Venta de gas de cualquier tipo.	2.00	3
135	3005001	Estaciones de servicio para el expendio de combustible.	1.00	1
203	3070001	Venta y reparación de Bicicletas, repuestos y accesorios.	3.00	2
204	3071001	Distribución y venta de aceite de todo tipo para vehículos y maquinarias, vendidos en pipas y similares.	3.00	3
136	3006001	Cadena de Tiendas de Ventas al Mayor o detal de Insumos Comerciales, Mega tiendas y Multitiendas. Incluye todos aquellos establecimientos o tiendas donde concurran los siguientes requisitos: a) Que ejerzan simultáneamente tres (3) o más aforos; y b) Que realicen ventas al mayor y detal.	3.50	5
137	3007001	Abastos, bodegas y pequeños detales de víveres.	2.00	2
138	3008001	Distribución y venta de productos químicos.	3.00	3
139	3009001	Distribución de productos farmacéuticos.	2.50	4
140	3010001	Farmacias.	2.00	3
141	3011001	Distribución de pinturas, lacas, barnices y materiales aislantes.	3.50	4
142	3012001	Detal de pinturas, lacas, barnices y materiales aislantes.	3.00	3
143	3013001	Distribución y venta de alimentos para animales.	2.00	3
144	3014001	Venta de desecho de cebada, cereal y afrecho.	4.00	4
145	3015001	Venta y Distribución de productos para el agro, avícola, pesquero y similares.	2.00	3
146	3016001	Distribución de víveres, aceites y grasas comestibles, presentados en envases retornables.	2.50	3
147	3017002	Distribución de víveres, aceites y grasas comestibles, presentados en envases no retornables.	3.00	3
148	3018001	Distribución de helados y productos similares, presentados en envases retornables o biodegradables.	3.50	2
149	3019002	Distribución de helados y productos similares, presentados en envases no retornables ni biodegradables.	5.00	3
150	3020001	Venta de helados, pastelería, cyber y refresquería al detal.	2.00	3
151	3021001	Distribución de carnes de cualquier tipo, excepto embutidos.	2.00	2
152	3022001	Venta de carnes, Charcutería y pescadería.	2.00	3
153	3023001	Distribución de embutidos de cualquier tipo empacados en plásticos.	3.00	3
154	3024001	Boutique y sastrería.	4.00	4
155	30240011	Boutique	3.00	3
156	30240012	Sastrería	2.00	2
157	3025001	Comercialización al detal de pan.	2.00	2
158	3026001	Mayorista de confiterías.	3.00	3
159	3027001	Distribuidor de productos lácteos, jugos de frutas y Vegetales, presentados en envases biodegradables.	2.00	3
160	3028001	Distribuidor de productos lácteos y jugos de frutas y Vegetales, presentados en envases, plásticos, vidrio, metal y tetra pack.	4.00	3
161	3029001	Distribución de bebidas alcohólicas y no alcohólicas, presentadas en envases o empaques retornables o biodegradables, excepto jugos de frutas y vegetales.	3.00	5
162	3030002	Distribución de bebidas alcohólicas y no alcohólicas, presentados en envases plásticos, vidrio, metal y tetra pack.	5.00	5
163	3031001	Venta de productos alimenticios, bebidas alcohólicas, no alcohólicas y gaseosas en vehículos automotores (sólo ruteros).	1.50	3
164	3032001	Distribución al mayor y detal de agua presentados en envases o empaques retornables o biodegradables.	2.20	3
165	3033002	Distribución al mayor y detal de agua presentada en envases o empaques plásticos o no biodegradables.	3.50	4
166	3034001	Licorerías (Depósito de licores).	4.00	5
167	3035001	Venta de frutas, verduras y hortalizas.	2.00	2
168	3036001	Venta de equipos médicos y quirúrgicos.	2.00	3
169	3037001	Artículos ortopédicos.	1.00	2
170	3038001	Laboratorio Dental, implantes y prótesis dentales, bracket, retenedores.	2.50	3
171	3039001	Artículos de lujo, pieles, joyas, reparación de prendas y relojes.	5.00	5
172	3040001	Venta de artículos de peluquerías (cepillos, tintes, secadores y otros productos relacionados).	2.00	3
173	3041001	Artículos religiosos.	1.00	1
174	3042001	Floristerías y viveros.	3.00	2
175	3043001	Jugueterías, quincallas, bazares y similares, artículos deportivos  y fotográficos.	3.00	3
176	3044001	Papelerías, revistas y artículos de oficina.	3.00	3
177	3045002	Venta de libros.	1.00	1
178	3046001	Venta de utensilios y enseres para la limpieza (Lampazos, escobas, rastrillos y similares).	3.00	3
179	3047001	Venta de Persianas, Alfombras, Cortinas, telas, cueros, semi-cueros y demás artículos para Tapicerías.	3.00	3
180	3048001	Venta de Lencerías.	3.00	3
181	3049001	Venta al Mayor y Detal de Artículos de Seguridad  Industrial (botas, guantes, cascos, mascarillas, lentes de seguridad y todo lo relacionado con la seguridad industrial).	3.00	4
182	3050001	Ventas de muebles.	3.00	3
183	3051001	Ventas de electrodomésticos.	2.00	4
184	3052001	Venta de repuestos y materiales electrónicos y eléctricos.	2.50	4
185	3053002	Venta de celulares, equipos de telecomunicaciones, accesorios y repuestos.	3.00	4
186	3054001	Ferreterías, tornillerías y cerrajerías.	3.00	3
187	3055001	Distribución y ventas  de cemento de cualquier tipo, bloques, arenas, granzón y demás materiales similares.	2.00	3
188	3056001	Distribución y venta productos de arcilla para la construcción y alfarería, cal y yeso. Bloques de arcilla. Productos de hormigón, granzones, granzoncillo y similares.	3.00	3
189	3057001	Distribución y Venta de Madera de cualquier tipo y demás materiales para carpintería.	2.00	3
190	3058001	Distribución y venta de productos de hierro.	2.00	4
191	3059001	Distribución y Venta de mármol, granitos y silestone en cualquiera de sus formatos.	5.00	6
192	3060001	Distribución y Venta de cerámicas en cualquiera de sus formatos.	3.00	4
193	3061001	Distribución y venta de calzados, carteras y otros artículos de cuero.	3.00	3
194	3062001	Cosméticos, perfumes y artículos de tocador.	3.00	3
195	3063001	Ópticas y Tiendas de artículos de oftalmología.	2.00	3
196	3064001	Distribución y venta de vehículos, motos, nuevos y usados.	5.00	6
197	30640011	Distribución y venta de vehículos y motos (nuevos).	5.00	4
198	3065001	Venta de maquinarias industriales, agrícolas, similares y repuestos para las mismas.	2.50	3
199	3066001	Venta al detal de motores nuevos, accesorios, repuestos para vehículos de cualquier tipo.	4.00	4
200	3067001	Ventas de cauchos y acumuladores de energía.	3.00	4
201	3068001	Importadoras de motores, repuestos usados y chiveras.	5.00	4
202	3069001	Importadoras de electrodomésticos usados y repuestos usados para electrodomésticos.	4.00	3
205	3072002	Distribución y ventas de lubricantes de todo tipo: aditivos, grasas y productos similares para vehículos y maquinaria  en envases sellado de plásticos, vidrio, metal o tetra pack.	2.00	3
206	3073001	Ventas de fuentes radioactivas y similares.	3.50	5
207	3074001	Distribución y venta de cartuchos para impresoras, fotocopiadoras y similares.	3.00	3
208	3075001	Distribución y venta de Vidrio para vehículos.	3.00	3
209	3076001	Distribución y venta de vidrio templado.	4.00	3
210	3077001	Venta de vidrio, excepto para vehículos y vidrio templado.	2.00	3
211	3078001	Distribución de Productos de Tabaco.	6.00	5
212	3079001	Tienda de Instrumentos musicales.	3.00	3
213	3080001	Venta de transformadores, plantas eléctricas, tendidos eléctricos, postes, interruptores y demás implementos y equipos eléctricos y mecánicos.	3.00	3
214	3081001	Acopio o recolección de envases plásticos, cartones, vidrio, materiales metálicos con fines de reciclaje	6.00	4
215	3082001	Distribución y venta de billetes de loterías.	5.00	5
216	3083001	Parley	5.00	6
217	3084001	Peñas Hipicas	4.00	4
218	3085001	Otras actividades comerciales no especificadas.	6.00	5
219	4001001	Pequeños Empresarios	0.50	1
220	1008001	Industrias de jugos, sopas, salsas, mermeladas, postres y otros de frutas y vegetales.	2.00	5
\.


--
-- Data for Name: actividad_economica_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.actividad_economica_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_actividad_economica) FROM stdin;
2	24	6
3	24	8
4	24	7
5	28	1
6	30	11
\.


--
-- Data for Name: actividad_economica_sucursal; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.actividad_economica_sucursal (id_actividad_economica_contribuyente, id_registro_municipal, numero_referencia, aplicable_desde) FROM stdin;
50	80	2005001	\N
51	80	3053002	\N
52	81	2013001	\N
56	86	3010001	\N
57	87	3001001	\N
58	87	3010001	\N
59	88	3001001	\N
60	88	3010001	\N
61	89	3001001	\N
62	89	3010001	\N
63	90	3001001	\N
64	90	3010001	\N
65	91	3001001	\N
66	91	3010001	\N
67	92	3001001	\N
68	92	3010001	\N
69	93	3001001	\N
70	93	3010001	\N
71	94	2077001	\N
72	95	2032001	\N
74	96	2047001	\N
75	99	3001001	\N
76	100	3001001	\N
77	101	3049001	\N
78	101	3054001	\N
79	101	3001001	\N
84	102	3001001	\N
85	102	3049001	\N
86	102	3054001	\N
88	103	3054001	\N
89	103	3001001	\N
90	103	3049001	\N
93	105	20270012	\N
97	107	2029001	\N
98	107	2030001	\N
99	107	2031001	\N
100	108	2029001	\N
101	108	2030001	\N
102	108	2031001	\N
103	109	2032001	\N
104	82	2034001	\N
105	110	2029001	\N
106	110	2030001	\N
107	110	2031001	\N
116	113	2032001	2020-06-26
117	113	2031001	2020-03-05
118	113	2029001	2019-07-12
119	113	2033001	2018-07-18
120	114	3007001	2019-12-01
53	83	3001001	2020-07-01
54	83	3010001	2020-03-05
55	83	3062001	2020-03-14
124	83	2029001	2019-07-03
94	106	2029001	2020-07-01
95	106	2030001	2020-07-02
96	106	2031001	2020-07-20
128	106	2032001	2020-07-15
137	115	3007001	2020-01-10
138	115	2045001	2020-02-01
139	116	3007001	2020-01-02
140	116	2031001	2020-03-02
141	116	2045001	2020-06-02
\.


--
-- Data for Name: avaluo_inmueble; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.avaluo_inmueble (id_avaluo_inmueble, id_inmueble, avaluo, anio) FROM stdin;
184	433	0	2020
185	434	0	2020
186	435	0	2020
187	436	0	2020
188	437	0	2020
189	438	0	2020
190	439	0	2020
191	440	0	2020
192	441	0	2020
193	442	0	2020
194	443	0	2020
195	444	0	2020
196	445	0	2020
197	446	0	2020
198	447	0	2020
199	448	0	2020
200	449	0	2020
201	450	0	2020
202	451	0	2020
203	452	0	2020
204	453	0	2020
205	454	0	2020
206	455	0	2020
207	456	0	2020
208	457	0	2020
209	458	0	2020
210	459	0	2020
211	460	0	2020
212	461	0	2020
213	462	0	2020
214	463	0	2020
215	464	0	2020
216	465	0	2020
217	466	0	2020
218	467	0	2020
219	468	0	2020
220	469	0	2020
221	470	0	2020
222	471	0	2020
223	472	0	2020
224	473	0	2020
225	474	0	2020
226	475	0	2020
227	476	0	2020
228	477	0	2020
229	478	0	2020
230	479	0	2020
231	481	22222	2020
232	482	123123	2020
233	483	123123	2020
234	484	12312333	2020
235	485	1231231	2020
236	485	123123	2017
237	486	35454751234867	2020
238	487	123123	2020
239	487	123132	2019
240	488	12313	2016
241	488	123123	2017
242	489	1313	2016
243	489	12313	2017
244	490	686768	2020
245	491	25000000000	2020
246	491	200000000	2019
247	491	500000000	2016
248	491	500000000	2017
249	491	4700000000	2018
250	492	16000000	2020
251	493	560000000	2020
252	494	300000000	2020
253	495	50000000	2020
\.


--
-- Data for Name: baremo_servicio_municipal; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.baremo_servicio_municipal (id_baremo, descripcion, indicador) FROM stdin;
1	Costo por Metro Cuadrado para Servicio de Gas	0.1
2	Límite del Costo para Servicio de Gas	150
\.


--
-- Data for Name: categoria_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.categoria_propaganda (id_categoria_propaganda, descripcion) FROM stdin;
1	A-001, PUBLICIDAD COMERCIAL DE PRODUCTOS DE BEBIDAS ALCOHÓLICAS REFRESCOS, MALTAS, Y BEBIDAS ENERGIZANTES.
3	A-003, PROPAGANDA SOBRE PRODUCTOS  MANUFACTURAS DE TABACO.
4	A-004, PUBLICIDAD COMERCIAL DE PRODUCTOS ALIMENTICIOS.
5	A-005, PROPAGANDA COMERCIAL PRODUCTOS DE HELADOS.
7	A-007, PROPAGANDA Y PUBLICIDAD COMERCIAL DE FRANQUICIAS.
6	A-006, PUBLICIDAD COMERCIAL DE PRODUCTOS DE PASAPALOS O SNACKS.
8	A-008, PUBLICIDAD COMERCIAL DE PRODUCTOS DE ASEO DE HIGIENE PERSONAL.
9	A-009, PROPAGANDA COMERCIAL DE PRODUCTOS DE LUBRICANTES, ADITIVOS Y DEMÁS PRODUCTOS PARA VEHICULOS.
10	A-010, PROPAGANDA COMERCIAL DE PRODUCTOS DE TELECOMUNICACIONES (TV POR CABLE  Y SATELITAL, TELEFONÍA MOVIL Y FIJA DE INTERNET).
11	A-011, PROPAGANDA COMERCIAL DE AUTOMERCADOS, SUPERMERCADOS E HIPERMERCADOS.
12	A-012, PUBLICIDAD Y PROPAGANDA EN INDUSTRIA, COMERCIO Y SERVICIOS NO PATROCINADOS POR MARCAS REGISTRADAS, PRODUCTOS O FRANQUICIAS.
13	A-013, PUBLICIDAD Y PROPAGANDA  EN MARCAS DE VEHICULOS, NEUMATICOS  Y ACUMULADOR DE ENERGÍA PARA VEHÍCULOS.
14	A-014, OTROS PRODUCTOS  DE PUBLICIDAD Y PROPAGANDA COMERCIAL.
2	PROPAGANDA COMERCIAL DE BANCS, SEGUROS Y DEMAS ENTIDADES FINANCIERAS.
\.


--
-- Data for Name: contribuyente; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.contribuyente (id_contribuyente, tipo_documento, documento, razon_social, denominacion_comercial, siglas, id_parroquia, sector, direccion, punto_referencia, verificado, tipo_contribuyente, es_agente_retencion) FROM stdin;
84	J	304689713	CORPORACION DIGITEL, C.A.	CORPORACION GSM		\N		\N		t	JURIDICO	f
85	J	070015357	POLICLINICA MCBO C A	POLICLINICA MARACAIBO		72	SANTA RITA	Avenida 8 Calle 71, Local Nro. 1	SANTA RITA	t	JURIDICO	f
86	J	308620483	FARMACIA COVIDES C.A.	FARMACIA COVIDES C.A.		64	INDIO MARA	Avenida 65 Calle  22A, Local Nro.  MZN	EDIF. IPSFA	t	JURIDICO	f
87	J	000202001	FARMATODO, C.A.	FARMATODO, C.A. FARMACIA FUERZAS ARMADAS		65	PARCELAMIENTO LA VILLA	Avenida 14B Calle 45, Local Nro. 789	frente a ferretotal	t	JURIDICO	f
88	V	123456789	Julio Sanchez	Julio Sanchez	si	76	tucupita	x ahi x alla	mmmm cerca d ahi	t	NATURAL	f
89	V	12543654	jose sanchez	comercializadora	CMCLZDR	69	123	mcbo	mcbo	t	NATURAL	f
90	J	313520209	TALLER DE TORNOS Y EMBOBINADOS D Y M,CA	TALLER DE TORNOS Y EMBOBINADOS D Y M,CA		64	NUEVA VIA	Avenida 16 Y 16B Calle 93, Local Nro. 16-32	FDO CEMENTERIO CUADRADO	t	JURIDICO	f
91	J	317355598	MSL GROUPAGE, C.A. (SUCURSAL)	MSL GROUPAGE, C.A. (SUCURSAL)		72	BELLA VISTA	Avenida 4 Calle 67, Local Nro.  71	SUCURSAL	t	JURIDICO	f
95	J	413060540	SERVICIOS INFORMATICOS WAKUPLUS CA	SERVICIOS INFORMATICOS WAKUPLUS CA	SERVICIOS INFORMATICOS WAKUPLUS CA	72	DELICIAS	Avenida 15 Y 14A-74 Calle 74, Local Nro. 7	5 DE JULIO	t	JURIDICO	f
96	J	311456759	MEGA 72 C.A	MEGA 72 C.A		72	0	Avenida 0 Calle 0, Casa Nro. 0	0	t	JURIDICO	f
97	J	400000005	Mi empresa CA	Lo q se CA	MECA	63	sabaneta	av 21 calle 86	lo que sea	t	JURIDICO	f
98	J	306020403	DISTRIBUIDORA J.K. C.A.	DISTRIBUIDORA J.K. C.A.		65	18 DE OCTUBRE	Avenida 2 Calle IJ, Casa Nro. 3--75	plaza de 18 de octubre	t	JURIDICO	f
99	J	003257176	FERRETOTAL CARACAS C.A.	FERRETOTAL CARACAS C.A. (SUCURSAL)		73		Avenida Calle  , Casa Nro.  		t	JURIDICO	f
100	V	18921679	Triny Rosales	Empanadas triny	EMPTR	62	Cañada Honda	av 21 calle 86	en visoca	t	NATURAL	f
101	J	312645978	Comercializadora	comercializadora	CMCLZDR	68	123	mcbo	mcbo	t	JURIDICO	f
103	J	312645976	jose coro	comercializadora	corocoro	61	bolivar	mcbo	mcbo	t	JURIDICO	f
104	J	356789134	jose coro	comercializadora	corocoro	65	bolivar	mcbo	mcbo	t	JURIDICO	f
105	J	4005	mi casa es esta CA	Empanadas Triny	CCA	62	Cañada Honda	Av 21 residencias visoca	diagolanl	t	JURIDICO	f
106	J	192837465	jose coro	comercializadora	corocorocoro	65	bolivar	mcbo	mcbo	t	JURIDICO	f
107	J	192837466	jose coro segundo	comercializadora	CMCLZDR	61	123	mcbo	mcbo	t	JURIDICO	f
111	V	7566202	ANTERO TROMPIZ	ANTERO TROMPIZ		\N		\N		t	NATURAL	f
112	V	14628028	CARLOS URBINA			73	SECTOR AMPARO	Avenida 145 Calle 98C-3, Casa Nro. 485	ENTRANDO POR LOS PLATANEROS	t	NATURAL	f
\.


--
-- Data for Name: contribuyente_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_registro_municipal, id_actividad_economica) FROM stdin;
\.


--
-- Data for Name: convenio; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.convenio (id_convenio, id_solicitud, cantidad) FROM stdin;
5	275	2
9	314	2
12	321	2
13	346	2
14	352	2
15	353	2
16	355	3
17	363	2
18	367	2
19	368	2
20	371	2
21	372	2
22	373	3
\.


--
-- Data for Name: credito_fiscal; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.credito_fiscal (id_credito_fiscal, id_persona, concepto, credito, fecha_creacion) FROM stdin;
1	76	JURIDICO	0	2020-07-23
2	77	JURIDICO	0	2020-07-23
3	78	JURIDICO	0	2020-07-23
4	79	JURIDICO	0	2020-07-23
5	80	JURIDICO	190980.48	2020-07-23
6	81	JURIDICO	14382764.53	2020-07-23
7	82	JURIDICO	55.00	2020-07-23
8	84	JURIDICO	1730508.75	2020-07-23
9	85	JURIDICO	31434.00	2020-07-23
11	86	JURIDICO	0	2020-07-23
13	88	JURIDICO	35806187.10	2020-07-23
14	89	JURIDICO	24701454.42	2020-07-23
15	90	JURIDICO	16697591.84	2020-07-23
16	91	JURIDICO	177311322.08	2020-07-23
22	94	JURIDICO	51198.65	2020-07-23
23	95	JURIDICO	0	2020-07-23
24	97	JURIDICO	0	2020-07-23
27	98	JURIDICO	0	2020-07-23
28	99	JURIDICO	144000.40	2020-07-23
25	96	JURIDICO	6913000	2020-07-23
12	87	JURIDICO	534.49	2020-07-23
18	93	JURIDICO	23018428.96	2020-07-23
17	92	JURIDICO	16179134.16	2020-07-23
10	83	JURIDICO	8414799.340000001	2020-07-23
34	100	JURIDICO	50000.00	2020-07-23
35	101	JURIDICO	0	2020-07-23
36	102	JURIDICO	89635.98	2020-07-23
37	103	JURIDICO	53360.00	2020-07-23
38	111	NATURAL	0	2020-07-23
39	112	NATURAL	0	2020-07-23
\.


--
-- Data for Name: detalle_retencion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.detalle_retencion (id_detalle_retencion, rif, numero_referencia, razon_social, tipo_retencion, fecha_retencion, base_imponible, monto_retenido, codigo_actividad, porcentaje, numero_factura, id_liquidacion) FROM stdin;
28	J3124123124	2900011265	 lo que sea .ca	C	2020-07-21	200000000	2000000	123123	0.01	123124123	1902
29	V1234123	2900011265	freddie mercurio	S	2237-02-04	200000000	2000000	123	0.01	123123124	1902
30	J1234123	0	Digitel C.A	C	2020-07-21	2123123	21231.23	123	0.01	1234123	1902
31	J3124123124	2900011265	 lo que sea .ca	C	2020-07-21	200000000	2000000	123123	0.01	123124123	1903
32	V1234123	2900011265	freddie mercurio	S	2237-02-04	200000000	2000000	123	0.01	123123124	1903
33	J1234123	0	Digitel C.A	C	2020-07-21	2123123	21231.23	123	0.01	1234123	1903
34	J3124123124	2900011265	 lo que sea .ca	C	2020-07-21	200000000	2000000	123123	0.01	123124123	1904
35	V1234123	2900011265	freddie mercurio	S	2237-02-04	200000000	2000000	123	0.01	123123124	1904
36	J1234123	0	Digitel C.A	C	2020-07-21	2123123	21231.23	123	0.01	1234123	1904
\.


--
-- Data for Name: dias_feriados; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.dias_feriados (id_dia_feriado, dia, descripcion) FROM stdin;
5	2020-02-25	Carnaval
6	2020-02-26	Carnaval
8	2020-06-16	Corpus christi\t
9	2020-06-25	Batalla de Carabobo
10	2020-06-30	Dia de San Pedro y San Pablo
11	2020-07-06	Dia de la independencia
12	2020-07-25	Natalicio del Libertador
13	2020-09-15	Dia de la Virgen del Coromoto
15	2020-10-13	Dia de la resistencia indegena
16	2020-11-24	Dia de la Virgen del Rosario de Chiquinquira
17	2020-12-15	Dia de la Inmacula Concepcion
18	2020-12-25	Feriado Nacional
19	2020-12-26	Navidad de Nuestro Señor
20	2021-01-01	Feriado Nacional
\.


--
-- Data for Name: evento_fraccion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.evento_fraccion (id_evento_fraccion, id_fraccion, event, "time") FROM stdin;
5	6	iniciar	2020-07-09 08:27:59.653175
6	7	iniciar	2020-07-09 08:27:59.653175
7	6	ingresardatos_pi	2020-07-09 08:27:59.653175
8	7	ingresardatos_pi	2020-07-09 08:27:59.653175
16	8	iniciar	2020-07-10 17:40:22.836976
17	9	iniciar	2020-07-10 17:40:22.836976
18	8	ingresardatos_pi	2020-07-10 17:40:22.836976
19	9	ingresardatos_pi	2020-07-10 17:40:22.836976
20	6	aprobacioncajero_pi	2020-07-10 17:41:17.348487
21	10	iniciar	2020-07-10 19:44:47.523322
22	11	iniciar	2020-07-10 19:44:47.523322
23	10	ingresardatos_pi	2020-07-10 19:44:47.523322
24	11	ingresardatos_pi	2020-07-10 19:44:47.523322
25	7	aprobacioncajero_pi	2020-07-13 15:52:50.598093
26	12	iniciar	2020-07-13 16:44:08.749839
27	13	iniciar	2020-07-13 16:44:08.749839
28	12	ingresardatos_pi	2020-07-13 16:44:08.749839
29	13	ingresardatos_pi	2020-07-13 16:44:08.749839
30	12	aprobacioncajero_pi	2020-07-13 16:51:06.153378
31	14	iniciar	2020-07-13 19:40:08.930921
32	15	iniciar	2020-07-13 19:40:08.930921
33	14	ingresardatos_pi	2020-07-13 19:40:08.930921
34	15	ingresardatos_pi	2020-07-13 19:40:08.930921
35	16	iniciar	2020-07-14 13:05:41.991268
36	17	iniciar	2020-07-14 13:05:41.991268
37	16	ingresardatos_pi	2020-07-14 13:05:41.991268
38	17	ingresardatos_pi	2020-07-14 13:05:41.991268
39	18	iniciar	2020-07-14 13:36:04.589736
40	19	iniciar	2020-07-14 13:36:04.589736
41	20	iniciar	2020-07-14 13:36:04.589736
42	18	ingresardatos_pi	2020-07-14 13:36:04.589736
43	19	ingresardatos_pi	2020-07-14 13:36:04.589736
44	20	ingresardatos_pi	2020-07-14 13:36:04.589736
45	21	iniciar	2020-07-15 13:41:54.298424
46	22	iniciar	2020-07-15 13:41:54.298424
47	21	ingresardatos_pi	2020-07-15 13:41:54.298424
48	22	ingresardatos_pi	2020-07-15 13:41:54.298424
49	23	iniciar	2020-07-15 16:42:59.372042
50	24	iniciar	2020-07-15 16:42:59.372042
51	25	iniciar	2020-07-15 16:42:59.372042
52	26	iniciar	2020-07-15 16:42:59.372042
53	23	ingresardatos_pi	2020-07-15 16:42:59.372042
54	24	ingresardatos_pi	2020-07-15 16:42:59.372042
55	25	ingresardatos_pi	2020-07-15 16:42:59.372042
56	26	ingresardatos_pi	2020-07-15 16:42:59.372042
57	27	iniciar	2020-07-15 16:56:12.835542
58	28	iniciar	2020-07-15 16:56:12.835542
59	29	iniciar	2020-07-15 16:56:12.835542
60	30	iniciar	2020-07-15 16:56:12.835542
61	27	ingresardatos_pi	2020-07-15 16:56:12.835542
62	28	ingresardatos_pi	2020-07-15 16:56:12.835542
63	29	ingresardatos_pi	2020-07-15 16:56:12.835542
64	30	ingresardatos_pi	2020-07-15 16:56:12.835542
65	31	iniciar	2020-07-15 16:57:09.206336
66	32	iniciar	2020-07-15 16:57:09.206336
67	33	iniciar	2020-07-15 16:57:09.206336
68	31	ingresardatos_pi	2020-07-15 16:57:09.206336
69	32	ingresardatos_pi	2020-07-15 16:57:09.206336
70	33	ingresardatos_pi	2020-07-15 16:57:09.206336
71	23	aprobacioncajero_pi	2020-07-15 17:22:58.322455
72	24	validar_pi	2020-07-15 17:28:47.568725
\.


--
-- Data for Name: evento_solicitud; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.evento_solicitud (id_evento_solicitud, id_solicitud, event, "time") FROM stdin;
455	269	iniciar	2020-07-09 08:12:02.010347
456	269	aprobacioncajero_pi	2020-07-09 08:12:02.010347
457	270	iniciar	2020-07-09 08:12:37.689752
458	270	ingresardatos_pi	2020-07-09 08:12:37.689752
467	275	iniciar	2020-07-09 08:27:59.653175
468	275	ingresardatos_pi	2020-07-09 08:27:59.653175
469	276	iniciar	2020-07-09 14:04:57.003454
470	276	aprobacioncajero_pi	2020-07-09 14:04:57.003454
471	277	iniciar	2020-07-09 14:06:40.280264
472	277	ingresardatos_pi	2020-07-09 14:06:40.280264
473	278	iniciar	2020-07-09 14:08:07.045071
474	278	ingresardatos_pi	2020-07-09 14:08:07.045071
475	277	validar_pi	2020-07-09 14:15:27.051053
476	278	validar_pi	2020-07-09 14:16:38.780877
477	279	iniciar	2020-07-10 12:03:13.465943
478	280	iniciar	2020-07-10 12:03:13.465943
479	281	iniciar	2020-07-10 12:03:13.465943
480	282	iniciar	2020-07-10 12:03:13.465943
481	279	aprobacioncajero_pi	2020-07-10 12:03:13.465943
482	280	aprobacioncajero_pi	2020-07-10 12:03:13.465943
483	281	aprobacioncajero_pi	2020-07-10 12:03:13.465943
484	282	aprobacioncajero_pi	2020-07-10 12:03:13.465943
485	283	iniciar	2020-07-10 12:05:40.028672
486	283	ingresardatos_pi	2020-07-10 12:05:40.028672
487	283	aprobacioncajero_pi	2020-07-10 13:20:44.682294
488	284	iniciar	2020-07-10 15:49:57.76097
489	285	iniciar	2020-07-10 15:49:57.76097
490	286	iniciar	2020-07-10 15:49:57.76097
491	287	iniciar	2020-07-10 15:49:57.76097
492	288	iniciar	2020-07-10 15:49:57.76097
493	289	iniciar	2020-07-10 15:49:57.76097
494	290	iniciar	2020-07-10 15:49:57.76097
495	284	aprobacioncajero_pi	2020-07-10 15:49:57.76097
496	285	aprobacioncajero_pi	2020-07-10 15:49:57.76097
497	286	aprobacioncajero_pi	2020-07-10 15:49:57.76097
498	287	aprobacioncajero_pi	2020-07-10 15:49:57.76097
499	288	aprobacioncajero_pi	2020-07-10 15:49:57.76097
500	289	aprobacioncajero_pi	2020-07-10 15:49:57.76097
501	290	aprobacioncajero_pi	2020-07-10 15:49:57.76097
502	291	iniciar	2020-07-10 15:49:57.76097
503	292	iniciar	2020-07-10 15:49:57.76097
504	293	iniciar	2020-07-10 15:49:57.76097
505	294	iniciar	2020-07-10 15:49:57.76097
506	295	iniciar	2020-07-10 15:49:57.76097
507	296	iniciar	2020-07-10 15:49:57.76097
508	297	iniciar	2020-07-10 15:49:57.76097
509	298	iniciar	2020-07-10 15:53:53.798013
510	298	ingresardatos_pi	2020-07-10 15:53:53.798013
511	298	aprobacioncajero_pi	2020-07-10 15:55:26.712598
512	299	iniciar	2020-07-10 15:58:14.973462
513	299	ingresardatos_pi	2020-07-10 15:58:14.973462
514	299	aprobacioncajero_pi	2020-07-10 15:59:40.607466
515	300	iniciar	2020-07-10 16:00:26.882307
516	300	ingresardatos_pi	2020-07-10 16:00:26.882307
517	301	iniciar	2020-07-10 16:26:16.682286
518	301	ingresardatos_pi	2020-07-10 16:26:16.682286
519	301	aprobacioncajero_pi	2020-07-10 16:27:28.188027
520	302	iniciar	2020-07-10 16:30:10.841389
521	302	ingresardatos_pi	2020-07-10 16:30:10.841389
522	302	aprobacioncajero_pi	2020-07-10 16:32:10.368419
523	303	iniciar	2020-07-10 16:46:15.751052
524	303	ingresardatos_pi	2020-07-10 16:46:15.751052
537	310	iniciar	2020-07-10 17:33:04.947948
538	310	ingresardatos_pi	2020-07-10 17:33:04.947948
539	310	aprobacioncajero_pi	2020-07-10 17:33:56.336678
540	311	iniciar	2020-07-10 17:36:13.373302
541	311	ingresardatos_pi	2020-07-10 17:36:13.373302
542	312	iniciar	2020-07-10 17:38:48.696094
543	312	ingresardatos_pi	2020-07-10 17:38:48.696094
544	313	iniciar	2020-07-10 17:40:22.836976
545	314	iniciar	2020-07-10 17:40:22.836976
546	315	iniciar	2020-07-10 17:40:22.836976
547	316	iniciar	2020-07-10 17:40:22.836976
548	313	ingresardatos_pi	2020-07-10 17:40:22.836976
549	314	ingresardatos_pi	2020-07-10 17:40:22.836976
550	315	ingresardatos_pi	2020-07-10 17:40:22.836976
551	316	ingresardatos_pi	2020-07-10 17:40:22.836976
560	321	iniciar	2020-07-10 19:44:47.523322
561	322	iniciar	2020-07-10 19:44:47.523322
562	321	ingresardatos_pi	2020-07-10 19:44:47.523322
563	322	ingresardatos_pi	2020-07-10 19:44:47.523322
564	323	iniciar	2020-07-13 00:45:58.613416
565	323	ingresardatos_pi	2020-07-13 00:45:58.613416
570	303	aprobacioncajero_pi	2020-07-13 01:31:30.980018
571	328	iniciar	2020-07-13 13:05:24.278176
572	328	ingresardatos_pi	2020-07-13 13:05:24.278176
573	328	aprobacioncajero_pi	2020-07-13 13:08:48.211087
574	329	iniciar	2020-07-13 13:29:53.967998
575	329	aprobacioncajero_pi	2020-07-13 13:29:53.967998
576	330	iniciar	2020-07-13 13:32:04.212903
577	330	aprobacioncajero_pi	2020-07-13 13:32:04.212903
578	331	iniciar	2020-07-13 13:39:59.276087
579	332	iniciar	2020-07-13 13:39:59.276087
580	331	aprobacioncajero_pi	2020-07-13 13:39:59.276087
581	332	aprobacioncajero_pi	2020-07-13 13:39:59.276087
582	333	iniciar	2020-07-13 13:39:59.276087
583	334	iniciar	2020-07-13 13:39:59.276087
584	335	iniciar	2020-07-13 13:40:21.728724
585	335	ingresardatos_pi	2020-07-13 13:40:21.728724
586	335	aprobacioncajero_pi	2020-07-13 13:43:11.43049
587	336	iniciar	2020-07-13 13:43:25.240907
588	337	iniciar	2020-07-13 13:43:25.240907
589	336	aprobacioncajero_pi	2020-07-13 13:43:25.240907
590	337	aprobacioncajero_pi	2020-07-13 13:43:25.240907
591	338	iniciar	2020-07-13 13:46:28.002889
592	338	ingresardatos_pi	2020-07-13 13:46:28.002889
593	339	iniciar	2020-07-13 13:46:58.89753
594	339	ingresardatos_pi	2020-07-13 13:46:58.89753
595	338	aprobacioncajero_pi	2020-07-13 13:48:15.334305
596	339	aprobacioncajero_pi	2020-07-13 13:49:31.196749
597	340	iniciar	2020-07-13 15:46:11.072425
598	340	ingresardatos_pi	2020-07-13 15:46:11.072425
599	340	aprobacioncajero_pi	2020-07-13 15:49:43.016642
600	275	aprobacioncajero_pi	2020-07-13 15:52:50.598093
601	341	iniciar	2020-07-13 16:22:13.907522
602	341	ingresardatos_pi	2020-07-13 16:22:13.907522
603	341	aprobacioncajero_pi	2020-07-13 16:27:24.960877
604	342	iniciar	2020-07-13 16:41:24.7627
605	342	ingresardatos_pi	2020-07-13 16:41:24.7627
606	343	iniciar	2020-07-13 16:42:27.380158
607	343	ingresardatos_pi	2020-07-13 16:42:27.380158
608	344	iniciar	2020-07-13 16:44:08.749839
609	345	iniciar	2020-07-13 16:44:08.749839
610	346	iniciar	2020-07-13 16:44:08.749839
611	347	iniciar	2020-07-13 16:44:08.749839
612	344	ingresardatos_pi	2020-07-13 16:44:08.749839
613	345	ingresardatos_pi	2020-07-13 16:44:08.749839
614	346	ingresardatos_pi	2020-07-13 16:44:08.749839
615	347	ingresardatos_pi	2020-07-13 16:44:08.749839
616	343	aprobacioncajero_pi	2020-07-13 16:44:23.08662
617	348	iniciar	2020-07-13 17:02:06.992831
618	348	ingresardatos_pi	2020-07-13 17:02:06.992831
619	348	aprobacioncajero_pi	2020-07-13 17:04:40.260167
620	349	iniciar	2020-07-13 17:06:24.272644
621	349	ingresardatos_pi	2020-07-13 17:06:24.272644
622	350	iniciar	2020-07-13 18:46:18.62149
623	350	ingresardatos_pi	2020-07-13 18:46:18.62149
624	350	aprobacioncajero_pi	2020-07-13 18:59:38.037471
625	351	iniciar	2020-07-13 19:29:29.131607
626	351	ingresardatos_pi	2020-07-13 19:29:29.131607
627	352	iniciar	2020-07-13 19:40:08.930921
628	352	ingresardatos_pi	2020-07-13 19:40:08.930921
629	353	iniciar	2020-07-14 13:05:41.991268
630	353	ingresardatos_pi	2020-07-14 13:05:41.991268
631	354	iniciar	2020-07-14 13:10:37.853072
632	354	ingresardatos_pi	2020-07-14 13:10:37.853072
633	355	iniciar	2020-07-14 13:36:04.589736
634	355	ingresardatos_pi	2020-07-14 13:36:04.589736
635	356	iniciar	2020-07-14 17:12:30.798115
636	356	aprobacioncajero_pi	2020-07-14 17:12:30.798115
637	357	iniciar	2020-07-14 18:06:20.787145
638	357	ingresardatos_pi	2020-07-14 18:06:20.787145
639	358	iniciar	2020-07-14 23:30:57.546707
640	359	iniciar	2020-07-14 23:30:57.546707
641	360	iniciar	2020-07-14 23:30:57.546707
642	358	aprobacioncajero_pi	2020-07-14 23:30:57.546707
643	359	aprobacioncajero_pi	2020-07-14 23:30:57.546707
644	360	aprobacioncajero_pi	2020-07-14 23:30:57.546707
645	361	iniciar	2020-07-14 23:42:11.698698
646	361	ingresardatos_pi	2020-07-14 23:42:11.698698
647	362	iniciar	2020-07-15 12:34:40.674303
648	362	ingresardatos_pi	2020-07-15 12:34:40.674303
649	363	iniciar	2020-07-15 13:41:54.298424
650	363	ingresardatos_pi	2020-07-15 13:41:54.298424
651	364	iniciar	2020-07-15 16:35:45.462845
652	364	ingresardatos_pi	2020-07-15 16:35:45.462845
653	365	iniciar	2020-07-15 16:38:42.964142
654	365	ingresardatos_pi	2020-07-15 16:38:42.964142
655	366	iniciar	2020-07-15 16:42:59.372042
656	367	iniciar	2020-07-15 16:42:59.372042
657	368	iniciar	2020-07-15 16:42:59.372042
658	366	ingresardatos_pi	2020-07-15 16:42:59.372042
659	367	ingresardatos_pi	2020-07-15 16:42:59.372042
660	368	ingresardatos_pi	2020-07-15 16:42:59.372042
661	369	iniciar	2020-07-15 16:52:02.233938
662	369	ingresardatos_pi	2020-07-15 16:52:02.233938
663	370	iniciar	2020-07-15 16:56:12.835542
664	371	iniciar	2020-07-15 16:56:12.835542
665	372	iniciar	2020-07-15 16:56:12.835542
666	370	ingresardatos_pi	2020-07-15 16:56:12.835542
667	371	ingresardatos_pi	2020-07-15 16:56:12.835542
668	372	ingresardatos_pi	2020-07-15 16:56:12.835542
669	373	iniciar	2020-07-15 16:57:09.206336
670	373	ingresardatos_pi	2020-07-15 16:57:09.206336
671	374	iniciar	2020-07-15 20:59:51.66042
672	374	ingresardatos_pi	2020-07-15 20:59:51.66042
673	375	iniciar	2020-07-15 21:34:30.714018
674	375	ingresardatos_pi	2020-07-15 21:34:30.714018
675	376	iniciar	2020-07-20 15:31:30.889108
676	376	ingresardatos_pi	2020-07-20 15:31:30.889108
677	377	iniciar	2020-07-20 17:14:30.598953
678	377	ingresardatos_pi	2020-07-20 17:14:30.598953
679	378	iniciar	2020-07-20 17:18:51.054977
680	378	ingresardatos_pi	2020-07-20 17:18:51.054977
681	379	iniciar	2020-07-21 17:30:12.760065
682	379	ingresardatos_pi	2020-07-21 17:30:12.760065
683	380	iniciar	2020-07-21 17:30:47.788345
684	380	ingresardatos_pi	2020-07-21 17:30:47.788345
685	381	iniciar	2020-07-22 21:35:24.237034
686	381	ingresardatos_pi	2020-07-22 21:35:24.237034
687	382	iniciar	2020-07-23 19:44:28.537126
688	382	ingresardatos_pi	2020-07-23 19:44:28.537126
689	383	iniciar	2020-07-23 21:51:18.248773
690	383	ingresardatos_pi	2020-07-23 21:51:18.248773
691	384	iniciar	2020-07-24 03:32:19.206073
692	384	ingresardatos_pi	2020-07-24 03:32:19.206073
708	400	iniciar	2020-07-24 19:09:03.840762
709	400	ingresardatos_pi	2020-07-24 19:09:03.840762
710	401	iniciar	2020-07-24 19:31:34.132088
711	401	ingresardatos_pi	2020-07-24 19:31:34.132088
\.


--
-- Data for Name: factor; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.factor (id_factor, descripcion, valor) FROM stdin;
\.


--
-- Data for Name: fraccion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.fraccion (id_fraccion, id_convenio, monto, porcion, fecha, aprobado, fecha_aprobado) FROM stdin;
8	9	2000000.00	1	2020-07-17	f	\N
9	9	1060000.00	2	2020-07-31	f	\N
6	5	100000.00	1	2020-09-07	t	2020-07-10
10	12	2000000.00	1	2020-07-18	f	\N
11	12	1000000.00	2	2020-07-31	f	\N
7	5	74000.00	2	2020-09-07	t	2020-07-13
13	13	4000000.00	2	2020-07-13	f	\N
12	13	20000000.00	1	2020-07-13	t	2020-07-13
14	14	75000.00	1	2020-07-20	f	\N
15	14	70000.00	2	2020-08-03	f	\N
16	15	4090000.00	1	2020-07-17	f	\N
17	15	5000000.00	2	2020-07-24	f	\N
18	16	50000000.00	1	2020-07-17	f	\N
19	16	50000000.00	2	2020-07-24	f	\N
20	16	48500000.00	3	2020-07-31	f	\N
21	17	10000000.00	1	2020-07-15	f	\N
22	17	8000000.00	2	2020-07-15	f	\N
24	18	4020000.00	2	2020-07-29	f	\N
25	19	100000000.00	1	2020-07-22	f	\N
26	19	15500000.00	2	2020-07-29	f	\N
27	20	4000000.00	1	2020-07-22	f	\N
28	20	2420000.00	2	2020-07-29	f	\N
29	21	100000000.00	1	2020-07-22	f	\N
30	21	34000000.00	2	2020-07-22	f	\N
31	22	50000000.00	1	2020-07-21	f	\N
32	22	50000000.00	2	2020-07-28	f	\N
33	22	34000000.00	3	2020-08-04	f	\N
23	18	3000000.00	1	2020-07-22	t	2020-07-15
\.


--
-- Data for Name: inmueble_contribuyente_natural; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.inmueble_contribuyente_natural (id_inmueble_contribuyente, id_inmueble, id_contribuyente) FROM stdin;
\.


--
-- Data for Name: liquidacion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.liquidacion (id_liquidacion, id_solicitud, monto, certificado, recibo, fecha_liquidacion, id_subramo, datos, fecha_vencimiento, id_registro_municipal, remitido) FROM stdin;
1339	269	309973947.02	\N	\N	2020-05-05	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	f
1340	269	263158578.15	\N	\N	2020-04-28	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1341	269	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1342	269	279426342.85	\N	\N	2020-04-24	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1343	269	222170329.10	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	80	f
1344	269	20228432.70	\N	\N	2020-02-14	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	80	f
1345	269	186591315.09	\N	\N	2020-02-04	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	80	f
1346	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	80	f
1347	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	80	f
1348	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1349	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	f
1350	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	80	f
1351	275	29000.00	\N	\N	2020-07-09	102	{"desglose":[{"inmueble":437,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":438,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	80	f
1367	277	1000000.00	\N	\N	2020-07-09	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1368	277	1000000.00	\N	\N	2020-07-09	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	81	f
1369	278	29000.00	\N	\N	2020-07-09	66	{"desglose":[{"inmueble":439,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":440,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1370	278	29000.00	\N	\N	2020-07-09	66	{"desglose":[{"inmueble":439,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":440,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	81	f
1371	278	29000.00	\N	\N	2020-07-09	66	{"desglose":[{"inmueble":439,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":440,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	81	f
1372	278	10000000.00	\N	\N	2020-07-09	12	{"desglose":[{"subarticulo":231,"monto":"10000000.00","cantidad":"5"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	81	f
1352	276	65558629.60	\N	\N	2020-05-05	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1353	276	42348439.23	\N	\N	2020-05-04	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1354	276	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	81	f
1355	276	62975493.06	\N	\N	2020-04-27	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	81	f
1356	276	48552805.76	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	81	f
1357	276	44660000.00	\N	\N	2020-04-23	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	81	f
1358	276	32480000.00	\N	\N	2020-03-09	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	81	f
1359	276	63426261.20	\N	\N	2020-03-04	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	81	f
1360	276	27025051.06	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	81	f
1361	276	32480000.00	\N	\N	2020-02-10	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	81	f
1362	276	400000.00	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	81	f
1363	276	21483200.00	\N	\N	2020-01-06	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	81	f
1364	277	5000000.00	\N	\N	2020-07-09	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	81	f
1365	277	2000000.00	\N	\N	2020-07-09	10	{"desglose":[{"aforo":83,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1366	277	2000000.00	\N	\N	2020-07-09	10	{"desglose":[{"aforo":83,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	81	f
1373	278	0.00	\N	\N	2020-07-09	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	81	f
1374	278	0.00	\N	\N	2020-07-09	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	81	f
1375	278	0.00	\N	\N	2020-07-09	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	81	f
1463	299	5000000.00	\N	\N	2020-07-10	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	91	f
1464	299	10000000.00	\N	\N	2020-07-10	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	91	f
1465	299	3030000.00	\N	\N	2020-07-10	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1466	299	3030000.00	\N	\N	2020-07-10	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	91	f
1376	279	369409.41	\N	\N	2020-04-22	52	{"fecha":{"month":"abril","year":2020}}	2020-07-31	82	f
1377	279	505635.97	\N	\N	2020-03-10	52	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	82	f
1378	279	0.00	\N	\N	2020-02-20	52	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	82	f
1379	279	945.00	\N	\N	2020-01-30	11	{"fecha":{"month":"enero","year":2020}}	2020-07-31	82	f
1768	\N	0.00	\N	\N	2020-07-21	10	{"month":"junio","year":2020}	2020-06-30	113	f
1769	\N	0.00	\N	\N	2020-07-21	10	{"month":"marzo","year":2020}	2020-03-31	113	f
1770	\N	0.00	\N	\N	2020-07-21	10	{"month":"julio","year":2019}	2019-07-31	113	f
1771	\N	0.00	\N	\N	2020-07-21	10	{"month":"julio","year":2018}	2018-07-31	113	f
1772	\N	0.00	\N	\N	2020-07-21	10	{"month":"diciembre","year":2019}	2019-12-31	114	f
1467	299	3030000.00	\N	\N	2020-07-10	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	91	f
1468	299	1000000.00	\N	\N	2020-07-10	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1469	299	1000000.00	\N	\N	2020-07-10	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	91	f
1380	280	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	84	f
1470	299	1000000.00	\N	\N	2020-07-10	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	91	f
1381	281	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	83	f
1382	281	54141217.24	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	83	f
1383	281	21864572.31	\N	\N	2020-03-09	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	83	f
1384	281	53360000.00	\N	\N	2020-03-09	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	83	f
1385	281	5600000.00	\N	\N	2020-02-19	12	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	83	f
1386	281	19818046.10	\N	\N	2020-02-05	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	83	f
1387	281	13920000.00	\N	\N	2020-02-05	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	83	f
1388	281	18560000.00	\N	\N	2020-01-07	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	83	f
1389	282	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	86	f
1390	282	55915480.00	\N	\N	2020-03-03	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	86	f
1391	283	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":444,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":445,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	83	f
1392	283	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":444,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":445,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	83	f
1393	283	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":444,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":445,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	83	f
1394	283	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":444,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":445,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	83	f
1395	283	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":444,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":445,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	83	f
1479	302	7500000.00	\N	\N	2020-07-10	12	{"desglose":[{"subarticulo":194,"monto":"7500000.00","cantidad":"5"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1480	302	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	89	f
1481	302	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	89	f
1482	302	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	89	f
1491	310	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":459,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":460,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1492	310	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":459,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":460,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	93	f
1493	310	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":459,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":460,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	93	f
1494	310	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":459,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":460,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	93	f
1525	329	2000000.00	\N	\N	2020-03-04	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	94	f
1526	329	8352000.00	\N	\N	2020-03-04	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	94	f
1527	329	2000000.00	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	94	f
1528	329	8352000.00	\N	\N	2020-02-10	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	94	f
1529	329	8352000.00	\N	\N	2020-01-07	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	94	f
1539	331	12754200.00	\N	\N	2020-05-06	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	97	f
1540	331	1000000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	97	f
1541	331	2500000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	97	f
1542	331	400000.00	\N	\N	2020-02-28	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	97	f
1543	332	12754200.00	\N	\N	2020-05-06	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1544	332	1000000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1545	332	2500000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1546	332	400000.00	\N	\N	2020-02-28	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	96	f
1471	300	7500000.00	\N	\N	2020-07-10	12	{"desglose":[{"subarticulo":194,"monto":"7500000.00","cantidad":"5"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1472	300	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	91	f
1473	300	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	91	f
1474	300	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	91	f
1512	328	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	88	f
1513	328	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	88	f
1514	328	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":450,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":451,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1495	311	7500000.00	\N	\N	2020-07-10	12	{"desglose":[{"subarticulo":194,"monto":"7500000.00","cantidad":"5"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1496	311	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	93	f
1497	311	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	93	f
1498	311	0.00	\N	\N	2020-07-10	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	93	f
1515	328	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":450,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":451,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	88	f
1488	321	1000000.00	\N	\N	2020-07-10	\N	{"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1489	321	1000000.00	\N	\N	2020-07-10	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	89	f
1490	321	1000000.00	\N	\N	2020-07-10	\N	{"fecha":{"month":"junio","year":2020}}	2020-06-30	89	f
1504	323	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":448,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":449,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1505	323	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":448,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":449,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	87	f
1506	323	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":448,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":449,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	87	f
1507	323	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":448,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":449,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	87	f
1508	328	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	88	f
1509	328	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	88	f
1510	328	15000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-07-31	88	f
1511	328	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1516	328	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":450,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":451,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	88	f
1517	328	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":450,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":451,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	88	f
1483	303	5000000.00	\N	\N	2020-07-10	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	89	t
1484	303	10000000.00	\N	\N	2020-07-10	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	89	t
1518	328	67500000.00	\N	\N	2020-07-13	12	{"desglose":[{"subarticulo":194,"monto":"67500000.00","cantidad":"45"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1485	353	3030000.00	\N	\N	2020-07-10	99	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1486	353	3030000.00	\N	\N	2020-07-10	99	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	89	f
1487	353	3030000.00	\N	\N	2020-07-10	99	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	89	f
1475	301	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":452,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":453,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1476	301	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":452,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":453,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	89	f
1477	301	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":452,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":453,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	89	f
1396	284	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1397	284	308223647.48	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1398	284	53360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1399	284	245341821.88	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	87	f
1400	284	27840000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	87	f
1401	284	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	87	f
1402	284	206009755.69	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	87	f
1403	284	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	87	f
1404	285	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1405	285	267260763.00	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1406	285	53360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1407	285	254324285.68	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	88	f
1408	285	27840000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	88	f
1409	285	220150334.96	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	88	f
1410	285	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	88	f
1411	285	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	88	f
1412	286	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1413	286	214094526.13	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1414	286	53360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	89	f
1415	286	182713050.68	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	89	f
1416	286	27840000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	89	f
1417	286	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	89	f
1418	286	153714488.29	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	89	f
1419	286	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	89	f
1420	287	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	90	f
1421	287	58439693.67	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	90	f
1422	287	2000000.00	\N	\N	2020-03-27	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	90	f
1423	287	113652894.37	\N	\N	2020-03-27	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	90	f
1424	287	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	90	f
1425	287	90139081.15	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	90	f
1426	288	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1427	288	35360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1428	288	262354442.99	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1429	288	13920000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	91	f
1430	288	215987393.79	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	91	f
1431	288	13920000.00	\N	\N	2020-02-13	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	91	f
1432	288	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	91	f
1433	288	186623180.86	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	91	f
1434	288	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	91	f
1435	289	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1436	289	245540952.42	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1437	289	53360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1438	289	235466663.74	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	92	f
1439	289	27840000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	92	f
1440	289	194218977.42	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	92	f
1441	289	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	92	f
1442	289	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	92	f
1443	290	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1444	290	249484060.42	\N	\N	2020-04-22	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1445	290	53360000.00	\N	\N	2020-04-22	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1446	290	239252276.52	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	93	f
1447	290	27840000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	93	f
1448	290	191433955.27	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	93	f
1449	290	1000000.00	\N	\N	2020-02-13	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	93	f
1450	290	10440000.00	\N	\N	2020-01-17	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	93	f
1478	301	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":452,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":453,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	89	f
1523	328	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	88	f
1451	291	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	87	f
1452	292	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	88	f
1453	293	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	89	f
1454	294	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	90	f
1455	294	2000000.00	\N	\N	\N	\N	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	90	f
1456	295	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	91	f
1457	296	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	92	f
1458	297	1000000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	93	f
1459	298	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":455,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":456,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	91	f
1460	298	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":455,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":456,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	91	f
1461	298	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":455,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":456,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	91	f
1462	298	29000.00	\N	\N	2020-07-10	66	{"desglose":[{"inmueble":455,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":456,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	91	f
1524	328	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	88	f
1547	333	2500000.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	97	f
1499	347	5000000.00	\N	\N	2020-07-10	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	80	t
1502	344	1000000.00	\N	\N	2020-07-10	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	t
1548	334	2500000.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1500	314	1530000.00	\N	\N	2020-07-10	99	{"desglose":[{"aforo":75,"montoDeclarado":"1000000.00","montoCobrado":1500000},{"aforo":185,"montoDeclarado":"1000000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	f
1501	314	1530000.00	\N	\N	2020-07-10	99	{"desglose":[{"aforo":75,"montoDeclarado":"1000000.00","montoCobrado":1500000},{"aforo":185,"montoDeclarado":"1000000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	80	f
1519	328	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	88	f
1520	328	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	88	f
1521	328	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	88	f
1522	328	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	88	f
1549	335	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	96	f
1550	335	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-07-31	96	f
1551	335	4000000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":19,"montoDeclarado":"50000000.00","montoCobrado":2000000},{"aforo":19,"montoDeclarado":"50000000.00","montoCobrado":2000000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1552	335	24000000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":19,"montoDeclarado":"600000000.00","montoCobrado":12000000},{"aforo":19,"montoDeclarado":"600000000.00","montoCobrado":12000000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	96	f
1530	330	4000000.00	\N	\N	2020-05-07	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	95	f
1531	330	5455526.40	\N	\N	2020-05-07	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	95	f
1532	330	400000.01	\N	\N	2020-04-06	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	95	f
1533	330	4640000.00	\N	\N	2020-04-06	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	95	f
1534	330	1600000.00	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	95	f
1535	330	4640000.00	\N	\N	2020-03-02	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	95	f
1536	330	4640000.00	\N	\N	2020-02-05	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	95	f
1537	330	1600000.00	\N	\N	2020-02-05	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	95	f
1538	330	3480000.00	\N	\N	2020-01-15	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	95	f
1553	335	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1554	335	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	96	f
1555	336	42352273.60	\N	\N	2020-05-08	52	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	98	f
1556	336	42352273.60	\N	\N	2020-05-04	52	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	98	f
1557	336	36909096.43	\N	\N	2020-04-22	52	{"fecha":{"month":"abril","year":2020}}	2020-07-31	98	f
1558	336	23602822.69	\N	\N	2020-03-09	52	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	98	f
1503	344	1000000.00	\N	\N	2020-07-10	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	80	t
1582	340	3060000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"3000000.00","montoCobrado":60000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1583	340	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	87	f
1584	340	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	87	f
1585	340	135000000.00	\N	\N	2020-07-13	12	{"desglose":[{"subarticulo":196,"monto":"135000000.00","cantidad":"54"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1586	340	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	87	f
1587	340	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	87	f
1559	337	69600000.00	\N	\N	2020-05-07	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	99	f
1560	337	377563945.61	\N	\N	2020-05-07	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	99	f
1561	337	25520000.00	\N	\N	2020-04-30	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	99	f
1562	337	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	99	f
1563	337	318201883.52	\N	\N	2020-04-28	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	99	f
1564	337	158572499.22	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	99	f
1565	337	205890461.81	\N	\N	2020-03-09	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	99	f
1566	337	3529296.37	\N	\N	2020-03-06	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	99	f
1567	337	13920000.00	\N	\N	2020-03-06	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	99	f
1568	337	2800000.00	\N	\N	2020-02-21	12	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	99	f
1569	337	2800000.00	\N	\N	2020-02-21	12	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	99	f
1570	337	182631569.73	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	99	f
1571	337	13920000.00	\N	\N	2020-02-10	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	99	f
1572	337	18560000.00	\N	\N	2020-01-10	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	99	f
1573	338	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":470,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":471,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	99	f
1574	338	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":470,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":471,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	99	f
1575	338	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":470,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":471,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	99	f
1576	339	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":467,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":468,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1577	339	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":467,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":468,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	96	f
1578	339	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":467,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":468,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	96	f
1579	340	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	87	f
1580	340	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	87	f
1581	340	15000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-07-31	87	f
1588	340	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	87	f
1589	340	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	87	f
1590	340	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	87	f
1591	340	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	87	f
1592	341	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	90	f
1593	341	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	90	f
1594	341	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	90	f
1595	341	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	90	f
1596	341	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	90	f
1597	341	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	90	f
1598	341	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	90	f
1599	341	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	90	f
1604	343	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	93	f
1605	343	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	93	f
1606	343	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1607	343	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	93	f
1608	343	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	93	f
1609	343	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	93	f
1610	343	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	93	f
1611	343	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	93	f
1600	346	24000000.00	\N	\N	2020-07-13	\N	{"desglose":[{"subarticulo":200,"monto":"24000000.00","cantidad":"12"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1601	346	0.00	\N	\N	2020-07-13	\N	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	f
1602	346	0.00	\N	\N	2020-07-13	\N	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	80	f
1603	346	0.00	\N	\N	2020-07-13	\N	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	80	f
1612	348	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-04-30	92	f
1613	348	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-05-31	92	f
1614	348	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1615	348	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	92	f
1616	348	3030000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"1500000.00","montoCobrado":30000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	92	f
1617	348	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":457,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":458,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1618	348	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":457,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":458,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	92	f
1619	348	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":457,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":458,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	92	f
1620	348	29000.00	\N	\N	2020-07-13	66	{"desglose":[{"inmueble":457,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":458,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	92	f
1621	348	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1622	348	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	92	f
1623	348	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	92	f
1624	349	7500000.00	\N	\N	2020-07-13	12	{"desglose":[{"subarticulo":253,"monto":"7500000.00","cantidad":"5"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	92	f
1625	349	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	92	f
1626	349	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	92	f
1627	349	0.00	\N	\N	2020-07-13	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	92	f
1628	350	5000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"marzo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-03-31	83	f
1629	350	10000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-04-30	83	f
1630	350	15000000.00	\N	\N	2020-07-13	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-05-31	83	f
1643	352	29000.00	\N	\N	2020-07-13	102	{"desglose":[{"inmueble":446,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":447,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	86	f
1631	350	5500000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"50000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"50000000.00","montoCobrado":1000000},{"aforo":194,"montoDeclarado":"50000000.00","montoCobrado":1500000}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	83	f
1632	350	10529999.97	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"590000000.00","montoCobrado":8850000},{"aforo":140,"montoDeclarado":"5800000.00","montoCobrado":1500000},{"aforo":194,"montoDeclarado":"5999999.00","montoCobrado":179999.97}],"fecha":{"month":"abril","year":2020}}	2020-07-31	83	f
1633	350	5770000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"56000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"56000000.00","montoCobrado":1120000},{"aforo":194,"montoDeclarado":"55000000.00","montoCobrado":1650000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	83	f
1634	350	5800000.00	\N	\N	2020-07-13	10	{"desglose":[{"aforo":131,"montoDeclarado":"56000000.00","montoCobrado":3000000},{"aforo":140,"montoDeclarado":"56000000.00","montoCobrado":1120000},{"aforo":194,"montoDeclarado":"56000000.00","montoCobrado":1680000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	83	f
1635	350	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	83	f
1636	350	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	83	f
1637	350	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	83	f
1638	350	1000000.00	\N	\N	2020-07-13	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	83	f
1655	357	0.00	\N	\N	2020-07-14	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	100	f
1656	357	0.00	\N	\N	2020-07-14	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	100	f
1657	357	0.00	\N	\N	2020-07-14	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	100	f
1642	352	29000.00	\N	\N	2020-07-13	102	{"desglose":[{"inmueble":446,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":447,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	86	f
1641	352	29000.00	\N	\N	2020-07-13	102	{"desglose":[{"inmueble":446,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":447,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	86	f
1640	352	29000.00	\N	\N	2020-07-13	102	{"desglose":[{"inmueble":446,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":447,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	86	f
1639	352	29000.00	\N	\N	2020-07-13	102	{"desglose":[{"inmueble":446,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":447,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	86	f
1644	355	148500000.00	\N	\N	2020-07-14	\N	{"desglose":[{"subarticulo":194,"monto":"148500000.00","cantidad":"99"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	90	f
1645	355	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	90	f
1646	355	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	90	f
1647	355	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	90	f
1648	356	76209596.28	\N	\N	2020-05-08	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	100	f
1649	356	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	100	f
1650	356	45928290.29	\N	\N	2020-04-09	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	100	f
1651	356	41760000.00	\N	\N	2020-03-06	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	100	f
1652	356	43898585.06	\N	\N	2020-03-06	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	100	f
1653	356	40512689.15	\N	\N	2020-02-05	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	100	f
1654	357	132000000.00	\N	\N	2020-07-14	12	{"desglose":[{"subarticulo":194,"monto":"132000000.00","cantidad":"88"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	100	f
1658	358	20596541.42	\N	\N	2020-05-05	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	101	f
1659	358	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	101	f
1660	358	23565679.37	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	101	f
1661	358	0.00	\N	\N	2020-04-23	66	{"fecha":{"month":"abril","year":2020}}	2020-07-31	101	f
1662	358	17401466.20	\N	\N	2020-04-14	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	101	f
1663	358	4640000.00	\N	\N	2020-03-05	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	101	f
1664	358	24337225.68	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	101	f
1665	358	18986143.10	\N	\N	2020-02-07	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	101	f
1666	358	4640000.00	\N	\N	2020-02-04	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	101	f
1667	358	7424000.00	\N	\N	2020-01-08	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	101	f
1668	359	30182356.36	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	102	f
1669	359	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	102	f
1670	359	33621492.21	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	102	f
1671	359	17043518.64	\N	\N	2020-04-14	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	102	f
1672	359	4640000.00	\N	\N	2020-03-05	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	102	f
1673	359	21694045.87	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	102	f
1674	359	24208501.00	\N	\N	2020-02-07	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	102	f
1675	359	4640000.00	\N	\N	2020-02-04	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	102	f
1676	359	5220000.00	\N	\N	2020-01-20	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	102	f
1677	360	35506556.92	\N	\N	2020-05-05	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	103	f
1678	360	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-07-31	103	f
1679	360	38159184.93	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-07-31	103	f
1680	360	24559784.64	\N	\N	2020-04-14	10	{"fecha":{"month":"abril","year":2020}}	2020-07-31	103	f
1681	360	9280000.00	\N	\N	2020-03-05	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	103	f
1682	360	46041110.18	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	103	f
1683	360	34580543.61	\N	\N	2020-02-05	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	103	f
1684	360	4640000.00	\N	\N	2020-02-05	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	103	f
1685	360	7424000.00	\N	\N	2020-01-08	66	{"fecha":{"month":"enero","year":2020}}	2020-07-31	103	f
1690	363	18000000.00	\N	\N	2020-07-15	\N	{"desglose":[{"subarticulo":201,"monto":"18000000.00","cantidad":"12"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	80	f
1691	363	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	80	f
1692	363	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	80	f
1693	363	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	80	f
1686	372	134000000.00	\N	\N	2020-07-14	\N	{"desglose":[{"subarticulo":200,"monto":"134000000.00","cantidad":"67"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	101	f
1687	372	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	101	f
1688	372	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	101	f
1689	372	0.00	\N	\N	2020-07-14	\N	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	101	f
1698	365	5000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	102	t
1701	366	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	102	f
1702	366	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	102	f
1699	367	3810000.00	\N	\N	2020-07-15	99	{"desglose":[{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"11500000.00","montoCobrado":345000},{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"11500000.00","montoCobrado":345000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	102	f
1700	367	3210000.00	\N	\N	2020-07-15	99	{"desglose":[{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000},{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	102	f
1694	368	115500000.00	\N	\N	2020-07-15	\N	{"desglose":[{"subarticulo":194,"monto":"115500000.00","cantidad":"77"}],"fecha":{"month":"abril","year":2020}}	2020-04-30	102	f
1695	368	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	102	f
1696	368	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	102	f
1697	368	0.00	\N	\N	2020-07-15	\N	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	102	f
1712	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"mayo","year":2020}}	2020-05-31	105	f
1713	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"junio","year":2020}}	2020-06-30	105	f
1703	369	5000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	101	t
1706	370	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	101	f
1707	370	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	101	f
1714	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"julio","year":2020}}	2020-07-31	105	f
1704	371	3210000.00	\N	\N	2020-07-15	99	{"desglose":[{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000},{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	101	f
1705	371	3210000.00	\N	\N	2020-07-15	99	{"desglose":[{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000},{"aforo":131,"montoDeclarado":"3000000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"2000000.00","montoCobrado":60000},{"aforo":186,"montoDeclarado":"1500000.00","montoCobrado":45000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	101	f
1708	374	1152000000.00	\N	\N	2020-07-15	12	{"desglose":[{"subarticulo":217,"monto":"1152000000.00","cantidad":"576"}],"fecha":{"month":"enero","year":2020}}	2020-07-31	105	f
1709	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"febrero","year":2020}}	2020-02-29	105	f
1710	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"marzo","year":2020}}	2020-03-31	105	f
1711	374	0.00	\N	\N	2020-07-15	12	{"desglose":[],"fecha":{"month":"abril","year":2020}}	2020-07-31	105	f
1715	375	5000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"enero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-01-31	105	f
1716	375	10000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"febrero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-02-29	105	f
1717	375	15000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"marzo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-03-31	105	f
1718	375	20000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":40}	2020-04-30	105	f
1719	375	25000000.00	\N	\N	2020-07-15	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":50}	2020-05-31	105	f
1720	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"enero","year":2020}}	2020-07-31	105	f
1721	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	105	f
1722	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	105	f
1723	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	105	f
1724	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	105	f
1725	375	2000000.00	\N	\N	2020-07-15	10	{"desglose":[{"aforo":48,"montoDeclarado":"2000000.00","montoCobrado":2000000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	105	f
1726	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"enero","year":2020}}	2020-07-31	105	f
1727	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	105	f
1728	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	105	f
1729	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"abril","year":2020}}	2020-07-31	105	f
1730	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	105	f
1899	401	5000000.00	\N	\N	2020-07-24	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo (AR)","monto":10}	2020-04-30	82	f
1900	401	5000000.00	\N	\N	2020-07-24	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo (AR)","monto":10}	2020-05-31	82	f
1901	401	5000000.00	\N	\N	2020-07-24	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo (AR)","monto":10}	2020-07-31	82	f
1902	401	4021231.23	\N	\N	2020-07-24	52	{"fecha":{"month":"abril","year":2020}}	2020-07-31	82	f
1903	401	4021231.23	\N	\N	2020-07-24	52	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	82	f
1904	401	4021231.23	\N	\N	2020-07-24	52	{"fecha":{"month":"junio","year":2020}}	2020-06-30	82	f
1731	375	1000000.00	\N	\N	2020-07-15	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	105	f
1755	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	110	f
1756	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	110	f
1757	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"abril","year":2020}}	2020-07-31	110	f
1758	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	110	f
1741	378	136068000.00	\N	\N	2020-07-20	66	{"desglose":[{"inmueble":476,"montoAseo":18000,"montoGas":7000},{"inmueble":477,"montoAseo":23100000,"montoGas":11000000},{"inmueble":482,"montoAseo":18000,"montoGas":0},{"inmueble":486,"montoAseo":75000000,"montoGas":11000000},{"inmueble":491,"montoAseo":4900000,"montoGas":11000000},{"inmueble":492,"montoAseo":18000,"montoGas":7000}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	102	f
1742	378	136068000.00	\N	\N	2020-07-20	66	{"desglose":[{"inmueble":476,"montoAseo":18000,"montoGas":7000},{"inmueble":477,"montoAseo":23100000,"montoGas":11000000},{"inmueble":482,"montoAseo":18000,"montoGas":0},{"inmueble":486,"montoAseo":75000000,"montoGas":11000000},{"inmueble":491,"montoAseo":4900000,"montoGas":11000000},{"inmueble":492,"montoAseo":18000,"montoGas":7000}],"fecha":{"month":"abril","year":2020}}	2020-07-31	102	f
1743	378	136068000.00	\N	\N	2020-07-20	66	{"desglose":[{"inmueble":476,"montoAseo":18000,"montoGas":7000},{"inmueble":477,"montoAseo":23100000,"montoGas":11000000},{"inmueble":482,"montoAseo":18000,"montoGas":0},{"inmueble":486,"montoAseo":75000000,"montoGas":11000000},{"inmueble":491,"montoAseo":4900000,"montoGas":11000000},{"inmueble":492,"montoAseo":18000,"montoGas":7000}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	102	f
1744	378	136068000.00	\N	\N	2020-07-20	66	{"desglose":[{"inmueble":476,"montoAseo":18000,"montoGas":7000},{"inmueble":477,"montoAseo":23100000,"montoGas":11000000},{"inmueble":482,"montoAseo":18000,"montoGas":0},{"inmueble":486,"montoAseo":75000000,"montoGas":11000000},{"inmueble":491,"montoAseo":4900000,"montoGas":11000000},{"inmueble":492,"montoAseo":18000,"montoGas":7000}],"fecha":{"month":"junio","year":2020}}	2020-06-30	102	f
1745	378	136068000.00	\N	\N	2020-07-20	66	{"desglose":[{"inmueble":476,"montoAseo":18000,"montoGas":7000},{"inmueble":477,"montoAseo":23100000,"montoGas":11000000},{"inmueble":482,"montoAseo":18000,"montoGas":0},{"inmueble":486,"montoAseo":75000000,"montoGas":11000000},{"inmueble":491,"montoAseo":4900000,"montoGas":11000000},{"inmueble":492,"montoAseo":18000,"montoGas":7000}],"fecha":{"month":"julio","year":2020}}	2020-07-31	102	f
1754	379	466666.67	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":466666.6666666667}],"fecha":{"month":"enero","year":2020}}	2020-07-31	110	f
1759	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"junio","year":2020}}	2020-06-30	110	f
1760	379	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":493,"monto":0}],"fecha":{"month":"julio","year":2020}}	2020-07-31	110	f
1761	380	250000.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":250000}],"fecha":{"month":"enero","year":2020}}	2020-07-31	96	f
1762	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	96	f
1763	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	96	f
1764	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"abril","year":2020}}	2020-07-31	96	f
1765	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	96	f
1766	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"junio","year":2020}}	2020-06-30	96	f
1767	380	0.00	\N	\N	2020-07-21	9	{"desglose":[{"inmueble":494,"monto":0}],"fecha":{"month":"julio","year":2020}}	2020-07-31	96	f
1780	381	3000330.00	\N	\N	2020-07-22	10	{"desglose":[{"aforo":131,"montoDeclarado":"10000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"1000.00","montoCobrado":30},{"aforo":186,"montoDeclarado":"10000.00","montoCobrado":300}],"fecha":{"month":"junio","year":2020}}	2020-06-30	103	f
1781	381	1000000.00	\N	\N	2020-07-22	100	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	103	f
1773	\N	0.00	\N	\N	2020-01-10	10	{"month":"enero","year":2020,"desglose":[{"aforo":137}]}	2020-01-31	115	f
1774	\N	0.00	\N	\N	2020-03-10	10	{"month":"marzo","year":2020,"desglose":[{"aforo":214}]}	2020-03-31	115	f
1775	\N	0.00	\N	\N	2020-06-10	10	{"month":"junio","year":2020,"desglose":[{"aforo":11}]}	2020-06-30	115	f
1776	\N	0	\N	\N	2020-02-01	10	{"month":"febrero","year":2020,"desglose":[{"aforo":17}]}	2020-02-29	115	f
1777	381	5000000.00	\N	\N	2020-07-22	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	103	f
1778	381	10000000.00	\N	\N	2020-07-22	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-07-31	103	f
1779	381	3000060.00	\N	\N	2020-07-22	10	{"desglose":[{"aforo":131,"montoDeclarado":"1000.00","montoCobrado":3000000},{"aforo":181,"montoDeclarado":"1000.00","montoCobrado":30},{"aforo":186,"montoDeclarado":"1000.00","montoCobrado":30}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	103	f
1782	381	1000000.00	\N	\N	2020-07-22	100	{"fecha":{"month":"junio","year":2020}}	2020-06-30	103	f
1786	382	365406.60	\N	\N	2020-07-23	49	{"fecha":{"month":"marzo","year":"2018"},"desglose":[{"aforo":19,"monto":234234,"mes":"marzo"},{"aforo":44,"monto":23424,"mes":"marzo"},{"aforo":92,"monto":23424,"mes":"marzo"}]}	2020-03-31	\N	f
1787	382	30451.20	\N	\N	2020-07-23	49	{"fecha":{"month":"diciembre","year":"2018"},"desglose":[{"aforo":93,"monto":23424,"mes":"diciembre"}]}	2020-07-31	\N	f
1788	382	5535072.40	\N	\N	2020-07-23	49	{"fecha":{"month":"febrero","year":"2020"},"desglose":[{"aforo":24,"monto":23424,"mes":"febrero"},{"aforo":78,"monto":4234324,"mes":"febrero"}]}	2020-02-29	\N	f
1783	\N	0.00	\N	\N	2020-01-02	10	{"month":"enero","year":2020,"desglose":[{"aforo":137}]}	2020-01-31	116	f
1784	\N	0.00	\N	\N	2020-03-02	10	{"month":"marzo","year":2020,"desglose":[{"aforo":3}]}	2020-03-31	116	f
1785	\N	0.00	\N	\N	2020-06-02	10	{"month":"junio","year":2020,"desglose":[{"aforo":17}]}	2020-06-30	116	f
1789	382	304504.20	\N	\N	2020-07-23	49	{"fecha":{"month":"septiembre","year":"2020"},"desglose":[{"aforo":92,"monto":234234,"mes":"septiembre"}]}	2020-09-30	\N	f
1790	382	30451.20	\N	\N	2020-07-23	49	{"fecha":{"month":"diciembre","year":"2020"},"desglose":[{"aforo":93,"monto":23424,"mes":"diciembre"}]}	2020-07-31	\N	f
\.


--
-- Data for Name: liquidacion_descuento; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.liquidacion_descuento (id_liquidacion_descuento, id_liquidacion, porcentaje_descuento) FROM stdin;
\.


--
-- Data for Name: multa; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.multa (id_multa, id_solicitud, id_tipo_multa, monto, mes, anio) FROM stdin;
\.


--
-- Data for Name: plazo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.plazo_exoneracion (id_plazo_exoneracion, fecha_inicio, fecha_fin) FROM stdin;
21	2020-06-26	\N
22	2020-06-26	\N
23	2020-06-26	\N
24	2020-01-02	2020-07-30
28	2020-07-21	2020-07-21
29	2020-01-21	\N
30	2020-07-21	\N
\.


--
-- Data for Name: ramo; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.ramo (id_ramo, codigo, descripcion, descripcion_corta) FROM stdin;
29	501	MULTAS	MUL
2	101	SITUADO CONSTITUCIONAL	\N
9	112	ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES	AE
8	111	INMUEBLES URBANOS	IU
3	102	SITUADO PUENTE SOBRE EL LAGO	\N
4	103	LEY DE ASIGNACIONES ESPECIALES	\N
5	104	FONDO INTERGUB.PARA LA DESCENT.(FIDES)	\N
6	105	CONSEJO NACIONAL DE VIVIENDA (CONAVI)	\N
7	120	REGALIAS PETROLERAS	\N
10	113	PATENTE DE VEHICULOS	\N
12	115	ESPECTACULOS PUBLICOS	\N
13	116	INSTITUTO NACIONAL DE HIPODROMO 5 Y 6	\N
14	117	JUEGOS Y APUESTAS LICITAS	\N
15	118	REMISION TRIBUTARIA	\N
16	119	CONVENIO DE PAGO GENERAL	\N
17	200	TASA DE ESPECTACULOS PUBLICOS	\N
18	201	EXPEDICION DE VARIABLES URBANAS	\N
19	202	CATASTRO Y NOMENCLATURA	\N
20	203	TASAS ADMINISTRATIVAS POR EXPEDICION DE LICENCIAS DE LICORES	\N
21	204	REGULACION DE ALQUILERES	\N
22	205	VENTA DE AGUA	\N
23	206	VENTA DE GAS	\N
24	301	CEMENTERIO JARDIN LA CHINITA	\N
25	303	MERCADOS MUNICIPALES	\N
26	304	PARTICIPACION PEAJE PUENTE SOBRE EL LAGO	\N
27	306	PARTICIPACION VENTA DE GAS	\N
28	402	INTERESES Y DIVIDENDOS (SEDEMAT)	\N
30	502	MULTA ESPECTACULOS PUBLICOS	\N
31	503	MULTA RECARGO E INT MORA DE CONSTRUCCION	\N
32	504	OTRAS MULTAS	\N
33	552	INTERESES	\N
34	602	COBRANZA DE DEUDA MOROSA	\N
35	604	COBRANZA DE DEUDA MOROSA	\N
36	702	REINTEGROS	\N
37	703	INGRESOS VARIOS	\N
38	704	O T R O S	\N
39	705	RESERVAS DEL TESORO NO COMPROMETIDAS	\N
40	706	INGRESOS A#O ANTERIOR	\N
41	804	CEMENTERIOS MUNICIPALES	\N
42	805	VENTAS DE TERRENOS	\N
43	806	VENTA DE TERRENO PATRIMONIO MUNICIPAL	\N
44	901	APORTES GUBERNAMENTALES Y OTROS	\N
45	902	APORTE DEL I.N.H.	\N
46	903	TRANSFERENCIAS	\N
48	911	REPAROS FISCALES (IND. Y COM.)	\N
49	912	REPARO POR RETENCIONES NO ENTERADAS	\N
51	918	COMPENS.RETENCIONES DEC.048	\N
52	920	DEDUCCIONES,ADELANTOS,Y OTROS GASTOS	\N
53	925	COMPENSACIONES	\N
54	929	CESION DE CREDITO FISCAL	\N
55	930	CORRECCIONES ADMINISTRATIVAS	\N
56	940	REBAJAS FISCALES	\N
57	950	INGRESOS POR SERVICIOS INTERNOS	\N
58	951	DEPOSITOS RECHAZADOS	\N
59	990	LIQUIDACIONES POR CHEQUE DEVUELTO	\N
67	505	MULTA POLIMARACAIBO	\N
60	106	FONDO D/INV.D/ESTAB.MACRO ECONOMICA	\N
61	107	RECURSOS DE MINFRA	\N
62	108	MINISTERIO DE PLANIFICACION Y DESARROLLO	\N
63	109	MINISTERIO DEL INTERIOR Y JUSTICIA	\N
65	207	CONSTANCIA DE VARIABLES URBANAS FUNDAMENTALES	\N
66	208	CONSTANCIAS DE CALIDAD TERMICAS	\N
68	123	DIRECCION DE CATASTRO	\N
69	124	DIRECCION DE OMPU	\N
70	403	INTERESES Y DIVIDENDOS (ALCALDIA MCBO CUENTAS SEDEMAT)	\N
71	404	INTERESES Y DIVIDENDOS (POLIMARACAIBO)	\N
72	405	INTERESES Y DIVIDENDOS (CPU)	\N
73	406	INTERESES Y DIVIDENDOS (BOMBEROS MCBO)	\N
74	407	INTERESES Y DIVIDENDOS (IMAU)	\N
75	408	INTERESES Y DIVIDENDOS (SAGAS)	\N
76	506	MULTA CONSEJO DE PROTECCION NNA	\N
77	409	INTERESES Y DIVIDENDOS (ALCALDIA MCBO)	\N
78	110	ACUERDO NRO. 003-2012	\N
79	410	PROCESO DE LICITACION	\N
80	209	SISTEMA VIAL URBANO	\N
81	401	INTERESES Y DIVIDENDOS (CONSEJO DE DERECHO)	\N
82	127	VENTAJAS ESPECIALES PETROLERAS	\N
83	904	TRANSFERENCIAS CORRIENTES INTERNAS DE LA REPUBLICA	\N
84	707	INGRESOS EN TRANSITO	\N
85	210	DIRECCION DE PROTECCION CIVIL	\N
86	211	TASAS ALCADIA DE MARACAIBO	\N
87	212	TASAS SAGAS	\N
88	411	INTERESES Y DIVIDENDOS (PROTECCION CIVIL)	\N
89	412	INTERESES Y DIVIDENDOS (SALUD MARACAIBO)	\N
90	213	TASAS IMTCUMA	\N
91	508	COPIAS CERTIFICADAS POLIMARACAIBO	\N
92	125	BOMBEROS DE MARACAIBO	\N
93	126	ANTICIPOS DE OBRAS (SIMA)	\N
94	507	MULTAS SALUD MARACAIBO	\N
97	130	DIRECCION DE AGUA	\N
98	140	DIRECCION DE INGENIERIA MUNICIPAL	\N
64	122	SERVICIOS MUNICIPALES	SM
11	114	PROPAGANDAS Y AVISOS COMERCIALES	PP
1	236	TASA ADMINISTRATIVA DE SOLVENCIA DE AE	SAE
50	915	RETENCIONES DECRETO 048	RD0
47	910	REPAROS FISCALES	REP
\.


--
-- Data for Name: ramo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.ramo_exoneracion (id_ramo_exoneracion, id_plazo_exoneracion, id_ramo) FROM stdin;
2	29	8
\.


--
-- Data for Name: registro_municipal; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.registro_municipal (id_registro_municipal, id_contribuyente, referencia_municipal, fecha_aprobacion, telefono_celular, telefono_habitacion, email, denominacion_comercial, nombre_representante, actualizado, capital_suscrito, tipo_sociedad, estado_licencia) FROM stdin;
76	84	2900011266	2020-07-09	4147212342	\N	snider8520@gmail.com	CORPORACION GSM	OSWALDO CISNEROS	t	\N	\N	\N
77	84	2900014139	2020-07-09	4147212342	\N	snider8520@gmail.com	CORPORACION DIGITEL, C.A.	ROBERTO JOSE ORTA	t	\N	\N	\N
78	84	2900013536	2020-07-09	4147212342	\N	snider8520@gmail.com	CORPORACION DIGITEL, C.A.  PALACIO DE EVENTOS	FRANCISCO  HUNG	t	\N	\N	\N
79	84	2900026280	2020-07-09	4147212342	\N	snider8520@gmail.com	CORPORACION DIGITEL, C.A.	DEMERIS RUIZ	t	\N	\N	\N
80	84	2900011265	2020-07-09	4147212342	\N	snider8520@gmail.com	CORPORACION DIGITEL, C.A.	ALFRED TULIO HUNG RIVERO	t	\N	\N	\N
81	85	2000082650	2020-07-09	4246336236	\N	prueba2@gmail.com	POLICLINICA MARACAIBO	DR.ROBERTO DE VICENTE RIOS	t	\N	\N	\N
84	86	207R002132	2020-07-10	4127645681	\N	gab.tc@icloud.com	RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )	JOSE ABEID	t	\N	\N	\N
87	87	204C000237	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMATODO, C.A. FARMACIA FUERZAS ARMADAS	RAFAEL ZUBILLAGA	t	\N	\N	\N
88	87	203C000844	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMATODO, C.A. FARMACIA LA ESQUINA	RAFAEL ZUBILLAGA	t	\N	\N	\N
89	87	203C000845	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMACIA TORRE EUROPA	RAFAEL ZUBILLAGA	t	\N	\N	\N
90	87	2900000031	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMACIA LAGOMAR	RAFAEL T ZUBILLAGA	t	\N	\N	\N
91	87	2900040085	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMATODO, C.A. FARMACIA FRANCISCO	ARMANDO ZUBILLAGA	t	\N	\N	\N
92	87	2900003892	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMACIA INDIO  MARA	VICTOR MICHELENA	t	\N	\N	\N
93	87	2900041800	2020-07-10	4246336236	\N	prueba3@gmail.com	FARMATODO, C.A. (FARMACIA NERIDA)	ARMANDO ZUBILLAGA	t	\N	\N	\N
94	90	2900004854	2020-07-13	261	\N	edssoncardenas@gmail.com	TALLER DE TORNOS Y EMBOBINADOS D Y M,CA	DOUGLAS CHACIN	t	\N	\N	\N
95	91	7000000999	2020-07-13	414	\N	diegosalazar2702@gmail.com	MSL GROUPAGE, C.A. (SUCURSAL)	MSL GROUPAGE, C.A.	t	\N	\N	\N
96	95	7000002467	2020-07-13	4146224064	\N	wakapluswakuplus@gmail.com	SERVICIOS INFORMATICOS WAKUPLUS CA	MANUEL MARULANDA	t	\N	\N	\N
97	95	7000002467	2020-07-13	4146224064	\N	wakapluswakuplus@gmail.com	SERVICIOS INFORMATICOS WAKUPLUS CA	MANUEL MARULANDA	t	\N	\N	\N
98	96	AR20200005	2020-07-13	4246336236	\N	yury@hotmail.com	MEGA 72 C.A	LILIA MATIAS DE TEXEIRA	t	\N	\N	\N
99	96	2900003475	2020-07-13	4246336236	\N	yury@hotmail.com	MEGA 72 C.A	LILIA MATIAS DE TEXEIRA	t	\N	\N	\N
86	86	2900013829	2020-07-10	4127645681	\N	covides@gmail.com	FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )	LILIANA SANCHEZ	t	\N	\N	\N
100	98	204R000441	2020-07-14	4246336236	\N	prueba7@gmail.com	DISTRIBUIDORA J.K. C.A.	JASAT MASEN	t	\N	\N	\N
85	86	207P000358	2020-07-10	4127645681	\N	gab.tc@icloud.com	FARMACIA COVIDES C.A.-	LILIANA SANCHEZ.-	t	\N	\N	\N
82	86	AR20200024	2020-07-10	4127645681	\N	gab.tc@icloud.com	FARMACIA COVIDES C.A.	IVECO	t	\N	\N	\N
101	99	2900049654	2020-07-14	4246336236	\N	prueba6@gmail.com	FERRETOTAL CARACAS C.A. (SUCURSAL)	CARLOS PEREZ	t	\N	\N	\N
102	99	2000812803	2020-07-14	4246336236	\N	prueba6@gmail.com	FERRETOTAL CARACAS C.A.	ALEJANDRO KERI	t	\N	\N	\N
103	99	2900040570	2020-07-14	4246336236	\N	prueba6@gmail.com	FERRETOTAL CARACAS C.A. (SUCURSAL)	ALEJANDRO KERI JESURUM	t	\N	\N	\N
105	100	8000000008	2020-07-15	4146053291	\N	trosales@gmail.com	Empanadas Triny	Triny Rosales	t	40000000	\N	\N
107	101	8000000010	2020-07-16	4246336236	\N	rodrigolamus@gmail.com	e	wgweg	t	58	\N	\N
108	101	8000000011	2020-07-16	4246336236	\N	rodrigolamus@gmail.com	comercializadora	jose sanchez	t	50000000	\N	\N
109	105	8000000012	2020-07-19	+584146053291	\N	orderleep@gmail.com	Empanadas Triny	Triny Rosales	t	5000000	\N	\N
110	106	8000000013	2020-07-21	4246336236	\N	prueba13@gmail.com	comercializadora	jose coro	t	360000000	\N	\N
113	86	8000000016	2020-07-21	1231241231	\N	prueba10@gmail.com	FARMACIA COVIDES	JOSE CORO	t	12039109	\N	PERMANENTE
114	89	8000000017	2020-07-21	4246336236	\N	prueba4@gmail.com	comercializadora	jose sanchez	t	50000000	\N	PERMANENTE
83	86	207R002131	2020-07-10	4127645681	\N	\N	FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )	JOSE ABELD	t	\N	\N	PERMANENTE
106	101	8000000009	2020-07-16	4246336236	\N	\N	comercializadora	jose sanchez	t	50000000	\N	PERMANENTE
115	107	8000000018	2020-07-21	4246336236	\N	\N	comercializadora	jose coro segundo	t	50000000	\N	PERMANENTE
116	107	8000000019	2020-07-23	4246336236	\N	prueba14@gmail.com	comercializadora	jose coro	t	50000000	\N	PERMANENTE
\.


--
-- Data for Name: registro_municipal_verificacion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.registro_municipal_verificacion (id_registro_municipal, id_verificacion_telefono) FROM stdin;
76	107
77	107
78	107
79	107
80	107
81	108
83	109
84	109
87	110
88	110
89	110
90	110
91	110
92	110
93	110
98	113
99	113
86	115
100	117
85	118
82	119
101	120
102	120
103	120
105	121
106	122
107	122
108	122
109	126
110	127
113	128
114	112
115	129
116	129
\.


--
-- Data for Name: retencion; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.retencion (id_retencion, rif, rim, monto, fecha, activo) FROM stdin;
\.


--
-- Data for Name: solicitud; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.solicitud (id_solicitud, id_usuario, aprobado, fecha, fecha_aprobado, id_tipo_tramite, id_contribuyente, tipo_solicitud) FROM stdin;
353	116	f	2020-07-14	\N	5	87	CONVENIO
314	155	f	2020-07-10	\N	5	84	CONVENIO
355	157	f	2020-07-14	\N	5	87	CONVENIO
401	209	f	2020-07-24	\N	5	86	RETENCION
321	116	f	2020-07-10	\N	5	87	CONVENIO
352	119	f	2020-07-13	\N	5	86	CONVENIO
269	155	t	2020-05-05	2020-07-09	5	84	IMPUESTO
363	155	f	2020-07-15	\N	5	84	CONVENIO
367	165	f	2020-07-15	\N	5	99	CONVENIO
275	155	t	2020-07-09	2020-07-13	5	84	CONVENIO
368	165	f	2020-07-15	\N	5	99	CONVENIO
346	155	f	2020-07-13	\N	5	84	CONVENIO
371	165	f	2020-07-15	\N	5	99	CONVENIO
372	165	f	2020-07-15	\N	5	99	CONVENIO
373	165	f	2020-07-15	\N	5	99	CONVENIO
382	83	f	2020-07-23	\N	5	107	IMPUESTO
383	118	f	2020-07-23	\N	5	86	RETENCION
384	118	f	2020-07-24	\N	5	86	RETENCION
270	155	f	2020-07-09	\N	5	84	IMPUESTO
276	156	t	2020-05-05	2020-07-09	5	85	IMPUESTO
277	156	f	2020-07-09	\N	5	85	IMPUESTO
278	156	f	2020-07-09	\N	5	85	IMPUESTO
354	116	f	2020-07-14	\N	5	87	IMPUESTO
279	\N	t	2020-04-22	2020-07-10	5	86	IMPUESTO
310	116	t	2020-07-10	2020-07-10	5	87	IMPUESTO
400	118	f	2020-07-24	\N	5	86	RETENCION
311	116	f	2020-07-10	\N	5	87	IMPUESTO
280	58	t	2020-04-28	2020-07-10	5	86	IMPUESTO
312	155	f	2020-07-10	\N	5	84	IMPUESTO
313	155	f	2020-07-10	\N	5	84	IMPUESTO
282	\N	t	2020-04-28	2020-07-10	5	86	IMPUESTO
315	155	f	2020-07-10	\N	5	84	IMPUESTO
316	155	f	2020-07-10	\N	5	84	IMPUESTO
356	173	t	2020-05-08	2020-07-14	5	98	IMPUESTO
357	116	f	2020-07-14	\N	5	98	IMPUESTO
284	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
285	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
322	116	f	2020-07-10	\N	5	87	IMPUESTO
286	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
287	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
323	157	f	2020-07-13	\N	5	87	IMPUESTO
288	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
289	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
290	157	t	2020-04-28	2020-07-10	5	87	IMPUESTO
291	157	f	2020-04-28	\N	5	87	IMPUESTO
292	157	f	2020-04-28	\N	5	87	IMPUESTO
293	157	f	2020-04-28	\N	5	87	IMPUESTO
294	157	f	2020-04-28	\N	5	87	IMPUESTO
295	157	f	2020-04-28	\N	5	87	IMPUESTO
296	157	f	2020-04-28	\N	5	87	IMPUESTO
297	157	f	2020-04-28	\N	5	87	IMPUESTO
298	116	t	2020-07-10	2020-07-10	5	87	IMPUESTO
299	116	t	2020-07-10	2020-07-10	5	87	IMPUESTO
300	116	f	2020-07-10	\N	5	87	IMPUESTO
301	116	t	2020-07-10	2020-07-10	5	87	IMPUESTO
303	157	t	2020-07-10	2020-07-13	5	87	IMPUESTO
302	116	t	2020-07-10	2020-07-10	5	87	IMPUESTO
328	116	t	2020-07-13	2020-07-13	5	87	IMPUESTO
281	194	t	2020-04-28	2020-07-10	5	86	IMPUESTO
283	194	t	2020-07-10	2020-07-10	5	86	IMPUESTO
329	116	t	2020-03-04	2020-07-13	5	90	IMPUESTO
358	165	t	2020-05-05	2020-07-14	5	99	IMPUESTO
350	194	t	2020-07-13	2020-07-13	5	86	IMPUESTO
330	116	t	2020-05-07	2020-07-13	5	91	IMPUESTO
359	165	t	2020-05-06	2020-07-14	5	99	IMPUESTO
376	117	f	2020-07-20	\N	5	99	IMPUESTO
360	165	t	2020-05-05	2020-07-14	5	99	IMPUESTO
331	116	t	2020-05-06	2020-07-13	5	95	IMPUESTO
361	116	f	2020-07-14	\N	5	99	IMPUESTO
332	116	t	2020-05-06	2020-07-13	5	95	IMPUESTO
333	116	f	2020-05-06	\N	5	95	IMPUESTO
334	116	f	2020-05-06	\N	5	95	IMPUESTO
362	116	f	2020-07-15	\N	5	84	IMPUESTO
335	116	t	2020-07-13	2020-07-13	5	95	IMPUESTO
336	164	t	2020-05-08	2020-07-13	5	96	IMPUESTO
364	116	f	2020-07-15	\N	5	99	IMPUESTO
365	165	f	2020-07-15	\N	5	99	IMPUESTO
337	164	t	2020-05-07	2020-07-13	5	96	IMPUESTO
366	165	f	2020-07-15	\N	5	99	IMPUESTO
338	116	t	2020-07-13	2020-07-13	5	96	IMPUESTO
339	116	t	2020-07-13	2020-07-13	5	95	IMPUESTO
340	117	t	2020-07-13	2020-07-13	5	87	IMPUESTO
341	117	t	2020-07-13	2020-07-13	5	87	IMPUESTO
342	118	f	2020-07-13	\N	5	84	IMPUESTO
344	155	f	2020-07-13	\N	5	84	IMPUESTO
345	155	f	2020-07-13	\N	5	84	IMPUESTO
347	155	f	2020-07-13	\N	5	84	IMPUESTO
369	116	f	2020-07-15	\N	5	99	IMPUESTO
343	117	t	2020-07-13	2020-07-13	5	87	IMPUESTO
370	165	f	2020-07-15	\N	5	99	IMPUESTO
348	117	t	2020-07-13	2020-07-13	5	87	IMPUESTO
349	117	f	2020-07-13	\N	5	87	IMPUESTO
377	117	f	2020-07-20	\N	5	99	IMPUESTO
351	119	f	2020-07-13	\N	5	86	IMPUESTO
378	117	f	2020-07-20	\N	5	99	IMPUESTO
374	116	f	2020-07-15	\N	5	100	IMPUESTO
375	116	f	2020-07-15	\N	5	100	IMPUESTO
379	117	f	2020-07-21	\N	5	106	IMPUESTO
380	117	f	2020-07-21	\N	5	95	IMPUESTO
381	165	f	2020-07-22	\N	5	99	IMPUESTO
\.


--
-- Data for Name: subramo; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.subramo (id_subramo, id_ramo, subindice, descripcion) FROM stdin;
3	2	1	Pago ordinario
4	3	1	Pago ordinario
5	4	1	Pago ordinario
6	5	1	Pago ordinario
7	6	1	Pago ordinario
8	7	1	Pago ordinario
9	8	1	Pago ordinario
10	9	1	Pago ordinario
11	10	1	Pago ordinario
12	11	1	Pago ordinario
13	12	1	Pago ordinario
14	13	1	Pago ordinario
15	14	1	Pago ordinario
16	15	1	Pago ordinario
17	16	1	Pago ordinario
18	17	1	Pago ordinario
19	18	1	Pago ordinario
20	19	1	Pago ordinario
21	20	1	Pago ordinario
22	21	1	Pago ordinario
23	22	1	Pago ordinario
24	23	1	Pago ordinario
25	24	1	Pago ordinario
26	25	1	Pago ordinario
27	26	1	Pago ordinario
28	27	1	Pago ordinario
29	28	1	Pago ordinario
32	30	1	Pago ordinario
33	31	1	Pago ordinario
34	32	1	Pago ordinario
35	33	1	Pago ordinario
36	34	1	Pago ordinario
37	35	1	Pago ordinario
38	36	1	Pago ordinario
39	37	1	Pago ordinario
40	38	1	Pago ordinario
41	39	1	Pago ordinario
42	40	1	Pago ordinario
43	41	1	Pago ordinario
44	42	1	Pago ordinario
45	43	1	Pago ordinario
46	44	1	Pago ordinario
47	45	1	Pago ordinario
48	46	1	Pago ordinario
49	47	1	Pago ordinario
50	48	1	Pago ordinario
51	49	1	Pago ordinario
52	50	1	Pago ordinario
53	51	1	Pago ordinario
54	52	1	Pago ordinario
55	53	1	Pago ordinario
56	54	1	Pago ordinario
57	55	1	Pago ordinario
58	56	1	Pago ordinario
59	57	1	Pago ordinario
60	58	1	Pago ordinario
61	59	1	Pago ordinario
62	60	1	Pago ordinario
63	61	1	Pago ordinario
64	62	1	Pago ordinario
65	63	1	Pago ordinario
66	64	1	Pago ordinario
67	65	1	Pago ordinario
68	66	1	Pago ordinario
69	67	1	Pago ordinario
70	68	1	Pago ordinario
71	69	1	Pago ordinario
72	70	1	Pago ordinario
73	71	1	Pago ordinario
74	72	1	Pago ordinario
75	73	1	Pago ordinario
76	74	1	Pago ordinario
77	75	1	Pago ordinario
78	76	1	Pago ordinario
79	77	1	Pago ordinario
80	78	1	Pago ordinario
81	79	1	Pago ordinario
82	80	1	Pago ordinario
83	81	1	Pago ordinario
84	82	1	Pago ordinario
85	83	1	Pago ordinario
86	84	1	Pago ordinario
87	85	1	Pago ordinario
88	86	1	Pago ordinario
89	87	1	Pago ordinario
90	88	1	Pago ordinario
91	89	1	Pago ordinario
92	90	1	Pago ordinario
93	91	1	Pago ordinario
94	92	1	Pago ordinario
95	93	1	Pago ordinario
96	94	1	Pago ordinario
97	97	1	Pago ordinario
98	98	1	Pago ordinario
99	9	2	Convenio de Pago
30	29	1	Multa por Declaracion Tardia (Actividad Economica)
100	1	1	Pago ordinario
101	29	2	Convenio de Pago
102	64	2	Convenio de Pago
103	8	2	Convenio de Pago
104	11	2	Convenio de Pago
105	29	3	Multa por Declaracion Tardia (Agente de Retención)
106	47	2	Convenio de Pago
\.


--
-- Data for Name: tabulador_aseo_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tabulador_aseo_actividad_economica (id_tabulador_aseo_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
2	83	1002001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
3	83	1003001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
5	83	1005001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
6	83	1006001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
7	83	1007001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
8	83	1008001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
9	83	1009001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
10	83	1010001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
11	83	1011001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
12	83	1012001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
13	83	1013001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
14	83	1014001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
15	83	1015001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
16	83	1016001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
17	83	1017001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
18	83	1018001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
19	83	1019001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
20	83	1020001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
22	83	1022001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
23	83	1023001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
24	83	1024001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
25	83	1025001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
26	83	1026001	9240000.00	2020-06-11 04:00:00+00	2020-06-11	\N
27	83	1027001	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
28	83	1028001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
29	83	1029001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
30	83	1030001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
31	83	1033001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
32	83	1034001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
33	83	1036001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
34	83	1037001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
35	83	1038001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
36	83	1039001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
37	83	1040001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
39	83	1042001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
40	83	1043001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
41	83	1044001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
42	83	1045001	9240000.00	2020-06-11 04:00:00+00	2020-06-11	\N
43	83	1046001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
44	83	1047001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
45	83	1048001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
46	83	2001001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
47	83	2002001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
48	83	2003001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
49	83	2004001	9240000.00	2020-06-11 04:00:00+00	2020-06-11	\N
50	83	2005001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
51	83	2006001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
52	83	2007001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
53	83	2008001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
54	83	2009001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
56	83	2011001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
57	83	2012001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
58	83	2013001	46200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
59	83	2014001	23100000.00	2020-06-11 04:00:00+00	2020-06-11	\N
61	83	2015001	13860000.00	2020-06-11 04:00:00+00	2020-06-11	\N
60	83	2016001	11550000.00	2020-06-11 04:00:00+00	2020-06-11	\N
62	83	2017001	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
63	83	2018001	30800000.00	2020-06-11 04:00:00+00	2020-06-11	\N
64	83	2019001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
65	83	2020001	27720000.00	2020-06-11 04:00:00+00	2020-06-11	\N
66	83	2021001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
67	83	2022001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
68	83	2023001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
69	83	2024002	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
70	83	2025003	23100000.00	2020-06-11 04:00:00+00	2020-06-11	\N
71	83	2026001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
73	83	2029001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
74	83	2030001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
75	83	2031001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
76	83	2032001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
77	83	2033001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
78	83	2034001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
79	83	2035001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
80	83	2036001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
81	83	2037001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
82	83	2038001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
83	83	2039001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
84	83	2040001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
85	83	2042001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
86	83	2043002	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
87	83	2044001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
88	83	2045001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
90	83	2047001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
91	83	2048001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
92	83	2049002	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
93	83	2051001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
94	83	2052001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
95	83	2053001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
96	83	2054001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
97	83	2055001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
98	83	2056001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
99	83	2057001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
100	83	2058001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
101	83	2059001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
102	83	2060001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
103	83	2061001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
104	83	2062001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
105	83	2063001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
107	83	2065001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
108	83	2066001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
109	83	2067001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
110	83	2068001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
113	83	2071001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
114	83	2072001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
115	83	2073001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
116	83	3001001	23100000.00	2020-06-11 04:00:00+00	2020-06-11	\N
117	83	3002001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
118	83	3003002	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
119	83	3004001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
120	83	3005001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
1	83	1001001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
4	83	1004001	13860000.00	2020-06-11 04:00:00+00	2020-06-11	\N
21	83	1021001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
204	83	1032001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
205	83	1035001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
38	83	1041001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
55	83	2010001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
195	83	20230011	23100000.00	2020-06-11 04:00:00+00	2020-06-11	\N
196	83	20230012	30800000.00	2020-06-11 04:00:00+00	2020-06-11	\N
197	83	20230013	46200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
206	83	2027001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
198	83	20270011	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
199	83	20270012	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
72	83	2028001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
207	83	2041001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
89	83	2046001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
208	83	2050001	12320000.00	2020-06-11 04:00:00+00	2020-06-11	\N
106	83	2064001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
111	83	2069002	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
112	83	2070003	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
121	83	3006001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
122	83	3007001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
123	83	3008001	8470000.00	2020-06-11 04:00:00+00	2020-06-11	\N
124	83	3009001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
125	83	3010001	16940000.00	2020-06-11 04:00:00+00	2020-06-11	\N
126	83	3011001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
127	83	3012001	8470000.00	2020-06-11 04:00:00+00	2020-06-11	\N
128	83	3013001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
129	83	3014001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
130	83	3015001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
131	83	3016001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
132	83	3017002	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
209	83	3018001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
133	83	3019002	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
134	83	3020001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
135	83	3021001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
136	83	3022001	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
137	83	3023001	6930000.00	2020-06-11 04:00:00+00	2020-06-11	\N
138	83	3024001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
200	83	30240011	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
201	83	30240012	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
139	83	3025001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
140	83	3026001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
141	83	3027001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
142	83	3028001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
210	83	3029001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
143	83	3030002	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
144	83	3031001	10010000.00	2020-06-11 04:00:00+00	2020-06-11	\N
145	83	3032001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
146	83	3033002	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
147	83	3034001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
148	83	3035001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
149	83	3036001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
150	83	3037001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
151	83	3038001	10780000.00	2020-06-11 04:00:00+00	2020-06-11	\N
152	83	3039001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
153	83	3040001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
154	83	3041001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
155	83	3042001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
156	83	3043001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
157	83	3044001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
158	83	3045002	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
159	83	3046001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
160	83	3047001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
161	83	3048001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
162	83	3049001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
163	83	3050001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
164	83	3051001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
165	83	3052001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
166	83	3053002	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
167	83	3054001	8470000.00	2020-06-11 04:00:00+00	2020-06-11	\N
168	83	3055001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
169	83	3056001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
170	83	3057001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
171	83	3058001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
172	83	3059001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
173	83	3060001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
174	83	3061001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
175	83	3062001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
176	83	3063001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
177	83	3064001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
202	83	30640011	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
203	83	30640012	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
178	83	3065001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
179	83	3066001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
180	83	3067001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
181	83	3068001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
211	83	3069001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
182	83	3070001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
212	83	3071001	7700000.00	2020-06-11 04:00:00+00	2020-06-11	\N
183	83	3072002	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
184	83	3073001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
185	83	3074001	3080000.00	2020-06-11 04:00:00+00	2020-06-11	\N
186	83	3075001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
187	83	3076001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
188	83	3077001	3850000.00	2020-06-11 04:00:00+00	2020-06-11	\N
189	83	3078001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
190	83	3079001	4620000.00	2020-06-11 04:00:00+00	2020-06-11	\N
191	83	3080001	6160000.00	2020-06-11 04:00:00+00	2020-06-11	\N
192	83	3081001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
193	83	3082001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
194	83	3083001	5390000.00	2020-06-11 04:00:00+00	2020-06-11	\N
\.


--
-- Data for Name: tabulador_aseo_residencial; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tabulador_aseo_residencial (id_tabulador_aseo_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	18000	2020-06-11 17:49:10.551481+00	2020-06-11	\N
\.


--
-- Data for Name: tabulador_gas; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tabulador_gas (id_tabulador_gas, id_actividad_economica, monto) FROM stdin;
\.


--
-- Data for Name: tabulador_gas_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tabulador_gas_actividad_economica (id_tabulador_gas_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
2	83	1003001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
3	83	1004001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
6	83	1006001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
7	83	1007001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
8	83	1008001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
9	83	1009001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
10	83	1010001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
11	83	1011001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
12	83	1012001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
13	83	1013001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
14	83	1014001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
15	83	1015001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
16	83	1016001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
17	83	1017001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
18	83	1018001	17600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
20	83	1020001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
21	83	1021001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
22	83	1022001	8800000.00	2020-06-11 04:00:00+00	2020-06-11	\N
23	83	1023001	8800000.00	2020-06-11 04:00:00+00	2020-06-11	\N
24	83	1024001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
25	83	1025001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
26	83	1026001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
27	83	1027001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
28	83	1028001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
29	83	1029001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
30	83	1030001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
31	83	1031001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
32	83	1032001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
33	83	1033001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
34	83	1034001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
35	83	1035001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
36	83	1036001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
37	83	1037001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
38	83	1039001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
40	83	1041001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
41	83	1042001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
42	83	1043001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
43	83	1044001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
44	83	1045001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
45	83	1046001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
46	83	1047001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
47	83	1048001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
48	83	2001001	17600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
49	83	2002001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
50	83	2003001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
51	83	2004001	8800000.00	2020-06-11 04:00:00+00	2020-06-11	\N
52	83	2005001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
53	83	2006001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
4	83	2007001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
54	83	2008001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
56	83	2010001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
57	83	2011001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
58	83	2012001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
59	83	2014001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
60	83	2015001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
61	83	2016001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
62	83	2017001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
63	83	2018001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
64	83	2019001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
65	83	2020001	17600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
66	83	2021001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
67	83	2022001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
68	83	2023001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
69	83	2024002	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
70	83	2025003	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
71	83	2026001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
73	83	2028001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
72	83	2029001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
75	83	2030001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
76	83	2031001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
77	83	2032001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
78	83	2033001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
79	83	2034001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
80	83	2035001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
81	83	2036001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
82	83	2037001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
83	83	2038001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
84	83	2039001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
85	83	2040001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
86	83	2041001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
87	83	2042001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
88	83	2043002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
90	83	2046001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
91	83	2047001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
92	83	2048001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
93	83	2049002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
94	83	2051001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
95	83	2052001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
96	83	2053001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
97	83	2054001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
98	83	2055001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
99	83	2056001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
100	83	2057001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
101	83	2058001	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
102	83	2059001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
103	83	2060001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
104	83	2061001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
105	83	2062001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
107	83	2064001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
108	83	2065001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
109	83	2066001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
110	83	2067001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
111	83	2068001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
112	83	2069002	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
113	83	2070003	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
114	83	2071001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
115	83	2072001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
119	83	2073001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
116	83	3001001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
117	83	3002001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
118	83	3003002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
120	83	3004001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
1	83	1002001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
5	83	1005001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
19	83	1019001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
206	83	1038001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
39	83	1040001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
55	83	2009001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
207	83	2013001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
197	83	20230011	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
198	83	20230012	13200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
199	83	20230013	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
74	83	2027001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
200	83	20270011	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
201	83	20270012	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
208	83	2044001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
89	83	2045001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
209	83	2050001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
106	83	2063001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
121	83	3005001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
122	83	3006001	11000000.00	2020-06-11 04:00:00+00	2020-06-11	\N
123	83	3007001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
125	83	3008001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
124	83	3009001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
126	83	3010001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
127	83	3011001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
128	83	3012001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
129	83	3013001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
130	83	3014001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
131	83	3015001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
132	83	3016001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
133	83	3017002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
210	83	3018001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
134	83	3019002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
135	83	3020001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
136	83	3021001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
137	83	3022001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
138	83	3023001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
139	83	3024001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
202	83	30240011	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
203	83	30240012	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
140	83	3025001	2200000.00	2020-06-11 04:00:00+00	2020-06-11	\N
141	83	3026001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
142	83	3027001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
143	83	3028001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
144	83	3029001	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
145	83	3030002	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
146	83	3031001	5500000.00	2020-06-11 04:00:00+00	2020-06-11	\N
147	83	3032001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
148	83	3033002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
149	83	3034001	15400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
150	83	3035001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
151	83	3036001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
152	83	3037001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
153	83	3038001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
154	83	3039001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
155	83	3040001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
156	83	3041001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
157	83	3042001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
158	83	3043001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
159	83	3044001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
160	83	3045002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
161	83	3046001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
162	83	3047001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
163	83	3048001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
211	83	3049001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
164	83	3050001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
165	83	3051001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
166	83	3052001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
167	83	3053002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
168	83	3054001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
169	83	3055001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
170	83	3056001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
171	83	3057001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
172	83	3058001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
173	83	3059001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
174	83	3060001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
175	83	3061001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
176	83	3062001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
177	83	3063001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
178	83	3064001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
204	83	30640011	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
205	83	30640012	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
179	83	3065001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
212	83	3066001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
180	83	3067001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
181	83	3068001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
182	83	3069001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
183	83	3070001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
184	83	3071001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
185	83	3072002	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
186	83	3073001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
187	83	3074001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
188	83	3075001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
189	83	3076001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
190	83	3077001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
191	83	3078001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
192	83	3079001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
193	83	3080001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
194	83	3081001	3300000.00	2020-06-11 04:00:00+00	2020-06-11	\N
195	83	3082001	6600000.00	2020-06-11 04:00:00+00	2020-06-11	\N
196	83	3083001	4400000.00	2020-06-11 04:00:00+00	2020-06-11	\N
\.


--
-- Data for Name: tabulador_gas_residencial; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tabulador_gas_residencial (id_tabulador_gas_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	7000	2020-06-11 17:48:49.040513+00	2020-06-11	\N
\.


--
-- Data for Name: tipo_aviso_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tipo_aviso_propaganda (id_tipo_aviso_propaganda, id_categoria_propaganda, descripcion, parametro, monto, id_valor) FROM stdin;
198	2	A-002.2, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
199	2	A-002.3, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
200	3	A-003.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIOS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
201	3	A-003.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCOPORADAS EN ANUNCIOS PORTAILES, EXHBIDORES, CABECERO MULTIMARCA, PIXEL.	UNIDADES	3	2
202	3	A-003.3, ANUNCIOS E IMÁGENES INCOPORADAS A VEHICULO AUTOMOTOR.	UNIDADES	4	2
204	3	A-003.5, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
203	3	A-003.4, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
205	4	A-004.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
206	4	A-004.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCOPORADAS EN ANUNCIOS PORTÁTILES, EXHBIDORES, CABECERO MULTIMARCA, PIXEL.	UNIDADES	3	2
207	4	A-004.3, ANUNCIOS E IMÁGENES INCOPORADAS A VEHICULO AUTOMOTOR.	UNIDADES	4	2
208	4	A-004.4, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
209	4	A-004.5, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
194	1	A-001.2, PROPAGANADA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS  EN ANUNCIOS PORTÁTILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
195	1	A-001.3, ANUNCIOS E IMÁGENES DEL PRODUCTO INCORPORADOS A VEHÍCULOS AUTOMOTORES.	UNIDADES	2	2
196	1	A-001.4, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
210	5	A-005.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
211	5	A-005.2, ANUNCIOS E IMÁGENES INCOPORADAS A VHEICULO AUTOMOTOR.	UNIDADES	4	2
193	1	A-001.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS, TOLDOS Y MARQUESINA. \nINCLUYE AVISOS EN CENTROS COMERCIALES, LICORERÍAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS, RESTAURANTE Y SIMILARES. PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTÁTILES, EXHIBIDORES, CABECERO MULTIMARCA.\n	UNIDADES	4	2
214	5	A-005.5, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
212	5	A-005.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
213	5	A-005.4, PROPAGANDA DE PRODUCTOS, IMAGEN O MARCAS INCORPORADA  A EQUIPOS TALES COMO: NEVERAS, FREEZER, CAVAS, ENFRIADORAS DE BOTELLAS, HELADOS Y YOGURT.	UNIDADES	4	2
215	6	A-006.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
216	6	A-006.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTÁTILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
217	6	A-006.3, ANUNCIOS E IMÁGENES INCOPORADAS A VHEICULO AUTOMOTOR.	UNIDADES	4	2
219	6	A-006.5, PROMOCIONES EVENTUALES.	UNIDADES	5	2
220	6	A-006.6, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
221	7	A-007.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE FACHADA, SALIENTES, PARED, SUELO, CHUPETA, COLGANTES DE VIENTOS, VALLAS, TOLDOS Y MARQUESINA.( Que estén  fijados en el piso, pared o fachada del establecimiento).	UNIDADES	4	2
222	7	A-007.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADOS EN ANUNCIOS PORTÁTILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
223	7	A-007.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
224	7	A-007.4, MAQUINAS DISPENSADORAS DE CAFÉ, SOLO O COMBINADO, CON INCORPORACIÓN DE PROPAGANDA DE PRODUCTOS O MARCAS. PROPAGANDA DE PRODUCTOS O MARCAS INCOPORADA A EQUIPOS TALES COMO, NEVERAS, FREEZER, CAVAS, ENFRIADORAS DE BOTELLAS Y YOGURT.	UNIDADES	3	2
225	7	A-007.5, PROMOCIONES EVENTUALES.	UNIDADES	5	2
226	7	A-007.6, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
227	8	A-008.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
228	8	A-008.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTATILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
230	8	A-008.4, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
231	9	A-009.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
232	9	A-009.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTATILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
233	9	A-009.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
234	9	A-009.4, OTROS MEDIOS NO ESPECÍFICADOS.	UNIDADES	7	2
235	10	A-010.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
236	10	A-010.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTATILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
237	10	A-010.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
238	10	A-010.4, ANUNCIOS E IMÁGENES DEL PRODUCTO ENCORPORADOS A VEHÍCULO AUTOMOTOR.	UNIDADES	3	2
239	10	A-010.5, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
240	11	A-011.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
241	11	A-011.2, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
242	11	A-011.3, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
243	12	A-012.1, PROPAGANDA DE FACHADA, SALIENTES, PARED, SUELO, CHUPETA, ANUNCIOS COLGANTE Y DE VIENTOS, TOLDOS Y MARQUESINAS.	UNIDADES	4	2
244	12	A-012.2, ANUNCIOS E IMÁGENES DEL PRODUCTO INCORPORADOS A VEHÍCULO AUTOMOTOR.	UNIDADES	3	2
245	12	A-012.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
246	12	A-012.4, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
247	13	A-013.1, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN AVISOS DE: PARED, FACHADA, DE SUELO, DE CHUPETA, COLGANTES DE VIENTOS, VALLAS,\nINCLUYE  AVISOS EN LICORERIAS, ESTABLECIMIENTOS NOCTURNOS, PANADERÍAS, MINI MERCADOS, FARMACIAS, SUPERMERCADOS Y SIMILARES.\n	UNIDADES	4	2
248	13	A-013.2, PROPAGANDA E IMAGEN DEL PRODUCTO O MARCA INCORPORADAS EN ANUNCIOS PORTATILES, EXHIBIDORES, CABECERO MULTIMARCA.	UNIDADES	3	2
218	6	A-006.4, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
229	8	A-008.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
249	13	A-013.3, IMAGEN DEL PRODUCTO O MARCA, INCORPORADAS EN: ANUNCIOS DE BILLETES, CARA A CARA, HABLADORES, BANDERINES, PANCARTAS, SUVENIR, ANUNCIOS O ENCARTES EN PERIODICOS, REVISTAS SERVILLETEROS. PITILLERAS, DESTAPADORES, LLAVEROS, AFICHES, POWER BANK, PENDONES, ROTULADORS MICROPERFORADOS, PUNTA DE GÓNDOLA, ROMPETRAFICO, BANDEA, VAOS, CAJAS O ENVASES, MESAS, SILLAS, DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA. DE CUALQUIER OTRO MATERIAL QUE INCORPOREN SU IMAGEN DE PRODUCTO O MARCA.	BANDA	5	2
250	13	A-013.4, ANUNCIOS E IMÁGENES DEL PRODUCTO INCORPORADOS A VEHÍCULO AUTOMOTOR.	UNIDADES	3	2
251	13	A-013.5, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
252	14	A-014.1, OTRAS CLASES DE PUBLICIDAD Y PROPAGANDA COMERCIAL.	UNIDADES	7	2
253	1	A-001.5, PROPAGANDA DE PRODUCTOS, IMAGEN O MARCAS, INCORPORADA A EQUIPOS TALES COMO: NEVERAS, FREEZER, CAVAS, ENFRIADORAS DE BOTELLAS, SIFONES, DISPENSADORES DE BEBIDAS.	UNIDADES	3	2
254	1	A-001.6, ESPECTACULOS DE PUBLICIDAD Y PROPAGANDA PROMOCIONES.	UNIDADES	6	2
255	1	A-001.7, OTROS MEDIOS NO ESPECIFICADOS.	UNIDADES	7	2
\.


--
-- Data for Name: tipo_multa; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.tipo_multa (id_tipo_multa, descripcion) FROM stdin;
1	Multa por Declaracion Tardia
\.


--
-- Data for Name: usuario_enlazado; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.usuario_enlazado (id_usuario_enlazado, id_contribuyente, email) FROM stdin;
\.


--
-- Data for Name: usuario_inmueble; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.usuario_inmueble (id_usuario_inmueble, id_usuario, id_inmueble) FROM stdin;
\.


--
-- Data for Name: verificacion_email; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.verificacion_email (id_verificacion_email, id_registro_municipal, codigo_recuperacion, fecha_recuperacion, verificado) FROM stdin;
\.


--
-- Data for Name: verificacion_telefono; Type: TABLE DATA; Schema: impuesto; Owner: pooijyzcnnfrso
--

COPY impuesto.verificacion_telefono (id_verificacion_telefono, codigo_verificacion, fecha_verificacion, verificado, id_usuario, telefono) FROM stdin;
82	638501	2020-06-26 23:01:55.167478+00	t	120	4129661659
83	062801	2020-06-26 23:04:24.049606+00	t	121	4129661659
84	310569	2020-06-26 23:14:02.661491+00	t	122	4129661659
85	505131	2020-06-27 16:30:31.169715+00	t	124	4129661659
86	513908	2020-06-30 17:36:19.389316+00	t	127	4121100342
87	955434	2020-06-30 17:49:53.472559+00	t	128	4121100342
88	088925	2020-06-30 18:50:42.605834+00	t	129	4246336236
89	247826	2020-06-30 18:58:29.260825+00	t	130	4121100342
90	900190	2020-06-30 19:13:34.089421+00	t	132	4121100342
91	313699	2020-06-30 19:29:55.67457+00	t	131	4246336236
92	706679	2020-06-30 19:42:34.387211+00	t	135	4121100342
93	734396	2020-06-30 20:10:04.534182+00	t	136	4121100342
94	405656	2020-07-01 11:57:41.956301+00	t	137	4121100342
95	961888	2020-07-01 12:20:56.945935+00	t	138	4121100342
96	934563	2020-07-01 12:35:30.630005+00	t	139	4121100342
97	256802	2020-07-01 13:11:33.516843+00	t	142	4246336236
98	\N	2020-07-01 13:26:28.837352+00	t	143	\N
99	\N	2020-07-01 13:27:18.764155+00	t	145	\N
100	\N	2020-07-01 14:04:09.930643+00	t	149	\N
101	\N	2020-07-01 14:04:22.233935+00	t	150	\N
102	818189	2020-07-01 14:45:45.788979+00	t	151	4246336236
103	217733	2020-07-02 13:33:55.873863+00	t	152	4246336236
104	\N	2020-07-02 15:29:55.973332+00	t	153	\N
105	787341	2020-07-03 14:35:49.656701+00	t	154	4126750593
106	\N	2020-07-03 15:21:19.489328+00	t	146	\N
107	853275	2020-07-09 12:12:02.173311+00	t	155	4147212342
108	050385	2020-07-09 14:04:57.140286+00	t	156	4246336236
110	534170	2020-07-10 15:49:58.606858+00	t	157	4246336236
111	\N	2020-07-12 23:47:58.535926+00	t	161	\N
112	\N	2020-07-13 01:09:31.49455+00	t	163	\N
113	999333	2020-07-13 13:43:25.380049+00	t	164	4246336236
114	956936	2020-07-13 16:40:33.570995+00	t	118	4126826450
115	111086	2020-07-13 18:41:16.594018+00	t	119	4127645681
116	\N	2020-07-13 19:31:42.422201+00	t	172	\N
117	700532	2020-07-14 17:12:31.058349+00	t	173	4246336236
118	308041	2020-07-14 19:47:26.655906+00	t	116	4127645681
119	668477	2020-07-14 20:22:48.854932+00	t	117	4127645681
120	577059	2020-07-14 23:30:57.871815+00	t	165	4246336236
121	\N	2020-07-15 19:52:51.590005+00	t	181	\N
122	\N	2020-07-16 12:32:53.4423+00	t	192	\N
124	\N	2020-07-16 17:54:47.156705+00	t	203	\N
109	590020	2020-07-10 12:03:13.709716+00	t	194	4127645681
125	\N	2020-07-17 14:26:59.593549+00	t	204	\N
126	\N	2020-07-19 22:15:59.001953+00	t	205	\N
127	\N	2020-07-21 03:17:26.779761+00	t	207	\N
128	\N	2020-07-21 17:58:32.167957+00	t	197	\N
129	\N	2020-07-21 18:16:26.390296+00	t	208	\N
\.


--
-- Data for Name: banco; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.banco (id_banco, nombre, validador) FROM stdin;
4	Abn Amro Bank	f
5	Bancamiga Banco Microfinanciero, C.A.	f
6	Banco Activo Banco Comercial, C.A.	f
7	Banco Agricola	f
8	Banco Bicentenario	f
9	Banco Caroni, C.A. Banco Universal	f
10	Banco De Desarrollo Del Microempresario	f
11	Banco De Venezuela S.A.C.A. Banco Universal	f
12	Bancaribe C.A. Banco Universal	f
13	Banco Del Pueblo Soberano C.A.	f
14	Banco Del Tesoro	f
15	Banco Espirito Santo, S.A.	f
16	Banco Exterior C.A.	f
17	Banco Industrial De Venezuela.	f
18	Banco Internacional De Desarrollo, C.A.	f
19	Banco Mercantil C.A.	f
22	Banco Plaza	f
24	Banco Venezolano De Credito S.A.	f
25	Bancrecer S.A. Banco De Desarrollo	f
27	Banfanb	f
28	Bangente	f
29	Banplus Banco Comercial C.A	f
30	Citibank.	f
31	Corp Banca.	f
32	Delsur Banco Universal	f
33	Bfc Banco Fondo Común C.A. Banco Universal	f
35	Mibanco Banco De Desarrollo, C.A.	f
36	Sofitasa	f
34	Instituto Municipal De Crédito Popular	f
23	Banco Provincial BBVA	f
1	Banco Occidental de Descuento	t
2	Banesco Banco Universal	t
3	Banco Nacional de Credito	t
20	100% Banco	f
\.


--
-- Data for Name: campo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.campo (id_campo, nombre, tipo, validacion, col) FROM stdin;
3	Direccion	string	direccion	12
4	Punto de Referencia	string	puntoReferencia	12
5	Sector	string	sector	8
6	Parroquia	string	parroquia	8
7	Metros Cuadrados	number	metrosCuadrados	8
8	Nombre	string	nombre	12
11	Correo Electronico	string	correo	12
12	Contacto	string	contacto	12
13	Horario	string	horario	12
1	Cedula o Rif	number	cedulaORif	10
2	Nombre o Razon Social	string	nombreORazon	14
10	Telefono	number	telefono	12
9	Cedula	number	cedula	12
17	Tipo de Ocupacion	string	tipoOcupacion	6
19	Numero de Proyecto	number	numeroProyecto	6
20	Fecha de Aprobacion	date	fechaAprobacion	6
18	Area de Construccion	number	areaConstruccion	6
15	RIF	string	rif	6
14	Razon Social	string	razonSocial	8
16	Ubicado en	string	ubicadoEn	10
21	Propietario del Terreno	string	nombre	14
22	Nombre de la Obra	string	nombreObra	8
24	Codigo de Permiso de Construcción	string	codigoPermisoConstruccion	7
25	Fecha de Permiso de Construcción	string	fechaPermisoConstruccion	7
26	Aforo	number	aforo	6
27	Informe	string	informe	24
28	Propietarios	array	propietarios	24
29	Nombre del Conjunto Residencial	string	nombreConjunto	12
30	Cantidad de Edificios en el Conjunto	number	cantidadEdificios	6
32	Nombre del Edificio	string	nombreEdificio	6
33	Cantidad de Pisos del Edificio	number	cantidadPisos	6
34	Piso donde se encuentra el apartamento o local	number	pisoApto	6
35	Cantidad de Apartamentos en el Piso	number	cantidadAptosPiso	6
36	Numero del Apartamento	number	numeroApto	6
37	Nomenclatura del Edificio	string	nomenclaturaEdificio	8
38	Parroquia	string	parroquiaEdificio	8
39	Tipo de Inmueble	option	tipoInmueble	6
40	Ubicacion del Edificio	string	ubicacionEdificio	8
42	Circuito	string	circuito	6
44	Plano	string	plano	6
45	Croquis de Ubicación	image	croquis	12
41	Datos del Registro	string	datosRegistro	10
46	Código Catastral	string	codCat	12
43	Area de Construcción	numeric	areaConstruccion	6
47	Area de Terreno	numeric	areaTerreno	6
23	Observaciones	string	observaciones	24
48	Tipo de Inmueble	option	tipoInmuebleSolvencia	6
49	Estimación Simple	object	estimacionSimple	24
50	Numero de Bohío	number	numeroBohio	6
51	Detalles del Bohío	string	detallesBohio	6
78	Dirección del Plantel	string	direccionPlantel	12
52	Fecha del Apartado	date	fechaApartado	6
57	Cedula	string	cedulaRepresentante	8
58	Telefono	string	telefonoRepresentante	8
53	Nombre Legal de la Organización	string	nombreOrganizacion	8
54	Tipo de Sociedad	string	tipoSociedad	8
55	Tipo de Transporte	string	tipoTransporte	8
59	Finalidad de la Solicitud	string	finalidad	6
60	Calle o Avenida de su Frente	string	frente	6
61	Frente	string	linderoFrente	6
62	Fondo	string	linderoFondo	6
63	Derecha	string	linderoDerecha	6
64	Izquierda	string	linderoIzquierda	6
65	Sitio	string	sitio	6
67	Numero de Placa	string	numeroPlaca	8
66	Código de Nomenclatura	string	codigoNomenclatura	24
68	Denominación o Razón Social	string	denominacion	8
69	Actividad Comercial	string	actividadComercial	8
70	Dirección del Inmueble	string	direccionInmueble	8
72	Teléfono	string	telefonoInmueble	8
73	Correo electrónico	string	correoInmueble	8
74	Nombre de la Institución	string	nombreInstitucion	8
75	Representante Legal o Director de la Institución	string	representanteInstitucion	12
76	Turno	option	turno	4
77	Nivel Educativo	string	nivelEducativo	8
71	Parroquía	string	parroquiaInmueble	8
79	Dirección de la Empresa	string	direccionEmpresa	8
80	Parroquia	string	parroquiaEmpresa	8
81	Teléfono	string	telefonoEmpresa	8
82	Correo Electrónico	string	correoEmpresa	8
83	Nombre de la Empresa o Comercio	string	nombreEmpresaComercio	8
86	Distribución	object	distribucion	24
87	Plano de Construcción	image	planoConstruccion	12
85	Area de Construcción (m²)	number	metrosCuadradosConstruccion	8
84	Uso Conforme	string	usoConforme	14
88	Documento de Identidad	string	documentoIdentidad	8
89	Denominación Comercial	string	denominacionComercial	8
90	Siglas	string	siglas	8
91	Tipo de Contribuyente	string	tipoContribuyente	6
56	Nombre del Representante Legal	string	nombreRepresentante	8
92	Actividades Económicas	object	actividadesEconomicas	24
93	Capital Suscrito	number	capitalSuscrito	8
94	Tipo de Sociedad	select	tipoSociedadContrib	8
95	Tipo de Licencia	select0	estadoLicencia	8
\.


--
-- Data for Name: campo_tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.campo_tramite (id_campo, id_tipo_tramite, orden, estado, id_seccion) FROM stdin;
21	10	1	iniciado	4
16	10	2	iniciado	4
17	10	3	iniciado	4
10	10	3	iniciado	4
14	2	1	enproceso	3
15	2	2	enproceso	3
16	2	3	enproceso	3
17	2	4	enproceso	3
18	2	4	enproceso	3
19	2	4	enproceso	3
20	2	4	enproceso	3
21	6	1	iniciado	4
16	6	2	iniciado	4
17	6	3	iniciado	4
10	6	3	iniciado	4
21	7	1	iniciado	4
16	7	2	iniciado	4
17	7	3	iniciado	4
10	7	3	iniciado	4
21	8	1	iniciado	4
16	8	2	iniciado	4
17	8	3	iniciado	4
10	8	3	iniciado	4
22	8	1	enproceso	5
5	8	2	enproceso	5
6	8	2	enproceso	5
22	6	1	enproceso	5
5	6	2	enproceso	5
6	6	2	enproceso	5
22	7	1	enproceso	5
5	7	2	enproceso	5
6	7	2	enproceso	5
21	11	1	iniciado	4
16	11	2	iniciado	4
17	11	3	iniciado	4
10	11	3	iniciado	4
21	12	1	iniciado	4
16	12	2	iniciado	4
17	12	3	iniciado	4
10	12	3	iniciado	4
21	13	1	iniciado	4
16	13	2	iniciado	4
17	13	3	iniciado	4
22	10	1	enproceso	6
5	10	2	enproceso	6
24	10	2	enproceso	6
22	11	1	enproceso	6
5	11	2	enproceso	6
24	11	2	enproceso	6
16	10	2	enproceso	6
16	11	2	enproceso	6
16	1	1	enproceso	7
5	1	3	enproceso	7
6	1	3	enproceso	7
16	13	2	enproceso	7
6	12	2	enproceso	7
2	2	2	iniciado	1
3	2	3	iniciado	1
4	2	4	iniciado	1
5	2	5	iniciado	1
6	2	6	iniciado	1
9	2	9	iniciado	2
11	2	11	iniciado	2
12	2	12	iniciado	2
6	1	6	iniciado	1
8	1	8	iniciado	2
9	1	9	iniciado	2
13	1	13	iniciado	2
4	3	4	iniciado	1
5	3	5	iniciado	1
8	3	8	iniciado	2
11	3	11	iniciado	2
12	3	12	iniciado	2
13	3	13	iniciado	2
10	13	3	iniciado	4
6	10	2	enproceso	6
25	10	2	enproceso	6
6	11	2	enproceso	6
25	11	2	enproceso	6
18	1	3	enproceso	7
26	1	2	enproceso	7
27	3	1	enproceso	8
22	12	1	enproceso	7
22	13	1	enproceso	7
16	12	2	enproceso	7
5	13	2	enproceso	7
1	2	1	iniciado	1
5	12	2	enproceso	7
6	13	2	enproceso	7
8	2	8	iniciado	2
10	2	10	iniciado	2
13	2	13	iniciado	2
2	1	2	iniciado	1
3	1	3	iniciado	1
4	1	4	iniciado	1
5	1	5	iniciado	1
10	1	10	iniciado	2
11	1	11	iniciado	2
12	1	12	iniciado	2
1	3	1	iniciado	1
2	3	2	iniciado	1
3	3	3	iniciado	1
6	3	6	iniciado	1
9	3	9	iniciado	2
10	3	10	iniciado	2
1	1	1	iniciado	1
28	14	1	iniciado	9
28	15	1	iniciado	9
8	14	1	iniciado	1
9	14	2	iniciado	1
10	14	3	iniciado	1
11	14	4	iniciado	1
6	14	6	iniciado	1
8	15	1	iniciado	1
9	15	2	iniciado	1
10	15	3	iniciado	1
11	15	4	iniciado	1
6	15	6	iniciado	1
16	14	1	iniciado	11
38	14	2	iniciado	11
39	14	3	iniciado	11
3	14	7	iniciado	1
29	15	2	iniciado	10
30	15	3	iniciado	10
32	15	5	iniciado	10
33	15	6	iniciado	10
34	15	7	iniciado	10
35	15	8	iniciado	10
23	6	4	enproceso	5
23	7	4	enproceso	5
36	15	9	iniciado	10
37	15	10	iniciado	10
38	15	17	iniciado	10
3	15	7	iniciado	1
40	15	15	iniciado	10
28	14	1	enproceso	9
41	14	1	enproceso	11
42	14	2	enproceso	11
6	14	3	enproceso	11
3	14	4	enproceso	11
43	14	5	enproceso	11
44	14	6	enproceso	11
46	14	1	enproceso	13
45	14	1	enproceso	14
28	15	1	enproceso	9
41	15	1	enproceso	11
42	15	2	enproceso	11
6	15	3	enproceso	11
3	15	4	enproceso	11
43	15	5	enproceso	11
44	15	6	enproceso	11
46	15	1	enproceso	13
45	15	1	enproceso	14
47	14	5	enproceso	11
47	15	5	enproceso	11
23	14	7	enproceso	12
23	15	7	enproceso	12
8	16	1	iniciado	1
9	16	2	iniciado	1
10	16	3	iniciado	1
11	16	4	iniciado	1
6	16	6	iniciado	1
3	16	7	iniciado	1
28	16	1	iniciado	9
16	16	1	iniciado	11
38	16	2	iniciado	11
48	16	3	iniciado	11
28	16	1	enproceso	9
16	16	1	enproceso	11
38	16	2	enproceso	11
49	16	1	enproceso	15
8	18	1	iniciado	1
9	18	2	iniciado	1
10	18	3	iniciado	1
11	18	4	iniciado	1
50	18	3	iniciado	16
8	25	1	iniciado	1
52	18	1	iniciado	16
51	18	4	iniciado	16
51	18	2	enproceso	16
52	18	3	enproceso	16
50	18	1	enproceso	16
8	21	1	iniciado	1
9	21	2	iniciado	1
10	21	3	iniciado	1
11	21	4	iniciado	1
6	21	6	iniciado	1
3	21	7	iniciado	1
53	21	1	iniciado	17
54	21	2	iniciado	17
55	21	3	iniciado	17
56	21	1	iniciado	18
57	21	2	iniciado	18
58	21	3	iniciado	18
8	21	1	enproceso	1
9	21	2	enproceso	1
10	21	3	enproceso	1
11	21	4	enproceso	1
6	21	6	enproceso	1
3	21	7	enproceso	1
53	21	1	enproceso	17
54	21	2	enproceso	17
55	21	3	enproceso	17
56	21	1	enproceso	18
57	21	2	enproceso	18
58	21	3	enproceso	18
8	22	1	iniciado	1
9	22	2	iniciado	1
10	22	3	iniciado	1
11	22	4	iniciado	1
6	22	6	iniciado	1
3	22	7	iniciado	1
28	22	1	enproceso	9
28	22	1	iniciado	9
4	22	2	iniciado	11
16	22	1	iniciado	11
9	25	2	iniciado	1
59	22	3	iniciado	11
60	22	4	iniciado	11
61	22	1	iniciado	19
62	22	2	iniciado	19
63	22	3	iniciado	19
64	22	4	iniciado	19
23	22	5	iniciado	19
66	22	1	enproceso	20
67	22	2	enproceso	20
16	22	1	enproceso	11
38	22	2	enproceso	11
65	22	3	enproceso	11
23	22	4	enproceso	11
45	22	1	enproceso	14
23	8	4	enproceso	5
15	8	3	enproceso	5
15	6	3	enproceso	5
15	7	3	enproceso	5
8	23	1	iniciado	1
9	23	2	iniciado	1
10	23	3	iniciado	1
11	23	4	iniciado	1
6	23	6	iniciado	1
3	23	7	iniciado	1
28	23	1	iniciado	9
8	24	1	iniciado	1
9	24	2	iniciado	1
10	24	3	iniciado	1
11	24	4	iniciado	1
6	24	6	iniciado	1
3	24	7	iniciado	1
28	24	1	iniciado	9
10	25	3	iniciado	1
11	25	4	iniciado	1
6	25	6	iniciado	1
3	25	7	iniciado	1
68	23	1	iniciado	21
69	23	2	iniciado	21
70	23	3	iniciado	21
71	23	4	iniciado	21
72	23	5	iniciado	21
73	23	6	iniciado	21
74	24	1	iniciado	22
75	24	2	iniciado	22
76	24	3	iniciado	22
77	24	4	iniciado	22
72	24	5	iniciado	22
73	24	6	iniciado	22
78	24	7	iniciado	22
71	24	8	iniciado	22
70	25	1	iniciado	11
71	25	2	iniciado	11
39	25	3	iniciado	11
68	25	1	iniciado	21
79	25	2	iniciado	21
80	25	3	iniciado	21
81	25	10	iniciado	21
82	25	11	iniciado	21
83	23	1	enproceso	23
15	23	2	enproceso	23
79	23	3	enproceso	23
80	23	4	enproceso	23
84	23	5	enproceso	23
85	23	6	enproceso	23
86	23	1	enproceso	24
45	23	1	enproceso	25
87	23	2	enproceso	25
83	24	1	enproceso	23
15	24	2	enproceso	23
79	24	3	enproceso	23
80	24	4	enproceso	23
84	24	5	enproceso	23
85	24	6	enproceso	23
86	24	1	enproceso	24
45	24	1	enproceso	25
87	24	2	enproceso	25
83	25	1	enproceso	23
15	25	2	enproceso	23
79	25	3	enproceso	23
80	25	4	enproceso	23
84	25	5	enproceso	23
86	25	1	enproceso	24
45	25	1	enproceso	25
87	25	2	enproceso	25
88	27	1	iniciado	26
14	27	2	iniciado	26
89	27	3	iniciado	26
90	27	4	iniciado	26
6	27	5	iniciado	26
5	27	6	iniciado	26
3	27	7	iniciado	26
4	27	8	iniciado	26
91	27	9	iniciado	26
88	27	1	enproceso	26
14	27	2	enproceso	26
89	27	3	enproceso	26
90	27	4	enproceso	26
6	27	5	enproceso	26
5	27	6	enproceso	26
3	27	7	enproceso	26
4	27	8	enproceso	26
91	27	9	enproceso	26
89	28	1	iniciado	27
56	28	2	iniciado	27
10	28	1	iniciado	1
11	28	2	iniciado	1
89	28	1	enproceso	27
56	28	2	enproceso	27
10	28	1	enproceso	1
11	28	2	enproceso	1
93	28	3	iniciado	27
93	28	3	enproceso	27
94	28	4	iniciado	27
94	28	4	enproceso	27
95	28	1	enproceso	29
92	28	1	enproceso	28
\.


--
-- Data for Name: cargo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.cargo (id_cargo, id_tipo_usuario, id_institucion, descripcion) FROM stdin;
1	2	1	Administrador
2	3	1	Funcionario
3	2	2	Administrador
4	3	2	Funcionario
5	2	3	Administrador
6	3	3	Funcionario
7	2	4	Administrador
8	3	4	Funcionario
9	2	5	Administrador
10	3	5	Funcionario
11	2	6	Administrador
12	3	6	Funcionario
13	2	7	Administrador
14	3	7	Funcionario
15	2	8	Administrador
16	3	8	Funcionario
17	5	3	Director OMPU
18	5	3	Director OMCAT
19	5	3	Director OMTU
20	2	0	Administrador
21	3	0	Funcionario
22	3	9	Cajero
23	3	9	Analista
24	2	9	Administrador
25	3	9	Jefe de Caja
26	5	9	Director Cobranzas
\.


--
-- Data for Name: caso_social; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.caso_social (id_caso, id_tipo_tramite, costo, datos, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla) FROM stdin;
2	0	\N	{"nombreCompleto":"Funcionario SAGAS","cedula":"1231231231","fechaNacimiento":"2020-04-02T00:33:42.930Z","edad":"1","nacionalidad":"asdasd","sexo":"true","poblacionIndigena":true,"etnia":"wayuu","profesion":"asdasd","oficio":"asdasd","estadoCivil":"casado","nivelInstruccion":"analfabeto","discapacidad":false,"condicionLaboral":"publico","empleadoAlcaldia":false,"asignacionesEconomicas":"ivss","razonDeSolicitud":"asd","patologiaActual":"asd","areaDeSalud":"traumatologia","direccion":"asdasdasd","parroquia":"CACIQUE MARA","telefono":"1231231231","email":"gab_tata_tc@hotmail.com","tipoAyuda":"electrodomesticos","tipoAyudaDesc":"asdasd","referidoPor":"despacho","isMenor":false,"nacionalidadSolicitante":"V","nacionalidadMenor":"V","nacionalidadBeneficiario":"V","solicitante":{"nombreCompleto":"asdasd","cedula":"1241214215","direccion":"asdasda"},"liderDeCalle":{"nombreCompleto":"asd","telefono":"21412412414"}}	2020-04-03 00:34:14.992725+00	ABMM-09042020-0-0001	1	66	\N
\.


--
-- Data for Name: certificado; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.certificado (id_certificado, id_tramite, url_certificado) FROM stdin;
\.


--
-- Data for Name: cuenta_funcionario; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.cuenta_funcionario (id_usuario, id_cargo) FROM stdin;
57	\N
56	1
59	3
66	20
67	5
68	6
70	17
71	21
72	7
73	8
75	10
76	9
77	13
78	14
79	11
80	12
81	15
82	16
65	4
83	24
116	22
117	23
168	25
209	26
\.


--
-- Data for Name: datos_facebook; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.datos_facebook (id_usuario, id_facebook) FROM stdin;
\.


--
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
118	108908642016425978799
119	107580273557060296119
120	108579339148659696569
121	116640733044552872609
122	107391274271360553386
133	118013466256112182845
\.


--
-- Data for Name: detalle_factura; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.detalle_factura (id_detalle, id_factura, nombre, costo) FROM stdin;
\.


--
-- Data for Name: evento_caso_social; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.evento_caso_social (id_evento_caso, id_caso, event, "time") FROM stdin;
2	2	iniciar	2020-04-03 00:34:14.992725+00
\.


--
-- Data for Name: evento_multa; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.evento_multa (id_evento_multa, id_multa, event, "time") FROM stdin;
\.


--
-- Data for Name: evento_tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.evento_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
668	298	iniciar	2020-06-26 22:49:43.696424+00
669	298	procesar_rc	2020-06-26 22:49:43.696424+00
670	298	aprobar_rc	2020-06-26 23:51:45.215522+00
672	300	iniciar	2020-06-30 17:50:29.797212+00
673	300	validar_pa	2020-06-30 17:50:29.797212+00
674	301	iniciar	2020-06-30 18:21:38.604251+00
675	301	validar_pa	2020-06-30 18:21:38.604251+00
676	302	iniciar	2020-06-30 18:22:40.387563+00
677	302	enproceso_pd	2020-06-30 18:22:40.387563+00
678	303	iniciar	2020-06-30 18:23:44.183727+00
679	303	validar_pa	2020-06-30 18:23:44.183727+00
680	304	iniciar	2020-06-30 18:24:55.057176+00
681	304	validar_pa	2020-06-30 18:24:55.057176+00
682	305	iniciar	2020-06-30 18:25:26.785389+00
683	305	enproceso_pd	2020-06-30 18:25:26.785389+00
684	306	iniciar	2020-06-30 18:27:13.595827+00
685	306	validar_cr	2020-06-30 18:27:13.595827+00
686	307	iniciar	2020-06-30 18:29:35.964286+00
687	307	enproceso_pd	2020-06-30 18:29:35.964286+00
688	308	iniciar	2020-06-30 18:30:23.317754+00
689	308	enproceso_pd	2020-06-30 18:30:23.317754+00
690	309	iniciar	2020-06-30 18:32:25.471914+00
691	309	enproceso_pd	2020-06-30 18:32:25.471914+00
692	310	iniciar	2020-06-30 18:33:22.766851+00
693	310	enproceso_pd	2020-06-30 18:33:22.766851+00
694	311	iniciar	2020-06-30 18:36:51.647562+00
695	311	validar_cr	2020-06-30 18:36:51.647562+00
696	312	iniciar	2020-06-30 18:38:44.270165+00
697	312	validar_cr	2020-06-30 18:38:44.270165+00
698	313	iniciar	2020-06-30 18:40:41.149505+00
699	313	validar_cr	2020-06-30 18:40:41.149505+00
700	314	iniciar	2020-06-30 18:42:30.344355+00
701	314	enproceso_ompu	2020-06-30 18:42:30.344355+00
702	315	iniciar	2020-06-30 18:44:24.903989+00
703	315	enproceso_ompu	2020-06-30 18:44:24.903989+00
704	316	iniciar	2020-06-30 18:45:46.644432+00
705	316	enproceso_ompu	2020-06-30 18:45:46.644432+00
706	317	iniciar	2020-06-30 18:46:46.8143+00
707	317	validar_pa	2020-06-30 18:46:46.8143+00
708	318	iniciar	2020-06-30 18:48:03.746067+00
709	318	enproceso_pd	2020-06-30 18:48:03.746067+00
710	319	iniciar	2020-06-30 18:57:02.83084+00
711	319	validar_lae	2020-06-30 18:57:02.83084+00
712	320	iniciar	2020-07-01 13:17:17.671537+00
713	320	procesar_rc	2020-07-01 13:17:17.671537+00
714	321	iniciar	2020-07-01 13:24:36.899794+00
715	321	procesar_rc	2020-07-01 13:24:36.899794+00
716	320	aprobar_rc	2020-07-01 13:26:28.837352+00
718	321	aprobar_rc	2020-07-01 13:27:18.764155+00
719	322	iniciar	2020-07-01 13:32:13.02945+00
720	322	procesar_rc	2020-07-01 13:32:13.02945+00
721	323	iniciar	2020-07-01 13:44:35.240099+00
722	323	procesar_rc	2020-07-01 13:44:35.240099+00
723	324	iniciar	2020-07-01 13:47:40.4185+00
724	324	procesar_rc	2020-07-01 13:47:40.4185+00
725	323	aprobar_rc	2020-07-01 14:04:09.930643+00
726	324	aprobar_rc	2020-07-01 14:04:22.233935+00
727	325	iniciar	2020-07-01 14:09:05.754533+00
728	325	validar_lae	2020-07-01 14:09:05.754533+00
729	326	iniciar	2020-07-01 14:13:32.706273+00
730	326	validar_lae	2020-07-01 14:13:32.706273+00
731	326	enproceso_lae	2020-07-01 14:28:11.778756+00
732	325	enproceso_lae	2020-07-01 14:28:11.778756+00
733	326	aprobar_lae	2020-07-01 15:26:52.828017+00
734	325	aprobar_lae	2020-07-01 15:42:57.618399+00
735	327	iniciar	2020-07-02 15:13:50.325816+00
736	327	procesar_rc	2020-07-02 15:13:50.325816+00
737	327	aprobar_rc	2020-07-02 15:29:55.973332+00
738	328	iniciar	2020-07-02 15:43:52.483359+00
739	328	validar_lae	2020-07-02 15:43:52.483359+00
740	328	enproceso_lae	2020-07-02 15:52:56.023119+00
741	328	aprobar_lae	2020-07-02 15:55:41.42259+00
742	322	aprobar_rc	2020-07-03 15:21:19.489328+00
743	329	iniciar	2020-07-03 15:34:49.578088+00
744	329	validar_lae	2020-07-03 15:34:49.578088+00
745	330	iniciar	2020-07-09 12:13:24.897936+00
746	330	revisar_bc	2020-07-09 12:13:24.897936+00
747	330	aprobar_bc	2020-07-09 12:27:59.653175+00
748	331	iniciar	2020-07-10 15:03:38.148479+00
749	331	procesar_rc	2020-07-10 15:03:38.148479+00
750	332	iniciar	2020-07-10 16:49:30.462689+00
751	332	revisar_bc	2020-07-10 16:49:30.462689+00
752	333	iniciar	2020-07-10 17:39:53.585245+00
753	333	revisar_bc	2020-07-10 17:39:53.585245+00
754	333	aprobar_bc	2020-07-10 17:40:22.836976+00
755	332	aprobar_bc	2020-07-10 19:44:47.523322+00
756	334	iniciar	2020-07-13 01:02:23.945848+00
757	334	procesar_rc	2020-07-13 01:02:23.945848+00
758	334	aprobar_rc	2020-07-13 01:09:31.49455+00
759	335	iniciar	2020-07-13 16:43:56.744309+00
760	335	revisar_bc	2020-07-13 16:43:56.744309+00
761	335	aprobar_bc	2020-07-13 16:44:08.749839+00
762	336	iniciar	2020-07-13 19:30:55.647732+00
763	336	procesar_rc	2020-07-13 19:30:55.647732+00
764	336	aprobar_rc	2020-07-13 19:31:42.422201+00
765	337	iniciar	2020-07-13 19:39:23.854275+00
766	337	revisar_bc	2020-07-13 19:39:23.854275+00
767	337	aprobar_bc	2020-07-13 19:40:08.930921+00
768	338	iniciar	2020-07-14 13:05:23.977838+00
769	338	revisar_bc	2020-07-14 13:05:23.977838+00
770	338	aprobar_bc	2020-07-14 13:05:41.991268+00
771	339	iniciar	2020-07-14 13:11:52.552643+00
772	339	revisar_bc	2020-07-14 13:11:52.552643+00
773	339	aprobar_bc	2020-07-14 13:36:04.589736+00
774	340	iniciar	2020-07-14 15:21:39.288954+00
775	340	validar_lae	2020-07-14 15:21:39.288954+00
776	340	enproceso_lae	2020-07-14 15:24:11.709181+00
777	340	revisar_lae	2020-07-14 15:24:51.133505+00
778	341	iniciar	2020-07-14 15:28:46.972941+00
779	341	validar_lae	2020-07-14 15:28:46.972941+00
780	341	enproceso_lae	2020-07-14 16:57:11.481725+00
781	341	revisar_lae	2020-07-14 16:59:49.29761+00
782	342	iniciar	2020-07-14 19:55:12.542001+00
783	342	revisar_bc	2020-07-14 19:55:12.542001+00
784	343	iniciar	2020-07-14 23:45:18.998482+00
785	343	revisar_bc	2020-07-14 23:45:18.998482+00
786	344	iniciar	2020-07-15 12:37:13.350097+00
787	344	revisar_bc	2020-07-15 12:37:13.350097+00
788	344	aprobar_bc	2020-07-15 13:41:54.298424+00
789	345	iniciar	2020-07-15 16:42:20.754409+00
790	345	revisar_bc	2020-07-15 16:42:20.754409+00
791	345	aprobar_bc	2020-07-15 16:42:59.372042+00
792	346	iniciar	2020-07-15 16:55:29.27274+00
793	346	revisar_bc	2020-07-15 16:55:29.27274+00
794	346	aprobar_bc	2020-07-15 16:56:12.835542+00
795	343	aprobar_bc	2020-07-15 16:57:09.206336+00
796	347	iniciar	2020-07-15 19:05:54.379185+00
797	347	validar_lae	2020-07-15 19:05:54.379185+00
798	347	enproceso_lae	2020-07-15 19:05:54.379185+00
800	349	iniciar	2020-07-15 19:37:41.710633+00
801	349	validar_lae	2020-07-15 19:37:41.710633+00
802	349	enproceso_lae	2020-07-15 19:37:41.710633+00
803	349	revisar_lae	2020-07-15 19:37:43.242016+00
804	350	iniciar	2020-07-15 19:43:36.436209+00
805	350	procesar_rc	2020-07-15 19:43:36.436209+00
806	351	iniciar	2020-07-15 19:47:44.589342+00
807	351	validar_lae	2020-07-15 19:47:44.589342+00
808	351	enproceso_lae	2020-07-15 19:47:44.589342+00
809	351	revisar_lae	2020-07-15 19:47:45.582491+00
810	350	aprobar_rc	2020-07-15 19:52:51.590005+00
811	352	iniciar	2020-07-15 20:05:25.42043+00
812	352	validar_lae	2020-07-15 20:05:25.42043+00
813	352	enproceso_lae	2020-07-15 20:07:39.39593+00
814	352	revisar_lae	2020-07-15 20:11:45.388665+00
815	353	iniciar	2020-07-15 20:36:53.81152+00
816	353	validar_lae	2020-07-15 20:36:53.81152+00
817	351	rechazar_lae	2020-07-15 20:41:48.168302+00
818	352	aprobar_lae	2020-07-15 20:42:13.077565+00
831	358	iniciar	2020-07-16 13:22:35.157748+00
832	358	validar_lae	2020-07-16 13:22:35.157748+00
833	358	enproceso_lae	2020-07-16 13:22:35.157748+00
834	358	revisar_lae	2020-07-16 13:22:35.157748+00
840	364	iniciar	2020-07-16 13:24:35.920108+00
841	364	validar_lae	2020-07-16 13:24:35.920108+00
842	364	enproceso_lae	2020-07-16 13:24:35.920108+00
843	364	revisar_lae	2020-07-16 13:24:35.920108+00
844	365	iniciar	2020-07-16 13:24:51.069615+00
845	365	validar_lae	2020-07-16 13:24:51.069615+00
846	365	enproceso_lae	2020-07-16 13:24:51.069615+00
847	365	revisar_lae	2020-07-16 13:24:51.069615+00
848	366	iniciar	2020-07-16 13:25:10.145422+00
849	366	validar_lae	2020-07-16 13:25:10.145422+00
850	366	enproceso_lae	2020-07-16 13:25:10.145422+00
851	366	revisar_lae	2020-07-16 13:25:10.145422+00
853	368	iniciar	2020-07-16 13:25:40.404514+00
854	368	validar_lae	2020-07-16 13:25:40.404514+00
855	368	enproceso_lae	2020-07-16 13:25:40.404514+00
856	368	revisar_lae	2020-07-16 13:25:40.404514+00
858	370	iniciar	2020-07-16 13:31:37.731847+00
859	370	validar_lae	2020-07-16 13:31:37.731847+00
860	370	enproceso_lae	2020-07-16 13:31:37.731847+00
861	370	revisar_lae	2020-07-16 13:31:37.731847+00
862	371	iniciar	2020-07-16 13:38:37.382146+00
863	371	validar_lae	2020-07-16 13:38:37.382146+00
864	371	enproceso_lae	2020-07-16 13:38:37.382146+00
865	371	revisar_lae	2020-07-16 13:38:37.382146+00
866	371	aprobar_lae	2020-07-16 13:44:01.801809+00
867	372	iniciar	2020-07-16 13:47:31.675709+00
868	372	validar_lae	2020-07-16 13:47:31.675709+00
869	372	enproceso_lae	2020-07-16 13:52:44.979626+00
870	373	iniciar	2020-07-16 14:09:28.210906+00
871	373	validar_lae	2020-07-16 14:09:28.210906+00
872	373	enproceso_lae	2020-07-16 14:09:28.210906+00
873	373	revisar_lae	2020-07-16 14:09:28.210906+00
874	372	revisar_lae	2020-07-16 14:17:58.212613+00
875	372	aprobar_lae	2020-07-16 14:20:45.577978+00
876	374	iniciar	2020-07-16 14:23:35.766739+00
877	374	validar_lae	2020-07-16 14:23:35.766739+00
878	374	enproceso_lae	2020-07-16 14:23:35.766739+00
879	374	revisar_lae	2020-07-16 14:23:35.766739+00
880	374	aprobar_lae	2020-07-16 14:29:01.363637+00
881	375	iniciar	2020-07-16 14:34:43.918672+00
882	375	validar_lae	2020-07-16 14:34:43.918672+00
883	375	enproceso_lae	2020-07-16 14:35:39.808672+00
884	375	rechazar_lae	2020-07-16 14:37:40.914077+00
885	376	iniciar	2020-07-19 22:19:16.91203+00
886	376	validar_lae	2020-07-19 22:19:16.91203+00
887	376	enproceso_lae	2020-07-19 22:19:16.91203+00
888	376	revisar_lae	2020-07-19 22:19:16.91203+00
889	376	aprobar_lae	2020-07-19 22:20:56.922172+00
890	377	iniciar	2020-07-21 12:29:41.381254+00
891	377	validar_lae	2020-07-21 12:29:41.381254+00
892	377	enproceso_lae	2020-07-21 12:29:41.381254+00
893	377	revisar_lae	2020-07-21 12:29:41.381254+00
894	377	aprobar_lae	2020-07-21 12:59:28.626332+00
895	378	iniciar	2020-07-21 14:10:11.544049+00
896	378	validar_lae	2020-07-21 14:10:11.544049+00
897	378	enproceso_lae	2020-07-21 14:10:11.544049+00
898	378	revisar_lae	2020-07-21 14:10:11.544049+00
899	379	iniciar	2020-07-21 14:31:05.501346+00
900	379	validar_lae	2020-07-21 14:31:05.501346+00
901	379	enproceso_lae	2020-07-21 14:31:05.501346+00
902	379	revisar_lae	2020-07-21 14:31:05.501346+00
903	380	iniciar	2020-07-21 17:50:27.086854+00
904	380	validar_lae	2020-07-21 17:50:27.086854+00
905	380	enproceso_lae	2020-07-21 17:50:27.086854+00
906	380	revisar_lae	2020-07-21 17:50:27.086854+00
907	379	aprobar_lae	2020-07-21 17:59:41.457994+00
908	380	aprobar_lae	2020-07-21 18:00:34.301877+00
909	381	iniciar	2020-07-21 19:06:17.864771+00
910	381	validar_lae	2020-07-21 19:06:17.864771+00
911	381	enproceso_lae	2020-07-21 19:06:17.864771+00
912	381	revisar_lae	2020-07-21 19:06:17.864771+00
913	381	aprobar_lae	2020-07-21 19:07:42.548864+00
914	382	iniciar	2020-07-23 03:30:13.166609+00
915	382	validar_lae	2020-07-23 03:30:13.166609+00
916	382	enproceso_lae	2020-07-23 03:30:13.166609+00
917	382	revisar_lae	2020-07-23 03:30:13.166609+00
918	382	aprobar_lae	2020-07-23 03:34:54.624143+00
\.


--
-- Data for Name: factura_tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.factura_tramite (id_factura, id_tramite) FROM stdin;
\.


--
-- Data for Name: inmueble_urbano; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, fecha_ultimo_avaluo, tipo_inmueble, id_registro_municipal, posee_gas) FROM stdin;
21	231315U01004083001001P0500	Calle 73 entre Av. 3E y 3F	108	200	300	2020-03-20 20:46:01.230084+00	2020-03-20 20:46:01.230084+00	\N	\N	\N	t
433	\N		\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	COMERCIAL	76	t
434	\N		\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	COMERCIAL	77	t
435	\N		\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	COMERCIAL	78	t
436	\N	Parroquia MANUEL DAGNINO Sector   Avenida   Calle  , Local Nro.  , Pto de Ref.	\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	COMERCIAL	79	t
437	\N	Parroquia CHIQUINQUIRA Sector 5 DE JULIO BFERCON Avenida   Calle  , Local Nro.  , Pto de Ref.	\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	RESIDENCIAL	80	t
438	\N	Parroquia CHIQUINQUIRA Sector 5 DE JULIO Avenida 16 Calle 77, Local Nro. bfercom, Pto de Ref. al lado de la torre bod	\N	\N	\N	2020-07-09 12:12:02.010347+00	2020-07-09 12:12:02.010347+00	\N	COMERCIAL	80	t
439	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   SANTA RITA CALLE 71  E.HOS 8-02 E.HOS POLICLIN.MCBO 8-02   Avenida 0 Calle 71, Local Nro. 8-02, Pto de Ref.  FTE. FARMACIA 2000 FTE EDF MAYA NIQUITAO MBO MARACAIBO ZUL	\N	\N	\N	2020-07-09 14:04:57.003454+00	2020-07-09 14:04:57.003454+00	\N	RESIDENCIAL	81	t
440	\N	Parroquia OLEGARIO VILLALOBOS Sector SANTA RITA  Avenida 8 Calle 71, Local Nro. 1, Pto de Ref. SANTA RITA	\N	\N	\N	2020-07-09 14:04:57.003454+00	2020-07-09 14:04:57.003454+00	\N	COMERCIAL	81	t
441	\N	Parroquia CHIQUINQUIRA Sector  INDIO MARA Avenida  65 Calle  22A, Local Nro.  MZN, Pto de Ref.   EDIF. IPSFA	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	COMERCIAL	82	t
442	\N	Parroquia CHIQUINQUIRA Sector - Avenida - Calle -, Local Nro. -, Pto de Ref. -	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	COMERCIAL	84	t
443	\N		\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	COMERCIAL	85	t
444	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   BELLA VISTA(OLEGARIO V) AVENIDA 4 BELLA VISTA 1684520 LOCAL 67-13 LOCAL EDF. BLITZ 67-13   FTE. CHURRASCO BAR-GRILL MBO Maracaibo ZUL Avenida 4 Calle 0, Apartamento Nro. 67-13, Pto de Ref. 0	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	RESIDENCIAL	83	t
445	\N	Parroquia CHIQUINQUIRA Sector INDIO MARA Avenida 22A Calle 65, Local Nro. MZN., Pto de Ref. EDIF. IPSFA	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	COMERCIAL	83	t
446	\N	Parroquia CHIQUINQUIRA Sector SCT   PARAISO AVENIDA 22 1674040   PB PB LDO. CUARTEL LIBERTADOR MBO Maracaibo ZUL Avenida 22A Calle 65, Local Nro. P A, Pto de Ref. IPFA	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	RESIDENCIAL	86	t
447	\N	Parroquia OLEGARIO VILLALOBOS Sector INDIO MARA Avenida 22A Calle 65, Local Nro. 3, Pto de Ref. IPFA	\N	\N	\N	2020-07-10 12:03:13.465943+00	2020-07-10 12:03:13.465943+00	\N	COMERCIAL	86	t
448	\N	Parroquia OLEGARIO VILLALOBOS Sector URB EL DORAL NORTE  Avenida   Calle 45, Local Nro. 14B-25 , Pto de Ref.	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	87	t
449	\N	Parroquia COQUIVACOA Sector PARCELAMIENTO LA VILLA  Avenida 14B Calle 45, Local Nro. 789, Pto de Ref. frente a ferretotal	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	87	t
450	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   BELLA VISTA(OLEGARIO V) CALLE 72 2973100  3Y-74    Avenida 0 Calle 72, Local Nro. 3Y-74, Pto de Ref.  FDO. EDF. VESUBIO. MBO Maracaibo ZUL	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	88	t
451	\N	Parroquia OLEGARIO VILLALOBOS Sector BELLA VISTA  Avenida - Calle 72, Local Nro. 3, Pto de Ref. frente a banco provincial	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	88	t
452	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   BELLA VISTA(OLEGARIO V) AVENIDA 4 BELLA VISTA 3765010  59-178   FARMATODO MBO Maracaibo ZUL Avenida 4 Calle  , Local Nro. 59-178, Pto de Ref. bella vista	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	89	t
453	\N	Parroquia OLEGARIO VILLALOBOS Sector BELLA VISTA Avenida 4 Calle 66, Local Nro. -59-178, Pto de Ref. torre europa frente a enne	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	89	t
454	\N	Parroquia IDELFONSO VASQUEZ Sector VIA EL MOJAN CC SAMBIL NIVEL FERIA  Avenida - Calle -, Local Nro. f-59-60, Pto de Ref. cc comercial sambil	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	90	t
455	\N	Parroquia RAUL LEONI Sector SCT   LA MACANDONA CALLE 79 0000657000 CASA 48-66 48-66   CERCA ATLAS COCINA IMPORTADA MBO Maracaibo ZUL Avenida   Calle 79, Casa Nro. 48-66, Pto de Ref. sector la macandona	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	91	t
456	\N	Parroquia RAUL LEONI Sector LA LIMPIA  Avenida 76 Calle 79, Local Nro. 79b, Pto de Ref. al lado de traki la limpia	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	91	t
457	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   PARAISO AVENIDA 20 2106222     ESQUINA CALLE 66 CON AVENIDA 20 MBO Maracaibo ZUL Avenida 20 Calle 66, Local Nro. -, Pto de Ref. -	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	92	t
458	\N	Parroquia CHIQUINQUIRA Sector INDIO MARA Avenida 20 Calle -66, Local Nro. -indiomara, Pto de Ref. diagonal al hospital universitario	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	92	t
459	\N	Parroquia LUIS HURTADO HIGUERA Sector SCT   ZONA INDUSTRIAL AVENIDA 58 CIRC. 2 0003273000 LOCAL 3273000 LOCAL INMOBILIARIA    INMOBILIARIA IROKA. LADO DE CASA PARIS. MBO Maracaibo ZUL Avenida 58 Calle -, Local Nro. INMOBILIARIA, Pto de Ref. -	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	RESIDENCIAL	93	t
460	\N	Parroquia LUIS HURTADO HIGUERA Sector AV CIRCUNVALACION 2 Avenida 60 Calle -, Local Nro. -, Pto de Ref. entrando a la zona industrial	\N	\N	\N	2020-07-10 15:49:57.76097+00	2020-07-10 15:49:57.76097+00	\N	COMERCIAL	93	t
461	\N	Parroquia CHIQUINQUIRA Sector NUEVA VIA  Avenida 16 Y 16B Calle 93, Local Nro. 16-32, Pto de Ref. FDO CEMENTERIO CUADRADO	\N	\N	\N	2020-07-13 13:29:53.967998+00	2020-07-13 13:29:53.967998+00	\N	RESIDENCIAL	94	t
462	\N	Parroquia CHIQUINQUIRA Sector NUEVA VIA Avenida 16 Y 16B Calle 93, Local Nro. 16-32, Pto de Ref. FDO CEMENTERIO CUADRADO	\N	\N	\N	2020-07-13 13:29:53.967998+00	2020-07-13 13:29:53.967998+00	\N	COMERCIAL	94	t
463	\N	Parroquia OLEGARIO VILLALOBOS Sector BELLA VISTA Avenida 4 Calle 67, Local Nro. 71, Pto de Ref. -	\N	\N	\N	2020-07-13 13:32:04.212903+00	2020-07-13 13:32:04.212903+00	\N	RESIDENCIAL	95	t
464	\N	Parroquia OLEGARIO VILLALOBOS Sector BELLA VISTA Avenida 4 Calle 67, Local Nro.  71, Pto de Ref. SUCURSAL	\N	\N	\N	2020-07-13 13:32:04.212903+00	2020-07-13 13:32:04.212903+00	\N	COMERCIAL	95	t
465	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida 15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-07-13 13:39:59.276087+00	2020-07-13 13:39:59.276087+00	\N	RESIDENCIAL	97	t
466	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS  Avenida 14A Y 15 DELICIAS Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO CON DELICIAS	\N	\N	\N	2020-07-13 13:39:59.276087+00	2020-07-13 13:39:59.276087+00	\N	COMERCIAL	97	t
467	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida 15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-07-13 13:39:59.276087+00	2020-07-13 13:39:59.276087+00	\N	RESIDENCIAL	96	t
468	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida  15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-07-13 13:39:59.276087+00	2020-07-13 13:39:59.276087+00	\N	COMERCIAL	96	t
469	\N	Parroquia OLEGARIO VILLALOBOS Sector 0 Avenida 0 Calle 0, Casa Nro. 0, Pto de Ref. 0	\N	\N	\N	2020-07-13 13:43:25.240907+00	2020-07-13 13:43:25.240907+00	\N	COMERCIAL	98	t
470	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT TIERRA NEGRA  Avenida - Calle 72, Local Nro. 9-53, Pto de Ref. FDO. ESP. MEDICAS CLARET MBO Maracaibo ZUL	\N	\N	\N	2020-07-13 13:43:25.240907+00	2020-07-13 13:43:25.240907+00	\N	RESIDENCIAL	99	t
471	\N	Parroquia OLEGARIO VILLALOBOS Sector TIERRA NEGRA Avenida 9 Y 9B Calle 72, Local Nro.  9-53, Pto de Ref. FRENTE A CHOPS	\N	\N	\N	2020-07-13 13:43:25.240907+00	2020-07-13 13:43:25.240907+00	\N	COMERCIAL	99	t
472	\N	Parroquia COQUIVACOA Sector SCT   MONTE CLARO CALLE IJ 0000219000 CASA 3-75 3-75   CERCA DE DISTRIBUIDORA JK MBO Maracaibo ZUL Avenida 2 Calle IJ, Local Nro. 3-75, Pto de Ref. PANADERIA	\N	\N	\N	2020-07-14 17:12:30.798115+00	2020-07-14 17:12:30.798115+00	\N	RESIDENCIAL	100	t
473	\N	Parroquia COQUIVACOA Sector 18 DE OCTUBRE Avenida 2 Calle IJ, Casa Nro. 3--75, Pto de Ref. plaza de 18 de octubre	\N	\N	\N	2020-07-14 17:12:30.798115+00	2020-07-14 17:12:30.798115+00	\N	COMERCIAL	100	t
474	\N	Parroquia RAUL LEONI Sector LA LIMPIA Avenida   Calle 79, Local Nro. 46-96, Pto de Ref.	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	RESIDENCIAL	101	t
475	\N	Parroquia RAUL LEONI Sector   Avenida   Calle  , Casa Nro.  , Pto de Ref.	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	COMERCIAL	101	t
476	\N	Parroquia COQUIVACOA Sector URB   EL ROSAL   Avenida 15 FUERZAS ARMADA Calle  , Local Nro. -, Pto de Ref. COND. FERRETOTAL    LADO CC DORAL MALL MBO Maracaibo ZUL	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	RESIDENCIAL	102	t
477	\N	Parroquia COQUIVACOA Sector URB EL ROSAL Avenida FUERZAS ARMADA Calle  , Local Nro.  , Pto de Ref. COND. FERRETOTAL LADO CC DORAL MALL MBO Maracaibo ZUL	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	COMERCIAL	102	t
478	\N	Parroquia OLEGARIO VILLALOBOS Sector EL MILAGRO Avenida 2 Calle 57, Local Nro. 12-46, Pto de Ref.	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	RESIDENCIAL	103	t
479	\N	Parroquia OLEGARIO VILLALOBOS Sector - Avenida - Calle -, Local Nro. -, Pto de Ref. -	\N	\N	\N	2020-07-14 23:30:57.546707+00	2020-07-14 23:30:57.546707+00	\N	COMERCIAL	103	t
480	aabbcc22	Por ahi	61	200	300	2020-07-15 14:34:28.01241+00	2020-07-15 14:34:28.01241+00	\N	COMERCIAL	103	t
481	q3231223aa11	aqui	63	332	336	2020-07-16 12:54:41.945182+00	2020-07-16 12:54:41.945182+00	\N	COMERCIAL	\N	t
483	1234555	13124aqwe	61	1322	1333	2020-07-16 14:37:42.41242+00	2020-07-16 14:37:42.41242+00	\N	RESIDENCIAL	\N	t
484	98766728	aqui por mi casa	63	2822	3000	2020-07-16 14:39:06.567742+00	2020-07-16 14:39:06.567742+00	\N	COMERCIAL	\N	t
485	12312312	13123	61	1112312	12312312311	2020-07-16 14:40:51.554595+00	2020-07-16 14:40:51.554595+00	\N	RESIDENCIAL	\N	t
487	123123123	1231231	62	1234	1235	2020-07-16 14:56:25.332047+00	2020-07-16 14:56:25.332047+00	\N	RESIDENCIAL	\N	t
488	4443553	1231123	62	1112	1122	2020-07-16 15:05:50.932307+00	2020-07-16 15:05:50.932307+00	\N	COMERCIAL	\N	t
489	667567	123123	62	13123	123144	2020-07-16 15:07:29.106717+00	2020-07-16 15:07:29.106717+00	\N	RESIDENCIAL	\N	t
490	guu	aesc	61	8	7	2020-07-16 17:44:20.60331+00	2020-07-16 17:44:20.60331+00	\N	RESIDENCIAL	\N	t
482	98i7790-8	asdqwew	61	312	322	2020-07-16 14:33:52.574634+00	2020-07-16 14:33:52.574634+00	\N	RESIDENCIAL	102	f
486	231312U01457854R7999	asdasdasdas;dkh jkahsdkjhas kjhasjkd hajkshd jh	62	1234123	1234123412	2020-07-16 14:53:16.065173+00	2020-07-16 14:53:16.065173+00	\N	COMERCIAL	102	t
491	ZMCM05478995	Av 21 calle 86	63	245	240	2020-07-19 22:02:35.219527+00	2020-07-19 22:02:35.219527+00	\N	COMERCIAL	102	t
492	1234	mcbo	61	15	15	2020-07-20 12:19:24.274789+00	2020-07-20 12:19:24.274789+00	\N	RESIDENCIAL	102	t
494	123456	mcbo	66	300	300	2020-07-21 17:23:53.729422+00	2020-07-21 17:23:53.729422+00	\N	RESIDENCIAL	96	t
493	12345	mcbo	61	15	15	2020-07-21 13:02:00.74786+00	2020-07-21 13:02:00.74786+00	\N	RESIDENCIAL	110	t
495	1234567	mcbo	69	30	30	2020-07-21 18:04:02.91275+00	2020-07-21 18:04:02.91275+00	\N	RESIDENCIAL	114	t
\.


--
-- Data for Name: institucion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.institucion (id_institucion, nombre_completo, nombre_corto) FROM stdin;
1	Bomberos de Maracaibo	CBM
2	Servicio Autonomo para el Suministro de Gas	SAGAS
0	Alcaldia del Municipio de Maracaibo	ABMM
3	Centro de Procesamiento Urbano	CPU
4	Terminal de Pasajeros de Maracaibo	SEDETEMA
5	Servicio Desconcentrado de Plazas y Parques	SEDEPAR
6	Instituto Municipal de Ambiente	IMA
7	Instituto Autónomo Policía del Municipio Maracaibo	PMM
8	Instituto Municipal de Transporte Colectivo y Urbano de Pasajeros del Municipio Maracaibo	IMTCUMA
9	Servicio Desconcentrado Municipal de Administración Tributaria	SEDEMAT
\.


--
-- Data for Name: institucion_banco; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.institucion_banco (id_institucion, id_banco, numero_cuenta, nombre_titular, documento_de_identificacion, id_institucion_banco) FROM stdin;
2	1	0116–0126–03–0018874177	SAGAS	rif:G-20005358-5	0
3	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0	0
3	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0	0
1	1	0116–0140–51–0014405090	CUERPO DE BOMBEROS DEL MUNICIPIO MARACAIBO	rif:G-20003346-0	0
4	1	0116–0101–46–0030138515	SEDETEMA	rif:G-20012866-6	0
5	1	0116–01–4054–0008937036	SEDEPAR	rif:G-20006426-9	0
7	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0	0
7	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0	0
8	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0	0
8	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0	0
6	1	0116–0126–0600–22777792	INSTITUTO MUNICIPAL DE AMBIENTE	rif:G-20000537-8	0
9	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0	0
9	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0	0
3	3	0191–0030–84–2130059755	SEDEMAT	rif:G-20002908-0	0
7	3	0191–0030–84–2130059755	SEDEMAT	rif:G-20002908-0	0
8	3	0191–0030–84–2130059755	SEDEMAT	rif:G-20002908-0	0
9	3	0191–0030–84–2130059755	SEDEMAT	rif:G-20002908-0	0
\.


--
-- Data for Name: multa; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.multa (id_multa, id_tipo_tramite, datos, costo, fecha_creacion, codigo_multa, consecutivo, id_usuario, cedula, nacionalidad, url_certificado, aprobado, url_boleta) FROM stdin;
\.


--
-- Data for Name: notificacion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.notificacion (id_notificacion, id_procedimiento, emisor, receptor, descripcion, status, fecha, estado, concepto) FROM stdin;
496	276	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 19:06:07.474372+00	enrevision	TRAMITE
498	277	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 20:22:46.388248+00	enproceso	TRAMITE
503	277	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 20:28:50.980214+00	finalizado	TRAMITE
525	288	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-26 01:11:08.029396+00	enproceso	TRAMITE
505	278	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:18:19.430757+00	enproceso	TRAMITE
527	289	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:19:50.96666+00	enproceso	TRAMITE
509	279	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 22:07:15.597688+00	validando	TRAMITE
532	289	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-26 01:22:23.405168+00	finalizado	TRAMITE
512	278	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 22:38:38.23326+00	finalizado	TRAMITE
515	279	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 23:31:43.275252+00	enproceso	TRAMITE
518	279	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 23:49:31.987536+00	finalizado	TRAMITE
520	286	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-26 01:02:31.651442+00	validando	TRAMITE
522	288	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-26 01:08:29.126954+00	validando	TRAMITE
534	290	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:41:33.008194+00	enproceso	TRAMITE
538	291	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:47:33.281706+00	enproceso	TRAMITE
964	323	V-10528417	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 00:45:58.689675+00	ingresardatos	IMPUESTO
542	292	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:48:49.384157+00	enproceso	TRAMITE
997	341	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 16:22:13.970586+00	ingresardatos	IMPUESTO
1188	380	V-1231931298	V-12543654	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 17:50:28.862769+00	enrevision	TRAMITE
1184	379	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-192837465	f	2020-07-21 17:30:12.836869+00	ingresardatos	IMPUESTO
1202	382	V-1231931298	J-192837466	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-23 03:30:16.90819+00	enrevision	TRAMITE
1203	382	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-23 03:30:16.947065+00	enrevision	TRAMITE
1204	382	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-23 03:30:16.956942+00	enrevision	TRAMITE
999	341	V-1231931298	V-1203912039	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 16:22:13.970586+00	ingresardatos	IMPUESTO
1189	380	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 17:50:28.877065+00	enrevision	TRAMITE
1052	341	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-14 16:57:11.781962+00	enproceso	TRAMITE
1073	369	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-15 16:52:02.368481+00	ingresardatos	IMPUESTO
998	341	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 16:22:13.970586+00	ingresardatos	IMPUESTO
1051	341	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 16:57:11.765868+00	enproceso	TRAMITE
1031	337	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-13 19:39:23.898294+00	enrevision	TRAMITE
546	293	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:51:23.483567+00	enproceso	TRAMITE
845	250	V-1923812093	V-1	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	f	2020-07-01 17:43:41.536246+00	finalizado	IMPUESTO
550	294	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:52:28.345188+00	enproceso	TRAMITE
862	328	V-1231931298	V-12934856	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-02 15:55:42.688945+00	finalizado	TRAMITE
554	295	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 01:58:00.633268+00	enproceso	TRAMITE
863	328	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-02 15:55:42.688945+00	finalizado	TRAMITE
559	295	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-26 02:01:05.832879+00	finalizado	TRAMITE
561	163	null-null	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 04:27:20.873159+00	ingresardatos	IMPUESTO
563	296	V-1231234444	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 06:44:52.231195+00	enrevision	TRAMITE
565	297	V-1231234444	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 06:47:30.627123+00	enrevision	TRAMITE
1112	358	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:22:37.003652+00	enrevision	TRAMITE
975	328	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 13:05:24.399972+00	ingresardatos	IMPUESTO
1113	358	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:22:37.017581+00	enrevision	TRAMITE
979	335	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-07-13 13:40:21.823894+00	ingresardatos	IMPUESTO
985	339	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-07-13 13:46:58.933594+00	ingresardatos	IMPUESTO
991	340	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 15:46:11.242445+00	ingresardatos	IMPUESTO
1186	380	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-07-21 17:30:47.836805+00	ingresardatos	IMPUESTO
567	165	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 17:03:36.969559+00	ingresardatos	IMPUESTO
966	334	V-12543654	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-13 01:02:24.114458+00	enproceso	TRAMITE
569	165	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 17:42:35.852862+00	{"state":"validando"}	IMPUESTO
1000	341	V-1231931298	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 16:27:25.958401+00	{"state":"finalizado"}	IMPUESTO
571	170	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 18:51:56.606695+00	ingresardatos	IMPUESTO
573	170	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 18:52:17.922487+00	{"state":"validando"}	IMPUESTO
575	171	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 18:58:24.718913+00	ingresardatos	IMPUESTO
865	252	V-12934856	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-406576458	f	2020-07-02 16:19:57.555154+00	ingresardatos	IMPUESTO
577	171	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 18:58:38.993864+00	{"state":"validando"}	IMPUESTO
1032	337	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-13 19:40:09.009702+00	finalizado	TRAMITE
579	173	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 20:41:34.670731+00	ingresardatos	IMPUESTO
1159	375	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:37:40.9648+00	finalizado	TRAMITE
581	173	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 22:42:37.350341+00	{"state":"validando"}	IMPUESTO
1160	375	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:37:40.9648+00	finalizado	TRAMITE
583	174	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 22:45:58.363933+00	ingresardatos	IMPUESTO
1028	336	V-1231931298	V-5678987	Se ha procesado su trámite de tipo Registro de Contribuyente	f	2020-07-13 19:31:42.521455+00	finalizado	TRAMITE
585	298	null-null	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 22:49:43.793752+00	enproceso	TRAMITE
869	253	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-07-02 19:44:33.057281+00	ingresardatos	IMPUESTO
881	258	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 21:47:47.966438+00	ingresardatos	IMPUESTO
970	334	V-1231931298	V-12543654	Se ha procesado su trámite de tipo Registro de Contribuyente	f	2020-07-13 01:09:31.533035+00	finalizado	TRAMITE
971	334	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-13 01:09:31.533035+00	finalizado	TRAMITE
873	254	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 21:22:39.960649+00	ingresardatos	IMPUESTO
1029	336	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-13 19:31:42.521455+00	finalizado	TRAMITE
885	260	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 22:10:41.583764+00	ingresardatos	IMPUESTO
877	256	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 21:41:52.330477+00	ingresardatos	IMPUESTO
977	328	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 13:08:50.062602+00	{"state":"finalizado"}	IMPUESTO
968	334	V-12543654	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 01:02:24.120644+00	enproceso	TRAMITE
889	262	V-10888777	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-03 14:51:51.83581+00	ingresardatos	IMPUESTO
833	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.465551+00	finalizado	IMPUESTO
589	181	null-null	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 23:17:15.038059+00	ingresardatos	IMPUESTO
591	181	null-null	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:46:26.508527+00	{"state":"validando"}	IMPUESTO
594	298	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-26 23:51:45.261735+00	finalizado	TRAMITE
1030	336	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-13 19:31:42.521455+00	finalizado	TRAMITE
593	298	V-1231931298	V-18496685	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-26 23:51:45.261735+00	finalizado	TRAMITE
596	193	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-06-27 01:36:27.634336+00	ingresardatos	IMPUESTO
598	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.85305+00	finalizado	IMPUESTO
599	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.85655+00	finalizado	IMPUESTO
600	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.859712+00	finalizado	IMPUESTO
601	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.862772+00	finalizado	IMPUESTO
602	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.865981+00	finalizado	IMPUESTO
603	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.868976+00	finalizado	IMPUESTO
981	335	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	f	2020-07-13 13:43:14.378583+00	{"state":"finalizado"}	IMPUESTO
987	338	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-311456759	f	2020-07-13 13:48:16.402619+00	{"state":"finalizado"}	IMPUESTO
1055	341	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-14 16:59:49.328302+00	enrevision	TRAMITE
604	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.872054+00	finalizado	IMPUESTO
605	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.875101+00	finalizado	IMPUESTO
606	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.878243+00	finalizado	IMPUESTO
607	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.881535+00	finalizado	IMPUESTO
608	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.885247+00	finalizado	IMPUESTO
609	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.888416+00	finalizado	IMPUESTO
610	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.891417+00	finalizado	IMPUESTO
611	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.89435+00	finalizado	IMPUESTO
612	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.897347+00	finalizado	IMPUESTO
613	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.900389+00	finalizado	IMPUESTO
614	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.903499+00	finalizado	IMPUESTO
615	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.906495+00	finalizado	IMPUESTO
616	181	V-1923812093	V-1	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 03:57:30.959002+00	finalizado	IMPUESTO
617	198	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-27 04:18:41.828186+00	ingresardatos	IMPUESTO
834	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.469406+00	finalizado	IMPUESTO
619	198	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 04:18:59.615839+00	{"state":"validando"}	IMPUESTO
835	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.472603+00	finalizado	IMPUESTO
621	174	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 04:30:50.849376+00	{"state":"validando"}	IMPUESTO
836	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.475725+00	finalizado	IMPUESTO
837	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.478862+00	finalizado	IMPUESTO
838	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.482375+00	finalizado	IMPUESTO
839	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.485528+00	finalizado	IMPUESTO
840	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.488475+00	finalizado	IMPUESTO
1115	364	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:24:37.65035+00	enrevision	TRAMITE
1205	382	V-1923812093	J-192837466	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-23 03:34:56.529731+00	finalizado	TRAMITE
841	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.491876+00	finalizado	IMPUESTO
842	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.49484+00	finalizado	IMPUESTO
843	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.497919+00	finalizado	IMPUESTO
844	250	V-1923812093	V-78945612	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 17:43:41.501276+00	finalizado	IMPUESTO
1002	342	V-25848973	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-13 16:41:24.88859+00	ingresardatos	IMPUESTO
1191	379	V-1923812093	J-312645977	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 17:59:43.14027+00	finalizado	TRAMITE
1116	364	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:24:37.665074+00	enrevision	TRAMITE
1192	379	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 17:59:43.164709+00	finalizado	TRAMITE
1187	380	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	t	2020-07-21 17:30:47.836805+00	ingresardatos	IMPUESTO
595	298	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-26 23:51:45.261735+00	finalizado	TRAMITE
1206	382	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-23 03:34:56.553441+00	finalizado	TRAMITE
650	198	V-1923812093	V-1	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 04:44:05.051233+00	finalizado	IMPUESTO
1108	374	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: V-18921679	f	2020-07-15 20:59:51.738355+00	ingresardatos	IMPUESTO
1075	346	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-15 16:55:29.30988+00	enrevision	TRAMITE
548	293	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:51:24.089517+00	enproceso	TRAMITE
1109	374	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: V-18921679	t	2020-07-15 20:59:51.738355+00	ingresardatos	IMPUESTO
508	278	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:18:20.299545+00	enproceso	TRAMITE
516	279	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 23:31:43.886633+00	enproceso	TRAMITE
1004	343	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 16:42:27.45734+00	ingresardatos	IMPUESTO
531	289	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-26 01:22:23.405168+00	finalizado	TRAMITE
871	253	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	f	2020-07-02 19:51:02.795929+00	{"state":"finalizado"}	IMPUESTO
1162	376	V-1231931298	J-4005	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-19 22:19:18.855897+00	enrevision	TRAMITE
1163	376	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-19 22:19:18.874451+00	enrevision	TRAMITE
1167	376	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-20 15:31:30.98507+00	ingresardatos	IMPUESTO
1110	375	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: V-18921679	f	2020-07-15 21:34:30.829195+00	ingresardatos	IMPUESTO
1118	365	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:24:52.478686+00	enrevision	TRAMITE
1119	365	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:24:52.496532+00	enrevision	TRAMITE
1053	341	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 16:57:11.789464+00	enproceso	TRAMITE
526	288	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-26 01:11:08.270204+00	enproceso	TRAMITE
501	277	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 20:22:47.502217+00	enproceso	TRAMITE
541	291	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:47:34.061785+00	enproceso	TRAMITE
545	292	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:48:50.587436+00	enproceso	TRAMITE
549	293	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:51:24.344544+00	enproceso	TRAMITE
553	294	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:52:29.211594+00	enproceso	TRAMITE
530	289	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:19:51.727124+00	enproceso	TRAMITE
537	290	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:41:33.977149+00	enproceso	TRAMITE
1027	336	V-5678987	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 19:30:55.776425+00	enproceso	TRAMITE
969	334	V-12543654	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 01:02:24.123515+00	enproceso	TRAMITE
557	295	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:58:01.390835+00	enproceso	TRAMITE
808	325	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 14:28:11.894785+00	enproceso	TRAMITE
1045	340	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 15:24:11.767287+00	enproceso	TRAMITE
651	199	V-10555777	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 16:36:18.328194+00	ingresardatos	IMPUESTO
846	251	V-12981762	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-410984694	f	2020-07-02 13:55:56.080604+00	ingresardatos	IMPUESTO
653	199	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 16:50:27.693809+00	{"state":"validando"}	IMPUESTO
655	200	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 17:01:41.466493+00	ingresardatos	IMPUESTO
861	328	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-02 15:52:56.100547+00	enproceso	TRAMITE
500	277	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 20:22:46.927251+00	enproceso	TRAMITE
1033	338	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-14 13:05:24.301111+00	enrevision	TRAMITE
511	278	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 22:38:37.696548+00	finalizado	TRAMITE
514	279	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 23:31:41.883319+00	enproceso	TRAMITE
517	279	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 23:49:30.702372+00	finalizado	TRAMITE
558	295	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-26 02:01:05.832879+00	finalizado	TRAMITE
623	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.878816+00	finalizado	IMPUESTO
929	331	V-18496685	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-10 15:03:38.330288+00	enproceso	TRAMITE
853	327	V-12934856	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-02 15:13:50.518638+00	enproceso	TRAMITE
768	320	V-20002000	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:17:17.794282+00	enproceso	TRAMITE
1087	350	V-18921679	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-15 19:43:36.473396+00	enproceso	TRAMITE
790	324	V-30002000	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:47:40.47044+00	enproceso	TRAMITE
806	326	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 14:28:11.88864+00	enproceso	TRAMITE
1169	377	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-20 17:14:30.697286+00	ingresardatos	IMPUESTO
657	200	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-30 12:58:42.910166+00	{"state":"validando"}	IMPUESTO
1006	335	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-13 16:43:56.842405+00	enrevision	TRAMITE
659	300	V-12345688	V-1	Un trámite de tipo Cumplimiento de Normas Tecnicas ha sido creado	f	2020-06-30 17:50:31.57895+00	validando	TRAMITE
660	300	V-12345688	V-1231231231	Un trámite de tipo Cumplimiento de Normas Tecnicas ha sido creado	f	2020-06-30 17:50:31.583639+00	validando	TRAMITE
661	206	V-15999000	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-297143858	f	2020-06-30 17:57:40.436255+00	ingresardatos	IMPUESTO
1081	349	V-1231931298	V-25848973	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 19:37:43.283951+00	enrevision	TRAMITE
663	301	V-12345688	V-1	Un trámite de tipo Constancia de Habitabilidad ha sido creado	f	2020-06-30 18:21:39.907298+00	validando	TRAMITE
664	301	V-12345688	V-1231231231	Un trámite de tipo Constancia de Habitabilidad ha sido creado	f	2020-06-30 18:21:39.913448+00	validando	TRAMITE
665	302	V-12345688	V-1	Un trámite de tipo Instalacion de Plantas Electricas ha sido creado	f	2020-06-30 18:22:41.425243+00	enproceso	TRAMITE
666	302	V-12345688	V-1231231231	Un trámite de tipo Instalacion de Plantas Electricas ha sido creado	f	2020-06-30 18:22:41.428826+00	enproceso	TRAMITE
667	303	V-12345688	V-1	Un trámite de tipo Constancia de Servicio Residencial ha sido creado	f	2020-06-30 18:23:45.395902+00	validando	TRAMITE
668	303	V-12345688	V-123123	Un trámite de tipo Constancia de Servicio Residencial ha sido creado	f	2020-06-30 18:23:45.400151+00	validando	TRAMITE
669	304	V-12345688	V-1	Un trámite de tipo Constancia de Servicio Persona Juridica ha sido creado	f	2020-06-30 18:24:56.169488+00	validando	TRAMITE
670	304	V-12345688	V-123123	Un trámite de tipo Constancia de Servicio Persona Juridica ha sido creado	f	2020-06-30 18:24:56.172843+00	validando	TRAMITE
671	305	V-12345688	V-1	Un trámite de tipo Permiso de Construccion ha sido creado	f	2020-06-30 18:25:27.61567+00	enproceso	TRAMITE
672	305	V-12345688	V-123123	Un trámite de tipo Permiso de Construccion ha sido creado	f	2020-06-30 18:25:27.619337+00	enproceso	TRAMITE
673	305	V-12345688	V-123133333	Un trámite de tipo Permiso de Construccion ha sido creado	f	2020-06-30 18:25:27.622327+00	enproceso	TRAMITE
674	306	V-12345688	V-1	Un trámite de tipo Solvencia de Inmuebles Urbanos ha sido creado	f	2020-06-30 18:27:14.693716+00	validando	TRAMITE
675	306	V-12345688	V-1231234444	Un trámite de tipo Solvencia de Inmuebles Urbanos ha sido creado	f	2020-06-30 18:27:14.69742+00	validando	TRAMITE
676	306	V-12345688	V-27139154	Un trámite de tipo Solvencia de Inmuebles Urbanos ha sido creado	f	2020-06-30 18:27:14.700557+00	validando	TRAMITE
677	307	V-12345688	V-1	Un trámite de tipo Permiso de Habitabilidad con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:29:36.973191+00	enproceso	TRAMITE
678	307	V-12345688	V-123123	Un trámite de tipo Permiso de Habitabilidad con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:29:36.976848+00	enproceso	TRAMITE
679	307	V-12345688	V-123133333	Un trámite de tipo Permiso de Habitabilidad con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:29:36.979904+00	enproceso	TRAMITE
680	308	V-12345688	V-1	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:30:24.531369+00	enproceso	TRAMITE
681	308	V-12345688	V-123123	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:30:24.534979+00	enproceso	TRAMITE
682	308	V-12345688	V-123133333	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:30:24.538259+00	enproceso	TRAMITE
683	309	V-12345688	V-1	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:32:26.659151+00	enproceso	TRAMITE
684	309	V-12345688	V-123123	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:32:26.663656+00	enproceso	TRAMITE
893	322	V-1231931298	V-9999999	Se ha procesado su trámite de tipo Registro de Contribuyente	f	2020-07-03 15:21:19.527365+00	finalizado	TRAMITE
894	322	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-03 15:21:19.527365+00	finalizado	TRAMITE
685	309	V-12345688	V-123133333	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:32:26.667268+00	enproceso	TRAMITE
686	310	V-12345688	V-1	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:33:23.952135+00	enproceso	TRAMITE
687	310	V-12345688	V-123123	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:33:23.957662+00	enproceso	TRAMITE
688	310	V-12345688	V-123133333	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-06-30 18:33:23.963883+00	enproceso	TRAMITE
689	311	V-12345688	V-1	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-06-30 18:36:52.578991+00	validando	TRAMITE
690	311	V-12345688	V-1231234444	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-06-30 18:36:52.583737+00	validando	TRAMITE
691	311	V-12345688	V-27139154	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-06-30 18:36:52.586934+00	validando	TRAMITE
692	312	V-12345688	V-1	Un trámite de tipo Codigo Catastral para Casas ha sido creado	f	2020-06-30 18:38:45.15148+00	validando	TRAMITE
693	312	V-12345688	V-1231234444	Un trámite de tipo Codigo Catastral para Casas ha sido creado	f	2020-06-30 18:38:45.155246+00	validando	TRAMITE
694	312	V-12345688	V-27139154	Un trámite de tipo Codigo Catastral para Casas ha sido creado	f	2020-06-30 18:38:45.158613+00	validando	TRAMITE
695	313	V-12345688	V-1	Un trámite de tipo Codigo Catastral para Apartamentos ha sido creado	f	2020-06-30 18:40:42.50787+00	validando	TRAMITE
696	313	V-12345688	V-1231234444	Un trámite de tipo Codigo Catastral para Apartamentos ha sido creado	f	2020-06-30 18:40:42.511562+00	validando	TRAMITE
697	313	V-12345688	V-27139154	Un trámite de tipo Codigo Catastral para Apartamentos ha sido creado	f	2020-06-30 18:40:42.514865+00	validando	TRAMITE
698	314	V-12345688	V-1	Un trámite de tipo Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales ha sido creado	f	2020-06-30 18:42:31.341865+00	enproceso	TRAMITE
699	314	V-12345688	V-1231234444	Un trámite de tipo Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales ha sido creado	f	2020-06-30 18:42:31.345382+00	enproceso	TRAMITE
700	314	V-12345688	V-27139154	Un trámite de tipo Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales ha sido creado	f	2020-06-30 18:42:31.348139+00	enproceso	TRAMITE
1082	349	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 19:37:43.283951+00	enrevision	TRAMITE
701	314	V-12345688	V-1283190247	Un trámite de tipo Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales ha sido creado	f	2020-06-30 18:42:31.350983+00	enproceso	TRAMITE
702	315	V-12345688	V-1	Un trámite de tipo Conformidad de la Edificación y Uso Unidades Educativas ha sido creado	f	2020-06-30 18:44:25.877128+00	enproceso	TRAMITE
703	315	V-12345688	V-1231234444	Un trámite de tipo Conformidad de la Edificación y Uso Unidades Educativas ha sido creado	f	2020-06-30 18:44:25.880874+00	enproceso	TRAMITE
704	315	V-12345688	V-27139154	Un trámite de tipo Conformidad de la Edificación y Uso Unidades Educativas ha sido creado	f	2020-06-30 18:44:25.883984+00	enproceso	TRAMITE
705	315	V-12345688	V-1283190247	Un trámite de tipo Conformidad de la Edificación y Uso Unidades Educativas ha sido creado	f	2020-06-30 18:44:25.888017+00	enproceso	TRAMITE
706	316	V-12345688	V-1	Un trámite de tipo Conformidad de la Edificación y Uso Locales en Centros Comerciales ha sido creado	f	2020-06-30 18:45:47.572841+00	enproceso	TRAMITE
707	316	V-12345688	V-1231234444	Un trámite de tipo Conformidad de la Edificación y Uso Locales en Centros Comerciales ha sido creado	f	2020-06-30 18:45:47.576073+00	enproceso	TRAMITE
708	316	V-12345688	V-27139154	Un trámite de tipo Conformidad de la Edificación y Uso Locales en Centros Comerciales ha sido creado	f	2020-06-30 18:45:47.579362+00	enproceso	TRAMITE
709	316	V-12345688	V-1283190247	Un trámite de tipo Conformidad de la Edificación y Uso Locales en Centros Comerciales ha sido creado	f	2020-06-30 18:45:47.582487+00	enproceso	TRAMITE
710	317	V-12345688	V-1	Un trámite de tipo Apartado de Bohío ha sido creado	f	2020-06-30 18:46:47.771885+00	validando	TRAMITE
711	317	V-12345688	V-1294712034	Un trámite de tipo Apartado de Bohío ha sido creado	f	2020-06-30 18:46:47.775074+00	validando	TRAMITE
712	318	V-12345688	V-1	Un trámite de tipo Certificación para Prestar Servicio de Transporte Público Urbano ha sido creado	f	2020-06-30 18:48:03.795316+00	enproceso	TRAMITE
713	318	V-12345688	V-1239812938	Un trámite de tipo Certificación para Prestar Servicio de Transporte Público Urbano ha sido creado	f	2020-06-30 18:48:03.799338+00	enproceso	TRAMITE
714	318	V-12345688	V-1023102938	Un trámite de tipo Certificación para Prestar Servicio de Transporte Público Urbano ha sido creado	f	2020-06-30 18:48:03.802298+00	enproceso	TRAMITE
715	209	V-12345688	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-410984694	f	2020-06-30 18:54:32.280094+00	ingresardatos	IMPUESTO
848	251	V-12981762	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-410984694	f	2020-07-02 14:02:13.294929+00	{"state":"validando"}	IMPUESTO
717	209	V-12345688	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-410984694	f	2020-06-30 18:55:16.030271+00	{"state":"validando"}	IMPUESTO
719	319	V-12345688	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-30 18:57:03.683855+00	validando	TRAMITE
1007	335	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-13 16:44:08.827329+00	finalizado	TRAMITE
721	213	V-18455333	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316120198	f	2020-06-30 19:00:25.439898+00	ingresardatos	IMPUESTO
723	213	V-18455333	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316120198	f	2020-06-30 19:01:06.107739+00	{"state":"validando"}	IMPUESTO
725	214	V-19649021	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-411827428	f	2020-06-30 19:07:35.915302+00	ingresardatos	IMPUESTO
727	214	V-19649021	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-411827428	f	2020-06-30 19:08:32.410389+00	{"state":"validando"}	IMPUESTO
850	327	V-12934856	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-02 15:13:50.508903+00	enproceso	TRAMITE
729	217	V-20000333	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316703649	f	2020-06-30 19:16:22.626473+00	ingresardatos	IMPUESTO
731	217	V-20000333	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316703649	f	2020-06-30 19:17:28.28983+00	{"state":"validando"}	IMPUESTO
733	226	V-12345690	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-302827515	f	2020-06-30 19:33:01.980484+00	ingresardatos	IMPUESTO
735	226	V-12345690	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-302827515	f	2020-06-30 19:33:41.487777+00	{"state":"validando"}	IMPUESTO
737	227	V-20000333	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316703649	f	2020-06-30 19:37:20.963383+00	ingresardatos	IMPUESTO
739	228	V-12345690	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-302827515	f	2020-06-30 19:37:46.983594+00	ingresardatos	IMPUESTO
741	227	V-20000333	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316703649	f	2020-06-30 19:38:28.497973+00	{"state":"validando"}	IMPUESTO
743	228	V-12345690	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-302827515	f	2020-06-30 19:38:59.812026+00	{"state":"validando"}	IMPUESTO
745	230	V-23555666	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070178787	f	2020-06-30 19:44:12.202112+00	ingresardatos	IMPUESTO
747	230	V-23555666	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070178787	f	2020-06-30 19:44:37.971408+00	{"state":"validando"}	IMPUESTO
1121	366	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:25:11.746834+00	enrevision	TRAMITE
749	233	V-7555189	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-306166220	f	2020-06-30 20:11:45.016567+00	ingresardatos	IMPUESTO
1193	380	V-1923812093	V-12543654	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 18:00:35.894712+00	finalizado	TRAMITE
751	233	V-7555189	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-306166220	f	2020-06-30 20:12:22.163939+00	{"state":"validando"}	IMPUESTO
1194	380	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 18:00:35.919475+00	finalizado	TRAMITE
753	235	V-18966554	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-400578116	f	2020-07-01 11:59:30.255968+00	ingresardatos	IMPUESTO
755	235	V-18966554	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-400578116	f	2020-07-01 12:10:52.274811+00	{"state":"validando"}	IMPUESTO
1008	343	V-1231931298	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 16:44:24.20089+00	{"state":"finalizado"}	IMPUESTO
757	241	V-36985214	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-313993557	f	2020-07-01 12:39:34.952136+00	ingresardatos	IMPUESTO
759	241	V-36985214	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-313993557	f	2020-07-01 12:40:34.21095+00	{"state":"validando"}	IMPUESTO
1122	366	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:25:11.77517+00	enrevision	TRAMITE
761	242	V-36985214	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-313993557	f	2020-07-01 13:03:31.738601+00	ingresardatos	IMPUESTO
1009	343	V-1231931298	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 16:44:24.20089+00	{"state":"finalizado"}	IMPUESTO
763	245	V-123456741	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-01 13:13:31.00922+00	ingresardatos	IMPUESTO
1057	357	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-306020403	f	2020-07-14 18:06:20.8892+00	ingresardatos	IMPUESTO
765	320	V-20002000	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-01 13:17:17.784506+00	enproceso	TRAMITE
769	321	V-12345696	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-01 13:24:37.004816+00	enproceso	TRAMITE
1063	362	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-15 12:34:40.765564+00	ingresardatos	IMPUESTO
1084	350	V-18921679	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-15 19:43:36.466795+00	enproceso	TRAMITE
774	320	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-01 13:26:28.8817+00	finalizado	TRAMITE
776	321	V-1231931298	V-12345696	Se ha procesado su trámite de tipo Registro de Contribuyente	f	2020-07-01 13:27:18.801112+00	finalizado	TRAMITE
777	321	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-01 13:27:18.801112+00	finalizado	TRAMITE
773	320	V-1231931298	V-20002000	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-07-01 13:26:28.8817+00	finalizado	TRAMITE
779	322	V-9999999	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-01 13:32:13.084208+00	enproceso	TRAMITE
783	323	V-78945612	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-01 13:44:35.288034+00	enproceso	TRAMITE
791	323	V-1231931298	V-78945612	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-07-01 14:04:09.979197+00	finalizado	TRAMITE
787	324	V-30002000	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-01 13:47:40.454628+00	enproceso	TRAMITE
804	325	V-1923812093	V-78945612	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 14:28:11.867213+00	enproceso	TRAMITE
792	323	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-01 14:04:09.979197+00	finalizado	TRAMITE
795	324	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-01 14:04:22.271112+00	finalizado	TRAMITE
854	327	V-1231931298	V-12934856	Se ha procesado su trámite de tipo Registro de Contribuyente	f	2020-07-02 15:29:56.01619+00	finalizado	TRAMITE
797	325	V-78945612	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-01 14:09:06.919816+00	validando	TRAMITE
855	327	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-02 15:29:56.01619+00	finalizado	TRAMITE
799	326	V-30002000	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-01 14:13:33.547026+00	validando	TRAMITE
801	206	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-297143858	f	2020-07-01 14:26:35.508573+00	{"state":"finalizado"}	IMPUESTO
1086	350	V-18921679	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-15 19:43:36.471373+00	enproceso	TRAMITE
805	326	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-01 14:28:11.884679+00	enproceso	TRAMITE
507	278	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:18:20.035799+00	enproceso	TRAMITE
807	325	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-01 14:28:11.891758+00	enproceso	TRAMITE
1034	338	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-14 13:05:42.087678+00	finalizado	TRAMITE
1041	340	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-14 15:21:42.803832+00	validando	TRAMITE
1076	346	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-15 16:56:12.9761+00	finalizado	TRAMITE
809	242	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-313993557	f	2020-07-01 14:36:28.406431+00	{"state":"finalizado"}	IMPUESTO
811	247	V-12345652	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-296585156	f	2020-07-01 14:51:15.021445+00	ingresardatos	IMPUESTO
813	247	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-296585156	f	2020-07-01 14:55:16.036465+00	{"state":"finalizado"}	IMPUESTO
1035	354	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-14 13:10:38.063349+00	ingresardatos	IMPUESTO
815	245	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-070020091	f	2020-07-01 15:07:41.066851+00	{"state":"finalizado"}	IMPUESTO
794	324	V-1231931298	V-30002000	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-07-01 14:04:22.271112+00	finalizado	TRAMITE
803	326	V-1923812093	V-30002000	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 14:28:11.863138+00	enproceso	TRAMITE
588	298	null-null	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 22:49:43.802474+00	enproceso	TRAMITE
772	321	V-12345696	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:24:37.020205+00	enproceso	TRAMITE
782	322	V-9999999	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:32:13.103509+00	enproceso	TRAMITE
817	248	V-18455333	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316120198	f	2020-07-01 15:17:49.730718+00	ingresardatos	IMPUESTO
820	326	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-01 15:26:54.339341+00	finalizado	TRAMITE
1165	376	V-1923812093	J-4005	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-19 22:20:57.953471+00	finalizado	TRAMITE
819	326	V-1231931298	V-30002000	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 15:26:54.339341+00	finalizado	TRAMITE
822	249	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-700020005	f	2020-07-01 15:38:01.424731+00	ingresardatos	IMPUESTO
826	325	V-1231931298	V-78945612	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 15:42:58.602367+00	finalizado	TRAMITE
824	249	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-700020005	f	2020-07-01 15:38:52.444418+00	{"state":"finalizado"}	IMPUESTO
857	328	V-12934856	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-02 15:43:54.274813+00	validando	TRAMITE
827	325	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-01 15:42:58.602367+00	finalizado	TRAMITE
829	250	V-78945612	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-314151612	f	2020-07-01 15:49:26.161521+00	ingresardatos	IMPUESTO
1166	376	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-19 22:20:57.965432+00	finalizado	TRAMITE
831	250	V-78945612	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-314151612	f	2020-07-01 15:50:33.202607+00	{"state":"validando"}	IMPUESTO
1059	342	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-14 19:55:12.801965+00	enrevision	TRAMITE
1065	344	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-15 12:37:13.397549+00	enrevision	TRAMITE
859	328	V-1923812093	V-12934856	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-02 15:52:56.085669+00	enproceso	TRAMITE
860	328	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-02 15:52:56.096907+00	enproceso	TRAMITE
1195	381	V-1231931298	J-192837466	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 19:06:20.300828+00	enrevision	TRAMITE
1196	381	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 19:06:20.317319+00	enrevision	TRAMITE
1044	340	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-14 15:24:11.764547+00	enproceso	TRAMITE
1088	351	V-1231931298	V-25848973	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 19:47:45.615655+00	enrevision	TRAMITE
1089	351	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 19:47:45.615655+00	enrevision	TRAMITE
1077	343	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-15 16:57:09.317804+00	finalizado	TRAMITE
1043	340	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 15:24:11.754081+00	enproceso	TRAMITE
786	323	V-78945612	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:44:35.30045+00	enproceso	TRAMITE
1124	368	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:25:41.635863+00	enrevision	TRAMITE
1012	348	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 17:02:07.266864+00	ingresardatos	IMPUESTO
1066	344	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-15 13:41:54.589272+00	finalizado	TRAMITE
1092	350	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-07-15 19:52:51.648619+00	finalizado	TRAMITE
1091	350	V-1231931298	V-18921679	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-07-15 19:52:51.648619+00	finalizado	TRAMITE
867	252	V-12934856	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-406576458	f	2020-07-02 16:21:46.902567+00	{"state":"validando"}	IMPUESTO
875	255	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 21:30:20.884036+00	ingresardatos	IMPUESTO
879	257	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 21:43:09.497351+00	ingresardatos	IMPUESTO
883	259	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 22:00:45.770935+00	ingresardatos	IMPUESTO
887	261	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	f	2020-07-02 22:18:32.335293+00	ingresardatos	IMPUESTO
891	262	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-07-03 15:04:09.856662+00	{"state":"finalizado"}	IMPUESTO
896	329	V-9999999	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-03 15:34:50.544321+00	validando	TRAMITE
898	263	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 17:59:54.246253+00	ingresardatos	IMPUESTO
900	264	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 18:17:28.291585+00	ingresardatos	IMPUESTO
902	265	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 18:22:52.758241+00	ingresardatos	IMPUESTO
529	289	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:19:51.471895+00	enproceso	TRAMITE
1037	339	V-1023910231	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-14 13:11:52.599676+00	enrevision	TRAMITE
1125	368	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:25:41.652526+00	enrevision	TRAMITE
1014	348	V-1231931298	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 17:04:41.776225+00	{"state":"finalizado"}	IMPUESTO
904	266	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 18:29:23.952297+00	ingresardatos	IMPUESTO
906	267	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 18:33:31.425025+00	ingresardatos	IMPUESTO
1060	361	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-14 23:42:11.759732+00	ingresardatos	IMPUESTO
908	268	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-06 18:40:42.222588+00	ingresardatos	IMPUESTO
910	270	V-1293812738	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-09 12:12:37.735892+00	ingresardatos	IMPUESTO
1067	364	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-15 16:35:45.552823+00	ingresardatos	IMPUESTO
912	330	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-09 12:13:25.011938+00	enrevision	TRAMITE
913	330	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-09 12:27:59.778264+00	finalizado	TRAMITE
914	277	V-12345679	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070015357	f	2020-07-09 14:06:40.382111+00	ingresardatos	IMPUESTO
916	278	V-12345679	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070015357	f	2020-07-09 14:08:07.133829+00	ingresardatos	IMPUESTO
1094	352	V-18921679	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-15 20:05:28.854083+00	validando	TRAMITE
918	277	V-12345679	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070015357	f	2020-07-09 14:15:27.18203+00	{"state":"validando"}	IMPUESTO
1046	340	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 15:24:51.15177+00	enrevision	TRAMITE
920	278	V-12345679	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070015357	f	2020-07-09 14:16:38.889143+00	{"state":"validando"}	IMPUESTO
922	283	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-10 12:05:40.085842+00	ingresardatos	IMPUESTO
924	283	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-07-10 13:20:45.06117+00	{"state":"finalizado"}	IMPUESTO
1198	381	V-1923812093	J-192837466	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 19:07:43.903517+00	finalizado	TRAMITE
1199	381	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 19:07:43.917791+00	finalizado	TRAMITE
1061	361	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-14 23:42:11.759732+00	ingresardatos	IMPUESTO
1068	364	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-15 16:35:45.552823+00	ingresardatos	IMPUESTO
1127	370	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:31:39.604557+00	enrevision	TRAMITE
1128	370	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:31:39.621337+00	enrevision	TRAMITE
1095	352	V-18921679	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-15 20:05:28.868057+00	validando	TRAMITE
1171	378	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-20 17:18:51.132302+00	ingresardatos	IMPUESTO
1015	348	V-1231931298	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 17:04:41.776225+00	{"state":"finalizado"}	IMPUESTO
1039	339	V-1923812093	V-1023910231	Se realizó la revisión de su trámite de tipo Beneficio de Contribuyente	f	2020-07-14 13:36:04.835584+00	finalizado	TRAMITE
1040	339	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-14 13:36:04.856733+00	finalizado	TRAMITE
1047	340	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-14 15:24:51.15177+00	enrevision	TRAMITE
528	289	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:19:51.212905+00	enproceso	TRAMITE
1016	349	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-13 17:06:24.328606+00	ingresardatos	IMPUESTO
1130	371	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:38:39.695145+00	enrevision	TRAMITE
1049	341	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-14 15:28:47.891986+00	validando	TRAMITE
1018	350	V-18496685	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-13 18:46:18.734208+00	ingresardatos	IMPUESTO
1062	343	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-14 23:45:19.330694+00	enrevision	TRAMITE
1131	371	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:38:39.719329+00	enrevision	TRAMITE
1173	377	V-1231931298	V-23543878	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 12:29:43.39716+00	enrevision	TRAMITE
1174	377	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 12:29:43.415038+00	enrevision	TRAMITE
1200	381	V-12354965	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-22 21:35:24.360555+00	ingresardatos	IMPUESTO
1019	350	V-18496685	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-13 18:46:18.734208+00	ingresardatos	IMPUESTO
890	262	V-10888777	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-03 14:51:51.83581+00	ingresardatos	IMPUESTO
895	322	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-03 15:21:19.527365+00	finalizado	TRAMITE
892	262	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-07-03 15:04:09.856662+00	{"state":"finalizado"}	IMPUESTO
897	329	V-9999999	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-03 15:34:50.548302+00	validando	TRAMITE
1069	365	V-12354965	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	f	2020-07-15 16:38:43.062497+00	ingresardatos	IMPUESTO
899	263	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 17:59:54.246253+00	ingresardatos	IMPUESTO
901	264	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 18:17:28.291585+00	ingresardatos	IMPUESTO
1133	371	V-1923812093	J-312645978	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:44:04.975364+00	finalizado	TRAMITE
1020	350	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-07-13 18:59:39.891426+00	{"state":"finalizado"}	IMPUESTO
1071	345	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-15 16:42:20.959344+00	enrevision	TRAMITE
524	288	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-26 01:11:07.448367+00	enproceso	TRAMITE
502	277	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 20:28:50.447402+00	finalizado	TRAMITE
1054	341	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 16:59:49.328302+00	enrevision	TRAMITE
624	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.882827+00	finalizado	IMPUESTO
536	290	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:41:33.713198+00	enproceso	TRAMITE
540	291	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:47:33.802821+00	enproceso	TRAMITE
544	292	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:48:50.298102+00	enproceso	TRAMITE
552	294	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:52:28.945246+00	enproceso	TRAMITE
556	295	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:58:01.144142+00	enproceso	TRAMITE
587	298	null-null	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 22:49:43.799291+00	enproceso	TRAMITE
852	327	V-12934856	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-02 15:13:50.515546+00	enproceso	TRAMITE
767	320	V-20002000	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:17:17.791392+00	enproceso	TRAMITE
771	321	V-12345696	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:24:37.013473+00	enproceso	TRAMITE
781	322	V-9999999	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:32:13.097819+00	enproceso	TRAMITE
926	331	V-18496685	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-10 15:03:38.310285+00	enproceso	TRAMITE
785	323	V-78945612	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:44:35.296851+00	enproceso	TRAMITE
789	324	V-30002000	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:47:40.466392+00	enproceso	TRAMITE
930	298	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 15:53:54.141082+00	ingresardatos	IMPUESTO
932	298	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-10 15:55:28.11513+00	{"state":"finalizado"}	IMPUESTO
934	299	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 15:58:15.308731+00	ingresardatos	IMPUESTO
936	299	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-10 15:59:41.686705+00	{"state":"finalizado"}	IMPUESTO
938	300	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 16:00:26.977582+00	ingresardatos	IMPUESTO
940	301	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 16:26:17.050893+00	ingresardatos	IMPUESTO
942	301	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-10 16:27:29.73935+00	{"state":"finalizado"}	IMPUESTO
1134	371	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:44:05.009701+00	finalizado	TRAMITE
944	302	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 16:30:10.956804+00	ingresardatos	IMPUESTO
1176	377	V-1923812093	V-23543878	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 12:59:30.510836+00	finalizado	TRAMITE
946	302	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-10 16:32:11.364479+00	{"state":"finalizado"}	IMPUESTO
948	303	V-10528417	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 16:46:15.987469+00	ingresardatos	IMPUESTO
950	332	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-10 16:49:31.022341+00	enrevision	TRAMITE
973	303	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 01:31:32.101582+00	{"state":"finalizado"}	IMPUESTO
625	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.886166+00	finalizado	IMPUESTO
983	338	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-311456759	f	2020-07-13 13:46:28.036453+00	ingresardatos	IMPUESTO
989	339	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	f	2020-07-13 13:49:32.232317+00	{"state":"finalizado"}	IMPUESTO
993	340	V-1231931298	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-13 15:49:44.551202+00	{"state":"finalizado"}	IMPUESTO
951	310	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 17:33:05.022337+00	ingresardatos	IMPUESTO
1022	351	V-18496685	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-07-13 19:29:29.277204+00	ingresardatos	IMPUESTO
953	310	V-1023910231	V-1	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	f	2020-07-10 17:33:58.361514+00	{"state":"finalizado"}	IMPUESTO
955	311	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	f	2020-07-10 17:36:13.46802+00	ingresardatos	IMPUESTO
957	312	V-1293812738	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-10 17:38:48.870822+00	ingresardatos	IMPUESTO
959	333	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-10 17:39:53.674928+00	enrevision	TRAMITE
960	333	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-10 17:40:22.959409+00	finalizado	TRAMITE
963	332	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-10 19:44:47.582839+00	finalizado	TRAMITE
1135	372	undefined-312645978	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-16 13:47:33.31935+00	validando	TRAMITE
1177	377	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 12:59:30.524107+00	finalizado	TRAMITE
1185	379	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-192837465	t	2020-07-21 17:30:12.836869+00	ingresardatos	IMPUESTO
928	331	V-18496685	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-10 15:03:38.324335+00	enproceso	TRAMITE
1074	369	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-15 16:52:02.368481+00	ingresardatos	IMPUESTO
1190	380	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-21 17:50:28.883233+00	enrevision	TRAMITE
1117	364	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:24:37.668846+00	enrevision	TRAMITE
1161	375	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:37:40.9648+00	finalizado	TRAMITE
555	295	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:58:00.888885+00	enproceso	TRAMITE
778	321	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-01 13:27:18.801112+00	finalizado	TRAMITE
780	322	V-9999999	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:32:13.090825+00	enproceso	TRAMITE
784	323	V-78945612	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:44:35.29387+00	enproceso	TRAMITE
788	324	V-30002000	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:47:40.4631+00	enproceso	TRAMITE
1036	354	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-14 13:10:38.063349+00	ingresardatos	IMPUESTO
726	214	V-19649021	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-411827428	t	2020-06-30 19:07:35.915302+00	ingresardatos	IMPUESTO
728	214	V-19649021	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-411827428	t	2020-06-30 19:08:32.410389+00	{"state":"validando"}	IMPUESTO
568	165	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-06-26 17:03:36.969559+00	ingresardatos	IMPUESTO
793	323	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-01 14:04:09.979197+00	finalizado	TRAMITE
1048	340	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 15:24:51.15177+00	enrevision	TRAMITE
1137	372	V-1923812093	J-312645978	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:52:45.316312+00	enproceso	TRAMITE
1138	372	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 13:52:45.343904+00	enproceso	TRAMITE
1139	372	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:52:45.350756+00	enproceso	TRAMITE
1178	378	V-1231931298	J-312645977	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 14:10:14.77124+00	enrevision	TRAMITE
1179	378	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 14:10:14.812009+00	enrevision	TRAMITE
1017	349	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 17:06:24.328606+00	ingresardatos	IMPUESTO
560	295	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-26 02:01:05.832879+00	finalizado	TRAMITE
775	320	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-01 13:26:28.8817+00	finalizado	TRAMITE
742	227	V-20000333	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316703649	t	2020-06-30 19:38:28.497973+00	{"state":"validando"}	IMPUESTO
939	300	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 16:00:26.977582+00	ingresardatos	IMPUESTO
1025	336	V-5678987	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 19:30:55.771456+00	enproceso	TRAMITE
1123	366	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:25:11.780526+00	enrevision	TRAMITE
1170	377	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-20 17:14:30.697286+00	ingresardatos	IMPUESTO
858	328	V-12934856	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-02 15:43:54.278604+00	validando	TRAMITE
519	279	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 23:49:32.283486+00	finalizado	TRAMITE
521	286	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-06-26 01:02:31.96821+00	validando	TRAMITE
523	288	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-06-26 01:08:29.355076+00	validando	TRAMITE
533	289	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-26 01:22:23.405168+00	finalizado	TRAMITE
539	291	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:47:33.541611+00	enproceso	TRAMITE
744	228	V-12345690	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-302827515	t	2020-06-30 19:38:59.812026+00	{"state":"validando"}	IMPUESTO
746	230	V-23555666	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070178787	t	2020-06-30 19:44:12.202112+00	ingresardatos	IMPUESTO
748	230	V-23555666	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070178787	t	2020-06-30 19:44:37.971408+00	{"state":"validando"}	IMPUESTO
586	298	null-null	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 22:49:43.796743+00	enproceso	TRAMITE
750	233	V-7555189	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-306166220	t	2020-06-30 20:11:45.016567+00	ingresardatos	IMPUESTO
752	233	V-7555189	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-306166220	t	2020-06-30 20:12:22.163939+00	{"state":"validando"}	IMPUESTO
754	235	V-18966554	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-400578116	t	2020-07-01 11:59:30.255968+00	ingresardatos	IMPUESTO
756	235	V-18966554	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-400578116	t	2020-07-01 12:10:52.274811+00	{"state":"validando"}	IMPUESTO
758	241	V-36985214	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-313993557	t	2020-07-01 12:39:34.952136+00	ingresardatos	IMPUESTO
760	241	V-36985214	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-313993557	t	2020-07-01 12:40:34.21095+00	{"state":"validando"}	IMPUESTO
762	242	V-36985214	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-313993557	t	2020-07-01 13:03:31.738601+00	ingresardatos	IMPUESTO
1140	373	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:09:30.848204+00	enrevision	TRAMITE
1141	373	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:09:30.861318+00	enrevision	TRAMITE
1181	379	V-1231931298	J-312645977	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 14:31:08.277381+00	enrevision	TRAMITE
1182	379	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-21 14:31:08.309972+00	enrevision	TRAMITE
764	245	V-123456741	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-01 13:13:31.00922+00	ingresardatos	IMPUESTO
796	324	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-01 14:04:22.271112+00	finalizado	TRAMITE
798	325	V-78945612	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-01 14:09:06.923916+00	validando	TRAMITE
800	326	V-30002000	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-01 14:13:33.550759+00	validando	TRAMITE
802	206	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-297143858	t	2020-07-01 14:26:35.508573+00	{"state":"finalizado"}	IMPUESTO
1126	368	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:25:41.658133+00	enrevision	TRAMITE
810	242	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-313993557	t	2020-07-01 14:36:28.406431+00	{"state":"finalizado"}	IMPUESTO
504	277	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-25 20:28:51.220302+00	finalizado	TRAMITE
506	278	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:18:19.70664+00	enproceso	TRAMITE
510	279	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-06-25 22:07:15.850543+00	validando	TRAMITE
513	278	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-25 22:38:38.475195+00	finalizado	TRAMITE
535	290	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:41:33.273263+00	enproceso	TRAMITE
812	247	V-12345652	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-296585156	t	2020-07-01 14:51:15.021445+00	ingresardatos	IMPUESTO
1129	370	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:31:39.625236+00	enrevision	TRAMITE
1172	378	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-20 17:18:51.132302+00	ingresardatos	IMPUESTO
1085	350	V-18921679	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-15 19:43:36.469331+00	enproceso	TRAMITE
814	247	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-296585156	t	2020-07-01 14:55:16.036465+00	{"state":"finalizado"}	IMPUESTO
816	245	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-070020091	t	2020-07-01 15:07:41.066851+00	{"state":"finalizado"}	IMPUESTO
1197	381	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-21 19:06:20.320091+00	enrevision	TRAMITE
497	276	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 19:06:07.748238+00	enrevision	TRAMITE
499	277	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 20:22:46.677223+00	enproceso	TRAMITE
821	326	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 15:26:54.339341+00	finalizado	TRAMITE
823	249	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-700020005	t	2020-07-01 15:38:01.424731+00	ingresardatos	IMPUESTO
830	250	V-78945612	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-314151612	t	2020-07-01 15:49:26.161521+00	ingresardatos	IMPUESTO
832	250	V-78945612	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-314151612	t	2020-07-01 15:50:33.202607+00	{"state":"validando"}	IMPUESTO
868	252	V-12934856	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-406576458	t	2020-07-02 16:21:46.902567+00	{"state":"validando"}	IMPUESTO
888	261	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 22:18:32.335293+00	ingresardatos	IMPUESTO
1001	341	V-1231931298	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 16:27:25.958401+00	{"state":"finalizado"}	IMPUESTO
1003	342	V-25848973	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-07-13 16:41:24.88859+00	ingresardatos	IMPUESTO
954	310	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-10 17:33:58.361514+00	{"state":"finalizado"}	IMPUESTO
1056	341	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-14 16:59:49.328302+00	enrevision	TRAMITE
849	251	V-12981762	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-410984694	t	2020-07-02 14:02:13.294929+00	{"state":"validando"}	IMPUESTO
1058	357	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-306020403	t	2020-07-14 18:06:20.8892+00	ingresardatos	IMPUESTO
1064	362	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-07-15 12:34:40.765564+00	ingresardatos	IMPUESTO
1005	343	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 16:42:27.45734+00	ingresardatos	IMPUESTO
967	334	V-12543654	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 01:02:24.117889+00	enproceso	TRAMITE
972	334	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-13 01:09:31.533035+00	finalizado	TRAMITE
978	328	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 13:08:50.062602+00	{"state":"finalizado"}	IMPUESTO
1026	336	V-5678987	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-13 19:30:55.774064+00	enproceso	TRAMITE
1143	372	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:17:58.250815+00	enrevision	TRAMITE
1144	372	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:17:58.250815+00	enrevision	TRAMITE
982	335	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	t	2020-07-13 13:43:14.378583+00	{"state":"finalizado"}	IMPUESTO
988	338	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-311456759	t	2020-07-13 13:48:16.402619+00	{"state":"finalizado"}	IMPUESTO
562	163	null-null	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-06-26 04:27:20.873159+00	ingresardatos	IMPUESTO
564	296	V-1231234444	V-1923812093	Un trámite de tipo Beneficio de Contribuyente ha sido creado	t	2020-06-26 06:44:52.45134+00	enrevision	TRAMITE
566	297	V-1231234444	V-1923812093	Un trámite de tipo Beneficio de Contribuyente ha sido creado	t	2020-06-26 06:47:30.877198+00	enrevision	TRAMITE
866	252	V-12934856	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-406576458	t	2020-07-02 16:19:57.555154+00	ingresardatos	IMPUESTO
882	258	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 21:47:47.966438+00	ingresardatos	IMPUESTO
870	253	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	t	2020-07-02 19:44:33.057281+00	ingresardatos	IMPUESTO
874	254	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 21:22:39.960649+00	ingresardatos	IMPUESTO
878	256	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 21:41:52.330477+00	ingresardatos	IMPUESTO
1072	345	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-15 16:42:59.518386+00	finalizado	TRAMITE
626	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.889366+00	finalizado	IMPUESTO
627	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.892688+00	finalizado	IMPUESTO
628	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.899163+00	finalizado	IMPUESTO
629	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.902389+00	finalizado	IMPUESTO
630	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.905627+00	finalizado	IMPUESTO
631	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.908885+00	finalizado	IMPUESTO
632	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.912126+00	finalizado	IMPUESTO
633	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.918123+00	finalizado	IMPUESTO
634	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.921334+00	finalizado	IMPUESTO
635	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.927119+00	finalizado	IMPUESTO
636	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.93176+00	finalizado	IMPUESTO
637	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.934951+00	finalizado	IMPUESTO
638	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.938292+00	finalizado	IMPUESTO
639	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.941518+00	finalizado	IMPUESTO
640	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.944752+00	finalizado	IMPUESTO
641	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.947877+00	finalizado	IMPUESTO
642	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.950765+00	finalizado	IMPUESTO
643	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.953861+00	finalizado	IMPUESTO
644	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.957173+00	finalizado	IMPUESTO
645	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.960366+00	finalizado	IMPUESTO
646	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.963419+00	finalizado	IMPUESTO
1024	336	V-5678987	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-07-13 19:30:55.768169+00	enproceso	TRAMITE
647	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.966536+00	finalizado	IMPUESTO
648	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.970117+00	finalizado	IMPUESTO
649	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:44:04.973424+00	finalizado	IMPUESTO
886	260	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 22:10:41.583764+00	ingresardatos	IMPUESTO
654	199	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-06-27 16:50:27.693809+00	{"state":"validando"}	IMPUESTO
907	267	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 18:33:31.425025+00	ingresardatos	IMPUESTO
1096	352	V-1923812093	V-18921679	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 20:07:39.477801+00	enproceso	TRAMITE
1099	352	V-1231931298	V-18921679	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 20:11:45.449384+00	enrevision	TRAMITE
909	268	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 18:40:42.222588+00	ingresardatos	IMPUESTO
1146	372	V-1923812093	J-312645978	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:20:47.071221+00	finalizado	TRAMITE
1147	372	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:20:47.088478+00	finalizado	TRAMITE
1098	352	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 20:07:39.502872+00	enproceso	TRAMITE
911	270	V-1293812738	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-07-09 12:12:37.735892+00	ingresardatos	IMPUESTO
1070	365	V-12354965	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-15 16:38:43.062497+00	ingresardatos	IMPUESTO
851	327	V-12934856	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-02 15:13:50.512562+00	enproceso	TRAMITE
590	181	null-null	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-06-26 23:17:15.038059+00	ingresardatos	IMPUESTO
1023	351	V-18496685	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-13 19:29:29.277204+00	ingresardatos	IMPUESTO
592	181	null-null	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-06-26 23:46:26.508527+00	{"state":"validando"}	IMPUESTO
1175	377	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-21 12:29:43.419+00	enrevision	TRAMITE
597	193	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	t	2020-06-27 01:36:27.634336+00	ingresardatos	IMPUESTO
543	292	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:48:49.670177+00	enproceso	TRAMITE
1042	340	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-14 15:21:42.813111+00	validando	TRAMITE
576	171	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-06-26 18:58:24.718913+00	ingresardatos	IMPUESTO
1097	352	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 20:07:39.498277+00	enproceso	TRAMITE
1100	352	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 20:11:45.449384+00	enrevision	TRAMITE
578	171	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-06-26 18:58:38.993864+00	{"state":"validando"}	IMPUESTO
1102	353	V-12543654	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-15 20:36:57.698841+00	validando	TRAMITE
580	173	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-06-26 20:41:34.670731+00	ingresardatos	IMPUESTO
582	173	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-26 22:42:37.350341+00	{"state":"validando"}	IMPUESTO
584	174	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-06-26 22:45:58.363933+00	ingresardatos	IMPUESTO
618	198	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-06-27 04:18:41.828186+00	ingresardatos	IMPUESTO
903	265	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 18:22:52.758241+00	ingresardatos	IMPUESTO
905	266	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-06 18:29:23.952297+00	ingresardatos	IMPUESTO
1021	350	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-07-13 18:59:39.891426+00	{"state":"finalizado"}	IMPUESTO
965	323	V-10528417	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 00:45:58.689675+00	ingresardatos	IMPUESTO
947	302	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-10 16:32:11.364479+00	{"state":"finalizado"}	IMPUESTO
620	198	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:18:59.615839+00	{"state":"validando"}	IMPUESTO
847	251	V-12981762	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-410984694	t	2020-07-02 13:55:56.080604+00	ingresardatos	IMPUESTO
720	319	V-12345688	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-06-30 18:57:03.69683+00	validando	TRAMITE
622	174	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 04:30:50.849376+00	{"state":"validando"}	IMPUESTO
976	328	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 13:05:24.399972+00	ingresardatos	IMPUESTO
980	335	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	t	2020-07-13 13:40:21.823894+00	ingresardatos	IMPUESTO
1148	374	V-1231931298	J-312645978	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:23:36.99382+00	enrevision	TRAMITE
1149	374	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:23:37.010412+00	enrevision	TRAMITE
986	339	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	t	2020-07-13 13:46:58.933594+00	ingresardatos	IMPUESTO
652	199	V-10555777	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-06-27 16:36:18.328194+00	ingresardatos	IMPUESTO
1136	372	undefined-312645978	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-16 13:47:33.323055+00	validando	TRAMITE
656	200	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-06-27 17:01:41.466493+00	ingresardatos	IMPUESTO
1201	381	V-12354965	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-22 21:35:24.360555+00	ingresardatos	IMPUESTO
658	200	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-06-30 12:58:42.910166+00	{"state":"validando"}	IMPUESTO
662	206	V-15999000	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-297143858	t	2020-06-30 17:57:40.436255+00	ingresardatos	IMPUESTO
716	209	V-12345688	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-410984694	t	2020-06-30 18:54:32.280094+00	ingresardatos	IMPUESTO
718	209	V-12345688	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-410984694	t	2020-06-30 18:55:16.030271+00	{"state":"validando"}	IMPUESTO
974	303	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 01:31:32.101582+00	{"state":"finalizado"}	IMPUESTO
984	338	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-311456759	t	2020-07-13 13:46:28.036453+00	ingresardatos	IMPUESTO
990	339	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	t	2020-07-13 13:49:32.232317+00	{"state":"finalizado"}	IMPUESTO
992	340	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 15:46:11.242445+00	ingresardatos	IMPUESTO
994	340	V-1231931298	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-13 15:49:44.551202+00	{"state":"finalizado"}	IMPUESTO
915	277	V-12345679	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070015357	t	2020-07-09 14:06:40.382111+00	ingresardatos	IMPUESTO
917	278	V-12345679	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070015357	t	2020-07-09 14:08:07.133829+00	ingresardatos	IMPUESTO
919	277	V-12345679	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070015357	t	2020-07-09 14:15:27.18203+00	{"state":"validando"}	IMPUESTO
956	311	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 17:36:13.46802+00	ingresardatos	IMPUESTO
958	312	V-1293812738	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	t	2020-07-10 17:38:48.870822+00	ingresardatos	IMPUESTO
766	320	V-20002000	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:17:17.788108+00	enproceso	TRAMITE
921	278	V-12345679	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-070015357	t	2020-07-09 14:16:38.889143+00	{"state":"validando"}	IMPUESTO
872	253	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-413060540	t	2020-07-02 19:51:02.795929+00	{"state":"finalizado"}	IMPUESTO
876	255	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 21:30:20.884036+00	ingresardatos	IMPUESTO
880	257	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 21:43:09.497351+00	ingresardatos	IMPUESTO
1180	378	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-21 14:10:14.820468+00	enrevision	TRAMITE
1142	373	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:09:30.863931+00	enrevision	TRAMITE
1183	379	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-21 14:31:08.316977+00	enrevision	TRAMITE
722	213	V-18455333	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316120198	t	2020-06-30 19:00:25.439898+00	ingresardatos	IMPUESTO
1145	372	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:17:58.250815+00	enrevision	TRAMITE
730	217	V-20000333	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316703649	t	2020-06-30 19:16:22.626473+00	ingresardatos	IMPUESTO
732	217	V-20000333	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316703649	t	2020-06-30 19:17:28.28983+00	{"state":"validando"}	IMPUESTO
734	226	V-12345690	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-302827515	t	2020-06-30 19:33:01.980484+00	ingresardatos	IMPUESTO
736	226	V-12345690	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-302827515	t	2020-06-30 19:33:41.487777+00	{"state":"validando"}	IMPUESTO
738	227	V-20000333	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316703649	t	2020-06-30 19:37:20.963383+00	ingresardatos	IMPUESTO
1150	374	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:23:37.016901+00	enrevision	TRAMITE
1114	358	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:22:37.022692+00	enrevision	TRAMITE
1164	376	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-19 22:19:18.876599+00	enrevision	TRAMITE
1168	376	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-003257176	t	2020-07-20 15:31:30.98507+00	ingresardatos	IMPUESTO
1111	375	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: V-18921679	t	2020-07-15 21:34:30.829195+00	ingresardatos	IMPUESTO
1151	374	V-1923812093	J-312645978	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:29:02.703031+00	finalizado	TRAMITE
1152	374	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:29:02.722306+00	finalizado	TRAMITE
1120	365	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:24:52.500637+00	enrevision	TRAMITE
1083	349	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 19:37:43.283951+00	enrevision	TRAMITE
740	228	V-12345690	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-302827515	t	2020-06-30 19:37:46.983594+00	ingresardatos	IMPUESTO
856	327	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-02 15:29:56.01619+00	finalizado	TRAMITE
770	321	V-12345696	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-01 13:24:37.00989+00	enproceso	TRAMITE
1038	339	V-1023910231	V-1923812093	Un trámite de tipo Beneficio de Contribuyente ha sido creado	t	2020-07-14 13:11:52.602415+00	enrevision	TRAMITE
864	328	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-02 15:55:42.688945+00	finalizado	TRAMITE
547	293	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:51:23.829598+00	enproceso	TRAMITE
551	294	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 01:52:28.677247+00	enproceso	TRAMITE
1013	348	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-13 17:02:07.266864+00	ingresardatos	IMPUESTO
1093	350	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-07-15 19:52:51.648619+00	finalizado	TRAMITE
825	249	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-700020005	t	2020-07-01 15:38:52.444418+00	{"state":"finalizado"}	IMPUESTO
828	325	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-01 15:42:58.602367+00	finalizado	TRAMITE
724	213	V-18455333	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-316120198	t	2020-06-30 19:01:06.107739+00	{"state":"validando"}	IMPUESTO
818	248	V-18455333	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-316120198	t	2020-07-01 15:17:49.730718+00	ingresardatos	IMPUESTO
570	165	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-26 17:42:35.852862+00	{"state":"validando"}	IMPUESTO
572	170	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-06-26 18:51:56.606695+00	ingresardatos	IMPUESTO
574	170	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-06-26 18:52:17.922487+00	{"state":"validando"}	IMPUESTO
1090	351	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 19:47:45.615655+00	enrevision	TRAMITE
1132	371	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 13:38:39.72353+00	enrevision	TRAMITE
923	283	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	t	2020-07-10 12:05:40.085842+00	ingresardatos	IMPUESTO
925	283	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	t	2020-07-10 13:20:45.06117+00	{"state":"finalizado"}	IMPUESTO
927	331	V-18496685	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-07-10 15:03:38.313648+00	enproceso	TRAMITE
931	298	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 15:53:54.141082+00	ingresardatos	IMPUESTO
933	298	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-10 15:55:28.11513+00	{"state":"finalizado"}	IMPUESTO
935	299	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 15:58:15.308731+00	ingresardatos	IMPUESTO
937	299	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-10 15:59:41.686705+00	{"state":"finalizado"}	IMPUESTO
941	301	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 16:26:17.050893+00	ingresardatos	IMPUESTO
1153	375	undefined-312645978	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-07-16 14:34:45.134499+00	validando	TRAMITE
943	301	V-1023910231	V-1923812093	Se ha validado el pago de una solicitud de pago de impuestos para el contribuyente: J-000202001	t	2020-07-10 16:27:29.73935+00	{"state":"finalizado"}	IMPUESTO
945	302	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 16:30:10.956804+00	ingresardatos	IMPUESTO
1050	341	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-14 15:28:47.895204+00	validando	TRAMITE
949	303	V-10528417	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 16:46:15.987469+00	ingresardatos	IMPUESTO
952	310	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-000202001	t	2020-07-10 17:33:05.022337+00	ingresardatos	IMPUESTO
1154	375	undefined-312645978	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-16 14:34:45.139045+00	validando	TRAMITE
1104	351	V-1923812093	V-25848973	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 20:41:48.252491+00	finalizado	TRAMITE
1105	351	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 20:41:48.274093+00	finalizado	TRAMITE
1107	352	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-15 20:42:15.910404+00	finalizado	TRAMITE
1106	352	V-1923812093	V-18921679	Se realizó la revisión de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 20:42:15.827588+00	finalizado	TRAMITE
1155	375	undefined-312645978	J-312645978	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:35:39.880899+00	enproceso	TRAMITE
1156	375	undefined-312645978	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-07-16 14:35:39.897004+00	enproceso	TRAMITE
1158	375	undefined-312645978	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:35:39.904854+00	enproceso	TRAMITE
884	259	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-070020091	t	2020-07-02 22:00:45.770935+00	ingresardatos	IMPUESTO
1101	352	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-15 20:11:45.449384+00	enrevision	TRAMITE
1103	353	V-12543654	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-07-15 20:36:57.715315+00	validando	TRAMITE
1157	375	undefined-312645978	V-1923812093	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-07-16 14:35:39.900748+00	enproceso	TRAMITE
\.


--
-- Data for Name: operacion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.operacion (id_operacion, nombre_op) FROM stdin;
\.


--
-- Data for Name: operatividad_terminal; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.operatividad_terminal (id_operatividad_terminal, destino, tipo, monto, tasa, habilitado) FROM stdin;
9	Caracas	BUSCAMA	610400	0.1	t
10	Puerto La Cruz	BUSCAMA	831200	0.1	t
11	Maracay	BUSCAMA	475690	0.1	t
12	Valencia	BUSCAMA	437520	0.1	t
13	San Cristóbal	BUSCAMA	416000	0.1	t
14	San Antonio Táchira	BUSCAMA	434560	0.1	t
15	El Vigía	BUSCAMA	407520	0.1	t
16	Mérida	BUSCAMA	359840	0.1	t
17	El Chivo	BUSCAMA	320800	0.1	t
18	Santa Bárbara	BUSCAMA	363280	0.1	t
19	La Fría	BUSCAMA	357440	0.1	t
20	Barinas	BUSCAMA	482640	0.1	t
21	Barquisimeto	BUSCAMA	234990	0.1	t
22	Puerto La Cruz	BUSETA	675350	0.1	t
23	Santa Bárbara	BUSETA	295165	0.1	t
24	Punto FIjo	BUSETA	196350	0.1	t
25	Barquisimeto	BUSETA	184635	0.1	t
26	El Vigía	BUSETA	331110	0.1	t
27	Mérida	BUSETA	292370	0.1	t
28	Mene de Mauroa	BUSETA	41265	0.1	t
29	Carora	BUSETA	130625	0.1	t
30	El Chivo	BUSETA	260650	0.1	t
31	Trujillo	BUSETA	128700	0.1	t
32	Cacigua	BUSETA	165000	0.1	t
33	Valencia	BUSETA	355485	0.1	t
34	Maracay	BUSETA	387530	0.1	t
35	Caracas	BUSETA	495950	0.1	t
36	Valera	BUSETA	120395	0.1	t
37	Boconó	BUSETA	163350	0.1	t
38	Caja Seca	BUSETA	143605	0.1	t
39	La Villa	BUSETA	37845	0.1	t
40	Machiques	BUSETA	56700	0.1	t
41	Paraguaipoa	BUSETA	45900	0.1	t
42	Perijá	BUSETA	79650	0.1	t
43	Barinas	BUSETA	39215	0.1	t
44	La Fría	BUSETA	290420	0.1	t
45	Ojeda	BUSETA	40140	0.1	t
46	Mene Grande	BUSETA	76500	0.1	t
47	Los Filuos	BUSETA	50400	0.1	t
48	Paraguachón	BUSETA	53100	0.1	t
49	Dabajuro	BUSETA	66150	0.1	t
50	San Felipe	BUSETA	283075	0.1	t
51	San Cristóbal	BUSETA	338000	0.1	t
52	San Antonio Táchira	BUSETA	353080	0.1	t
53	Paraguachón	CARRO POR PUESTO	106200	0.1	t
54	Paraguaipoa	CARRO POR PUESTO	91800	0.1	t
55	Barquisimeto	CARRO POR PUESTO	36927	0.1	t
56	Ojeda	CARRO POR PUESTO	80280	0.0560538116592	t
58	Santa Rita	CARRO POR PUESTO	22000	0.113636363636	t
59	Moján	CARRO POR PUESTO	59400	0.1	t
60	La Villa	CARRO POR PUESTO	75600	0.1	t
61	Punto Fijo	CARRO POR PUESTO	392700	0.1	t
62	Santa Bárbara	CARRO POR PUESTO	676000	0.1	t
63	San Cristóbal	CARRO POR PUESTO	676000	0.1	t
64	Coro	CARRO POR PUESTO	295900	0.1	t
65	Caja Seca	CARRO POR PUESTO	287210	0.1	t
66	Mene Grande	CARRO POR PUESTO	153000	0.1	t
67	Valera	CARRO POR PUESTO	240790	0.1	t
68	Mene Mauroa	CARRO POR PUESTO	82530	0.1	t
69	Dabajuro	CARRO POR PUESTO	132300	0.1	t
70	Casigua El Cubo	CARRO POR PUESTO	330000	0.1	t
71	El Vigía	CARRO POR PUESTO	662220	0.1	t
72	Carrasquero	CARRO POR PUESTO	70200	0.1	t
73	Filuos	CARRO POR PUESTO	100800	0.1	t
74	Nueva Lucha	CARRO POR PUESTO	22000	0.1	t
75	Santa Cruz	CARRO POR PUESTO	22000	0.1	t
76	Machiques	CARRO POR PUESTO	113400	0.1	t
77	Sinamaica	CARRO POR PUESTO	46000	0.1	t
57	Cabimas	CARRO POR PUESTO	34000	0.0882352941176	t
\.


--
-- Data for Name: ordenanza; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.ordenanza (id_ordenanza, descripcion, tarifa, id_valor, habilitado) FROM stdin;
1	Análisis, revisión, y aprobación de la memoria descriptiva, planos y proyecto de gas según normativa y especificaciones del servicio autónomo para el suministro de gas e infraestructura de Maracaibo (SAGAS)	25	2	t
2	Certificación de planos indicativos de distribución interna de servicio, sistema de regulación, ductería, etc.	1.5	2	t
3	Emisión del Permiso Construcción	20	2	t
23	Inspección para otorgar el permiso de habitabilidad para edificaciones multifamiliares (COM)	0.2	2	t
19	Inspección para otorgar el permiso de habitabilidad para edificaciones multifamiliares (COM)	0.1	2	t
20	Inspección para otorgar el permiso de habitabilidad a mini locales comerciales y oficinas (COM)	30	2	t
21	Inspección para otorgar el permiso de habitabilidad a locales comerciales, oficinas y centros industriales (COM)	0.2	2	t
22	Emisión del permiso de habitabilidad (COM)	20	2	t
24	Inspección para otorgar el permiso de condiciones habitables para mini locales comerciales (COM)	30	2	t
13	Pre Inspección durante la ejecución de la obra, por unidad residencial para confirmar y testificar que la construcción se está realizando de acuerdo a las normas y especificaciones del Servicio Autónomo para el Suministro de Gas e Infraestructura de Maracaibo (SAGAS) (RES)	4	2	t
14	Inspección final para otorgar el permiso de habitabilidad a viviendas (RES)	10	2	t
15	Inspección de instalación y verifiación de una (1) prueba neumática de disco (24 horas) (RES)	4	2	t
16	Comprobación y certifiación final de una (1) prueba neumática de disco (RES)	4	2	t
17	Incorporación a la red de gas por vivienda (RES)	6	2	t
18	Emisión del permiso de habitabilidad residencial (RES)	10	2	t
4	Pre Inspección durante la ejecución de la obra, por unidad comercial para confirmar y testificar que la construcción se está realizando de acuerdo a las normas y especificaciones del Servicio Autónomo para el Suministro de Gas e Infraestructura de Maracaibo (SAGAS) (COM)	8	2	t
5	Inspección final para otorgar el permiso de habitabilidad para edificaciones multifamiliares (COM)	0.2	2	t
6	Inspeccion final para otorgar el permiso de habitabilidad a mini locales comerciales, y oficinas (COM)	30	2	t
7	Inspección final para otorgar el permiso de habitabilidad a locales comerciales, oficinas y centros industriales (COM)	0.3	2	t
8	Inspección final para otorgar el permiso de habitabilidad para centros asistenciales, educativos, plantas eléctricas u otros (COM)	20	2	t
9	Inspección de instalación y verifiación de una (1) prueba neumática de disco (24 horas) (COM)	10	2	t
10	Comprobación y certifiación final de una (1) prueba neumática de disco (COM)	10	2	t
11	Incorporación a la red gas (COM)	10	2	t
12	Emisión de permiso de habitabilidad (COM)	20	2	t
25	Inspección para otorgar el permiso de condiciones habitables a locales comerciales, oficinas y centros industriales (COM)	0.3	2	t
26	Inspección para otorgar el permiso de condiciones habitables para centros asistenciales, educativos, plantas eléctricas u otras (COM)	20	2	t
27	Emisión del permiso de condiciones habitables comerciales (COM)	20	2	t
28	Inspección para otorgar el permiso de condiciones habitables para viviendas (RES)	4	2	t
29	Emisión del permiso de condiciones habitables residencial (RES)	10	2	t
30	Inspección para desincorporación del sistema de cobro de tarifas residenciales (RES)	2	2	t
31	Inspección para desincorporación del sistema de cobro de tarifas comerciales (RES)	10	2	t
32	Desincorporación de la red de gas residencial (RES)	4	2	t
33	Desincorporación de la red de gas comercial (RES)	12	2	t
34	Cualquier otro tramite Documental que deba realizarse por ante el Servicio Autónomo para el Suministro de Gas e Infraestructura de Maracaibo (SAGAS) (RES)	5	2	t
35	Certificación de Habitabilidad	0.2	2	t
36	Inspección por emisión de constancias de cumplimiento de normas técnicas CCNT	0.2	2	t
37	Constancias de inspección e instalación de generador o planta eléctica (uso doméstico)	10	2	t
38	Constancias de inspección e instalación de generador o planta eléctica (uso comercial)	50	2	t
39	Constancias de inspección e instalación de generador o planta eléctica (uso industrial)	100	2	t
40	Sociedad Civil, Cooperativas y OSP - Carro por Puesto (CPP)	20	2	t
41	Sociedad Civil, Cooperativas y OSP - Micro Bus (MB)	25	2	t
42	Sociedad Civil, Cooperativas y OSP - Autobús (AB)	30	2	t
43	Sociedad Civil, Cooperativas y OSP - Mixta	35	2	t
44	Sociedad Mercantil (Organización) - Carro por Puesto (CPP)	25	2	t
45	Sociedad Mercantil (Organización) - Micro Bus (MB)	30	2	t
46	Sociedad Mercantil (Organización) - Autobús (AB)	35	2	t
47	Sociedad Mercantil (Organización) - Mixta	40	2	t
48	Inspección	0.8	2	t
49	Inspección	0.8	2	t
50	Inspección	6	2	t
51	Constancia/Certificación	60	2	t
52	Constancia/Certificación	0.02	2	t
53	Edificación cuenta con CVUF	2	2	t
54	Edificación no cuenta con CVUF	4	2	t
55	Constancia/Certificación	0.05	2	t
56	Edificación cuenta con CVUF	2	2	t
57	Edificación no cuenta con CVUF	4	2	t
\.


--
-- Data for Name: ordenanza_tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.ordenanza_tramite (id_ordenanza_tramite, id_tramite, id_tarifa, petro, valor_calc, factor, factor_value, costo_ordenanza) FROM stdin;
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.pago (id_pago, id_procedimiento, referencia, monto, fecha_de_pago, aprobado, id_banco, fecha_de_aprobacion, concepto, metodo_pago, id_usuario) FROM stdin;
235	165	29688874	100000000	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
236	165	40000587	76960210	2020-06-26	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
237	170	1	31231241241	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
238	171	123	123124123123123	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
239	173	29877744	100000000	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
240	173	47000000	64660000	2020-06-26	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
285	325	123412345	1000000.0	2020-06-30	t	1	2020-07-01 14:28:11.778756+00	TRAMITE	TRANSFERENCIA	\N
291	247	7899	30000000	2020-07-01	t	14	2020-07-01 14:55:15.967365+00	IMPUESTO	PUNTO DE VENTA	\N
292	247	9012121212	2265000	2020-07-01	t	8	2020-07-01 14:55:15.967365+00	IMPUESTO	CHEQUE	\N
293	245	\N	63000000	2020-07-01	t	\N	2020-07-01 15:07:41.002446+00	IMPUESTO	EFECTIVO	\N
294	249	456789999	124500000	2020-07-01	t	2	2020-07-01 15:38:52.404891+00	IMPUESTO	TRANSFERENCIA	\N
295	250	123456789	17600000	2020-07-01	t	1	2020-07-01 17:15:06.309225+00	IMPUESTO	TRANSFERENCIA	\N
296	250	1234567888	50000000	2020-07-01	t	1	2020-07-01 17:21:42.133087+00	IMPUESTO	TRANSFERENCIA	\N
297	250	12345687	50000000	2020-07-01	t	1	2020-07-01 17:43:41.384891+00	IMPUESTO	TRANSFERENCIA	\N
298	251	383456768	21558000	2020-07-23	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
299	328	383438345	1000000.0	2020-07-02	t	1	2020-07-02 15:52:56.023119+00	TRAMITE	TRANSFERENCIA	\N
241	181	123456	131225000	2020-06-26	t	1	2020-06-27 03:57:30.760909+00	IMPUESTO	TRANSFERENCIA	\N
243	174	\N	0	2020-06-29	t	\N	2020-06-27 04:30:50.793404+00	IMPUESTO	EFECTIVO	\N
242	198	123123	60000000	2020-06-29	t	1	2020-06-27 04:44:04.819951+00	IMPUESTO	TRANSFERENCIA	\N
244	199	\N	87995999.999999999984	2020-06-29	f	\N	2020-06-27 16:50:27.55877+00	IMPUESTO	EFECTIVO	\N
245	200	\N	123000000	2020-07-01	t	\N	2020-06-30 12:58:42.828701+00	IMPUESTO	EFECTIVO	\N
246	200	87999	200000000	2020-07-01	t	4	2020-06-30 12:58:42.828701+00	IMPUESTO	TRANSFERENCIA	\N
248	300	2	20000000	2020-06-29	f	1	\N	TRAMITE	TRANSFERENCIA	\N
249	301	12	20000000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
250	303	3	600000000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
251	304	4	2400000000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
252	306	5	3000000	2020-06-22	f	1	\N	TRAMITE	TRANSFERENCIA	\N
253	311	6	200000.0	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
254	312	7	3000000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
255	313	8	3000000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
256	317	9	2500000	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
257	209	10	16645000	2020-07-01	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
258	319	11	1000000.0	2020-06-30	f	1	\N	TRAMITE	TRANSFERENCIA	\N
259	213	245465468	57616000	2020-06-29	f	3	\N	IMPUESTO	TRANSFERENCIA	\N
260	214	25212512	116048000	2020-07-01	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
262	217	25212515	55485000	2020-07-01	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
263	226	11	57616000	2020-06-29	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
265	227	25212515	55936000	2020-07-01	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
268	228	13	57616000	2020-07-01	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
269	230	25212515	56116000	2020-07-01	f	3	\N	IMPUESTO	TRANSFERENCIA	\N
270	233	4521532	115145000	2020-07-01	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
271	235	252125216	56203000	2020-07-01	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
273	241	25212510	56150000	2020-07-01	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
288	206	\N	61674000	2020-07-01	t	\N	2020-07-01 14:26:35.441993+00	IMPUESTO	EFECTIVO	\N
287	326	489000111	1000000.0	2020-07-01	t	1	2020-07-01 14:28:11.778756+00	TRAMITE	TRANSFERENCIA	\N
302	252	123456789	100000000	2020-07-02	f	2	\N	IMPUESTO	TRANSFERENCIA	\N
303	252	123456786	32280000	2020-07-02	f	1	\N	IMPUESTO	TRANSFERENCIA	\N
304	253	1212	5000000	2020-07-02	t	14	2020-07-02 19:51:02.733564+00	IMPUESTO	PUNTO DE VENTA	\N
305	253	\N	11000000	2020-07-02	t	\N	2020-07-02 19:51:02.733564+00	IMPUESTO	EFECTIVO	\N
306	262	89895	50000000	2020-07-03	t	14	2020-07-03 15:04:09.710614+00	IMPUESTO	PUNTO DE VENTA	\N
307	262	\N	69970000	2020-07-03	t	\N	2020-07-03 15:04:09.710614+00	IMPUESTO	EFECTIVO	\N
308	329	67789099	1000000.0	2020-07-03	f	1	\N	TRAMITE	TRANSFERENCIA	\N
309	277	123456756	11000000	2020-07-09	f	1	\N	IMPUESTO	TRANSFERENCIA	156
310	278	123456756	5000000	2020-07-09	f	2	\N	IMPUESTO	TRANSFERENCIA	156
311	278	123456756	5087000	2020-07-09	f	3	\N	IMPUESTO	TRANSFERENCIA	156
314	283	\N	140000	2020-07-10	t	\N	2020-07-10 13:20:44.682294+00	IMPUESTO	EFECTIVO	116
315	283	\N	5000	2020-07-10	t	\N	2020-07-10 13:20:44.682294+00	IMPUESTO	CREDITO_FISCAL	116
316	298	\N	116000	2020-07-10	t	\N	2020-07-10 15:55:26.712598+00	IMPUESTO	CREDITO_FISCAL	116
317	299	\N	27090000	2020-07-10	t	\N	2020-07-10 15:59:40.607466+00	IMPUESTO	CREDITO_FISCAL	116
319	302	3634646463	3000000	2020-07-10	t	8	2020-07-10 16:32:10.368419+00	IMPUESTO	CHEQUE	116
320	302	\N	500000	2020-07-10	t	\N	2020-07-10 16:32:10.368419+00	IMPUESTO	EFECTIVO	116
321	302	3634646463	4000000	2020-07-10	t	14	2020-07-10 16:32:10.368419+00	IMPUESTO	PUNTO DE VENTA	116
289	242	8888899999	56145000	2020-07-01	t	1	2020-07-01 14:36:28.350918+00	IMPUESTO	PUNTO DE VENTA	\N
290	247	890765444	25000000	2020-07-01	t	1	2020-07-01 14:55:15.967365+00	IMPUESTO	TRANSFERENCIA	\N
318	301	3634646463	116000	2020-07-10	t	1	2020-07-10 16:27:28.188027+00	IMPUESTO	TRANSFERENCIA	116
322	310	3634646463	10000000	2020-07-10	t	8	2020-07-10 17:33:56.336678+00	IMPUESTO	TRANSFERENCIA	116
323	6	\N	100000	2020-07-10	t	\N	2020-07-10 17:41:17.348487+00	CONVENIO	EFECTIVO	116
324	303	3634646463	15000000	2020-07-13	t	4	2020-07-13 01:31:30.980018+00	IMPUESTO	TRANSFERENCIA	116
325	328	12345678	100000000	2020-07-08	t	30	2020-07-13 13:08:48.211087+00	IMPUESTO	TRANSFERENCIA	116
326	328	12345678	5000000	2020-07-10	t	7	2020-07-13 13:08:48.211087+00	IMPUESTO	TRANSFERENCIA	116
327	328	456123789	4706000	2020-07-13	t	2	2020-07-13 13:08:48.211087+00	IMPUESTO	PUNTO DE VENTA	116
328	335	000877	52000000	2020-07-13	t	8	2020-07-13 13:43:11.43049+00	IMPUESTO	PUNTO DE VENTA	116
329	338	12345678	87000	2020-07-13	t	2	2020-07-13 13:48:15.334305+00	IMPUESTO	TRANSFERENCIA	116
330	339	\N	87000	2020-07-13	t	\N	2020-07-13 13:49:31.196749+00	IMPUESTO	CREDITO_FISCAL	116
331	340	\N	19000	2020-07-13	t	\N	2020-07-13 15:49:43.016642+00	IMPUESTO	CREDITO_FISCAL	117
332	340	456554565	177101000	2020-07-13	t	1	2020-07-13 15:49:43.016642+00	IMPUESTO	TRANSFERENCIA	117
333	7	\N	74000	2020-07-13	t	\N	2020-07-13 15:52:50.598093+00	CONVENIO	EFECTIVO	116
334	341	46879455	27090000	2020-07-13	t	2	2020-07-13 16:27:24.960877+00	IMPUESTO	TRANSFERENCIA	117
335	343	\N	15000000	2020-07-13	t	\N	2020-07-13 16:44:23.08662+00	IMPUESTO	CREDITO_FISCAL	117
336	343	465123585	12090000	2020-07-13	t	2	2020-07-13 16:44:23.08662+00	IMPUESTO	TRANSFERENCIA	117
337	12	\N	200000000	2020-07-13	t	\N	2020-07-13 16:51:06.153378+00	CONVENIO	EFECTIVO	116
338	348	\N	15000000	2020-07-13	t	\N	2020-07-13 17:04:40.260167+00	IMPUESTO	CREDITO_FISCAL	117
339	348	789546568	12206000	2020-07-13	t	3	2020-07-13 17:04:40.260167+00	IMPUESTO	PUNTO DE VENTA	117
340	350	989890	50000000	2020-07-13	t	14	2020-07-13 18:59:38.037471+00	IMPUESTO	PUNTO DE VENTA	116
341	350	898945456	20000000	2020-07-13	t	8	2020-07-13 18:59:38.037471+00	IMPUESTO	TRANSFERENCIA	116
342	340	1234567868	1000000.00	2020-07-14	t	1	2020-07-14 15:24:11.709181+00	TRAMITE	TRANSFERENCIA	58
343	341	123123123	1000000.00	2020-07-14	t	1	2020-07-14 16:57:11.481725+00	TRAMITE	TRANSFERENCIA	58
344	23	123456455	3000000	2020-07-10	t	5	2020-07-15 17:22:58.322455+00	CONVENIO	TRANSFERENCIA	83
346	24	3634646464	4020000	2020-07-30	f	1	\N	CONVENIO	TRANSFERENCIA	165
347	347	1231412312	1000000.0	2020-07-15	t	11	2020-07-15 19:05:54.379185+00	TRAMITE	TRANSFERENCIA	118
349	349	12314123125	1000000.0	2020-07-15	t	11	2020-07-15 19:37:41.710633+00	TRAMITE	TRANSFERENCIA	118
350	351	123123123	1000000.0	2020-07-15	t	11	2020-07-15 19:47:44.589342+00	TRAMITE	TRANSFERENCIA	118
351	352	391227475	1000000.00	2020-07-15	t	1	2020-07-15 20:07:39.39593+00	TRAMITE	TRANSFERENCIA	181
352	353	476477577	1000000.0	2020-07-15	f	1	\N	TRAMITE	TRANSFERENCIA	163
357	358	53353535353	1000000.0	2020-07-03	t	8	2020-07-16 13:22:35.157748+00	TRAMITE	TRANSFERENCIA	192
363	364	53353535356	1000000.0	2020-07-03	t	8	2020-07-16 13:24:35.920108+00	TRAMITE	TRANSFERENCIA	192
364	365	533535353	1000000.0	2020-07-03	t	8	2020-07-16 13:24:51.069615+00	TRAMITE	TRANSFERENCIA	192
365	366	746574656	1000000.0	2020-07-03	t	8	2020-07-16 13:25:10.145422+00	TRAMITE	TRANSFERENCIA	192
367	368	746574656	1000000.0	2020-07-03	t	15	2020-07-16 13:25:40.404514+00	TRAMITE	TRANSFERENCIA	192
369	370	112986734	1000000.0	2020-07-03	t	15	2020-07-16 13:31:37.731847+00	TRAMITE	TRANSFERENCIA	192
370	371	253453423	1000000.0	2020-07-16	t	8	2020-07-16 13:38:37.382146+00	TRAMITE	TRANSFERENCIA	192
371	372	23522523552	1000000.00	2020-07-15	t	1	2020-07-16 13:52:44.979626+00	TRAMITE	TRANSFERENCIA	192
372	373	243224332	1000000.0	2020-07-16	t	1	2020-07-16 14:09:28.210906+00	TRAMITE	TRANSFERENCIA	192
373	374	453453545	1000000.0	2020-07-16	t	1	2020-07-16 14:23:35.766739+00	TRAMITE	TRANSFERENCIA	192
374	375	243354645	1000000.00	2020-07-16	t	1	2020-07-16 14:35:39.808672+00	TRAMITE	TRANSFERENCIA	192
375	376	588888441	1000000	2020-07-19	t	19	2020-07-19 22:19:16.91203+00	TRAMITE	PUNTO DE VENTA	205
376	377	546372851	1000000	2020-07-21	t	8	2020-07-21 12:29:41.381254+00	TRAMITE	TRANSFERENCIA	207
377	378	1581891651	1000000	2020-07-21	t	9	2020-07-21 14:10:11.544049+00	TRAMITE	TRANSFERENCIA	197
378	379	123124123	1000000	2020-07-21	t	10	2020-07-21 14:31:05.501346+00	TRAMITE	TRANSFERENCIA	197
379	380	222333444	1000000	2020-07-21	t	8	2020-07-21 17:50:27.086854+00	TRAMITE	TRANSFERENCIA	163
380	381	666777888	1000000	2020-07-21	t	8	2020-07-21 19:06:17.864771+00	TRAMITE	TRANSFERENCIA	208
381	382	777888999	1000000	2020-07-23	t	8	2020-07-23 03:30:13.166609+00	TRAMITE	TRANSFERENCIA	208
\.


--
-- Data for Name: pago_manual; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.pago_manual (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- Data for Name: parroquia; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.parroquia (id, nombre) FROM stdin;
61	BOLIVAR
62	CACIQUE MARA
63	CECILIO ACOSTA
64	CHIQUINQUIRA
65	COQUIVACOA
66	CRISTO DE ARANZA
68	IDELFONSO VASQUEZ
69	JUANA DE AVILA
70	LUIS HURTADO HIGUERA
71	MANUEL DAGNINO
72	OLEGARIO VILLALOBOS
73	RAUL LEONI
74	SAN ISIDRO
75	SANTA LUCIA
76	VENANCIO PULGAR
108	ANTONIO BORJAS ROMERO
109	CARACCIOLO PARRA PEREZ
110	FRANCISCO EUGENIO BUSTAMANTE
\.


--
-- Data for Name: permiso_de_acceso; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.permiso_de_acceso (id_permiso, id_usuario, id_tipo_tramite) FROM stdin;
3	65	6
4	65	7
5	65	8
6	65	10
7	65	11
8	65	12
9	65	13
10	57	1
11	57	2
12	57	3
16	71	0
17	73	17
18	75	18
19	82	21
24	68	14
25	68	15
26	68	16
27	68	22
28	68	23
29	68	24
30	68	25
31	116	5
32	116	27
36	117	27
37	117	26
38	117	5
39	117	28
40	168	5
\.


--
-- Data for Name: propietario; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.propietario (id_propietario, razon_social, cedula, rif, email) FROM stdin;
1	Luis Acurero	V26775497	V267754973	13luismb@gmail.com
2	Vivian Palacios	V26514270	V26514270	palaciosvivi14@gmail.com
3	Luis Acurero	V26775497	V267754973	13luismb@gmail.com
4	Vivian Palacios	V26514270	V26514270	palaciosvivi14@gmail.com
5	Luis Acurero	V26775497	V267754973	13luismb@gmail.com
6	Vivian Palacios	V26514270	V26514270	palaciosvivi14@gmail.com
7	Luis Acurero	V26775497	V267754973	13luismb@gmail.com
8	Vivian Palacios	V26514270	V26514270	palaciosvivi14@gmail.com
9	Luis Acurero	V26775497	V267754973	13luismb@gmail.com
10	Vivian Palacios	V26514270	V26514270	palaciosvivi14@gmail.com
11	asdasd	\N	\N	\N
12	asdasd	\N	\N	\N
13	asdasd	\N	\N	\N
14	asdasd	\N	\N	\N
15	asdasd	\N	\N	\N
16	asdasd	\N	\N	\N
17	asdasd	\N	\N	\N
18	asdasd	\N	\N	\N
\.


--
-- Data for Name: propietario_inmueble; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.propietario_inmueble (id_propietario_inmueble, id_propietario, id_inmueble) FROM stdin;
9	17	21
\.


--
-- Data for Name: recaudo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.recaudo (id_recaudo, nombre_largo, nombre_corto, obligatorio, planilla, extension) FROM stdin;
8	Autorización para Trámites a Terceros (si el caso lo amerita)	AutorizacionTramitesTerceros	f	\N	image/*
9	Copia de Cedula Legible del Tramitante o Tercero (si el caso lo amerita)	CedulaTercero	f	\N	image/*
61	Original del Visto Bueno emitido por la Asociación de Vecinos del sector y/o Consejo comunal	VistoBueno	t	\N	image/*
62	Plano de Distribución Interna del local con medidas a escala incluyendo la ubicación de los puestos de estacionamiento (Impreso y Digital en un CD, Avalado por un Arquitecto)	VistoBueno	t	\N	image/*
63	En caso de poseer Conformidad de Uso otorgada en años anteriores, deberá consignar copia de la misma	ConformidadUso	f	\N	image/*
64	Original y copia de la Solvencia de Inmuebles Urbanos o en su defecto la resolución de Exoneración respectiva emitida por SEDEMAT.	VistoBueno	t	\N	image/*
65	Solvencia de Inmuebles Urbanos del Local	Solvencia	f	\N	image/*
66	Plano de Distribución Interna del Local con medidas a escala (Impreso y Digital en CD, Avalado por un Arquitecto formato 2010 ACAD)	Planos	f	\N	image/*
4	Documento de Propiedad del Terreno Notariado y Registrado (copia)	DocumentoDePropiedad	t	\N	image/*
5	Original y copia del Plano de Mensura Catastrado en tamaño original, firmado y sellado por la Dirección de Catastro (original)	PlanoMensura	t	\N	image/*
6	Copia del RIF del Propietario	RIFPropietario	t	\N	image/*
7	Copia de Cedula de Identidad Legible del Propietario	CedulaPropietario	t	\N	image/*
10	Planos del Proyecto de Instalaciones de Gas (en CD)	PlanosInstalacionGas	t	\N	image/*
13	Memoria descriptiva del proyecto de Gas (en CD)	MemoriaDesc	t	\N	image/*
14	Memoria del cálculo del sistema de Gas (en CD)	MemoriaCalculo	t	\N	image/*
11	Detalles del Proyecto de Instalaciones de Gas (Tanquilla Principal de Seccionamiento, Detalle de zanja, Detalle de Válvulas de Equipos, Detalle de Sistema de Regulación, Detalle de Ductos de Gas, Detalle de Venteo, Detalle de Soportes, Isometría de Gas, Especificaciones) (en CD)	DetalleProyecto	t	\N	image/*
15	Especificaciones técnicas del Proyecto de Gas (en CD)	EspecificacionesTecnicas	t	\N	image/*
12	Capas cargadas de los Siguientes Servicios: Aguas Servidas, Aguas Blancas, Aguas de Lluvia, Electricidad u Otros Servicios (en CD)	CapasServicios	t	\N	image/*
21	Copia de Constancia de Servicio SAGAS actualizada	ConstanciaSAGAS	t	\N	image/*
22	Copia de Variables Urbanas expedida por la Alcaldía de Maracaibo	VariablesUrb	t	\N	image/*
26	Un (1) Juego de Planos Impresos de Arquitectura	PlanosArq	t	\N	image/*
16	3 Juegos de Planos del Proyecto de Gas Impresos de Cada Nivel de Arquitectura (90cm. x 60cm.)	JuegoPlanosCadaNivel	t	\N	image/*
18	3 Juegos de Planos de Detalles de Gas (90cm. x 60cm.)	JuegoPlanosDetallesGas	t	\N	image/*
19	3 Juegos de Memoria de Cálculo del Proyecto de Gas (90cm. x 60cm.)	JuegoPlanosProyectoGas	t	\N	image/*
20	3 Juegos de Especificaciones Técnicas del Proyecto de Gas (90cm x. 60cm.)	JuegoPlanosEspecificacionesProyectoGas	t	\N	image/*
17	3 Juegos de Planos de Detalles de Gas (90cm. x 60cm.)	JuegoPlanosDetallesGas	t	\N	image/*
23	Tener en Expediente SAGAS: Inspecciones de las instalaciones de Gas	ExpSAGASInstGas	t	\N	image/*
24	Tener en Expediente SAGAS: Inspecciones de Pruebas de Hermeticidad con Carta de Registro Original firmada y sellada	ExpSAGASHermeticidad	t	\N	image/*
25	Tener en Expediente SAGAS: Inspección Final de las Instalaciones de Gas	ExpSAGASInspFinal	t	\N	image/*
27	Tener en Expediente SAGAS: Inspección Final de la Obra, para constatar que no posee Servicio de Gas	ExpSAGASFinalObra	t	\N	image/*
28	Copia de Permiso de Construcción SAGAS	PermisoConstruccionSAGAS	t	\N	image/*
29	Documento Notariado donde se especifica que el inmueble no contará con instalaciones del servicio de gas	DocNotInstGas	t	\N	image/*
30	Copia del Documento de Propiedad del Inmueble y Plano de Mensura Registrado	DocPropiedadPlanoMensura	t	\N	image/*
35	Copia del pago de la factura de los Servicios Municipales (GAS, ASEO, INMUEBLE).	FacturaServiciosMunicipales	t	\N	image/*
31	Constancia de Nomenclatura emitido por la Oficina Municipal de Catastro (si no la menciona el documento)	ConstanciaNomenclatura	f	\N	image/*
32	Para Urbanización, Villas y Conjuntos residenciales, consignar plano de parcelamiento.	PlanoParcelamiento	f	\N	image/*
57	Plano de Distribución Interna del local con medidas a escala incluyendo la ubicación de los puestos de estacionamiento (Impreso Avalado por un Arquitecto y Digital en versión AutoCAD 2010 en un CD)	PlanoDist	t	\N	image/*
33	Para los Centros Comerciales presentar plano de distribución de locales con sus respectivas nomenclaturas del nivel donde se encuentra el local.	PlanoDistribucion	f	\N	image/*
34	Si el trámite no lo realiza el Propietario, presentar un poder y copia de la Cédula de Identidad del mismo.	PoderCopiaCedulaTramitante	f	\N	image/*
36	Fotocopia Legible de la Cedula de Identidad del Solicitante	CedulaSolicitante	t	\N	image/*
37	Comunicación solicitando la Renovación de la Certificación de Prestación de Servicio de Transporte, dirigida al Presidente del Instituto, y la misma debe contener: Nombre legal de la Organización, Sectores que se benefician con la prestación del servicio y Nombre y firma del Representante Legal de la Organización	ComunicacionRenovacion	t	\N	image/*
38	Copia de la última Acta de Asamblea celebrada por la organización	ActaAsamblea	t	\N	image/*
41	Copia de la última Certificación de Prestación de Servicio otorgada por la Institución	CertificacionDePrestacion	t	\N	image/*
44	Para terreno ejido: Copia del documento de bienhechurías del inmueble notariado o constancia de residencia emitida por el consejo comunal.	Bienhechurias	f	\N	image/*
53	Original y Copia de la Constancia de Cumplimiento de Normas Tecnicas emitida por el Instituto Autonomo Cuerpo de Bomberos del Municipio Maracaibo	CCNT	t	\N	image/*
42	Copia de Pago de Servicios Municipales para Barrios Consolidados, Urbanizaciones y Locales Comerciales	PagosMunicipales	f	\N	image/*
43	Para terreno propio: Copia del documento de propiedad del inmueble registrado y notariado	DocumentoPropiedad	f	\N	image/*
45	Copia del documento de propiedad del inmueble	DocumentoPropiedad	t	\N	image/*
46	Si el inmueble pertenece a una sucesión presentar copia de la planilla sucesoral y RIF	PlanillaSucesorial	f	\N	image/*
47	Si el inmueble pertenece a una persona jurídica presentar copia del RIF.	CopiaRif	f	\N	image/*
48	Si es un parcelamiento u urbanización presentar documento, relación de parcelas vendidas y Constancia de Habitabilidad	DeTodo	f	\N	image/*
49	Copia de Nomenclatura emitido por la Oficina Municipal de Catastro	Nomenclatura	t	\N	image/*
40	Planilla de Registro de Unidades, referida a los datos de las unidades que presten servicio en la organización, y las mismas deben estar matriculadas como transporte público (formato digital e impreso ver anexo)	PlanillaRegistrosUnidades	t	http://localhost:5000/recaudos/PLANILLA_DE_REGISTRO_DE_UNIDADES.xls	.xls
50	Copia del documento de propiedad o contrato de arrendamiento a nombre de la empresa notariado o visado por el Colegio de Abogados	DocPropiedad	t	\N	image/*
51	Croquis de Ubicacion con Punto de Referencia	Croquis	t	\N	image/*
54	Dos (2) fotografias de la fachada del inmueble	Fachada	t	\N	image/*
55	Dos (2) copias del Registro de Comercio (Acta Constitutiva - Estatutos)	RegistroComercio	t	\N	image/*
56	Copia del Recibo de CORPOELEC	ReciboCorpoelec	f	\N	image/*
58	Original y copia de Solvencia Municipal sobre Inmueble Urbano vigente	Solvencia	t	\N	image/*
60	Fotocopia legible de la Cedula de Identidad del Propietario del Inmueble	CedulaPropietario	t	\N	image/*
59	En caso de que el establecimiento comercial posea renta de licores anterior debe presentar copia de la misma	Licores	f	\N	image/*
52	Constancia de Nomenclatura expedida por la Oficina Municipal de Catastro (en caso de que el documento de registro no lo especifique)	ConstanciaNomenclatura	f	\N	image/*
39	Planilla de Junta Directiva, referida a los datos de los miembros de la organización (formato digital e impreso ver anexo)	PlanillaJuntaDirectiva	t	http://localhost:5000/recaudos/PLANILLA_DE_JUNTA_DIRECTIVA.xls	.xls
67	Fotocopia legible del documento de identidad o RIF	DocIdentidad	t	\N	image/*
72	Fotocopia legible del RIF	RIF	t	\N	.pdf
68	Registro de Comercio	RegistroComercio	f	\N	.pdf
69	Contrato de Arrendamiento o Titulo de Propiedad segun la condición del inmueble	Contrato	f	\N	.pdf
71	Tres primeras facturas en blanco	Facturas	f	\N	.pdf
70	Constancia de Cumplimiento de Normas Técnicas emitido por el Cuerpo de Bomberos de Maracaibo	CCNT	f	\N	image/*
\.


--
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
\.


--
-- Data for Name: seccion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.seccion (id_seccion, nombre) FROM stdin;
1	Datos del Solicitante
2	Solicitud de Inspeccion
3	Datos de Inspeccion
4	Datos del Propietario o Tramitante
5	Datos de Permiso de Construccion
6	Datos de Permiso de Habitabilidad
7	Datos Técnicos
8	Datos del Informe
9	Datos de Propietario(s)
10	Datos del Conjunto Residencial
11	Datos del Inmueble y/o Parcela
13	Código Catstral
14	Planos
12	Observaciones
15	Estimación Simple
16	Datos del Apartado
17	Datos de la Organización
18	Datos del Representante Legal de la Organización
19	Linderos Actuales del Inmueble
20	Datos de Nomenclatura
21	Datos de la Empresa
22	Datos de la Unidad Educativa
23	Datos de la Empresa o Comercio
24	Distribución
25	Croquis y Plano
26	Datos del Contribuyente
27	Datos de la Sucursal
28	Actividades Económicas
29	Datos de la Licencia
\.


--
-- Data for Name: tarifa_inspeccion; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tarifa_inspeccion (id_tarifa, id_ordenanza, id_tipo_tramite, formula, utiliza_codcat, id_variable) FROM stdin;
1	1	8	\N	f	\N
3	3	8	\N	f	\N
5	5	10	\N	t	\N
6	6	10	\N	f	\N
7	7	10	\N	t	\N
8	8	10	\N	f	\N
9	9	10	\N	f	\N
10	10	10	\N	f	\N
11	11	10	\N	f	\N
12	12	10	\N	f	\N
13	13	10	\N	f	\N
14	14	10	\N	f	\N
15	15	10	\N	f	\N
16	16	10	\N	f	\N
18	18	10	\N	f	\N
19	19	11	\N	t	\N
20	20	11	\N	f	\N
21	21	11	\N	t	\N
22	22	11	\N	f	\N
23	23	12	\N	t	\N
25	25	12	\N	t	\N
27	27	12	\N	f	\N
29	29	12	\N	f	\N
30	30	12	\N	f	\N
31	31	12	\N	f	\N
34	34	12	\N	f	\N
35	35	2	\N	t	\N
36	36	1	\N	t	\N
37	37	3	\N	f	\N
38	38	3	\N	f	\N
39	39	3	\N	f	\N
2	2	8	\N	f	1
4	4	10	\N	f	2
17	17	10	\N	f	3
24	24	12	\N	f	4
26	26	12	\N	f	4
28	28	12	\N	f	4
32	32	12	\N	f	4
33	33	12	\N	f	5
40	40	21	\N	f	\N
41	41	21	\N	f	\N
42	42	21	\N	f	\N
43	43	21	\N	f	\N
44	44	21	\N	f	\N
45	45	21	\N	f	\N
46	46	21	\N	f	\N
47	47	21	\N	f	\N
48	48	23	\N	f	\N
49	49	24	\N	f	\N
50	50	25	\N	f	\N
51	51	25	\N	f	\N
52	52	24	\N	t	\N
53	53	24	\N	f	\N
54	54	24	\N	f	\N
55	55	23	\N	t	\N
56	56	23	\N	f	\N
57	57	23	\N	f	\N
\.


--
-- Data for Name: template_certificado; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.template_certificado (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- Data for Name: tipo_tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, sufijo, nombre_corto, formato, planilla, certificado, utiliza_informacion_catastral, pago_previo, costo_petro, planilla_rechazo) FROM stdin;
8	2	Permiso de Construccion	\N	pd	Permiso de Construccion	SAGAS-004	sagas-solt-PC	sagas-cert-PC	f	f	\N	\N
10	2	Permiso de Habitabilidad con Instalaciones de Servicio de Gas	\N	pd	Habitabilidad con Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	t	f	\N	\N
11	2	Permiso de Habitabilidad sin Instalaciones de Servicio de Gas	\N	pd	Habitabilidad sin Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	t	f	\N	\N
12	2	Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas	\N	pd	Condiciones Habitables con Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	t	f	\N	\N
13	2	Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas	\N	pd	Condiciones Habitables sin Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	t	f	\N	\N
0	0	Casos Sociales	\N	pa	Casos Sociales	ABMM-001	\N	\N	\N	f	\N	\N
17	4	Tasa de Salida de Pasajeros	\N	tl	Tasa de Salida	SEDETEMA-001	sedetema-solt-TS	sedetema-cert-TS	f	t	\N	\N
3	1	Instalacion de Plantas Electricas	\N	pd	Plantas Electricas	CBM-003	bomberos-solt	bomberos-cert-IPE	f	f	\N	\N
19	6	Multa	\N	ml	Multa	IMA-001	\N	constancia-multas	f	f	\N	\N
20	7	Multa	\N	ml	Multa	PMM-001	\N	constancia-multas	f	f	\N	\N
25	3	Conformidad de la Edificación y Uso Locales en Centros Comerciales	\N	ompu	Uso Conforme: Locales	CPU-OMPU-AU-004	cpu-solt-UC-CC	cpu-cert-UC-CC	f	f	\N	cpu-rechazo
23	3	Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales	\N	ompu	Uso Conforme: Actividades Comerciales	CPU-OMPU-AU-001	cpu-solt-UC-AE	cpu-cert-UC-AE	t	f	\N	cpu-rechazo
21	8	Certificación para Prestar Servicio de Transporte Público Urbano	\N	pd	Servicio Transporte Público	IMTCUMA-001	\N	imtcuma-cert-STP	f	f	\N	\N
24	3	Conformidad de la Edificación y Uso Unidades Educativas	\N	ompu	Uso Conforme: Unidades Educativas	CPU-OMPU-AU-003	cpu-solt-UC-UE	cpu-cert-UC-UE	t	f	\N	cpu-rechazo
5	9	Pago de Impuestos	\N	pi	Pago de Impuestos	\N	\N	\N	f	f	\N	\N
26	9	Beneficio de Contribuyente	\N	bc	BC	\N	\N	\N	f	f	\N	\N
27	9	Registro de Contribuyente	\N	rc	Registro de Contribuyente	\N	\N	\N	f	f	\N	\N
7	2	Constancia de Servicio Persona Juridica	12000000	pa	Servicio Persona Juridica	SAGAS-003	sagas-solt-CS	sagas-cert-CS	t	t	24	\N
6	2	Constancia de Servicio Residencial	3000000	pa	Servicio Residencial	SAGAS-002	sagas-solt-CS	sagas-cert-CS	t	t	6	\N
14	3	Codigo Catastral para Casas	3000000	cr	CC	CPU-OMCAT-001	cpu-solt-CCC	cpu-cert-CC	f	t	6	\N
15	3	Codigo Catastral para Apartamentos	3000000	cr	CC	CPU-OMCAT-001	cpu-solt-CCA	cpu-cert-CC	f	t	6	\N
2	1	Constancia de Habitabilidad	100000.0	pa	Habitabilidad	CBM-002	bomberos-solt	bomberos-cert-HAB	t	t	0.2	\N
1	1	Cumplimiento de Normas Tecnicas	100000.0	pa	Normas Tecnicas	CBM-001	bomberos-solt	bomberos-cert-CCNT	t	t	0.2	\N
16	3	Solvencia de Inmuebles Urbanos	3000000	cr	SIU	CPU-OMCAT-002	cpu-solt-SIU	cpu-cert-SIU	f	t	6	\N
18	5	Apartado de Bohío	2500000	pa	Apartado de Bohío	SEDEPAR-001	sedepar-solt-AB	sedepar-cert-AB	f	t	5	\N
22	3	Constancia de Nomenclatura	200000.0	cr	NM	CPU-OMCAT-003	cpu-solt-NM	cpu-cert-NM	f	t	0.4	\N
28	9	Solicitud de Licencia de Actividades Económicas	1000000	lae	Licencia de Actividades Económicas	SEDEMAT-001	sedemat-solt-LAE	sedemat-cert-LAE	f	t	2	\N
\.


--
-- Data for Name: tipo_tramite_recaudo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tipo_tramite_recaudo (id_tipo_tramite, id_recaudo, fisico) FROM stdin;
6	4	t
6	5	t
6	6	f
6	7	f
6	8	f
6	9	f
7	4	t
7	5	t
7	6	f
7	7	f
7	8	f
7	9	f
8	10	t
8	11	t
8	12	t
8	13	t
8	14	t
8	15	t
8	16	t
8	17	t
8	18	t
8	19	t
8	20	t
10	21	f
10	22	t
10	23	t
10	24	t
10	25	t
11	21	f
11	22	t
11	26	t
11	27	t
12	21	f
12	22	t
12	28	t
12	23	t
12	24	t
12	25	t
13	21	f
13	22	t
13	26	t
13	27	t
13	29	t
14	7	f
14	30	t
14	31	t
14	32	t
14	33	t
14	34	t
14	35	t
15	7	f
15	30	t
15	31	t
15	32	t
15	33	t
15	34	t
15	35	t
18	36	f
21	37	f
21	38	f
21	39	f
21	40	f
21	41	f
22	7	f
22	42	f
22	43	f
22	44	f
22	34	f
16	7	f
16	45	f
16	46	t
16	47	f
16	48	t
16	49	f
16	35	t
23	50	t
23	51	f
23	52	f
23	53	t
23	54	f
23	55	t
23	56	f
23	57	t
23	58	t
23	59	t
23	8	f
23	9	f
23	60	f
24	50	t
24	53	t
24	52	f
24	54	f
24	55	t
24	51	f
24	61	t
24	62	t
24	63	f
24	64	t
25	50	t
25	53	t
25	55	t
25	65	t
25	66	t
27	67	f
28	68	f
28	69	f
28	70	f
28	71	f
28	72	f
\.


--
-- Data for Name: tipo_usuario; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tipo_usuario (id_tipo_usuario, descripcion) FROM stdin;
1	Superuser
2	Administrador
3	Funcionario
4	Usuario externo
5	Director/Gerente
\.


--
-- Data for Name: tramite; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tramite (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla, url_certificado, aprobado, fecha_culminacion) FROM stdin;
298	27	{"usuario":{"documentoIdentidad":"400197520","razonSocial":"Wak Casa de Software CA","denominacionComercial":"Wak Casa de Software CA","siglas":"WAK","parroquia":"OLEGARIO VILLALOBOS","sector":"Tierra Negra","direccion":"Av 21 Calle 86","puntoReferencia":"Diagonal CDO","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"400197520","razonSocial":"Wak Casa de Software CA","denominacionComercial":"Wak Casa de Software CA","siglas":"WAK","parroquia":"OLEGARIO VILLALOBOS","sector":"Tierra Negra","direccion":"Av 21 Calle 86","puntoReferencia":"Diagonal CDO","tipoContribuyente":"JURIDICO","tipoDocumento":"V"}}	\N	2020-06-26 22:49:43.696424+00	SEDEMAT-26062020-27-0001	1	119	\N	\N	t	2020-06-26 23:51:45.215522+00
302	3	{"usuario":{"cedulaORif":"12345688","nombreORazon":"jose","direccion":"mcbo","puntoReferencia":"mcbo","sector":"3123123","parroquia":"BOLIVAR","nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","contacto":"jose","horario":"8 a 12","prefix":"V","nacionalidad":"V","codCat":null,"contribuyente":null}}	\N	2020-06-30 18:22:40.387563+00	CBM-30062020-3-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CBM/planillas/CBM-30062020-3-0001	\N	f	\N
300	1	{"usuario":{"cedulaORif":"12345688","nombreORazon":"jose","direccion":"mcbo","puntoReferencia":"mcbo","sector":"3123123","parroquia":"BOLIVAR","nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","contacto":"jose","horario":"9 a 12","prefix":"V","nacionalidad":"V","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	20000000	2020-06-30 17:50:29.797212+00	CBM-30062020-1-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CBM/planillas/CBM-30062020-1-0001	\N	f	\N
301	2	{"usuario":{"cedulaORif":"12345688","nombreORazon":"jose","direccion":"mcbo","puntoReferencia":"mcbo","sector":"3123123","parroquia":"CACIQUE MARA","nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","contacto":"jose","horario":"8 a 12","prefix":"V","nacionalidad":"V","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	20000000	2020-06-30 18:21:38.604251+00	CBM-30062020-2-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CBM/planillas/CBM-30062020-2-0001	\N	f	\N
303	6	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	600000000	2020-06-30 18:23:44.183727+00	SAGAS-30062020-6-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-6-0001	\N	f	\N
305	8	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":null,"contribuyente":null}}	\N	2020-06-30 18:25:26.785389+00	SAGAS-30062020-8-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-8-0001	\N	f	\N
304	7	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	2400000000	2020-06-30 18:24:55.057176+00	SAGAS-30062020-7-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-7-0001	\N	f	\N
307	10	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	\N	2020-06-30 18:29:35.964286+00	SAGAS-30062020-10-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-10-0001	\N	f	\N
306	16	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12345688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR"}],"ubicadoEn":"mcbo","parroquiaEdificio":"BOLIVAR","tipoInmuebleSolvencia":"terreno","nacionalidad":"V","codCat":null,"contribuyente":null}}	3000000	2020-06-30 18:27:13.595827+00	CPU-30062020-16-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-16-0001	\N	f	\N
308	11	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	\N	2020-06-30 18:30:23.317754+00	SAGAS-30062020-11-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-11-0001	\N	f	\N
309	12	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	\N	2020-06-30 18:32:25.471914+00	SAGAS-30062020-12-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-12-0001	\N	f	\N
310	13	{"usuario":{"nombre":"jose","ubicadoEn":"mcbo","telefono":"4246336236","tipoOcupacion":"panadero","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"contribuyente":null}}	\N	2020-06-30 18:33:22.766851+00	SAGAS-30062020-13-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS/planillas/SAGAS-30062020-13-0001	\N	f	\N
313	15	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12354688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR"}],"nombreConjunto":"x","cantidadEdificios":"5","nombreEdificio":"5","cantidadPisos":"5","pisoApto":"5","cantidadAptosPiso":"5","numeroApto":"5","nomenclaturaEdificio":"5","ubicacionEdificio":"5","parroquiaEdificio":"JUANA DE AVILA","nacionalidad":"V","codCat":null,"contribuyente":null}}	3000000	2020-06-30 18:40:41.149505+00	CPU-30062020-15-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-15-0001	\N	f	\N
311	22	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12345688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA"}],"ubicadoEn":"mcbo","puntoReferencia":"mcbo","finalidad":"Actualización","frente":"123","linderoFrente":"fretne","linderoFondo":"fondo","linderoDerecha":"derecha","linderoIzquierda":"izquierda","observaciones":"observaciones","nacionalidad":"V","codCat":null,"contribuyente":null}}	200000.0	2020-06-30 18:36:51.647562+00	CPU-30062020-22-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-22-0001	\N	f	\N
312	14	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12345688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR"}],"ubicadoEn":"mcbo","parroquiaEdificio":"BOLIVAR","tipoInmueble":"casa","nacionalidad":"V","codCat":null,"contribuyente":null}}	3000000	2020-06-30 18:38:44.270165+00	CPU-30062020-14-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-14-0001	\N	f	\N
314	23	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12345688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"CHIQUINQUIRA"}],"denominacion":"j","actividadComercial":"j","direccionInmueble":"j","parroquiaInmueble":"CRISTO DE ARANZA","telefonoInmueble":"4246336236","correoInmueble":"zapasolca1@gmail.com","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"nacionalidad":"V","contribuyente":null}}	\N	2020-06-30 18:42:30.344355+00	CPU-30062020-23-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-23-0001	\N	f	\N
315	24	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA","direccion":"mcbo","propietarios":[{"razonSocial":"jose","nacionalidad":"V","cedulaORif":"12345688","telefono":"4246336236","direccion":"1620 Columbia arms circle unit 161","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR"}],"nombreInstitucion":"j","representanteInstitucion":"j","turno":"M","nivelEducativo":"j","telefonoInmueble":"4246336236","correoInmueble":"zapasolca1@gmail.com","direccionPlantel":"j","parroquiaInmueble":"IDELFONSO VASQUEZ","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]},"nacionalidad":"V","contribuyente":null}}	\N	2020-06-30 18:44:24.903989+00	CPU-30062020-24-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-24-0001	\N	f	\N
316	25	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"BOLIVAR","direccion":"mcbo","direccionInmueble":"j","parroquiaInmueble":"BOLIVAR","tipoInmueble":"j","denominacion":"j","direccionEmpresa":"j","parroquiaEmpresa":"JUANA DE AVILA","telefonoEmpresa":"4246336236","correoEmpresa":"zapasolca1@gmail.com","nacionalidad":"V","codCat":null,"contribuyente":null}}	\N	2020-06-30 18:45:46.644432+00	CPU-30062020-25-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU/planillas/CPU-30062020-25-0001	\N	f	\N
318	21	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","parroquia":"CACIQUE MARA","direccion":"mcbo","nombreOrganizacion":"j","tipoSociedad":"Civil","tipoTransporte":"CPP","nombreRepresentante":"j","cedulaRepresentante":"12345688","telefonoRepresentante":"4246336236","nacionalidad":"V","nacionalidadRepresentante":"V","codCat":null,"contribuyente":null}}	\N	2020-06-30 18:48:03.746067+00	IMTCUMA-30062020-21-0001	1	129	\N	\N	f	\N
317	18	{"usuario":{"nombre":"jose","cedula":"12345688","telefono":"4246336236","correo":"zapasolca1@gmail.com","fechaApartado":"2020-06-30T18:46:22.908Z","numeroBohio":"1","detallesBohio":"g","nacionalidad":"V","codCat":null,"contribuyente":null}}	2500000	2020-06-30 18:46:46.8143+00	SEDEPAR-30062020-18-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEPAR/planillas/SEDEPAR-30062020-18-0001	\N	f	\N
319	28	{"usuario":{"telefono":"4246336236","correo":"zapasolca1@gmail.com","denominacionComercial":"j","nombreRepresentante":"j","codCat":null,"contribuyente":{"id":66,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"410984694","razonSocial":"ZAPASOL, C.A.","denomComercial":"ZAPASOL, C.A.","sector":"CIRCUNVALACION 2","direccion":"Avenida 58 Calle  , Local Nro. PB-28","puntoReferencia":"FRENTE A TRAKI CV2","verificado":true,"verificacionTelefono":true}}}	1000000.0	2020-06-30 18:57:02.83084+00	SEDEMAT-30062020-28-0001	1	129	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-30062020-28-0001	\N	f	\N
320	27	{"usuario":{"documentoIdentidad":"308333666","razonSocial":"Mi negocio C.A.","denominacionComercial":"Mi negocio","siglas":"MNCA","parroquia":"JUANA DE AVILA","sector":"Canchancha","direccion":"Av 21 Villa Punta Arenas","puntoReferencia":"CC Sambil","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"308333666","razonSocial":"Mi negocio C.A.","denominacionComercial":"Mi negocio","siglas":"MNCA","parroquia":"JUANA DE AVILA","sector":"Canchancha","direccion":"Av 21 Villa Punta Arenas","puntoReferencia":"CC Sambil","tipoContribuyente":"JURIDICO","tipoDocumento":"V"}}	\N	2020-07-01 13:17:17.671537+00	SEDEMAT-01072020-27-0001	1	143	\N	\N	t	2020-07-01 13:26:28.837352+00
323	27	{"usuario":{"documentoIdentidad":"314151612","razonSocial":"tienda 2","denominacionComercial":"tienda 2","siglas":"tienda 2","parroquia":"JUANA DE AVILA","sector":"tienda 2","direccion":"mcbo","puntoReferencia":"mcbo","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"314151612","razonSocial":"tienda 2","denominacionComercial":"tienda 2","siglas":"tienda 2","parroquia":"JUANA DE AVILA","sector":"tienda 2","direccion":"mcbo","puntoReferencia":"mcbo","tipoContribuyente":"JURIDICO","tipoDocumento":"J"}}	\N	2020-07-01 13:44:35.240099+00	SEDEMAT-01072020-27-0004	4	149	\N	\N	t	2020-07-01 14:04:09.930643+00
324	27	{"usuario":{"documentoIdentidad":"700020005","razonSocial":"Negocio CA","denominacionComercial":"Negocio CA","siglas":"NCA","parroquia":"RAUL LEONI","sector":"NNNN","direccion":"DDDD","puntoReferencia":"PPPP","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"700020005","razonSocial":"Negocio CA","denominacionComercial":"Negocio CA","siglas":"NCA","parroquia":"RAUL LEONI","sector":"NNNN","direccion":"DDDD","puntoReferencia":"PPPP","tipoContribuyente":"JURIDICO","tipoDocumento":"J"}}	\N	2020-07-01 13:47:40.4185+00	SEDEMAT-01072020-27-0005	5	150	\N	\N	t	2020-07-01 14:04:22.233935+00
321	27	{"usuario":{"documentoIdentidad":"565789109","razonSocial":"Tienda","denominacionComercial":"Tienda","siglas":"TT","parroquia":"BOLIVAR","sector":"Los Mangos","direccion":"Av 34","puntoReferencia":"Los locos","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"565789109","razonSocial":"Tienda","denominacionComercial":"Tienda","siglas":"TT","parroquia":"BOLIVAR","sector":"Los Mangos","direccion":"Av 34","puntoReferencia":"Los locos","tipoContribuyente":"JURIDICO","tipoDocumento":"V"}}	\N	2020-07-01 13:24:36.899794+00	SEDEMAT-01072020-27-0002	2	145	\N	\N	t	2020-07-01 13:27:18.764155+00
322	27	{"usuario":{"documentoIdentidad":"4002557713","razonSocial":"waku waku CA","denominacionComercial":"soy yo ","siglas":"WWW","parroquia":"OLEGARIO VILLALOBOS","sector":"Canchancha, villa Puerto Azul","direccion":"av 16","puntoReferencia":"frente fuji","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"4002557713","razonSocial":"waku waku CA","denominacionComercial":"soy yo ","siglas":"WWW","parroquia":"OLEGARIO VILLALOBOS","sector":"Canchancha, villa Puerto Azul","direccion":"av 16","puntoReferencia":"frente fuji","tipoContribuyente":"JURIDICO","tipoDocumento":"J"}}	\N	2020-07-01 13:32:13.02945+00	SEDEMAT-01072020-27-0003	3	146	\N	\N	t	2020-07-03 15:21:19.489328+00
326	28	{"usuario":{"telefono":"4121100342","correo":"user2@gmail.com","denominacionComercial":"Negocio CA","nombreRepresentante":"Prueba ","codCat":null,"contribuyente":{"id":80,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"700020005","razonSocial":"Negocio CA","denomComercial":"Negocio CA","siglas":"NCA","sector":"NNNN","direccion":"DDDD","puntoReferencia":"PPPP","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4121100342","correo":"user2@gmail.com","denominacionComercial":"Negocio CA","nombreRepresentante":"Prueba ","actividadesEconomicas":[{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","key":4}],"referenciaMunicipal":"8000000004"}}	1000000.0	2020-07-01 14:13:32.706273+00	SEDEMAT-01072020-28-0002	2	150	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-01072020-28-0002	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-01072020-28-0002	t	2020-07-01 15:26:52.828017+00
325	28	{"usuario":{"telefono":"4246336236","correo":"prueba123@gmail.com","denominacionComercial":"tienda","nombreRepresentante":"jose","codCat":null,"contribuyente":{"id":79,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"314151612","razonSocial":"tienda 2","denomComercial":"tienda 2","siglas":"tienda 2","sector":"tienda 2","direccion":"mcbo","puntoReferencia":"mcbo","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4246336236","correo":"prueba123@gmail.com","denominacionComercial":"tienda  soft","nombreRepresentante":"jose","actividadesEconomicas":[{"id":19,"codigo":2047001,"descripcion":"Venta e Implementación de Software.","key":18},{"id":61,"codigo":1039001,"descripcion":"Empresas Desarrolladoras de Software.","key":60}],"referenciaMunicipal":"8000000005"}}	1000000.0	2020-07-01 14:09:05.754533+00	SEDEMAT-01072020-28-0001	1	149	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-01072020-28-0001	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-01072020-28-0001	t	2020-07-01 15:42:57.618399+00
327	27	{"usuario":{"documentoIdentidad":"406576458","razonSocial":"Comercializadora 5 de Julio","denominacionComercial":"Comercializadora 5 de Julio","siglas":"C5J","parroquia":"OLEGARIO VILLALOBOS","sector":"Juana de Avila","direccion":"calle 77 con avenida 16","puntoReferencia":"Wendys Kids","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"406576458","razonSocial":"Comercializadora 5 de Julio","denominacionComercial":"Comercializadora 5 de Julio","siglas":"C5J","parroquia":"OLEGARIO VILLALOBOS","sector":"Juana de Avila","direccion":"calle 77 con avenida 16","puntoReferencia":"Wendys Kids","tipoContribuyente":"JURIDICO","tipoDocumento":"J"}}	\N	2020-07-02 15:13:50.325816+00	SEDEMAT-02072020-27-0001	1	153	\N	\N	t	2020-07-02 15:29:55.973332+00
328	28	{"usuario":{"telefono":"4246336236","correo":"comercializadora5j@gmail.com","denominacionComercial":"Comercializadora","nombreRepresentante":"Jose Perez","codCat":null,"contribuyente":{"id":82,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"406576458","razonSocial":"Comercializadora 5 de Julio","denomComercial":"Comercializadora 5 de Julio","siglas":"C5J","sector":"Juana de Avila","direccion":"calle 77 con avenida 16","puntoReferencia":"Wendys Kids","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4246336236","correo":"comercializadora5j@gmail.com","denominacionComercial":"Comercializadora","nombreRepresentante":"Jose Perez","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","key":1}],"referenciaMunicipal":"8000000006"}}	1000000.0	2020-07-02 15:43:52.483359+00	SEDEMAT-02072020-28-0001	1	153	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-02072020-28-0001	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-02072020-28-0001	t	2020-07-02 15:55:41.42259+00
329	28	{"usuario":{"telefono":"4146053291","correo":"fake2@gmail.com","denominacionComercial":"tienda  soft","nombreRepresentante":"Jhonnatan Romay","codCat":null,"contribuyente":{"id":83,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"4002557713","razonSocial":"waku waku CA","denomComercial":"soy yo ","siglas":"WWW","sector":"Canchancha, villa Puerto Azul","direccion":"av 16","puntoReferencia":"frente fuji","verificado":true,"verificacionTelefono":true}}}	1000000.0	2020-07-03 15:34:49.578088+00	SEDEMAT-03072020-28-0001	1	146	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-03072020-28-0001	\N	f	\N
330	26	{"funcionario":{"beneficios":[{"idRamo":"64","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":100000,"fechaDePago":"09-07-2020"},{"porcion":"2","monto":74000,"fechaDePago":"09-07-2020"}]}],"contribuyente":{"id":84,"tipoDocumento":"J","documento":"304689713","registroMunicipal":"2900011265","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","sector":"","direccion":null,"puntoReferencia":"","verificado":true,"liquidaciones":[{"id":64,"ramo":"SERVICIOS MUNICIPALES","monto":"174000.00"}],"totalDeuda":"174000.00"}}}	\N	2020-07-09 12:13:24.897936+00	SEDEMAT-09072020-26-0001	1	83	\N	\N	t	2020-07-09 12:27:59.653175+00
331	27	{"usuario":{"documentoIdentidad":"123123123","razonSocial":"asdasdasd","denominacionComercial":"FARMACIA COVIDES 2","siglas":"COVIDES 2","parroquia":"CACIQUE MARA","sector":"123","direccion":"asdasdasd","puntoReferencia":"123","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null,"contribuyente":null}}	\N	2020-07-10 15:03:38.148479+00	SEDEMAT-10072020-27-0001	1	119	\N	\N	f	\N
334	27	{"usuario":{"documentoIdentidad":"12543654","razonSocial":"jose sanchez","denominacionComercial":"comercializadora","siglas":"CMCLZDR","parroquia":"JUANA DE AVILA","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","tipoContribuyente":"NATURAL","tipoDocumento":"V","codCat":null},"funcionario":{"documentoIdentidad":"12543654","razonSocial":"jose sanchez","denominacionComercial":"comercializadora","siglas":"CMCLZDR","parroquia":"JUANA DE AVILA","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","tipoContribuyente":"NATURAL","tipoDocumento":"V"}}	\N	2020-07-13 01:02:23.945848+00	SEDEMAT-13072020-27-0001	1	163	\N	\N	t	2020-07-13 01:09:31.49455+00
332	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":2000000,"fechaDePago":"07-18-2020"},{"porcion":"2","monto":1000000,"fechaDePago":"07-31-2020"}]},{"idRamo":"9","tipoBeneficio":"pagoCompleto"},{"idRamo":"29","tipoBeneficio":"remision"}],"contribuyente":{"id":87,"tipoDocumento":"J","documento":"000202001","registroMunicipal":"203C000845","razonSocial":"FARMATODO, C.A.","denomComercial":"FARMATODO, C.A. FARMACIA FUERZAS ARMADAS","sector":"PARCELAMIENTO LA VILLA","direccion":"Avenida 14B Calle 45, Local Nro. 789","puntoReferencia":"frente a ferretotal","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"3000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"9090000.00"},{"id":29,"ramo":"MULTAS","monto":"15000000.00"}],"totalDeuda":27090000}}}	\N	2020-07-10 16:49:30.462689+00	SEDEMAT-10072020-26-0001	1	83	\N	\N	t	2020-07-10 19:44:47.523322+00
333	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"pagoCompleto"},{"idRamo":"9","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":2000000,"fechaDePago":"07-17-2020"},{"porcion":"2","monto":1060000,"fechaDePago":"07-31-2020"}]},{"idRamo":"29","tipoBeneficio":"pagoCompleto"},{"idRamo":"64","tipoBeneficio":"pagoCompleto"}],"contribuyente":{"id":84,"tipoDocumento":"J","documento":"304689713","registroMunicipal":"2900011265","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","sector":"","direccion":null,"puntoReferencia":"","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"2000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"3060000.00"},{"id":29,"ramo":"MULTAS","monto":"5000000.00"},{"id":64,"ramo":"SERVICIOS MUNICIPALES","monto":"174000.00"}],"totalDeuda":10234000}}}	\N	2020-07-10 17:39:53.585245+00	SEDEMAT-10072020-26-0002	2	83	\N	\N	t	2020-07-10 17:40:22.836976+00
335	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"pagoCompleto"},{"idRamo":"9","tipoBeneficio":"pagoCompleto"},{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":20000000,"fechaDePago":"07-13-2020"},{"porcion":"2","monto":4000000,"fechaDePago":"07-13-2020"}]},{"idRamo":"29","tipoBeneficio":"pagoCompleto"}],"contribuyente":{"id":84,"tipoDocumento":"J","documento":"304689713","registroMunicipal":"2900011265","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","sector":"","direccion":null,"puntoReferencia":"","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"2000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"3060000.00"},{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"24000000.00"},{"id":29,"ramo":"MULTAS","monto":"5000000.00"}],"totalDeuda":34060000}}}	\N	2020-07-13 16:43:56.744309+00	SEDEMAT-13072020-26-0001	1	83	\N	\N	t	2020-07-13 16:44:08.749839+00
336	27	{"usuario":{"documentoIdentidad":"400000005","razonSocial":"Mi empresa CA","denominacionComercial":"Lo q se CA","siglas":"MECA","parroquia":"CECILIO ACOSTA","sector":"sabaneta","direccion":"av 21 calle 86","puntoReferencia":"lo que sea","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"400000005","razonSocial":"Mi empresa CA","denominacionComercial":"Lo q se CA","siglas":"MECA","parroquia":"CECILIO ACOSTA","sector":"sabaneta","direccion":"av 21 calle 86","puntoReferencia":"lo que sea","tipoContribuyente":"JURIDICO","tipoDocumento":"J"}}	\N	2020-07-13 19:30:55.647732+00	SEDEMAT-13072020-27-0002	2	172	\N	\N	t	2020-07-13 19:31:42.422201+00
338	26	{"funcionario":{"beneficios":[{"idRamo":"9","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":4090000,"fechaDePago":"07-17-2020"},{"porcion":"2","monto":5000000,"fechaDePago":"07-24-2020"}]}],"contribuyente":{"id":87,"tipoDocumento":"J","documento":"000202001","registroMunicipal":"203C000845","razonSocial":"FARMATODO, C.A.","denomComercial":"FARMATODO, C.A. FARMACIA FUERZAS ARMADAS","sector":"PARCELAMIENTO LA VILLA","direccion":"Avenida 14B Calle 45, Local Nro. 789","puntoReferencia":"frente a ferretotal","verificado":true,"liquidaciones":[{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"9090000.00"}],"totalDeuda":"9090000.00"}}}	\N	2020-07-14 13:05:23.977838+00	SEDEMAT-14072020-26-0001	1	83	\N	\N	t	2020-07-14 13:05:41.991268+00
337	26	{"funcionario":{"beneficios":[{"idRamo":"64","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":75000,"fechaDePago":"07-20-2020"},{"porcion":"2","monto":70000,"fechaDePago":"08-03-2020"}]}],"contribuyente":{"id":86,"tipoDocumento":"J","documento":"308620483","registroMunicipal":"2900013829","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","puntoReferencia":"EDIF. IPSFA","verificado":true,"liquidaciones":[{"id":64,"ramo":"SERVICIOS MUNICIPALES","monto":"145000.00"}],"totalDeuda":"145000.00"}}}	\N	2020-07-13 19:39:23.854275+00	SEDEMAT-13072020-26-0002	2	83	\N	\N	t	2020-07-13 19:40:08.930921+00
340	28	{"usuario":{"telefono":"4127645681","correo":"external@user.com","denominacionComercial":"farmacia prueba","nombreRepresentante":"Jose Jose","capitalSuscrito":"20000","tipoSociedadContrib":"Compañía Anónima","codCat":null,"contribuyente":{"id":86,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"308620483","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","puntoReferencia":"EDIF. IPSFA","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4127645681","correo":"external@user.com","denominacionComercial":"farmacia prueba","nombreRepresentante":"Jose Jose","capitalSuscrito":"20000","tipoSociedadContrib":"Compañía Anónima","actividadesEconomicas":[{"id":140,"codigo":3010001,"descripcion":"Farmacias.","alicuota":"2.00","key":141},{"id":44,"codigo":1025001,"descripcion":"Fabricación de productos farmacéuticos,\\tlaboratorio farmacológico, medicamentos y cosméticos.","alicuota":"2.00","key":43}]}}	1000000.0	2020-07-14 15:21:39.288954+00	SEDEMAT-14072020-28-0001	1	58	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-14072020-28-0001	\N	f	\N
339	26	{"funcionario":{"beneficios":[{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":50000000,"fechaDePago":"07-17-2020"},{"porcion":"2","monto":50000000,"fechaDePago":"07-24-2020"},{"porcion":"3","monto":48500000,"fechaDePago":"07-31-2020"}]}],"contribuyente":{"id":87,"tipoDocumento":"J","documento":"000202001","registroMunicipal":"2900000031","razonSocial":"FARMATODO, C.A.","denomComercial":"FARMATODO, C.A. FARMACIA FUERZAS ARMADAS","sector":"PARCELAMIENTO LA VILLA","direccion":"Avenida 14B Calle 45, Local Nro. 789","puntoReferencia":"frente a ferretotal","verificado":true,"liquidaciones":[{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"148500000.00"}],"totalDeuda":"148500000.00"}}}	\N	2020-07-14 13:11:52.552643+00	SEDEMAT-14072020-26-0002	2	116	\N	\N	t	2020-07-14 13:36:04.589736+00
341	28	{\n    "usuario": {\n        "telefono": "4127645681",\n        "correo": "external@user.com",\n        "denominacionComercial": "123",\n        "nombreRepresentante": "123",\n        "capitalSuscrito": "123",\n        "tipoSociedadContrib": "Compañía Anónima",\n        "codCat": null,\n        "contribuyente": {\n            "id": 86,\n            "tipoDocumento": "J",\n            "tipoContribuyente": "JURIDICO",\n            "documento": "308620483",\n            "razonSocial": "FARMACIA COVIDES C.A.",\n            "denomComercial": "FARMACIA COVIDES C.A.",\n            "sector": "INDIO MARA",\n            "direccion": "Avenida 65 Calle  22A, Local Nro.  MZN",\n            "puntoReferencia": "EDIF. IPSFA",\n            "verificado": true,\n            "verificacionTelefono": true\n        }\n    },\n    "funcionario": {\n        "telefono": "4127645681",\n        "correo": "external@user.com",\n        "denominacionComercial": "123",\n        "nombreRepresentante": "123",\n        "capitalSuscrito": "123",\n        "tipoSociedadContrib": "Compañía Anónima",\n        "pago": [{\n                    "monto": "1000000.00",\n        "formaPago": "CULO",\n        "banco": "BOD",\n        "fecha": "07-14-2020",\n        "nro": "123123123"\n        }],\n        "actividadesEconomicas": [\n            {\n                "id": 1,\n                "codigo": 2029001,\n                "descripcion": "Transporte Terrestre de Carga refrigerada.",\n                "alicuota": "2.00",\n                "key": 0\n            }\n        ]\n    }\n}	1000000.0	2020-07-14 15:28:46.972941+00	SEDEMAT-14072020-28-0002	2	58	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-14072020-28-0002	\N	f	\N
342	26	{"funcionario":{"beneficios":{"11":{"benefit":"convenio","pagos":3,"1_monto":50000000,"1_fechaDePago":"2020-08-01T19:54:50.067Z","2_monto":50000000,"2_fechaDePago":"2020-08-14T19:54:55.027Z","3_monto":32000000,"3_fechaDePago":"2020-07-30T19:55:01.404Z"}},"contribuyente":{"id":98,"tipoDocumento":"J","documento":"306020403","registroMunicipal":"204R000441","razonSocial":"DISTRIBUIDORA J.K. C.A.","denomComercial":"DISTRIBUIDORA J.K. C.A.","sector":"18 DE OCTUBRE","direccion":"Avenida 2 Calle IJ, Casa Nro. 3--75","puntoReferencia":"plaza de 18 de octubre","verificado":true,"liquidaciones":[{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"132000000.00"}],"totalDeuda":"132000000.00"}}}	\N	2020-07-14 19:55:12.542001+00	SEDEMAT-14072020-26-0003	3	83	\N	\N	f	\N
344	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"remision"},{"idRamo":"9","tipoBeneficio":"remision"},{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":10000000,"fechaDePago":"07-15-2020"},{"porcion":"2","monto":8000000,"fechaDePago":"07-15-2020"}]},{"idRamo":"29","tipoBeneficio":"remision"}],"contribuyente":{"id":84,"tipoDocumento":"J","documento":"304689713","registroMunicipal":"2900011265","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","sector":"","direccion":null,"puntoReferencia":"","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"2000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"3060000.00"},{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"18000000.00"},{"id":29,"ramo":"MULTAS","monto":"5000000.00"}],"totalDeuda":28060000}}}	\N	2020-07-15 12:37:13.350097+00	SEDEMAT-15072020-26-0001	1	83	\N	\N	t	2020-07-15 13:41:54.298424+00
343	26	{"funcionario":{"beneficios":[{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":50000000,"fechaDePago":"07-21-2020"},{"porcion":"2","monto":50000000,"fechaDePago":"07-28-2020"},{"porcion":"3","monto":34000000,"fechaDePago":"08-04-2020"}]}],"contribuyente":{"id":99,"tipoDocumento":"J","documento":"003257176","registroMunicipal":"2900049654","razonSocial":"FERRETOTAL CARACAS C.A.","denomComercial":"FERRETOTAL CARACAS C.A. (SUCURSAL)","sector":"","direccion":"Avenida Calle  , Casa Nro.  ","puntoReferencia":"","verificado":true,"liquidaciones":[{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"134000000.00"}],"totalDeuda":"134000000.00"}}}	\N	2020-07-14 23:45:18.998482+00	SEDEMAT-14072020-26-0004	4	83	\N	\N	t	2020-07-15 16:57:09.206336+00
345	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"pagoCompleto"},{"idRamo":"9","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":3000000,"fechaDePago":"07-22-2020"},{"porcion":"2","monto":4020000,"fechaDePago":"07-29-2020"}]},{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":100000000,"fechaDePago":"07-22-2020"},{"porcion":"2","monto":15500000,"fechaDePago":"07-29-2020"}]},{"idRamo":"29","tipoBeneficio":"remision"}],"contribuyente":{"id":99,"tipoDocumento":"J","documento":"003257176","registroMunicipal":"2000812803","razonSocial":"FERRETOTAL CARACAS C.A.","denomComercial":"FERRETOTAL CARACAS C.A. (SUCURSAL)","sector":"","direccion":"Avenida Calle  , Casa Nro.  ","puntoReferencia":"","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"2000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"7020000.00"},{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"115500000.00"},{"id":29,"ramo":"MULTAS","monto":"5000000.00"}],"totalDeuda":129520000}}}	\N	2020-07-15 16:42:20.754409+00	SEDEMAT-15072020-26-0002	2	83	\N	\N	t	2020-07-15 16:42:59.372042+00
370	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":15,"referencia":"112986734","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:31:37.731847+00	SEDEMAT-16072020-28-0006	6	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0006	\N	f	\N
346	26	{"funcionario":{"beneficios":[{"idRamo":"1","tipoBeneficio":"pagoCompleto"},{"idRamo":"9","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":4000000,"fechaDePago":"07-22-2020"},{"porcion":"2","monto":2420000,"fechaDePago":"07-29-2020"}]},{"idRamo":"11","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":100000000,"fechaDePago":"07-22-2020"},{"porcion":"2","monto":34000000,"fechaDePago":"07-22-2020"}]},{"idRamo":"29","tipoBeneficio":"remision"}],"contribuyente":{"id":99,"tipoDocumento":"J","documento":"003257176","registroMunicipal":"2900049654","razonSocial":"FERRETOTAL CARACAS C.A.","denomComercial":"FERRETOTAL CARACAS C.A. (SUCURSAL)","sector":"","direccion":"Avenida Calle  , Casa Nro.  ","puntoReferencia":"","verificado":true,"liquidaciones":[{"id":1,"ramo":"TASA ADMINISTRATIVA DE SOLVENCIA DE AE","monto":"2000000.00"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"6420000.00"},{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"134000000.00"},{"id":29,"ramo":"MULTAS","monto":"5000000.00"}],"totalDeuda":147420000}}}	\N	2020-07-15 16:55:29.27274+00	SEDEMAT-15072020-26-0003	3	83	\N	\N	t	2020-07-15 16:56:12.835542+00
347	28	{"usuario":{"username":"jsanchez.waku@gmail.com","denominacionComercial":"Si","nombreRepresentante":"Si","capitalSuscrito":"1000","tipoSociedadContrib":"Compañía Anónima","telefono":"13212312331","actividadesEconomicas":[{"id":6,"codigo":2034001,"descripcion":"Transporte terrestre de pasajeros.","alicuota":"1.00","key":5}],"pago":{"metodoPago":"TRANSFERENCIA","banco":11,"referencia":"1231412312","fecha":"2020-07-15T19:05:51.476Z","costo":"1000000.0"},"correo":"jsanchez.waku@gmail.com","contribuyente":{"id":84}}}	1000000.0	2020-07-15 19:05:54.379185+00	SEDEMAT-15072020-28-0001	1	118	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-15072020-28-0001	\N	f	\N
350	27	{"usuario":{"documentoIdentidad":"18921679","razonSocial":"Triny Rosales","denominacionComercial":"Empanadas triny","siglas":"EMPTR","parroquia":"CACIQUE MARA","sector":"Cañada Honda","direccion":"av 21 calle 86","puntoReferencia":"en visoca","tipoContribuyente":"NATURAL","tipoDocumento":"V","codCat":null},"funcionario":{"documentoIdentidad":"18921679","razonSocial":"Triny Rosales","denominacionComercial":"Empanadas triny","siglas":"EMPTR","parroquia":"CACIQUE MARA","sector":"Cañada Honda","direccion":"av 21 calle 86","puntoReferencia":"en visoca","tipoContribuyente":"NATURAL","tipoDocumento":"V"}}	\N	2020-07-15 19:43:36.436209+00	SEDEMAT-15072020-27-0001	1	181	\N	\N	t	2020-07-15 19:52:51.590005+00
349	28	{"usuario":{"username":"jsanchez.waku@gmail.com","denominacionComercial":"Si","nombreRepresentante":"Si","capitalSuscrito":"1000","tipoSociedadContrib":"Compañía Anónima","telefono":"13212312331","actividadesEconomicas":[{"id":6,"codigo":2034001,"descripcion":"Transporte terrestre de pasajeros.","alicuota":"1.00","key":5}],"pago":{"metodoPago":"TRANSFERENCIA","banco":11,"referencia":"12314123125","fecha":"2020-07-15T19:05:51.476Z","costo":"1000000.0"},"correo":"jsanchez.waku@gmail.com","contribuyente":{"id":84}},"funcionario":{"username":"jsanchez.waku@gmail.com","denominacionComercial":"Si","nombreRepresentante":"Si","capitalSuscrito":"1000","tipoSociedadContrib":"Compañía Anónima","telefono":"13212312331","actividadesEconomicas":[{"id":6,"codigo":2034001,"descripcion":"Transporte terrestre de pasajeros.","alicuota":"1.00","key":5}],"pago":[{"monto":"1000000.0","formaPago":"TRANSFERENCIA","banco":"Banco De Venezuela S.A.C.A. Banco Universal","fecha":"2020-07-15T00:00:00.000Z","nro":"12314123125"}],"correo":"jsanchez.waku@gmail.com","contribuyente":{"id":84}}}	1000000.0	2020-07-15 19:37:41.710633+00	SEDEMAT-15072020-28-0002	2	118	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-15072020-28-0002	\N	f	\N
358	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"53353535353","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:22:35.157748+00	SEDEMAT-16072020-28-0001	1	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0001	\N	f	\N
351	28	{"usuario":{"username":"jsanchez.waku@gmail.com","denominacionComercial":"asdasd","nombreRepresentante":"asdasd","capitalSuscrito":"1000","tipoSociedadContrib":"Sociedad Anónima","telefono":"12312412123","actividadesEconomicas":[{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4}],"pago":{"metodoPago":"TRANSFERENCIA","banco":11,"referencia":"123123123","fecha":"2020-07-15T19:46:04.391Z","costo":"1000000.0"},"correo":"jsanchez.waku@gmail.com","contribuyente":{"id":84,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"304689713","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","parroquia":null,"sector":"","direccion":null,"creditoFiscal":0,"puntoReferencia":"","verificado":true,"sucursales":[{"id":"76","referenciaMunicipal":"2900011266","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION GSM","nombreRepresentante":"OSWALDO CISNEROS","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"77","referenciaMunicipal":"2900014139","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"ROBERTO JOSE ORTA","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"78","referenciaMunicipal":"2900013536","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.  PALACIO DE EVENTOS","nombreRepresentante":"FRANCISCO  HUNG","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"79","referenciaMunicipal":"2900026280","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"DEMERIS RUIZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"80","referenciaMunicipal":"2900011265","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"ALFRED TULIO HUNG RIVERO","capitalSuscrito":null,"creditoFiscal":"190980.48","tipoSociedad":null,"actualizado":true}],"key":84}},"funcionario":{"username":"jsanchez.waku@gmail.com","denominacionComercial":"asdasd","nombreRepresentante":"asdasd","capitalSuscrito":"1000","tipoSociedadContrib":"Sociedad Anónima","telefono":"12312412123","actividadesEconomicas":[{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4}],"pago":[{"monto":"1000000.0","formaPago":"TRANSFERENCIA","banco":"Banco De Venezuela S.A.C.A. Banco Universal","fecha":"2020-07-15T00:00:00.000Z","nro":"123123123"}],"correo":"jsanchez.waku@gmail.com","contribuyente":{"id":84,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"304689713","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","parroquia":null,"sector":"","direccion":null,"creditoFiscal":0,"puntoReferencia":"","verificado":true,"sucursales":[{"id":"76","referenciaMunicipal":"2900011266","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION GSM","nombreRepresentante":"OSWALDO CISNEROS","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"77","referenciaMunicipal":"2900014139","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"ROBERTO JOSE ORTA","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"78","referenciaMunicipal":"2900013536","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.  PALACIO DE EVENTOS","nombreRepresentante":"FRANCISCO  HUNG","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"79","referenciaMunicipal":"2900026280","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"DEMERIS RUIZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"80","referenciaMunicipal":"2900011265","fechaAprobacion":"2020-07-09T00:00:00.000Z","telefono":"4147212342","email":"snider8520@gmail.com","denomComercial":"CORPORACION DIGITEL, C.A.","nombreRepresentante":"ALFRED TULIO HUNG RIVERO","capitalSuscrito":null,"creditoFiscal":"190980.48","tipoSociedad":null,"actualizado":true}],"key":84},"observaciones":"me lo mama"}}	1000000.0	2020-07-15 19:47:44.589342+00	SEDEMAT-15072020-28-0003	3	118	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-15072020-28-0003	\N	f	\N
379	28	{"usuario":{"username":"prueba10@gmail.com","denominacionComercial":"FARMACIA COVIDES","nombreRepresentante":"JOSE CORO","capitalSuscrito":"12039109","tipoSociedadContrib":"Compañía Anónima","telefono":"1231241231","actividadesEconomicas":[{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3,"desde":"2020-06-26T14:30:39.559Z"},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2,"desde":"2020-03-05T14:30:41.981Z"},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0,"desde":"2019-07-12T14:30:45.034Z"},{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4,"desde":"2018-07-18T14:30:47.659Z"}],"estadoLicencia":"PERMANENTE","pago":{"metodoPago":"TRANSFERENCIA","banco":10,"referencia":"123124123","fecha":"2020-07-21T14:31:00.082Z","costo":"1000000"},"correo":"prueba10@gmail.com","contribuyente":{"id":86,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"308620483","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","parroquia":64,"sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","creditoFiscal":0,"puntoReferencia":"EDIF. IPSFA","verificado":true,"sucursales":[{"id":"83","referenciaMunicipal":"207R002131","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )","nombreRepresentante":"JOSE ABELD","capitalSuscrito":null,"creditoFiscal":"8414799.340000001","tipoSociedad":null,"actualizado":true},{"id":"84","referenciaMunicipal":"207R002132","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )","nombreRepresentante":"JOSE ABEID","capitalSuscrito":null,"creditoFiscal":"1730508.75","tipoSociedad":null,"actualizado":true},{"id":"86","referenciaMunicipal":"2900013829","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"covides@gmail.com","denomComercial":"FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )","nombreRepresentante":"LILIANA SANCHEZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"85","referenciaMunicipal":"207P000358","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.-","nombreRepresentante":"LILIANA SANCHEZ.-","capitalSuscrito":null,"creditoFiscal":"31434.00","tipoSociedad":null,"actualizado":true},{"id":"82","referenciaMunicipal":"AR20200024","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.","nombreRepresentante":"IVECO","capitalSuscrito":null,"creditoFiscal":"55.00","tipoSociedad":null,"actualizado":true}],"key":86}},"funcionario":{"username":"prueba10@gmail.com","denominacionComercial":"FARMACIA COVIDES","nombreRepresentante":"JOSE CORO","capitalSuscrito":"12039109","tipoSociedadContrib":"Compañía Anónima","telefono":"1231241231","actividadesEconomicas":[{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3,"desde":"2020-06-26T14:30:39.559Z"},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2,"desde":"2020-03-05T14:30:41.981Z"},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0,"desde":"2019-07-12T14:30:45.034Z"},{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4,"desde":"2018-07-18T14:30:47.659Z"}],"estadoLicencia":"PERMANENTE","pago":[],"correo":"prueba10@gmail.com","contribuyente":{"id":86,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"308620483","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","parroquia":64,"sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","creditoFiscal":0,"puntoReferencia":"EDIF. IPSFA","verificado":true,"sucursales":[{"id":"83","referenciaMunicipal":"207R002131","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )","nombreRepresentante":"JOSE ABELD","capitalSuscrito":null,"creditoFiscal":"8414799.340000001","tipoSociedad":null,"actualizado":true},{"id":"84","referenciaMunicipal":"207R002132","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )","nombreRepresentante":"JOSE ABEID","capitalSuscrito":null,"creditoFiscal":"1730508.75","tipoSociedad":null,"actualizado":true},{"id":"86","referenciaMunicipal":"2900013829","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"covides@gmail.com","denomComercial":"FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )","nombreRepresentante":"LILIANA SANCHEZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"85","referenciaMunicipal":"207P000358","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.-","nombreRepresentante":"LILIANA SANCHEZ.-","capitalSuscrito":null,"creditoFiscal":"31434.00","tipoSociedad":null,"actualizado":true},{"id":"82","referenciaMunicipal":"AR20200024","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.","nombreRepresentante":"IVECO","capitalSuscrito":null,"creditoFiscal":"55.00","tipoSociedad":null,"actualizado":true}],"key":86},"referenciaMunicipal":"8000000016"},"idTramite":379}	1000000	2020-07-21 14:31:05.501346+00	SEDEMAT-21072020-28-0003	3	197	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-21072020-28-0003	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-21072020-28-0003	t	2020-07-21 17:59:41.457994+00
371	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"253453423","fecha":"2020-07-16T13:38:32.892Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101},"referenciaMunicipal":"8000000009"},"idTramite":371}	1000000.0	2020-07-16 13:38:37.382146+00	SEDEMAT-16072020-28-0007	7	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0007	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-16072020-28-0007	t	2020-07-16 13:44:01.801809+00
352	28	{"usuario":{"telefono":"4146053291","correo":"trosales@gmail.com","denominacionComercial":"Empanadas Triny","nombreRepresentante":"Triny Rosales","capitalSuscrito":"40000000","tipoSociedadContrib":"Sociedad de Responsabilidad Limitada","codCat":null,"contribuyente":{"id":100,"tipoDocumento":"V","tipoContribuyente":"NATURAL","documento":"18921679","razonSocial":"Triny Rosales","denomComercial":"Empanadas triny","siglas":"EMPTR","sector":"Cañada Honda","direccion":"av 21 calle 86","puntoReferencia":"en visoca","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4146053291","correo":"trosales@gmail.com","denominacionComercial":"Empanadas Triny","nombreRepresentante":"Triny Rosales","capitalSuscrito":"40000000","tipoSociedadContrib":"Sociedad de Responsabilidad Limitada","actividadesEconomicas":[{"id":48,"codigo":20270012,"descripcion":"Puestos de Comida Callejera (Empanadas, Tequeños, Pastelitos, Mandocas y Similares, excluye Franquicias)","alicuota":"2.00","key":47}],"pago":[{"monto":"1000000.00","formaPago":"TRANSFERENCIA","banco":"Banco Occidental de Descuento","fecha":"2020-07-15T00:00:00.000Z","nro":"391227475"}],"referenciaMunicipal":"8000000008"},"idTramite":352}	1000000.0	2020-07-15 20:05:25.42043+00	SEDEMAT-15072020-28-0004	4	181	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-15072020-28-0004	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-15072020-28-0004	t	2020-07-15 20:42:13.077565+00
353	28	{"usuario":{"telefono":"4246336236","correo":"prueba4@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"30000000","tipoSociedadContrib":"Compañía Anónima","codCat":null,"contribuyente":{"id":89,"tipoDocumento":"V","tipoContribuyente":"NATURAL","documento":"12543654","razonSocial":"jose sanchez","denomComercial":"comercializadora","siglas":"CMCLZDR","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","verificado":true,"verificacionTelefono":true}}}	1000000.0	2020-07-15 20:36:53.81152+00	SEDEMAT-15072020-28-0005	5	163	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-15072020-28-0005	\N	f	\N
380	28	{"usuario":{"username":"prueba4@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":0,"desde":"2019-12-01T17:49:39.593Z"}],"estadoLicencia":"PERMANENTE","pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"222333444","fecha":"2020-07-21T17:50:22.731Z","costo":"1000000"},"correo":"prueba4@gmail.com","contribuyente":{"id":89,"tipoDocumento":"V","tipoContribuyente":"NATURAL","documento":"12543654","razonSocial":"jose sanchez","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":69,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":89}},"funcionario":{"username":"prueba4@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":0,"desde":"2019-12-01T17:49:39.593Z"}],"estadoLicencia":"PERMANENTE","pago":[],"correo":"prueba4@gmail.com","contribuyente":{"id":89,"tipoDocumento":"V","tipoContribuyente":"NATURAL","documento":"12543654","razonSocial":"jose sanchez","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":69,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":89},"referenciaMunicipal":"8000000017"},"idTramite":380}	1000000	2020-07-21 17:50:27.086854+00	SEDEMAT-21072020-28-0004	4	163	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-21072020-28-0004	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-21072020-28-0004	t	2020-07-21 18:00:34.301877+00
364	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"53353535356","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:24:35.920108+00	SEDEMAT-16072020-28-0002	2	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0002	\N	f	\N
366	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"746574656","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:25:10.145422+00	SEDEMAT-16072020-28-0004	4	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0004	\N	f	\N
381	28	{"usuario":{"username":"prueba14@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro segundo","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":0,"desde":"2020-01-10T19:05:34.325Z"},{"id":214,"codigo":3081001,"descripcion":"Acopio o recolección de envases plásticos, cartones, vidrio, materiales metálicos con fines de reciclaje","alicuota":"6.00","key":1,"desde":"2020-03-10T19:05:43.802Z"},{"id":11,"codigo":2039001,"descripcion":"Agencias Funerarias y Capillas Velatorias.","alicuota":"1.00","key":2,"desde":"2020-06-10T19:05:49.790Z"}],"estadoLicencia":"TEMPORAL","pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"666777888","fecha":"2020-07-21T19:06:07.656Z","costo":"1000000"},"correo":"prueba14@gmail.com","contribuyente":{"id":107,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837466","razonSocial":"jose coro segundo","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":61,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":107}},"funcionario":{"username":"prueba14@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro segundo","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":0,"desde":"2020-01-10T19:05:34.325Z"},{"id":214,"codigo":3081001,"descripcion":"Acopio o recolección de envases plásticos, cartones, vidrio, materiales metálicos con fines de reciclaje","alicuota":"6.00","key":1,"desde":"2020-03-10T19:05:43.802Z"},{"id":11,"codigo":2039001,"descripcion":"Agencias Funerarias y Capillas Velatorias.","alicuota":"1.00","key":2,"desde":"2020-06-10T19:05:49.790Z"}],"estadoLicencia":"TEMPORAL","pago":[],"correo":"prueba14@gmail.com","contribuyente":{"id":107,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837466","razonSocial":"jose coro segundo","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":61,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":107},"referenciaMunicipal":"8000000018"},"idTramite":381}	1000000	2020-07-21 19:06:17.864771+00	SEDEMAT-21072020-28-0005	5	208	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-21072020-28-0005	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-21072020-28-0005	t	2020-07-21 19:07:42.548864+00
368	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":15,"referencia":"746574656","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:25:40.404514+00	SEDEMAT-16072020-28-0005	5	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0005	\N	f	\N
365	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"533535353","fecha":"2020-07-03T13:22:30.622Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":101}}}	1000000.0	2020-07-16 13:24:51.069615+00	SEDEMAT-16072020-28-0003	3	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0003	\N	f	\N
382	28	{"usuario":{"username":"prueba14@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":137,"desde":"2020-01-02T03:26:59.492Z"},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":3,"desde":"2020-03-02T03:27:08.758Z"},{"id":17,"codigo":2045001,"descripcion":"Alquiler de Vehículos.","alicuota":"3.00","key":17,"desde":"2020-06-02T03:27:15.996Z"}],"estadoLicencia":"PERMANENTE","pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"777888999","fecha":"2020-07-23T03:30:09.433Z","costo":"1000000"},"correo":"prueba14@gmail.com","contribuyente":{"id":107,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837466","razonSocial":"jose coro segundo","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":61,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"115","referenciaMunicipal":"8000000018","fechaAprobacion":"2020-07-21T00:00:00.000Z","telefono":"4246336236","email":null,"denomComercial":"comercializadora","nombreRepresentante":"jose coro segundo","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true,"estadoLicencia":"PERMANENTE","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","minimoTributable":2,"desde":"2020-01-10T00:00:00.000Z"},{"id":17,"codigo":2045001,"descripcion":"Alquiler de Vehículos.","alicuota":"3.00","minimoTributable":5,"desde":"2020-02-01T00:00:00.000Z"}]}],"key":107}},"funcionario":{"username":"prueba14@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","key":137,"desde":"2020-01-02T03:26:59.492Z"},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":3,"desde":"2020-03-02T03:27:08.758Z"},{"id":17,"codigo":2045001,"descripcion":"Alquiler de Vehículos.","alicuota":"3.00","key":17,"desde":"2020-06-02T03:27:15.996Z"}],"estadoLicencia":"PERMANENTE","pago":[],"correo":"prueba14@gmail.com","contribuyente":{"id":107,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837466","razonSocial":"jose coro segundo","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":61,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"115","referenciaMunicipal":"8000000018","fechaAprobacion":"2020-07-21T00:00:00.000Z","telefono":"4246336236","email":null,"denomComercial":"comercializadora","nombreRepresentante":"jose coro segundo","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true,"estadoLicencia":"PERMANENTE","actividadesEconomicas":[{"id":137,"codigo":3007001,"descripcion":"Abastos, bodegas y pequeños detales de víveres.","alicuota":"2.00","minimoTributable":2,"desde":"2020-01-10T00:00:00.000Z"},{"id":17,"codigo":2045001,"descripcion":"Alquiler de Vehículos.","alicuota":"3.00","minimoTributable":5,"desde":"2020-02-01T00:00:00.000Z"}]}],"key":107},"referenciaMunicipal":"8000000019"},"idTramite":382}	1000000	2020-07-23 03:30:13.166609+00	SEDEMAT-23072020-28-0001	1	208	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-23072020-28-0001	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-23072020-28-0001	t	2020-07-23 03:34:54.624143+00
373	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"500000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2},{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3}],"estadoLicencia":"TEMPORAL","pago":{"metodoPago":"TRANSFERENCIA","banco":1,"referencia":"243224332","fecha":"2020-07-16T14:09:23.875Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"106","referenciaMunicipal":"8000000009","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true}],"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"500000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2},{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3}],"estadoLicencia":"TEMPORAL","pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"106","referenciaMunicipal":"8000000009","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true}],"key":101}}}	1000000.0	2020-07-16 14:09:28.210906+00	SEDEMAT-16072020-28-0009	9	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0009	\N	f	\N
372	28	{"usuario":{"telefono":"4246336236","correo":"rodrigolamus@gmail.com","denominacionComercial":"e","nombreRepresentante":"wgweg","capitalSuscrito":"58","tipoSociedadContrib":"Compañía Anónima","codCat":null,"contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","verificado":true,"verificacionTelefono":true}},"funcionario":{"telefono":"4246336236","correo":"rodrigolamus@gmail.com","denominacionComercial":"e","nombreRepresentante":"wgweg","capitalSuscrito":"58","tipoSociedadContrib":"Compañía Anónima","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"estadoLicencia":"TEMPORAL","pago":[{"monto":"1000000.00","formaPago":"TRANSFERENCIA","banco":"Banco Occidental de Descuento","fecha":"2020-07-15T00:00:00.000Z","nro":"23522523552"}],"referenciaMunicipal":"8000000010"},"idTramite":372}	1000000.0	2020-07-16 13:47:31.675709+00	SEDEMAT-16072020-28-0008	8	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0008	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-16072020-28-0008	t	2020-07-16 14:20:45.577978+00
378	28	{"usuario":{"username":"prueba10@gmail.com","denominacionComercial":"FARMACIA COVIDES","nombreRepresentante":"JOSE CORO","capitalSuscrito":"1000000","tipoSociedadContrib":"Compañía Anónima","telefono":"04127645681","actividadesEconomicas":[{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4,"desde":"2020-06-04T14:09:10.631Z"},{"id":9,"codigo":2037001,"descripcion":"Transporte de personal.","alicuota":"1.00","key":8,"desde":"2020-04-11T14:09:31.160Z"},{"id":8,"codigo":2036001,"descripcion":"Transporte aéreo de pasajeros.","alicuota":"3.00","key":7,"desde":"2020-02-13T14:09:35.148Z"},{"id":7,"codigo":2035001,"descripcion":"Transporte Lacustre o Marítimo de pasajeros.","alicuota":"3.00","key":6,"desde":"2019-08-09T14:09:39.397Z"}],"estadoLicencia":"PERMANENTE","pago":{"metodoPago":"TRANSFERENCIA","banco":9,"referencia":"1581891651","fecha":"2020-07-21T14:10:04.988Z","costo":"1000000"},"correo":"prueba10@gmail.com","contribuyente":{"id":86,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"308620483","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","parroquia":64,"sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","creditoFiscal":0,"puntoReferencia":"EDIF. IPSFA","verificado":true,"sucursales":[{"id":"83","referenciaMunicipal":"207R002131","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )","nombreRepresentante":"JOSE ABELD","capitalSuscrito":null,"creditoFiscal":"8414799.340000001","tipoSociedad":null,"actualizado":true},{"id":"84","referenciaMunicipal":"207R002132","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )","nombreRepresentante":"JOSE ABEID","capitalSuscrito":null,"creditoFiscal":"1730508.75","tipoSociedad":null,"actualizado":true},{"id":"86","referenciaMunicipal":"2900013829","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"covides@gmail.com","denomComercial":"FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )","nombreRepresentante":"LILIANA SANCHEZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"85","referenciaMunicipal":"207P000358","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.-","nombreRepresentante":"LILIANA SANCHEZ.-","capitalSuscrito":null,"creditoFiscal":"31434.00","tipoSociedad":null,"actualizado":true},{"id":"82","referenciaMunicipal":"AR20200024","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.","nombreRepresentante":"IVECO","capitalSuscrito":null,"creditoFiscal":"55.00","tipoSociedad":null,"actualizado":true}],"key":86}},"funcionario":{"username":"prueba10@gmail.com","denominacionComercial":"FARMACIA COVIDES","nombreRepresentante":"JOSE CORO","capitalSuscrito":"1000000","tipoSociedadContrib":"Compañía Anónima","telefono":"04127645681","actividadesEconomicas":[{"id":5,"codigo":2033001,"descripcion":"Servicio de encomiendas.","alicuota":"3.00","key":4,"desde":"2020-06-04T14:09:10.631Z"},{"id":9,"codigo":2037001,"descripcion":"Transporte de personal.","alicuota":"1.00","key":8,"desde":"2020-04-11T14:09:31.160Z"},{"id":8,"codigo":2036001,"descripcion":"Transporte aéreo de pasajeros.","alicuota":"3.00","key":7,"desde":"2020-02-13T14:09:35.148Z"},{"id":7,"codigo":2035001,"descripcion":"Transporte Lacustre o Marítimo de pasajeros.","alicuota":"3.00","key":6,"desde":"2019-08-09T14:09:39.397Z"}],"estadoLicencia":"PERMANENTE","pago":[],"correo":"prueba10@gmail.com","contribuyente":{"id":86,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"308620483","razonSocial":"FARMACIA COVIDES C.A.","denomComercial":"FARMACIA COVIDES C.A.","parroquia":64,"sector":"INDIO MARA","direccion":"Avenida 65 Calle  22A, Local Nro.  MZN","creditoFiscal":0,"puntoReferencia":"EDIF. IPSFA","verificado":true,"sucursales":[{"id":"83","referenciaMunicipal":"207R002131","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )","nombreRepresentante":"JOSE ABELD","capitalSuscrito":null,"creditoFiscal":"8414799.340000001","tipoSociedad":null,"actualizado":true},{"id":"84","referenciaMunicipal":"207R002132","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )","nombreRepresentante":"JOSE ABEID","capitalSuscrito":null,"creditoFiscal":"1730508.75","tipoSociedad":null,"actualizado":true},{"id":"86","referenciaMunicipal":"2900013829","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"covides@gmail.com","denomComercial":"FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )","nombreRepresentante":"LILIANA SANCHEZ","capitalSuscrito":null,"creditoFiscal":"0","tipoSociedad":null,"actualizado":true},{"id":"85","referenciaMunicipal":"207P000358","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.-","nombreRepresentante":"LILIANA SANCHEZ.-","capitalSuscrito":null,"creditoFiscal":"31434.00","tipoSociedad":null,"actualizado":true},{"id":"82","referenciaMunicipal":"AR20200024","fechaAprobacion":"2020-07-10T00:00:00.000Z","telefono":"4127645681","email":"gab.tc@icloud.com","denomComercial":"FARMACIA COVIDES C.A.","nombreRepresentante":"IVECO","capitalSuscrito":null,"creditoFiscal":"55.00","tipoSociedad":null,"actualizado":true}],"key":86}}}	1000000	2020-07-21 14:10:11.544049+00	SEDEMAT-21072020-28-0002	2	197	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-21072020-28-0002	\N	f	\N
375	28	{"usuario":{"telefono":"4246336236","correo":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"80","tipoSociedadContrib":"Compañía Anónima","codCat":null,"contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","verificado":true,"verificacionTelefono":true}},"funcionario":{"usuario":{"telefono":"4246336236","correo":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"80","tipoSociedadContrib":"Compañía Anónima","codCat":null,"contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","sector":"123","direccion":"mcbo","puntoReferencia":"mcbo","verificado":true,"verificacionTelefono":true}},"informe":"<p>pq quiero</p>","pago":[{"monto":"1000000.00","formaPago":"TRANSFERENCIA","banco":"Banco Occidental de Descuento","fecha":"2020-07-16T00:00:00.000Z","nro":"243354645"}]}}	1000000.0	2020-07-16 14:34:43.918672+00	SEDEMAT-16072020-28-0011	11	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0011	\N	f	\N
374	28	{"usuario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"estadoLicencia":"TEMPORAL","pago":{"metodoPago":"TRANSFERENCIA","banco":1,"referencia":"453453545","fecha":"2020-07-16T14:23:09.920Z","costo":"1000000.0"},"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"106","referenciaMunicipal":"8000000009","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true},{"id":"107","referenciaMunicipal":"8000000010","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"e","nombreRepresentante":"wgweg","capitalSuscrito":"58","creditoFiscal":0,"tipoSociedad":null,"actualizado":true}],"key":101}},"funcionario":{"username":"rodrigolamus@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"estadoLicencia":"TEMPORAL","pago":[],"correo":"rodrigolamus@gmail.com","contribuyente":{"id":101,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"312645978","razonSocial":"Comercializadora","denomComercial":"comercializadora","siglas":"CMCLZDR","parroquia":68,"sector":"123","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"sucursales":[{"id":"106","referenciaMunicipal":"8000000009","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"comercializadora","nombreRepresentante":"jose sanchez","capitalSuscrito":"50000000","creditoFiscal":0,"tipoSociedad":null,"actualizado":true},{"id":"107","referenciaMunicipal":"8000000010","fechaAprobacion":"2020-07-16T00:00:00.000Z","telefono":"4246336236","email":"rodrigolamus@gmail.com","denomComercial":"e","nombreRepresentante":"wgweg","capitalSuscrito":"58","creditoFiscal":0,"tipoSociedad":null,"actualizado":true}],"key":101},"referenciaMunicipal":"8000000011"},"idTramite":374}	1000000.0	2020-07-16 14:23:35.766739+00	SEDEMAT-16072020-28-0010	10	192	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-16072020-28-0010	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-16072020-28-0010	t	2020-07-16 14:29:01.363637+00
376	28	{"usuario":{"username":"orderleep@gmail.com","denominacionComercial":"Empanadas Triny","nombreRepresentante":"Triny Rosales","capitalSuscrito":"5000000","tipoSociedadContrib":"Compañía Anónima","telefono":"+584146053291","actividadesEconomicas":[{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3}],"estadoLicencia":"PERMANENTE","pago":{"metodoPago":"PUNTO DE VENTA","banco":19,"referencia":"588888441","fecha":"2020-07-19T22:19:05.613Z","costo":"1000000"},"correo":"orderleep@gmail.com","contribuyente":{"id":105,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"4005","razonSocial":"mi casa es esta CA","denomComercial":"Empanadas Triny","siglas":"CCA","parroquia":62,"sector":"Cañada Honda","direccion":"Av 21 residencias visoca","creditoFiscal":0,"puntoReferencia":"diagolanl","verificado":true,"key":105}},"funcionario":{"username":"orderleep@gmail.com","denominacionComercial":"Empanadas Triny","nombreRepresentante":"Triny Rosales","capitalSuscrito":"5000000","tipoSociedadContrib":"Compañía Anónima","telefono":"+584146053291","actividadesEconomicas":[{"id":4,"codigo":2032001,"descripcion":"Transporte Aéreo y Marítimo de Carga.","alicuota":"3.50","key":3}],"estadoLicencia":"PERMANENTE","pago":[],"correo":"orderleep@gmail.com","contribuyente":{"id":105,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"4005","razonSocial":"mi casa es esta CA","denomComercial":"Empanadas Triny","siglas":"CCA","parroquia":62,"sector":"Cañada Honda","direccion":"Av 21 residencias visoca","creditoFiscal":0,"puntoReferencia":"diagolanl","verificado":true,"key":105},"referenciaMunicipal":"8000000012"},"idTramite":376}	1000000	2020-07-19 22:19:16.91203+00	SEDEMAT-19072020-28-0001	1	205	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-19072020-28-0001	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-19072020-28-0001	t	2020-07-19 22:20:56.922172+00
377	28	{"usuario":{"username":"prueba13@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro","capitalSuscrito":"360000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"estadoLicencia":"TEMPORAL","pago":{"metodoPago":"TRANSFERENCIA","banco":8,"referencia":"546372851","fecha":"2020-07-21T12:29:36.499Z","costo":"1000000"},"correo":"prueba13@gmail.com","contribuyente":{"id":106,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837465","razonSocial":"jose coro","denomComercial":"comercializadora","siglas":"corocorocoro","parroquia":65,"sector":"bolivar","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":106}},"funcionario":{"username":"prueba13@gmail.com","denominacionComercial":"comercializadora","nombreRepresentante":"jose coro","capitalSuscrito":"360000000","tipoSociedadContrib":"Compañía Anónima","telefono":"4246336236","actividadesEconomicas":[{"id":1,"codigo":2029001,"descripcion":"Transporte Terrestre de Carga refrigerada.","alicuota":"2.00","key":0},{"id":2,"codigo":2030001,"descripcion":"Almacenamiento de productos, materiales, insumos, equipos, maquinarias.","alicuota":"2.00","key":1},{"id":3,"codigo":2031001,"descripcion":"Almacenamiento Refrigerado.","alicuota":"3.50","key":2}],"estadoLicencia":"TEMPORAL","pago":[],"correo":"prueba13@gmail.com","contribuyente":{"id":106,"tipoDocumento":"J","tipoContribuyente":"JURIDICO","documento":"192837465","razonSocial":"jose coro","denomComercial":"comercializadora","siglas":"corocorocoro","parroquia":65,"sector":"bolivar","direccion":"mcbo","creditoFiscal":0,"puntoReferencia":"mcbo","verificado":true,"key":106},"referenciaMunicipal":"8000000013"},"idTramite":377}	1000000	2020-07-21 12:29:41.381254+00	SEDEMAT-21072020-28-0001	1	207	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/planillas/SEDEMAT-21072020-28-0001	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT/certificados/SEDEMAT-21072020-28-0001	t	2020-07-21 12:59:28.626332+00
\.


--
-- Data for Name: tramite_archivo_recaudo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.tramite_archivo_recaudo (id_tramite, url_archivo_recaudo) FROM stdin;
298	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-26062020-27-0001/DocIdentidad.png
303	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-6-0001/RIFPropietario.png
303	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-6-0001/CedulaPropietario.png
303	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-6-0001/AutorizacionTramitesTerceros.png
303	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-6-0001/CedulaTercero.png
304	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-7-0001/RIFPropietario.png
304	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-7-0001/CedulaPropietario.png
304	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-7-0001/AutorizacionTramitesTerceros.png
304	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-7-0001/CedulaTercero.png
306	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-16-0001/CedulaPropietario.png
306	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-16-0001/DocumentoPropiedad.png
306	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-16-0001/Nomenclatura.png
306	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-16-0001/CopiaRif.png
307	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-10-0001/ConstanciaSAGAS.png
308	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-11-0001/ConstanciaSAGAS.png
309	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-12-0001/ConstanciaSAGAS.png
310	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SAGAS-30062020-13-0001/ConstanciaSAGAS.png
311	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-22-0001/CedulaPropietario.png
311	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-22-0001/PoderCopiaCedulaTramitante.png
311	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-22-0001/PagosMunicipales.png
311	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-22-0001/DocumentoPropiedad.png
311	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-22-0001/Bienhechurias.png
312	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-14-0001/CedulaPropietario.png
313	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-15-0001/CedulaPropietario.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/Croquis.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/Fachada.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/CedulaPropietario.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/AutorizacionTramitesTerceros.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/CedulaTercero.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/ConstanciaNomenclatura.png
314	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-23-0001/ReciboCorpoelec.png
315	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-24-0001/Croquis.png
315	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-24-0001/Fachada.png
315	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-24-0001/ConstanciaNomenclatura.png
315	https://sut-maracaibo.s3.us-east-2.amazonaws.com/CPU-30062020-24-0001/ConformidadUso.png
317	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEPAR-30062020-18-0001/CedulaSolicitante.png
318	https://sut-maracaibo.s3.us-east-2.amazonaws.com/IMTCUMA-30062020-21-0001/ComunicacionRenovacion.png
318	https://sut-maracaibo.s3.us-east-2.amazonaws.com/IMTCUMA-30062020-21-0001/ActaAsamblea.png
318	https://sut-maracaibo.s3.us-east-2.amazonaws.com/IMTCUMA-30062020-21-0001/PlanillaJuntaDirectiva.png
318	https://sut-maracaibo.s3.us-east-2.amazonaws.com/IMTCUMA-30062020-21-0001/PlanillaRegistrosUnidades.png
318	https://sut-maracaibo.s3.us-east-2.amazonaws.com/IMTCUMA-30062020-21-0001/CertificacionDePrestacion.png
319	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-30062020-28-0001/RegistroComercio.png
319	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-30062020-28-0001/Contrato.png
319	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-30062020-28-0001/CCNT.png
319	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-30062020-28-0001/Facturas.png
319	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-30062020-28-0001/RIF.png
320	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-27-0001/DocIdentidad.jpg
321	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-27-0002/DocIdentidad.jpg
322	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-27-0003/DocIdentidad.jpg
323	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-27-0004/DocIdentidad.jpg
324	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-27-0005/DocIdentidad.jpg
325	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0001/CCNT.jpg
326	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0002/RegistroComercio.png
326	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0002/Contrato.png
326	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0002/CCNT.png
326	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0002/Facturas.jpg
326	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-01072020-28-0002/RIF.png
327	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-27-0001/DocIdentidad.jpeg
328	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-28-0001/RegistroComercio.jpeg
328	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-28-0001/Contrato.jpeg
328	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-28-0001/CCNT.jpeg
328	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-28-0001/Facturas.jpeg
328	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-02072020-28-0001/RIF.jpeg
329	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-03072020-28-0001/CCNT.png
331	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-10072020-27-0001/DocIdentidad.png
334	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-13072020-27-0001/DocIdentidad.png
336	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-13072020-27-0002/DocIdentidad.jpg
340	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-14072020-28-0001/CCNT.jpeg
341	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-14072020-28-0002/CCNT.png
350	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-27-0001/DocIdentidad.jpg
352	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0004/CCNT.png
353	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0005/RegistroComercio.png
353	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0005/Contrato.png
353	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0005/CCNT.png
353	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0005/Facturas.png
353	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-15072020-28-0005/RIF.png
372	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-16072020-28-0008/RIF.png
375	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-16072020-28-0011/RIF.pdf
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.usuario (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono, id_contribuyente) FROM stdin;
133	Rodrigo Lamus	\N	\N	\N	\N	4	\N	\N	\N
135	Ricardo Portillo	zulianadelresorte@gmail.com	San Jacinto	23555666	V	4	$2a$10$iP9W9NqTnbktAG8q6wptSO0zm7YqMHEEUvcn7AtCNwBMbkjRu35Z6	4121100342	\N
82	Funcionario INTCUMA	funcionario@intcuma.com	INTCUMA	1023102938	V	3	$2a$10$qVi/NuT7X1ELSfz5mpM8e.OrMKAuSqJLPQ4H45/SB/WiwUw2TkA2i	1829038123	\N
68	Funcionario CPU	funcionario@cpu.com	CPU	1283190247	V	3	$2a$10$qLVJeDD5mKiXlhrNQEJDtOX9baIZcjY3zwMmepViWXp.VENHwaOda	9271092741	\N
83	Admin SEDEMAT	admin@sedemat.com	SEDEMAT	1923812093	V	2	$2a$10$24HQ9feMqbPag1esm.IhIOkaAYcQlTKeKlTZlU8xg78bLqeQuCCMC	1902831092	\N
144	jose	pruebaprueba123@gmail.com	mcbo	12345695	V	4	$2a$10$jMGwmkO/XLxPwIwtGen4vOZRdOyFizMM1ewI3h/39gCt3wx16xWTS	4246336236	\N
145	Jose Fake	prueba@gmail.com	JKJAKA	12345696	V	4	$2a$10$7nTTW.PNOJKFGGZ1fC7nBeXD2pPe.fFva9KvkZxfhJYXrDzU9gqw6	4121100342	\N
149	jose	prueba123@gmail.com	mcbo	78945612	V	4	$2a$10$rZVst/BmC4CAE4lK.DrkCewKxkYl/bog4hyerwRx0wf0ZboRK.JBm	4246336236	\N
150	Prueba	user2@gmail.com	San Jacinto	30002000	V	4	$2a$10$0BtHlMFRPBB0vv7ldjv7c.GMEuWiBwF8RxpehAhHJnky5xEpNu.W6	4121100342	\N
151	jose	zulianadecamionas123@gmail.com	mcbo	12345652	V	4	$2a$10$4koNifuQ4UDHwz2OlzJlN.KecSy1h99yjTSIYquFGFfpn/DrwD.JC	4246336236	\N
152	Jose Sanchez	zetalimentosca@gmail.com	urb. San Miguel, calle 96	12981762	V	4	$2a$10$6dA1lQK579FynEaPu/q3ruvJAq9B5rqFStkd6wdERfHikxgPNShDi	4246336236	\N
153	Jose Perez	comercializadora5j@gmail.com	av. 16, calle 77 (5 de Julio)	12934856	V	4	$2a$10$IS8k7Q0GfJdDC6PlZUBrPOtgH6SPwqrqtEPQ2oq5NbrobSACJ.pTi	4246336236	\N
154	mahuampi alvarado	mahuampi@waku.com	av 21	10888777	V	4	$2a$10$FOiZ/HB5jxBjlYDZUFitEOIqCT3Apry3te4fNADLuSoqG3iQzklDm	4146053299	\N
146	soy yo	fake2@gmail.com	av 21 	9999999	V	4	$2a$10$WyvOcRw0D0gJPyRxNP4cO.GJCk3l1PlAmwT2gpNRIo5KwYnkAReuG	4146053291	\N
155	digitel	impuestos_digitel@digitel.com.ve	s8102389102839183lkajsd	1293812738	V	4	$2a$10$gMg.7ejD6lFb.slFmg4V8OuiJgY1Pwl9fTIxtTCWe.HDbBKb/dwqG	1902739127	84
55	Super Usuario	super@user.com	Super Usuario	1	V	1	$2a$10$VVT8CHvO3jEEoj/djKK4Z.CGPO9JAHw1NMUIK6QwM3BEwElf68kUW	\N	\N
56	Administrador Bomberos	admin@bomberos.com	Bomberos	1231231231	V	2	$2a$10$nqEy4iyMTQJLAN.BOQ2GuuWioAwRcnXY7ClFbJtmp4svHLg9os/8m	1231231231	\N
59	Administrador SAGAS	admin@sagas.com	SAGAS	123123	V	2	$2a$10$.avdkJGtcLhgw/UydHdZf.QEeiSoAjUxRM/xLiTA1gQLUDkDy4lfm	1231231231	\N
66	Administrador Alcaldia	admin@alcaldia.com	Alcaldia	99999999	V	2	$2a$10$OtCHXU7MOIa6a5K2dt.soOa4AvzrKvp5qY1RtYTaCQqpV2.KTsOyu	8123814877	\N
67	Administrador CPU	admin@cpu.com	CPU	1231234444	V	2	$2a$10$qEObA7PrDPq2vv/MsfcyFutEKZQuPdVxQnv.5cafIrxfaBnN/P0ba	1231239811	\N
70	Director CPU	director@cpu.com	CPU	27139154	V	5	$2a$10$yBVC5M9rGWV5i.i2Nyl1fOGg1FKV2HQ0keq3jPcOvrGXtrjEra.z.	1231231231	\N
65	Funcionario SAGAS	funcionario@sagas.com	SAGAS	123133333	V	3	$2a$10$Na8DEr4PxMVxAQXgeAGkR.DjVx7YX/8/FJIhPeePIrPzKItJvTscy	1231231231	\N
57	Funcionario Bomberos	funcionario@bomberos.com	Bomberos	123123123	V	3	$2a$10$fFZ3EHbzdimZ9tDvrGod9ureMPkROVtzScEd0pO/piaQh6RLmedMG	1231231233	\N
71	Funcionario Alcaldia	funcionario@alcaldia.com	Alcaldia	7878787855	V	3	$2a$10$4vosHs6BExfapyssBS5XUekAR9AUa2Be.mhjLuqqmr7i1aZCWUehu	7777777777	\N
72	Administrador Terminal	terminal@admin.com	Terminal	128488188	V	2	$2a$10$hIeSExSylu8RY2bVPk6dPeLzKIR7Wo0yNjvRyqxR/QwZqTYEEf4wq	1723817728	\N
73	Funcionario Terminal	funcionario@terminal.com	Terminal	1028124812	V	3	$2a$10$4oNhbsHJuAaFE.xY8bS1HOPakehWJmx6IkGbuaU57nBqro7iLsgg.	1092471093	\N
75	Funcionario SEDEPAR	funcionario@sedepar.com	SEDEPAR	1289417241	V	3	$2a$10$8.dFFea0jSaDPFYmH4GM9urNDgGy6SawTnqALfevVvQdzodEkR7fS	1974102937	\N
76	Administrador SEDEPAR	admin@sedepar.com	SEDEPAR	1294712034	V	2	$2a$10$mIBjS3jXMabi8XXohLECoeyKOUr.rZc8jlQXvdZcaSaZT88YLYLaG	8374198241	\N
77	Administrador Policia	admin@policia.com	Policia	1249712091	V	2	$2a$10$P.v8kW77Xzm1ecmVsuBVuu.5avlhiv8izDmK51hW2/Jj6q/j/beNi	1029471204	\N
78	Funcionario Policia	funcionario@policia.com	Policia	1293712049	V	3	$2a$10$e.DuvVSdwlr23z1I8B/STeX5V.8V3rhoeXgRWokiP.dEmf3A/eoPK	1927312029	\N
79	Administrador IMA	admin@ima.com	IMA	1028310919	V	2	$2a$10$I2NhOoazRC2gF0pIdzNXrumPh0soj/9/KDA5dx1RqDNrow1fNzsbG	1923109472	\N
80	Funcionario IMA	funcionario@ima.com	IMA	1231740197	V	3	$2a$10$eAu/NEg9vEd5nKXbjSyemODqqLt2J1nO4joWhwbDpZopJAj7N0ZSW	1902741092	\N
81	Administrador INTCUMA	admin@intcuma.com	INTCUMA	1239812938	V	2	$2a$10$mHlp3WfgE.99gg2i2wSI2OrL29UABov9Lo4iylvngFZTwAi2gmBOa	9132801238	\N
120	Rafael Lares	cedgob2020@gmail.com	Av 21 Calle 86	15592914	V	4	$2a$10$z5gRrl3ezE0Ksj/Q4.A2gevmo/llADCLtfjKdDEfwL2Jv9gIMOYq6	4129661659	\N
121	Brian Maldonado	bhmadolnado@gmail.com	av 16	9747320	V	4	$2a$10$lnO3K4QhVgPft.9pqZBlt.M6mfASHTHX.Fqs./8xKgC7EPd8LZIfe	4129661659	\N
122	Jhon Jose Romay	jhonjromy@gmail.com	av 21	16079142	V	4	$2a$10$RcZ6dQf5Tdi0wgcq2lH8a.VG4ab4z8nx68V1ZdRwE58MHBVU3y4t.	4129661659	\N
124	Raul Fuentes	jj5star@hotmail.com	av 21 calle 86	10555777	V	4	$2a$10$qCFDSaIdAEZi3dH4RLXT/uQk2qQ0IQOkmES2ycbXXKH2bkJNNBUSW	4146053291	\N
126	jose	zulianadepersianas1@gmail.com	mcbo	12345678	V	4	$2a$10$5is48UJlOyJ5jmHhMMRBaucBw/g9HTYFz/l5O/O/xOnRuoSd.04em	4246336236	\N
125	Ranhdal Yon	yonset@gmail.com	Los Prados 	124435366	V	4	$2a$10$FH65lFZrmmpHk35xPTSfTeMwz0C4lVmqN309UJIl5EQuCZiMncHsC	4121100342	\N
127	Alberto Santos	exval2008@hotmail.com	La Rosaleda	19649021	V	4	$2a$10$.t24sVvZUGAGnovMMBxUPOdBBo.PTCd4vXPfMKv1idpA.qKGE7ynW	4121100342	\N
118	Jose Andres Sanchez	jsanchez.waku@gmail.com	asdasdasd	25848973	V	4	$2a$10$Rsw1oZfuB2.u3X410AGUYedDg9W3WW89DEvBMhLvd7HJfhNcIDcoa	1231241231	84
119	Jhonnatan Romay	romayjj@gmail.com	Av 21 calle 86	18496685	V	4	$2a$10$Mfw/1FYYPxQOiXzfEM19wen5RTTychOjBke778b/kYKJYv2iXhCX.	4146053291	86
117	Funcionario SEDEMAT	funcionario@sedemat.com	daidajiwjfiieajdk	1231931298	V	3	$2a$10$fbutta0xyv6uPZEaOP/D8uTRFNOl1/3eZ61SpOmqFyLSmJl31NzWy	4243828238	86
116	Cajero SEDEMAT	cajero@sedemat.com	SEDEMAT	1023910231	V	3	$2a$10$EUnmYqbqHl6Aw2FoUYofmOebPprOKWkHFJY3OE2GthBQhwi4pSGvO	1092831209	86
143	Fake User	fakeuser@gmail.com	Los Olivos	20002000	V	4	$2a$10$Ltgb.zGhrTjfu/qzgUPTIeU0UJpQVqxKi408esaneOec/p7hTmtMW	4121100342	111
128	Roberto Blas	zupeca69@gmail.com	Los Naranjos	15999000	V	4	$2a$10$B3Y4WRvVIyZMVWNl3/wkDephZUPtu4zOjNG9wg0wcc3flhw1k6chq	4121100342	\N
129	jose	zapasolca1@gmail.com	mcbo	12345688	V	4	$2a$10$MHLc0mb9itLXHI/oJmVUeu3uv5wSDVBO/N6vlZs919ZvCE1hsZCSO	4246336236	\N
130	Willy Jhons	willyjhons.mcbo17@gmail.com	La Rotaria	18455333	V	4	$2a$10$EamfUaXVpfADhVn5VTd5sOYBeeAm7PNrB8.C6kiQOghgWT1Owb4Su	4121100342	\N
132	Ricardo Portillo	scacontadores2@gmail.com	Los Bucares	20000333	V	4	$2a$10$1kNaL8HpUQJujG3/n1phNOvo8gCyj2h0hWjBrFSNeHwSMLdZcG5Ym	4121100342	\N
131	jose	tecalsucre@gmail.com	mcbo	12345690	V	4	$2a$10$IUaopzSxED716KwgJAtP/.ZZO6ldoj4n.5mrPFGHvDmxviX.RYg0i	4246336236	\N
136	Carlos Lopez	zulianaderodamientos1234@gmail.com	Veritas	7555189	V	4	$2a$10$Ge2MRYzw3KdJW3xR6CxauOj.JcRNp5WLebm3x80i5KIHtjkqTQaze	4121100342	\N
137	Yoly Perez	yolyjeansca123@hotmail.com	La pradera	18966554	V	4	$2a$10$Y5BdJcbk3NUuqPgu.CWCm.NnzMNLCoF9bFi4hl4uYW0RBQOiZSRf2	4121100342	\N
138	Pablo Garcia	rbclientes4280123@gmail.com	Maracaibo	19000333	V	4	$2a$10$Sr71OOxl7fCUthRQuHS6buCpEGdnUQlsMETJfoLLJO3swo/7PHqTW	4121100342	\N
139	Carmen Rivas	csuarez.factory123@gmail.com	San Jacinto	36985214	V	4	$2a$10$NfyNa.zGD.0.9L7nCYYRZ.gQtQzJ1G4JBK2GLEU4V8pkFuTmBe5RK	4121100342	\N
141	Jhonatan romay	fulano2@gmail.com	av 21	18496688	V	4	$2a$10$X1IUKp0iGg.zQXooJLA8/eYXXfawj14J1oZdTYc2oXQ.AQs/jv26m	4146053291	\N
142	jose	zuliaelectronicstvca@gmail.com	mcbo	123456741	V	4	$2a$10$4d9.oqnA.ZemF/Xlhv2gMejQpdHujWtEXlVoik6Hw25JgQQPv706m	4246336236	\N
156	Jose sanchez	prueba2@gmail.com	mcbo	12345679	V	4	$2a$10$Bwx19dcofe0DnXQFqusq1uzRFK4w8Ph3tclCTWhWDtpJgtfmpi2aS	4246336236	85
58	External User	external@user.com	Aqui	27139153	V	4	$2a$10$1az9AKXYIZ48FrTXXnb24.QT89PZuCTh2n0zabqVW7G8YyKinYNXe	4127645681	86
157	Jose sanchez	prueba3@gmail.com	mcbo	10528417	V	4	$2a$10$k6aYLqQB7EPtbjsoWIhOPOcZTCDekgbYv1l2VfjdV1Tu2PCi/MWdS	4246336236	87
161	Julio Sanchez	juliosanchez@hotmail.com	x ahi x alla	123456789	V	4	$2a$10$AeZN8KeOMY1ztxkYb8jRI.BOcbNE0llM2kQPJcHWMMHn.ITe65Iri	4121231234	88
163	Jose sanchez	prueba4@gmail.com	mcbo	12543654	V	4	$2a$10$we.EpiOcpHibDjLTiaq1j.ZIRpL7WZPHs4ZrzXjNTPdMoTK7CKPBa	4246336236	89
164	jose perez	prueba5@gmail.com	mareaciabo	4562574	V	4	$2a$10$JpbRJ5.eeYiv2YAK9Sr8heE/JyzC.aSM5oKQDDIaw7kokGMwTp4Ve	4246336236	96
168	Jefe de Caja	jefe.caja@sedemat.com	SEDEMAT	1293123910	V	3	$2a$10$cxJY0yXUkwZSvcmQp4X1KOgJdzTi7Z1IObYl9XmWJw//1ixhhl6pa	1203912391	\N
172	Daniel Boza	danielbm87@gmail.com	av 21 	5678987	V	4	$2a$10$/kJjG7Cu5CS.0zVcox2V2uPQRiA12y7cqQqjePVU21wfkwejNjx2.	4146053291	97
165	ramon	prueba6@gmail.com	veritas	12354965	V	4	$2a$10$HLyRz/vnUeenpQJLOYpfyuRJkvDcyXGfQo77kVtz4KhW0zGBtHpji	4146359875	99
175	Jose sanchez	prueba8@gmail.com	mcbo	10528418	V	4	$2a$10$jxtyTBP6gr6H/ag2XL33MO7bk/KSz39kf70Ma9p.cx8vXm1JhwyJm	4246336236	\N
173	Jose sanchez	prueba7@gmail.com	mcbo	5235342	V	4	$2a$10$vgKxH1cDNAgVMEgGtKbvhew19X6VsFOsoPZZ9lH3dfwxziF18zgBC	4246336236	98
181	Triny Rosales	trosales@gmail.com	av 21 calle 86	18921679	V	4	$2a$10$OZStF4H9Xly7rurqLh6nqO6shVopXsfqSPG8kX1RW0zkWt878jiUm	4146053291	100
192	Comercializadora	rodrigolamus@gmail.com	mcbo	312645978	J	4	$2a$10$Y4oFwgBVYjunGKG0Cqofg.fUnvXg1qaJNWj/6SWdCpBDgZfftseI6	4246336236	101
207	jose sanchez	prueba13@gmail.com	mcbo	23543878	V	4	$2a$10$camAZt0lhARwvjy1Ix.HcuI3tab.Viopv1smSqRzxcAzaS0w6JSXW	4246336236	106
208	jose coro segundo	prueba14@gmail.com	mcbo	192837466	J	4	$2a$10$QniN2f/Vz/b4EMeXsyRO1uB7ygAZSDG0LBJ2CSxrX1s/rdz7/3toS	4246336236	107
209	Director Cobranzas	director.cobranzas@sedemat.com	asdasd	1234123412	V	5	$2a$10$ewWQU2Bc/dB8tCvF/x0fouhpJ/GBA35gLrT6R7d0fYqfVAhYnPKA.	1231241231	\N
178	asdasdas	externala@user.com	aqui	1231231232	V	4	$2a$10$Wc5ER1HbRegDfotBR0.xn.jJly3JIGf/q8i3feDKOqojzjGWdEnua	1231231232	\N
197	jose coro	prueba10@gmail.com	mcbo	312645977	J	4	$2a$10$D5j4iina0Z/IKAbNtRjJYuepOXFGcZV9pOyHZFTUusX4ZUtSr94Hm	4246336236	86
203	jose coro	prueba11@gmail.com	mcbo	312645976	J	4	$2a$10$IMVM8ZqElegM9saMJ/xBn.4WQsKSG6m65nk03gizrZRdBy82MrP8C	4246336237	86
194	jose sanchez	prueba9@gmail.com	mcbo	23543876	V	4	$2a$10$2xxbrJ7ESyxNwSpw5d.zeumnKedbiW5DMaKx7tQ8EZ/oUyV2A5F7i	4246336236	86
204	jose coro	prueba12@gmail.com	mcbo	356789134	J	4	$2a$10$W.LLdB0wHC5IAN2jshG.COoRGI11a.Fy1jdRK1ucGDKIhoHI7VCXW	4246336236	104
205	mi casa es esta CA	orderleep@gmail.com	Av 21 residencias visoca	4005	J	4	$2a$10$JSJdhQb87Lv0wIjxKQSfFupB.9X5Zl//Nac9rge0gUNn9QBYbQCJe	4146053291	105
\.


--
-- Data for Name: valor; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.valor (id_valor, descripcion, valor_en_bs) FROM stdin;
1	Bolivares	1
2	PETRO	500000
3	Dolar	200000
\.


--
-- Data for Name: variable; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.variable (id_var, nombre_variable) FROM stdin;
\.


--
-- Data for Name: variable_de_costo; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.variable_de_costo (id_variable_de_costo, id_tipo_tramite, id_operacion, precedencia, aumento) FROM stdin;
\.


--
-- Data for Name: variable_ordenanza; Type: TABLE DATA; Schema: public; Owner: pooijyzcnnfrso
--

COPY public.variable_ordenanza (id_variable, nombre, nombre_plural) FROM stdin;
1	Plano	Planos
2	Pre Inspección	Pre Inspecciones
4	Inspección	Inspecciones
3	Vivienda	Viviendas
5	Persona jurídica	Personas jurídicas
\.


--
-- Data for Name: base_task; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.base_task (task_id, name, kind, script) FROM stdin;
1	Fin de dia revisar pagos	SQL	SELECT revisar_pagos_fin_de_dia()
\.


--
-- Data for Name: chain_execution_config; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.chain_execution_config (chain_execution_config, chain_id, chain_name, run_at, max_instances, live, self_destruct, exclusive_execution, excluded_execution_configs, client_name) FROM stdin;
1	1	chain_1	1 1 1 1 *	\N	f	f	f	\N	\N
\.


--
-- Data for Name: chain_execution_parameters; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.chain_execution_parameters (chain_execution_config, chain_id, order_id, value) FROM stdin;
\.


--
-- Data for Name: database_connection; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.database_connection (database_connection, connect_string, comment) FROM stdin;
\.


--
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.execution_log (chain_execution_config, chain_id, task_id, name, script, kind, last_run, finished, returncode, pid) FROM stdin;
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.log (id, ts, client_name, pid, log_level, message) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.migrations (id, version) FROM stdin;
\.


--
-- Data for Name: run_status; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.run_status (run_status, start_status, execution_status, chain_id, current_execution_element, started, last_status_update, chain_execution_config) FROM stdin;
\.


--
-- Data for Name: task_chain; Type: TABLE DATA; Schema: timetable; Owner: pooijyzcnnfrso
--

COPY timetable.task_chain (chain_id, parent_id, task_id, run_uid, database_connection, ignore_error) FROM stdin;
1	\N	1	\N	\N	t
\.


--
-- Data for Name: ano; Type: TABLE DATA; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

COPY valores_fiscales.ano (id, descripcion) FROM stdin;
1	2015
2	2016
3	2017
4	2018
5	2019
6	2020
\.


--
-- Data for Name: construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

COPY valores_fiscales.construccion (valor_fiscal, id, tipo_construccion_id, ano_id) FROM stdin;
3.32	104	1	3
2.92	105	2	3
800.00	54	1	4
680.00	55	2	4
640.00	56	3	4
540.00	57	4	4
480.00	58	5	4
408.00	59	6	4
840.00	60	7	4
700.00	61	8	4
660.00	62	9	4
620.00	63	10	4
540.00	64	11	4
500.00	65	12	4
450.00	66	13	4
540.00	67	14	4
450.00	68	15	4
420.00	69	16	4
400.00	70	17	4
380.00	71	18	4
350.00	72	19	4
330.00	73	20	4
300.00	74	21	4
280.00	75	22	4
260.00	76	23	4
220.00	77	24	4
200.00	78	25	4
850.00	79	26	4
830.00	80	27	4
800.00	81	28	4
760.00	82	29	4
740.00	83	30	4
700.00	84	31	4
0.11	204	1	1
0.09	205	2	1
0.07	206	3	1
0.10	207	4	1
0.09	208	5	1
0.08	209	6	1
0.08	210	7	1
0.08	211	8	1
0.09	212	9	1
0.08	213	10	1
0.09	214	11	1
0.05	215	12	1
0.06	216	13	1
0.07	217	14	1
0.07	218	15	1
0.09	219	16	1
0.09	220	17	1
0.07	221	18	1
0.06	222	19	1
0.13	154	1	2
0.11	155	2	2
0.11	156	3	2
0.10	157	4	2
0.09	158	5	2
0.08	159	6	2
0.11	160	7	2
0.10	161	8	2
0.09	162	9	2
0.10	163	10	2
0.09	164	11	2
0.08	165	12	2
0.08	166	13	2
0.07	167	14	2
0.06	168	15	2
0.05	169	16	2
0.04	170	17	2
0.04	171	18	2
0.04	172	19	2
0.04	173	20	2
0.03	174	21	2
0.03	175	22	2
0.03	176	23	2
0.03	177	24	2
0.03	178	25	2
0.38	179	26	2
0.23	180	27	2
0.20	181	28	2
0.12	182	29	2
0.10	183	30	2
0.03	184	31	2
0.03	185	32	2
0.03	186	33	2
0.04	187	34	2
0.05	188	35	2
0.05	189	36	2
0.02	190	37	2
0.02	191	38	2
0.09	192	39	2
0.07	193	40	2
0.04	194	41	2
0.04	195	42	2
0.03	196	43	2
0.28	197	44	2
0.24	198	45	2
0.14	199	46	2
1.11	137	34	3
1.01	138	35	3
0.91	139	36	3
0.81	140	37	3
0.71	141	38	3
0.90	142	39	3
0.78	143	40	3
0.65	144	41	3
0.53	145	42	3
0.41	146	43	3
2.37	147	44	3
1.82	148	45	3
1.46	149	46	3
1.17	150	47	3
0.93	151	48	3
1.39	152	49	3
1.12	153	50	3
0.04	223	20	1
0.03	224	21	1
0.05	225	22	1
0.06	226	23	1
0.03	227	24	1
0.03	228	25	1
0.03	229	26	1
0.02	230	27	1
0.10	231	28	1
0.08	232	29	1
0.10	233	30	1
0.31	234	31	1
0.19	235	32	1
0.08	236	33	1
0.08	237	34	1
0.17	238	35	1
0.17	239	36	1
0.07	240	37	1
0.06	241	38	1
0.07	242	39	1
0.03	243	40	1
0.02	244	41	1
0.01	245	42	1
0.03	246	43	1
0.07	247	44	1
0.06	248	45	1
0.03	249	46	1
0.08	250	47	1
0.23	251	48	1
0.20	252	49	1
0.20	253	50	1
0.10	200	47	2
0.07	201	48	2
0.14	202	49	2
0.10	203	50	2
2.51	106	3	3
2.10	107	4	3
1.70	108	5	3
1.29	109	6	3
1.29	110	7	3
1.14	111	8	3
0.95	112	9	3
0.80	113	10	3
0.71	114	11	3
0.62	115	12	3
0.50	116	13	3
0.28	117	14	3
0.26	118	15	3
0.24	119	16	3
0.22	120	17	3
0.21	121	18	3
0.19	122	19	3
0.17	123	20	3
0.15	124	21	3
0.14	125	22	3
0.12	126	23	3
0.10	127	24	3
0.08	128	25	3
2.52	129	26	3
2.12	130	27	3
1.73	131	28	3
1.61	132	29	3
1.51	133	30	3
1.41	134	31	3
1.31	135	32	3
1.21	136	33	3
680.00	85	32	4
640.00	86	33	4
600.00	87	34	4
580.00	88	35	4
560.00	89	36	4
540.00	90	37	4
520.00	91	38	4
500.00	92	39	4
480.00	93	40	4
460.00	94	41	4
440.00	95	42	4
420.00	96	43	4
680.00	97	44	4
660.00	98	45	4
640.00	99	46	4
600.00	100	47	4
580.00	101	48	4
560.00	102	49	4
540.00	103	50	4
2160000.00	4	1	5
1980000.00	5	2	5
1620000.00	6	3	5
1440000.00	7	4	5
1260000.00	8	5	5
1080000.00	9	6	5
2160000.00	10	7	5
2052000.00	11	8	5
1944000.00	12	9	5
1836000.00	13	10	5
1728000.00	14	11	5
1620000.00	15	12	5
1440000.00	16	13	5
1332000.00	17	14	5
1224000.00	18	15	5
1116000.00	19	16	5
1008000.00	20	17	5
900000.00	21	18	5
792000.00	22	19	5
1188000.00	23	20	5
1080000.00	24	21	5
1008000.00	25	22	5
936000.00	26	23	5
792000.00	27	24	5
720000.00	28	25	5
2160000.00	29	26	5
2088000.00	30	27	5
2016000.00	31	28	5
1944000.00	32	29	5
1872000.00	33	30	5
1800000.00	34	31	5
2160000.00	35	32	5
1656000.00	36	33	5
1584000.00	37	34	5
1512000.00	38	35	5
1440000.00	39	36	5
1368000.00	40	37	5
1296000.00	41	38	5
1800000.00	42	39	5
1728000.00	43	40	5
1656000.00	44	41	5
1584000.00	45	42	5
1512000.00	46	43	5
2448000.00	47	44	5
2376000.00	48	45	5
2304000.00	49	46	5
2160000.00	50	47	5
2088000.00	51	48	5
2016000.00	52	49	5
1944000.00	53	50	5
2160000.00	256	1	6
1980000.00	257	2	6
1620000.00	258	3	6
1440000.00	259	4	6
1260000.00	260	5	6
1080000.00	261	6	6
2160000.00	262	7	6
2052000.00	263	8	6
1944000.00	264	9	6
1836000.00	265	10	6
1728000.00	266	11	6
1620000.00	267	12	6
1440000.00	268	13	6
1332000.00	269	14	6
1224000.00	270	15	6
1116000.00	271	16	6
1008000.00	272	17	6
900000.00	273	18	6
792000.00	274	19	6
1188000.00	275	20	6
1080000.00	276	21	6
1008000.00	277	22	6
936000.00	278	23	6
792000.00	279	24	6
720000.00	280	25	6
2160000.00	281	26	6
2088000.00	282	27	6
2016000.00	283	28	6
1944000.00	284	29	6
1872000.00	285	30	6
1800000.00	286	31	6
2160000.00	287	32	6
1656000.00	288	33	6
1584000.00	289	34	6
1512000.00	290	35	6
1440000.00	291	36	6
1368000.00	292	37	6
1296000.00	293	38	6
1800000.00	294	39	6
1728000.00	295	40	6
1656000.00	296	41	6
1584000.00	297	42	6
1512000.00	298	43	6
2448000.00	299	44	6
2376000.00	300	45	6
2304000.00	301	46	6
2160000.00	302	47	6
2088000.00	303	48	6
2016000.00	304	49	6
1944000.00	305	50	6
\.


--
-- Data for Name: sector; Type: TABLE DATA; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

COPY valores_fiscales.sector (descripcion, parroquia_id, id) FROM stdin;
001	108	1
002	108	2
003	108	3
004	108	4
005	108	5
006	108	6
007	108	7
008	108	8
009	108	9
010	108	10
001	61	11
002	61	12
003	61	13
004	61	14
005	61	15
006	61	16
001	62	17
002	62	18
003	62	19
004	62	20
005	62	21
006	62	22
007	62	23
008	62	24
009	62	25
010	62	26
001	109	27
002	109	28
003	109	29
004	109	30
005	109	31
006	109	32
007	109	33
008	109	34
009	109	35
001	63	36
002	63	37
003	63	38
004	63	39
005	63	40
006	63	41
007	63	42
008	63	43
009	63	44
010	63	45
001	64	46
002	64	47
003	64	48
004	64	49
005	64	50
006	64	51
007	64	52
008	64	53
009	64	54
010	64	55
011	64	56
012	64	57
013	64	58
001	65	59
002	65	60
003	65	61
004	65	62
005	65	63
006	65	64
007	65	65
008	65	66
009	65	67
010	65	68
011	65	69
012	65	70
013	65	71
014	65	72
015	65	73
016	65	74
017	65	75
018	65	76
001	66	77
002	66	78
003	66	79
004	66	80
005	66	81
006	66	82
007	66	83
008	66	84
009	66	85
010	66	86
011	66	87
012	66	88
013	66	89
014	66	90
015	66	91
016	66	92
017	66	93
018	66	94
001	110	95
002	110	96
003	110	97
004	110	98
005	110	99
006	110	100
007	110	101
008	110	102
009	110	103
010	110	104
011	110	105
012	110	106
013	110	107
014	110	108
015	110	109
016	110	110
017	110	111
001	68	112
002	68	113
003	68	114
004	68	115
005	68	116
006	68	117
007	68	118
008	68	119
009	68	120
010	68	121
011	68	122
012	68	123
013	68	124
014	68	125
015	68	126
016	68	127
017	68	128
001	69	129
002	69	130
003	69	131
004	69	132
005	69	133
006	69	134
007	69	135
008	69	136
009	69	137
010	69	138
001	70	139
002	70	140
003	70	141
004	70	142
005	70	143
006	70	144
007	70	145
008	70	146
009	70	147
010	70	148
011	70	149
012	70	150
013	70	151
014	70	152
001	71	153
002	71	154
003	71	155
004	71	156
005	71	157
006	71	158
007	71	159
008	71	160
009	71	161
010	71	162
011	71	163
012	71	164
013	71	165
014	71	166
015	71	167
016	71	168
017	71	169
018	71	170
001	72	171
002	72	172
003	72	173
004	72	174
005	72	175
006	72	176
007	72	177
008	72	178
009	72	179
010	72	180
011	72	181
012	72	182
013	72	183
014	72	184
015	72	185
001	73	186
002	73	187
003	73	188
004	73	189
005	73	190
006	73	191
007	73	192
008	73	193
009	73	194
010	73	195
011	73	196
012	73	197
013	73	198
001	75	199
002	75	200
003	75	201
004	75	202
005	75	203
006	75	204
007	75	205
001	76	206
002	76	207
003	76	208
004	76	209
005	76	210
006	76	211
007	76	212
008	76	213
009	76	214
010	76	215
011	76	216
012	76	217
013	76	218
014	76	219
015	76	220
\.


--
-- Data for Name: terreno; Type: TABLE DATA; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

COPY valores_fiscales.terreno (valor_fiscal, sector_id, id, ano_id) FROM stdin;
161.55	1	1	3
161.55	1	5	2
161.55	2	10	2
217.39	3	15	2
275.47	4	20	2
232.75	5	25	2
214.96	6	30	2
366.92	7	35	2
484.16	8	40	2
179.90	9	45	2
161.55	10	50	2
2410.15	11	55	2
2660.07	12	60	2
1993.26	13	65	2
1992.96	14	70	2
2297.56	15	75	2
2608.88	16	80	2
263.83	17	85	2
263.83	18	90	2
858.69	19	95	2
262.05	20	100	2
597.42	21	105	2
757.39	22	110	2
582.51	23	115	2
472.83	24	120	2
161.55	2	6	3
217.39	3	11	3
275.47	4	16	3
232.75	5	21	3
214.96	6	26	3
366.92	7	31	3
484.16	8	36	3
179.90	9	41	3
161.55	10	46	3
2410.15	11	51	3
2660.07	12	56	3
1993.26	13	61	3
1992.96	14	66	3
2297.56	15	71	3
2608.88	16	76	3
263.83	17	81	3
263.83	18	86	3
858.69	19	91	3
262.05	20	96	3
597.42	21	101	3
757.39	22	106	3
582.51	23	111	3
472.83	24	116	3
660.93	25	121	3
1700.00	1	2	4
1700.00	2	7	4
2550.00	3	12	4
2550.00	4	17	4
2550.00	5	22	4
2550.00	6	27	4
3400.00	7	32	4
4250.00	8	37	4
1700.00	9	42	4
1700.00	10	47	4
24650.00	11	52	4
27200.00	12	57	4
20400.00	13	62	4
20400.00	14	67	4
23800.00	15	72	4
27200.00	16	77	4
2550.00	17	82	4
4250.00	18	87	4
7650.00	19	92	4
2550.00	20	97	4
5100.00	21	102	4
6800.00	22	107	4
5100.00	23	112	4
4250.00	24	117	4
5950.00	25	122	4
5950.00	26	127	4
1093.85	32	160	2
1071.47	33	165	2
810.01	34	170	2
1956.93	35	175	2
230.42	36	180	2
658.33	37	185	2
439.21	38	190	2
460.79	39	195	2
520.91	40	200	2
415.54	41	205	2
461.66	42	210	2
461.66	43	215	2
521.51	44	220	2
207.38	45	225	2
3069.22	46	230	2
2612.30	47	235	2
2296.15	48	240	2
1430.78	49	245	2
969.23	50	250	2
2612.30	51	255	2
1991.54	52	260	2
2101.14	53	265	2
1119.26	54	270	2
1991.53	55	275	2
955.39	56	280	2
1071.47	33	161	3
810.01	34	166	3
1956.93	35	171	3
230.42	36	176	3
658.33	37	181	3
439.21	38	186	3
460.79	39	191	3
520.91	40	196	3
415.54	41	201	3
461.66	42	206	3
461.66	43	211	3
521.51	44	216	3
207.38	45	221	3
3069.22	46	226	3
2612.30	47	231	3
2296.15	48	236	3
1430.78	49	241	3
969.23	50	246	3
2612.30	51	251	3
1991.54	52	256	3
2101.14	53	261	3
1119.26	54	266	3
1991.53	55	271	3
955.39	56	276	3
3914.92	57	281	3
9350.00	33	162	4
6800.00	34	167	4
16150.00	35	172	4
2550.00	36	177	4
5950.00	37	182	4
4250.00	38	187	4
4250.00	39	192	4
4250.00	40	197	4
3400.00	41	202	4
4250.00	42	207	4
4250.00	43	212	4
4250.00	44	217	4
1700.00	45	222	4
25500.00	46	227	4
21250.00	47	232	4
18700.00	48	237	4
11900.00	49	242	4
8500.00	50	247	4
21250.00	51	252	4
16150.00	52	257	4
17850.00	53	262	4
21250.00	54	267	4
16150.00	55	272	4
8500.00	56	277	4
32300.00	57	282	4
1435.07	63	315	2
1438.74	64	320	2
1451.23	65	325	2
1943.44	66	330	2
1748.73	67	335	2
1218.34	68	340	2
1747.58	69	345	2
897.02	70	348	2
1440.07	71	353	2
2142.99	72	358	2
2132.55	73	363	2
2148.71	74	368	2
1943.96	75	373	2
1593.26	76	378	2
381.39	77	383	2
748.04	78	388	2
656.79	79	393	2
370.38	80	398	2
409.06	81	403	2
431.98	82	408	2
422.31	83	413	2
754.69	84	418	2
280.88	85	423	2
2192.30	86	428	2
1438.74	64	316	3
1451.23	65	321	3
1943.44	66	326	3
1748.73	67	331	3
1218.34	68	336	3
1747.58	69	341	3
897.02	70	346	3
1440.07	71	349	3
2142.99	72	354	3
2132.55	73	359	3
2148.71	74	364	3
1943.96	75	369	3
1593.26	76	374	3
381.39	77	379	3
748.04	78	384	3
656.79	79	389	3
370.38	80	394	3
409.06	81	399	3
431.98	82	404	3
422.31	83	409	3
754.69	84	414	3
280.88	85	419	3
2192.30	86	424	3
466.80	87	429	3
584.91	88	434	3
2192.32	89	439	3
23800.00	64	317	4
23800.00	65	322	4
32300.00	66	327	4
28900.00	67	332	4
20400.00	68	337	4
28900.00	69	342	4
23800.00	71	350	4
34850.00	72	355	4
34850.00	73	360	4
34850.00	74	365	4
32300.00	75	370	4
26350.00	76	375	4
3400.00	77	380	4
6800.00	78	385	4
5950.00	79	390	4
3400.00	80	395	4
3400.00	81	400	4
4250.00	82	405	4
4250.00	83	410	4
6800.00	84	415	4
2550.00	85	420	4
17850.00	86	425	4
4250.00	87	430	4
5100.00	88	435	4
17850.00	89	440	4
4250.00	90	445	4
161.53	95	473	2
207.70	96	478	2
459.23	97	483	2
731.55	98	488	2
611.53	99	493	2
657.69	100	498	2
161.53	101	503	2
207.70	102	508	2
415.38	103	513	2
830.77	104	518	2
657.70	105	523	2
161.53	106	528	2
459.23	107	533	2
459.23	108	538	2
459.23	109	543	2
161.53	110	548	2
459.23	111	553	2
161.54	112	558	2
161.54	113	563	2
161.54	114	568	2
161.54	115	573	2
179.88	116	578	2
366.92	117	583	2
366.92	118	586	2
878.48	119	591	2
207.70	96	474	3
459.23	97	479	3
731.55	98	484	3
611.53	99	489	3
657.69	100	494	3
161.53	101	499	3
207.70	102	504	3
415.38	103	509	3
830.77	104	514	3
657.70	105	519	3
161.53	106	524	3
459.23	107	529	3
459.23	108	534	3
459.23	109	539	3
161.53	110	544	3
459.23	111	549	3
161.54	112	554	3
161.54	113	559	3
161.54	114	564	3
161.54	115	569	3
179.88	116	574	3
366.92	117	579	3
366.92	118	584	3
878.48	119	587	3
217.38	120	592	3
794.99	121	597	3
1700.00	96	475	4
4250.00	97	480	4
5950.00	98	485	4
5100.00	99	490	4
5950.00	100	495	4
1700.00	101	500	4
1700.00	102	505	4
3400.00	103	510	4
6800.00	104	515	4
5950.00	105	520	4
1700.00	106	525	4
4250.00	107	530	4
4250.00	108	535	4
4250.00	109	540	4
1700.00	110	545	4
4250.00	111	550	4
1700.00	112	555	4
1700.00	113	560	4
1700.00	114	565	4
1700.00	115	570	4
1700.00	116	575	4
3400.00	117	580	4
7650.00	119	588	4
2550.00	120	593	4
6800.00	121	598	4
161.54	127	631	2
1675.38	128	636	2
1672.00	129	641	2
1421.38	130	646	2
1192.26	131	651	2
1671.78	132	656	2
1523.26	133	661	2
1447.90	134	666	2
1053.97	135	671	2
1537.12	136	676	2
1671.78	137	681	2
1709.65	138	686	2
161.15	139	691	2
194.53	140	696	2
162.15	141	701	2
185.66	142	706	2
636.79	143	711	2
160.57	144	716	2
162.15	145	721	2
162.39	146	726	2
162.39	147	731	2
229.95	148	736	2
192.73	149	741	2
369.72	150	745	2
231.15	151	750	2
1675.38	128	632	3
1672.00	129	637	3
1421.38	130	642	3
1192.26	131	647	3
1671.78	132	652	3
1523.26	133	657	3
1447.90	134	662	3
1053.97	135	667	3
1537.12	136	672	3
1671.78	137	677	3
1709.65	138	682	3
161.15	139	687	3
194.53	140	692	3
162.15	141	697	3
185.66	142	702	3
636.79	143	707	3
160.57	144	712	3
162.15	145	717	3
162.39	146	722	3
162.39	147	727	3
229.95	148	732	3
192.73	149	737	3
369.72	150	746	3
231.15	151	751	3
637.48	152	756	3
179.03	153	761	3
13600.00	128	633	4
27200.00	129	638	4
24650.00	130	643	4
19550.00	131	648	4
27200.00	132	653	4
25500.00	133	658	4
23800.00	134	663	4
17850.00	135	668	4
25500.00	136	673	4
27200.00	137	678	4
28050.00	138	683	4
1700.00	139	688	4
1700.00	140	693	4
1700.00	141	698	4
1700.00	142	703	4
5950.00	143	708	4
1700.00	144	713	4
1700.00	145	718	4
1700.00	146	723	4
1700.00	147	728	4
2550.00	148	733	4
1700.00	149	738	4
3400.00	150	742	4
2550.00	151	747	4
227.68	159	790	2
327.06	160	795	2
340.66	161	800	2
351.06	162	805	2
348.36	163	810	2
428.77	164	815	2
403.00	165	820	2
348.16	166	825	2
577.51	167	830	2
461.17	168	835	2
319.70	169	840	2
428.28	170	845	2
2065.17	171	850	2
1652.37	172	855	2
1486.66	173	860	2
1651.77	174	865	2
2669.76	175	870	2
3068.40	176	875	2
2065.86	177	880	2
2064.93	178	885	2
2761.98	179	890	2
2379.46	180	895	2
3068.54	181	900	2
4785.39	182	905	2
336.38	158	786	3
227.68	159	791	3
327.06	160	796	3
340.66	161	801	3
351.06	162	806	3
348.36	163	811	3
428.77	164	816	3
403.00	165	821	3
348.16	166	826	3
577.51	167	831	3
461.17	168	836	3
319.70	169	841	3
428.28	170	846	3
2065.17	171	851	3
1652.37	172	856	3
1486.66	173	861	3
1651.77	174	866	3
2669.76	175	871	3
3068.40	176	876	3
2065.86	177	881	3
2064.93	178	886	3
2761.98	179	891	3
2379.46	180	896	3
3068.54	181	901	3
4785.39	182	906	3
2550.00	159	787	4
3400.00	160	792	4
3400.00	161	797	4
3400.00	162	802	4
3400.00	163	807	4
4250.00	164	812	4
3400.00	165	817	4
3400.00	166	822	4
5100.00	167	827	4
5100.00	168	832	4
4250.00	169	837	4
4250.00	170	842	4
34000.00	171	847	4
27200.00	172	852	4
24650.00	173	857	4
27200.00	174	862	4
43350.00	175	867	4
50150.00	176	872	4
34000.00	177	877	4
34000.00	178	882	4
45050.00	179	887	4
39100.00	180	892	4
50150.00	181	897	4
78200.00	182	902	4
62050.00	183	907	4
24650.00	184	912	4
161.55	1	4	1
161.55	2	9	1
846.91	190	945	2
415.38	191	950	2
521.55	192	955	2
643.84	193	960	2
1465.37	194	965	2
459.24	195	970	2
646.16	196	975	2
2088.47	197	980	2
1093.85	198	985	2
1560.01	199	990	2
3066.93	200	995	2
1560.01	201	1000	2
4306.16	202	1005	2
1324.62	203	1010	2
2296.16	204	1015	2
3835.38	205	1020	2
173.07	206	1025	2
161.53	207	1030	2
161.53	208	1035	2
173.08	209	1040	2
207.70	210	1045	2
184.61	211	1050	2
161.55	212	1055	2
161.54	213	1060	2
173.08	214	1065	2
846.91	190	946	3
415.38	191	951	3
521.55	192	956	3
643.84	193	961	3
1465.37	194	966	3
459.24	195	971	3
646.16	196	976	3
2088.47	197	981	3
1093.85	198	986	3
1560.01	199	991	3
3066.93	200	996	3
1560.01	201	1001	3
4306.16	202	1006	3
1324.62	203	1011	3
2296.16	204	1016	3
3835.38	205	1021	3
173.07	206	1026	3
161.53	207	1031	3
161.53	208	1036	3
173.08	209	1041	3
207.70	210	1046	3
184.61	211	1051	3
161.55	212	1056	3
161.54	213	1061	3
173.08	214	1066	3
3400.00	191	947	4
4250.00	192	952	4
5950.00	193	957	4
11900.00	194	962	4
4250.00	195	967	4
5950.00	196	972	4
17000.00	197	977	4
9350.00	198	982	4
12750.00	199	987	4
25500.00	200	992	4
12750.00	201	997	4
35700.00	202	1002	4
11050.00	203	1007	4
18700.00	204	1012	4
31450.00	205	1017	4
1700.00	206	1022	4
1700.00	207	1027	4
1700.00	208	1032	4
1700.00	209	1037	4
1700.00	210	1042	4
1700.00	211	1047	4
1700.00	212	1052	4
1700.00	213	1057	4
1700.00	214	1062	4
1700.00	215	1067	4
217.39	3	14	1
275.47	4	19	1
232.75	5	24	1
214.96	6	29	1
366.92	7	34	1
484.16	8	39	1
179.90	9	44	1
161.55	10	49	1
2410.15	11	54	1
2660.07	12	59	1
1993.26	13	64	1
1992.96	14	69	1
2297.56	15	74	1
2608.88	16	79	1
263.83	17	84	1
263.83	18	89	1
858.69	19	94	1
262.05	20	99	1
597.42	21	104	1
757.39	22	109	1
582.51	23	114	1
472.83	24	119	1
660.93	25	124	1
679.04	26	129	1
1236.92	27	134	1
927.69	28	139	1
657.69	29	144	1
558.47	30	149	1
759.22	31	154	1
1093.85	32	159	1
1071.47	33	164	1
810.01	34	169	1
1956.93	35	174	1
230.42	36	179	1
658.33	37	184	1
439.21	38	189	1
460.79	39	194	1
520.91	40	199	1
415.54	41	204	1
461.66	42	209	1
461.66	43	214	1
521.51	44	219	1
207.38	45	224	1
3069.22	46	229	1
2612.30	47	234	1
2296.15	48	239	1
1430.78	49	244	1
969.23	50	249	1
2612.30	51	254	1
1991.54	52	259	1
2101.14	53	264	1
1119.26	54	269	1
1991.53	55	274	1
955.39	56	279	1
3914.92	57	284	1
3069.23	58	289	1
1433.86	59	294	1
1579.90	60	299	1
902.52	61	304	1
897.02	62	309	1
1435.07	63	314	1
1438.74	64	319	1
1451.23	65	324	1
1943.44	66	329	1
1748.73	67	334	1
1218.34	68	339	1
1747.58	69	344	1
897.02	70	347	1
1440.07	71	352	1
2142.99	72	357	1
2132.55	73	362	1
2148.71	74	367	1
1943.96	75	372	1
1593.26	76	377	1
381.39	77	382	1
748.04	78	387	1
656.79	79	392	1
370.38	80	397	1
409.06	81	402	1
431.98	82	407	1
422.31	83	412	1
754.69	84	417	1
280.88	85	422	1
2192.30	86	427	1
466.80	87	432	1
584.91	88	437	1
2192.32	89	442	1
426.93	90	447	1
422.65	91	452	1
403.85	92	457	1
403.85	93	462	1
846.26	94	467	1
161.53	95	472	1
207.70	96	477	1
459.23	97	482	1
731.55	98	487	1
611.53	99	492	1
657.69	100	497	1
161.53	101	502	1
207.70	102	507	1
415.38	103	512	1
830.77	104	517	1
657.70	105	522	1
161.53	106	527	1
459.23	107	532	1
459.23	108	537	1
459.23	109	542	1
161.53	110	547	1
459.23	111	552	1
161.54	112	557	1
161.54	113	562	1
161.54	114	567	1
161.54	115	572	1
179.88	116	577	1
366.92	117	582	1
366.92	118	585	1
878.48	119	590	1
217.38	120	595	1
794.99	121	600	1
161.53	122	605	1
550.51	123	610	1
1119.26	124	615	1
366.92	125	620	1
646.15	126	625	1
161.54	127	630	1
1675.38	128	635	1
1672.00	129	640	1
1421.38	130	645	1
1192.26	131	650	1
1671.78	132	655	1
1523.26	133	660	1
1447.90	134	665	1
1053.97	135	670	1
1537.12	136	675	1
1671.78	137	680	1
1709.65	138	685	1
161.15	139	690	1
194.53	140	695	1
162.15	141	700	1
185.66	142	705	1
636.79	143	710	1
160.57	144	715	1
162.15	145	720	1
162.39	146	725	1
162.39	147	730	1
229.95	148	735	1
192.73	149	740	1
369.72	150	744	1
231.15	151	749	1
637.48	152	754	1
179.03	153	759	1
365.33	154	764	1
272.44	155	769	1
366.96	156	774	1
244.64	157	779	1
336.38	158	784	1
227.68	159	789	1
327.06	160	794	1
340.66	161	799	1
351.06	162	804	1
348.36	163	809	1
428.77	164	814	1
403.00	165	819	1
348.16	166	824	1
577.51	167	829	1
461.17	168	834	1
319.70	169	839	1
428.28	170	844	1
2065.17	171	849	1
1652.37	172	854	1
1486.66	173	859	1
1651.77	174	864	1
2669.76	175	869	1
3068.40	176	874	1
2065.86	177	879	1
2064.93	178	884	1
2761.98	179	889	1
2379.46	180	894	1
3068.54	181	899	1
4785.39	182	904	1
3829.38	183	909	1
1487.69	184	914	1
3253.83	185	919	1
731.54	186	924	1
613.84	187	929	1
459.24	188	934	1
1006.15	189	939	1
846.91	190	944	1
415.38	191	949	1
521.55	192	954	1
643.84	193	959	1
1465.37	194	964	1
459.24	195	969	1
646.16	196	974	1
2088.47	197	979	1
1093.85	198	984	1
1560.01	199	989	1
3066.93	200	994	1
1560.01	201	999	1
4306.16	202	1004	1
1324.62	203	1009	1
2296.16	204	1014	1
3835.38	205	1019	1
173.07	206	1024	1
161.53	207	1029	1
161.53	208	1034	1
173.08	209	1039	1
207.70	210	1044	1
184.61	211	1049	1
161.55	212	1054	1
161.54	213	1059	1
173.08	214	1064	1
184.61	215	1069	1
207.69	216	1074	1
230.76	217	1079	1
461.54	218	1084	1
173.08	219	1089	1
161.53	220	1094	1
660.93	25	125	2
679.04	26	130	2
1236.92	27	135	2
927.69	28	140	2
657.69	29	145	2
558.47	30	150	2
759.22	31	155	2
3914.92	57	285	2
3069.23	58	290	2
1433.86	59	295	2
1579.90	60	300	2
902.52	61	305	2
897.02	62	310	2
466.80	87	433	2
584.91	88	438	2
2192.32	89	443	2
426.93	90	448	2
422.65	91	453	2
403.85	92	458	2
403.85	93	463	2
846.26	94	468	2
217.38	120	596	2
794.99	121	601	2
161.53	122	606	2
550.51	123	611	2
1119.26	124	616	2
366.92	125	621	2
646.15	126	626	2
637.48	152	755	2
179.03	153	760	2
365.33	154	765	2
272.44	155	770	2
366.96	156	775	2
244.64	157	780	2
336.38	158	785	2
3829.38	183	910	2
1487.69	184	915	2
3253.83	185	920	2
731.54	186	925	2
613.84	187	930	2
459.24	188	935	2
1006.15	189	940	2
184.61	215	1070	2
207.69	216	1075	2
230.76	217	1080	2
461.54	218	1085	2
173.08	219	1090	2
161.53	220	1095	2
679.04	26	126	3
1236.92	27	131	3
927.69	28	136	3
657.69	29	141	3
558.47	30	146	3
759.22	31	151	3
1093.85	32	156	3
3069.23	58	286	3
1433.86	59	291	3
1579.90	60	296	3
902.52	61	301	3
897.02	62	306	3
1435.07	63	311	3
426.93	90	444	3
422.65	91	449	3
403.85	92	454	3
403.85	93	459	3
846.26	94	464	3
161.53	95	469	3
161.53	122	602	3
550.51	123	607	3
1119.26	124	612	3
366.92	125	617	3
646.15	126	622	3
161.54	127	627	3
365.33	154	766	3
272.44	155	771	3
366.96	156	776	3
244.64	157	781	3
3829.38	183	911	3
1487.69	184	916	3
3253.83	185	921	3
731.54	186	926	3
613.84	187	931	3
459.24	188	936	3
1006.15	189	941	3
184.61	215	1071	3
207.69	216	1076	3
230.76	217	1081	3
461.54	218	1086	3
173.08	219	1091	3
161.53	220	1096	3
10200.00	27	132	4
7650.00	28	137	4
5950.00	29	142	4
5100.00	30	147	4
6800.00	31	152	4
11900.00	32	157	4
25500.00	58	287	4
23800.00	59	292	4
26350.00	60	297	4
15300.00	61	302	4
15300.00	62	307	4
23800.00	63	312	4
4250.00	91	450	4
17850.00	92	455	4
3400.00	93	460	4
7650.00	94	465	4
1700.00	95	470	4
1700.00	122	603	4
5100.00	123	608	4
9350.00	124	613	4
3400.00	125	618	4
5950.00	126	623	4
1700.00	127	628	4
5950.00	152	752	4
1700.00	153	757	4
3400.00	154	762	4
2550.00	155	767	4
3400.00	156	772	4
2550.00	157	777	4
3400.00	158	782	4
52700.00	185	917	4
5950.00	186	922	4
5100.00	187	927	4
4250.00	188	932	4
8500.00	189	937	4
7650.00	190	942	4
1700.00	216	1072	4
2550.00	217	1077	4
4250.00	218	1082	4
1700.00	219	1087	4
1700.00	220	1092	4
1601.50	4	18	5
7200.00	1	3	5
7200.00	2	8	5
10800.00	3	13	5
10800.00	5	23	5
10800.00	6	28	5
14400.00	7	33	5
14400.00	8	38	5
7200.00	9	43	5
7200.00	10	48	5
82800.00	11	53	5
90000.00	12	58	5
68400.00	13	63	5
68400.00	14	68	5
79200.00	15	73	5
90000.00	16	78	5
25200.00	17	83	5
33600.00	18	88	5
58800.00	19	93	5
25200.00	20	98	5
42000.00	21	103	5
58800.00	22	108	5
42000.00	23	113	5
33600.00	24	118	5
50400.00	25	123	5
50400.00	26	128	5
32400.00	27	133	5
39600.00	32	158	5
25200.00	28	138	5
32400.00	33	163	5
21600.00	29	143	5
25200.00	34	168	5
18000.00	30	148	5
54000.00	35	173	5
25200.00	31	153	5
10800.00	36	178	5
21600.00	37	183	5
14400.00	38	188	5
14400.00	39	193	5
14400.00	40	198	5
14400.00	41	203	5
14400.00	42	208	5
14400.00	43	213	5
14400.00	44	218	5
7200.00	45	223	5
82800.00	46	228	5
61200.00	47	233	5
52020.00	48	238	5
33660.00	49	243	5
24480.00	50	248	5
61200.00	51	253	5
45900.00	52	258	5
48960.00	53	263	5
79200.00	64	318	5
61200.00	54	268	5
79200.00	65	323	5
45900.00	55	273	5
108000.00	66	328	5
24480.00	56	278	5
93600.00	67	333	5
91800.00	57	283	5
68400.00	68	338	5
70380.00	58	288	5
93600.00	69	343	5
79200.00	59	293	5
86400.00	60	298	5
79200.00	71	351	5
50400.00	61	303	5
115200.00	72	356	5
50400.00	62	308	5
115200.00	73	361	5
79200.00	63	313	5
115200.00	74	366	5
108000.00	75	371	5
86400.00	76	376	5
14400.00	77	381	5
25200.00	78	386	5
21600.00	79	391	5
14400.00	80	396	5
14400.00	81	401	5
7200.00	96	476	5
14400.00	82	406	5
14400.00	97	481	5
14400.00	83	411	5
21600.00	98	486	5
25200.00	84	416	5
18000.00	99	491	5
10800.00	85	421	5
21600.00	100	496	5
57600.00	86	426	5
7200.00	101	501	5
14400.00	87	431	5
7200.00	102	506	5
18000.00	88	436	5
14400.00	103	511	5
57600.00	89	441	5
25200.00	104	516	5
14400.00	90	446	5
21600.00	105	521	5
14400.00	91	451	5
7200.00	106	526	5
57600.00	92	456	5
14400.00	107	531	5
14400.00	93	461	5
25200.00	94	466	5
7200.00	127	629	5
14400.00	108	536	5
46800.00	128	634	5
14400.00	109	541	5
90000.00	129	639	5
7200.00	110	546	5
82800.00	130	644	5
14400.00	111	551	5
64800.00	131	649	5
7200.00	112	556	5
90000.00	132	654	5
7200.00	113	561	5
82800.00	133	659	5
7200.00	114	566	5
79200.00	134	664	5
7200.00	115	571	5
7200.00	116	576	5
14400.00	117	581	5
25200.00	119	589	5
10800.00	120	594	5
25200.00	121	599	5
7200.00	122	604	5
18000.00	123	609	5
32400.00	124	614	5
14400.00	125	619	5
21600.00	126	624	5
10800.00	159	788	5
57600.00	135	669	5
14400.00	160	793	5
82800.00	136	674	5
14400.00	161	798	5
90000.00	137	679	5
93600.00	138	684	5
7200.00	139	689	5
7200.00	140	694	5
7200.00	141	699	5
7200.00	142	704	5
21600.00	143	709	5
7200.00	144	714	5
7200.00	145	719	5
7200.00	146	724	5
7200.00	147	729	5
10800.00	148	734	5
7200.00	149	739	5
14400.00	150	743	5
10800.00	151	748	5
21600.00	152	753	5
7200.00	153	758	5
14400.00	154	763	5
10800.00	155	768	5
14400.00	156	773	5
10800.00	157	778	5
14400.00	158	783	5
14400.00	162	803	5
14400.00	163	808	5
14400.00	164	813	5
14400.00	165	818	5
14400.00	166	823	5
18000.00	167	828	5
18000.00	168	833	5
14400.00	169	838	5
14400.00	170	843	5
111600.00	171	848	5
90000.00	172	853	5
82800.00	173	858	5
90000.00	174	863	5
140400.00	175	868	5
165600.00	176	873	5
111600.00	177	878	5
111600.00	178	883	5
147600.00	179	888	5
126000.00	180	893	5
165600.00	181	898	5
252000.00	182	903	5
201600.00	183	908	5
82800.00	184	913	5
172800.00	185	918	5
50400.00	186	923	5
7200.00	95	471	5
42000.00	187	928	5
33600.00	188	933	5
67200.00	189	938	5
58800.00	190	943	5
33600.00	191	948	5
33600.00	192	953	5
50400.00	193	958	5
92400.00	194	963	5
33600.00	195	968	5
50400.00	196	973	5
134400.00	197	978	5
75600.00	198	983	5
43200.00	199	988	5
82800.00	200	993	5
43200.00	201	998	5
252000.00	202	1003	5
39600.00	203	1008	5
61200.00	204	1013	5
252000.00	205	1018	5
7200.00	206	1023	5
7200.00	207	1028	5
7200.00	208	1033	5
7200.00	209	1038	5
7200.00	210	1043	5
7200.00	211	1048	5
7200.00	212	1053	5
7200.00	213	1058	5
7200.00	214	1063	5
7200.00	215	1068	5
7200.00	216	1073	5
10800.00	217	1078	5
14400.00	218	1083	5
7200.00	219	1088	5
7200.00	220	1093	5
1601.50	4	1098	6
7200.00	1	1099	6
7200.00	2	1100	6
10800.00	3	1101	6
10800.00	5	1102	6
10800.00	6	1103	6
14400.00	7	1104	6
14400.00	8	1105	6
7200.00	9	1106	6
7200.00	10	1107	6
82800.00	11	1108	6
90000.00	12	1109	6
68400.00	13	1110	6
68400.00	14	1111	6
79200.00	15	1112	6
90000.00	16	1113	6
25200.00	17	1114	6
33600.00	18	1115	6
58800.00	19	1116	6
25200.00	20	1117	6
42000.00	21	1118	6
58800.00	22	1119	6
42000.00	23	1120	6
33600.00	24	1121	6
50400.00	25	1122	6
50400.00	26	1123	6
32400.00	27	1124	6
39600.00	32	1125	6
25200.00	28	1126	6
32400.00	33	1127	6
21600.00	29	1128	6
25200.00	34	1129	6
18000.00	30	1130	6
54000.00	35	1131	6
25200.00	31	1132	6
10800.00	36	1133	6
21600.00	37	1134	6
14400.00	38	1135	6
14400.00	39	1136	6
14400.00	40	1137	6
14400.00	41	1138	6
14400.00	42	1139	6
14400.00	43	1140	6
14400.00	44	1141	6
7200.00	45	1142	6
82800.00	46	1143	6
61200.00	47	1144	6
52020.00	48	1145	6
33660.00	49	1146	6
24480.00	50	1147	6
61200.00	51	1148	6
45900.00	52	1149	6
48960.00	53	1150	6
79200.00	64	1151	6
61200.00	54	1152	6
79200.00	65	1153	6
45900.00	55	1154	6
108000.00	66	1155	6
24480.00	56	1156	6
93600.00	67	1157	6
91800.00	57	1158	6
68400.00	68	1159	6
70380.00	58	1160	6
93600.00	69	1161	6
79200.00	59	1162	6
86400.00	60	1163	6
79200.00	71	1164	6
50400.00	61	1165	6
115200.00	72	1166	6
50400.00	62	1167	6
115200.00	73	1168	6
79200.00	63	1169	6
115200.00	74	1170	6
108000.00	75	1171	6
86400.00	76	1172	6
14400.00	77	1173	6
25200.00	78	1174	6
21600.00	79	1175	6
14400.00	80	1176	6
14400.00	81	1177	6
7200.00	96	1178	6
14400.00	82	1179	6
14400.00	97	1180	6
14400.00	83	1181	6
21600.00	98	1182	6
25200.00	84	1183	6
18000.00	99	1184	6
10800.00	85	1185	6
21600.00	100	1186	6
57600.00	86	1187	6
7200.00	101	1188	6
14400.00	87	1189	6
7200.00	102	1190	6
18000.00	88	1191	6
14400.00	103	1192	6
57600.00	89	1193	6
25200.00	104	1194	6
14400.00	90	1195	6
21600.00	105	1196	6
14400.00	91	1197	6
7200.00	106	1198	6
57600.00	92	1199	6
14400.00	107	1200	6
14400.00	93	1201	6
25200.00	94	1202	6
7200.00	127	1203	6
14400.00	108	1204	6
46800.00	128	1205	6
14400.00	109	1206	6
90000.00	129	1207	6
7200.00	110	1208	6
82800.00	130	1209	6
14400.00	111	1210	6
64800.00	131	1211	6
7200.00	112	1212	6
90000.00	132	1213	6
7200.00	113	1214	6
82800.00	133	1215	6
7200.00	114	1216	6
79200.00	134	1217	6
7200.00	115	1218	6
7200.00	116	1219	6
14400.00	117	1220	6
25200.00	119	1221	6
10800.00	120	1222	6
25200.00	121	1223	6
7200.00	122	1224	6
18000.00	123	1225	6
32400.00	124	1226	6
14400.00	125	1227	6
21600.00	126	1228	6
10800.00	159	1229	6
57600.00	135	1230	6
14400.00	160	1231	6
82800.00	136	1232	6
14400.00	161	1233	6
90000.00	137	1234	6
93600.00	138	1235	6
7200.00	139	1236	6
7200.00	140	1237	6
7200.00	141	1238	6
7200.00	142	1239	6
21600.00	143	1240	6
7200.00	144	1241	6
7200.00	145	1242	6
7200.00	146	1243	6
7200.00	147	1244	6
10800.00	148	1245	6
7200.00	149	1246	6
14400.00	150	1247	6
10800.00	151	1248	6
21600.00	152	1249	6
7200.00	153	1250	6
14400.00	154	1251	6
10800.00	155	1252	6
14400.00	156	1253	6
10800.00	157	1254	6
14400.00	158	1255	6
14400.00	162	1256	6
14400.00	163	1257	6
14400.00	164	1258	6
14400.00	165	1259	6
14400.00	166	1260	6
18000.00	167	1261	6
18000.00	168	1262	6
14400.00	169	1263	6
14400.00	170	1264	6
111600.00	171	1265	6
90000.00	172	1266	6
82800.00	173	1267	6
90000.00	174	1268	6
140400.00	175	1269	6
165600.00	176	1270	6
111600.00	177	1271	6
111600.00	178	1272	6
147600.00	179	1273	6
126000.00	180	1274	6
165600.00	181	1275	6
252000.00	182	1276	6
201600.00	183	1277	6
82800.00	184	1278	6
172800.00	185	1279	6
50400.00	186	1280	6
7200.00	95	1281	6
42000.00	187	1282	6
33600.00	188	1283	6
67200.00	189	1284	6
58800.00	190	1285	6
33600.00	191	1286	6
33600.00	192	1287	6
50400.00	193	1288	6
92400.00	194	1289	6
33600.00	195	1290	6
50400.00	196	1291	6
134400.00	197	1292	6
75600.00	198	1293	6
43200.00	199	1294	6
82800.00	200	1295	6
43200.00	201	1296	6
252000.00	202	1297	6
39600.00	203	1298	6
61200.00	204	1299	6
252000.00	205	1300	6
7200.00	206	1301	6
7200.00	207	1302	6
7200.00	208	1303	6
7200.00	209	1304	6
7200.00	210	1305	6
7200.00	211	1306	6
7200.00	212	1307	6
7200.00	213	1308	6
7200.00	214	1309	6
7200.00	215	1310	6
7200.00	216	1311	6
10800.00	217	1312	6
14400.00	218	1313	6
7200.00	219	1314	6
7200.00	220	1315	6
\.


--
-- Data for Name: tipo_construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

COPY valores_fiscales.tipo_construccion (descripcion, id) FROM stdin;
M1	1
M2	2
M3	3
M4	4
M5	5
M6	6
M7	7
M8	8
M9	9
M10	10
M11	11
M12	12
M13	13
M14	14
M15	15
M16	16
M17	17
M18	18
M19	19
M20	20
M21	21
M22	22
M23	23
M24	24
M25	25
M26	26
M27	27
M28	28
M29	29
M30	30
M31	31
M32	32
M33	33
M34	34
M35	35
M36	36
M37	37
M38	38
M39	39
M40	40
M41	41
M42	42
M43	43
M44	44
M45	45
M46	46
M47	47
M48	48
M49	49
M50	50
\.


--
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq', 141, true);


--
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq', 6, true);


--
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.actividad_economica_id_actividad_economica_seq', 220, true);


--
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq', 253, true);


--
-- Name: baremo_servicio_municipal_id_baremo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.baremo_servicio_municipal_id_baremo_seq', 2, true);


--
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.categoria_propaganda_id_categoria_propaganda_seq', 1, false);


--
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq', 11, true);


--
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.contribuyente_id_contribuyente_seq', 112, true);


--
-- Name: convenio_id_convenio_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.convenio_id_convenio_seq', 22, true);


--
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.credito_fiscal_id_credito_fiscal_seq', 39, true);


--
-- Name: detalle_retencion_id_detalle_retencion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.detalle_retencion_id_detalle_retencion_seq', 36, true);


--
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.dias_feriados_id_dia_feriado_seq', 47, true);


--
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.evento_fraccion_id_evento_fraccion_seq', 72, true);


--
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.evento_solicitud_id_evento_solicitud_seq', 711, true);


--
-- Name: factor_id_factor_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.factor_id_factor_seq', 1, false);


--
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.fraccion_id_fraccion_seq', 33, true);


--
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq', 1, false);


--
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq', 1, false);


--
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.liquidacion_id_liquidacion_seq', 1904, true);


--
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.multa_id_multa_seq', 33, true);


--
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq', 30, true);


--
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq', 2, true);


--
-- Name: ramo_id_ramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.ramo_id_ramo_seq', 1, true);


--
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.registro_municipal_id_registro_municipal_seq', 116, true);


--
-- Name: registro_municipal_referencia_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.registro_municipal_referencia_municipal_seq', 8000000019, true);


--
-- Name: retencion_id_retencion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.retencion_id_retencion_seq', 1, false);


--
-- Name: rim_retencion; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.rim_retencion', 2, true);


--
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.solicitud_id_solicitud_seq', 401, true);


--
-- Name: subramo_id_subramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.subramo_id_subramo_seq', 106, true);


--
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq', 212, true);


--
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq', 1, true);


--
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq', 212, true);


--
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_id_tabulador_gas_seq', 1, false);


--
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq', 1, true);


--
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq', 1, false);


--
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.tipo_multa_id_tipo_multa_seq', 1, true);


--
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.usuario_enlazado_id_usuario_enlazado_seq', 1, false);


--
-- Name: usuario_inmueble_id_usuario_inmueble_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.usuario_inmueble_id_usuario_inmueble_seq', 1, false);


--
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.verificacion_email_id_verificacion_email_seq', 5, true);


--
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('impuesto.verificacion_telefono_id_verificacion_telefono_seq', 129, true);


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 36, true);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 13, true);


--
-- Name: cargo_id_cargo_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.cargo_id_cargo_seq', 26, true);


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.casos_sociales_id_caso_seq', 2, true);


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.certificados_id_certificado_seq', 1, false);


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.detalles_facturas_id_detalle_seq', 1, false);


--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.evento_multa_id_evento_multa_seq', 41, true);


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.eventos_casos_sociales_id_evento_caso_seq', 2, true);


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 918, true);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, false);


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.inmueble_urbano_id_inmueble_seq', 495, true);


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.multa_id_multa_seq', 14, true);


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1206, true);


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);


--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.operatividad_terminal_id_operatividad_terminal_seq', 77, true);


--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.ordenanzas_id_ordenanza_seq', 57, true);


--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.ordenanzas_tramites_id_ordenanza_tramite_seq', 15, true);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 381, true);


--
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 1, false);


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.permiso_de_acceso_id_permiso_seq', 40, true);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 18, true);


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.propietarios_inmuebles_id_propietario_inmueble_seq', 10, true);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, true);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 1, false);


--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.tarifas_inspeccion_id_tarifa_seq', 57, true);


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.templates_certificados_id_template_certificado_seq', 1, false);


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 28, true);


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 382, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 209, true);


--
-- Name: valores_id_valor_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.valores_id_valor_seq', 2, true);


--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE SET; Schema: public; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('public.variables_ordenanzas_id_variable_seq', 5, true);


--
-- Name: base_task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.base_task_task_id_seq', 1, true);


--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.chain_execution_config_chain_execution_config_seq', 1, true);


--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.database_connection_database_connection_seq', 1, false);


--
-- Name: log_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.log_id_seq', 1, false);


--
-- Name: run_status_run_status_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.run_status_run_status_seq', 1, false);


--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('timetable.task_chain_chain_id_seq', 1, true);


--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('valores_fiscales.ano_fiscal_id_seq', 6, true);


--
-- Name: construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('valores_fiscales.construccion_id_seq', 305, true);


--
-- Name: sector_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('valores_fiscales.sector_id_seq', 220, true);


--
-- Name: terreno_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('valores_fiscales.terreno_id_seq', 1315, true);


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

SELECT pg_catalog.setval('valores_fiscales.tipo_construccion_id_seq', 50, true);


--
-- Name: actividad_economica_sucursal actividad_economica_contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_sucursal
    ADD CONSTRAINT actividad_economica_contribuyente_pkey PRIMARY KEY (id_actividad_economica_contribuyente);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_pkey PRIMARY KEY (id_actividad_economica_exoneracion);


--
-- Name: actividad_economica actividad_economica_numero_referencia_key; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_numero_referencia_key UNIQUE (numero_referencia);


--
-- Name: actividad_economica actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_pkey PRIMARY KEY (id_actividad_economica);


--
-- Name: actividad_economica_sucursal actividad_economica_sucursal_id_registro_municipal_numero_r_key; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_sucursal
    ADD CONSTRAINT actividad_economica_sucursal_id_registro_municipal_numero_r_key UNIQUE (id_registro_municipal, numero_referencia);


--
-- Name: avaluo_inmueble avaluo_inmueble_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_pkey PRIMARY KEY (id_avaluo_inmueble);


--
-- Name: baremo_servicio_municipal baremo_servicio_municipal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.baremo_servicio_municipal
    ADD CONSTRAINT baremo_servicio_municipal_pkey PRIMARY KEY (id_baremo);


--
-- Name: categoria_propaganda categoria_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.categoria_propaganda
    ADD CONSTRAINT categoria_propaganda_pkey PRIMARY KEY (id_categoria_propaganda);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_pkey PRIMARY KEY (id_contribuyente_exoneracion);


--
-- Name: contribuyente contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_pkey PRIMARY KEY (id_contribuyente);


--
-- Name: contribuyente contribuyente_tipo_documento_documento_key; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_tipo_documento_documento_key UNIQUE (tipo_documento, documento);


--
-- Name: convenio convenio_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_pkey PRIMARY KEY (id_convenio);


--
-- Name: credito_fiscal credito_fiscal_id_persona_concepto_key; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.credito_fiscal
    ADD CONSTRAINT credito_fiscal_id_persona_concepto_key UNIQUE (id_persona, concepto);


--
-- Name: credito_fiscal credito_fiscal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.credito_fiscal
    ADD CONSTRAINT credito_fiscal_pkey PRIMARY KEY (id_credito_fiscal);


--
-- Name: detalle_retencion detalle_retencion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.detalle_retencion
    ADD CONSTRAINT detalle_retencion_pkey PRIMARY KEY (id_detalle_retencion);


--
-- Name: dias_feriados dias_feriados_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.dias_feriados
    ADD CONSTRAINT dias_feriados_pkey PRIMARY KEY (id_dia_feriado);


--
-- Name: evento_fraccion evento_fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_pkey PRIMARY KEY (id_evento_fraccion);


--
-- Name: evento_solicitud evento_solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_pkey PRIMARY KEY (id_evento_solicitud);


--
-- Name: factor factor_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.factor
    ADD CONSTRAINT factor_pkey PRIMARY KEY (id_factor);


--
-- Name: fraccion fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_pkey PRIMARY KEY (id_fraccion);


--
-- Name: liquidacion_descuento liquidacion_descuento_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_pkey PRIMARY KEY (id_liquidacion_descuento);


--
-- Name: liquidacion liquidacion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_pkey PRIMARY KEY (id_liquidacion);


--
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- Name: plazo_exoneracion plazo_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.plazo_exoneracion
    ADD CONSTRAINT plazo_exoneracion_pkey PRIMARY KEY (id_plazo_exoneracion);


--
-- Name: ramo_exoneracion procedimiento_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_pkey PRIMARY KEY (id_ramo_exoneracion);


--
-- Name: ramo ramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo
    ADD CONSTRAINT ramo_pkey PRIMARY KEY (id_ramo);


--
-- Name: registro_municipal registro_municipal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_pkey PRIMARY KEY (id_registro_municipal);


--
-- Name: retencion retencion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.retencion
    ADD CONSTRAINT retencion_pkey PRIMARY KEY (id_retencion);


--
-- Name: solicitud solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_pkey PRIMARY KEY (id_solicitud);


--
-- Name: subramo subramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_pkey PRIMARY KEY (id_subramo);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_pkey PRIMARY KEY (id_tabulador_aseo_actividad_economica);


--
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_pkey PRIMARY KEY (id_tabulador_aseo_residencial);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_pkey PRIMARY KEY (id_tabulador_gas_actividad_economica);


--
-- Name: tabulador_gas tabulador_gas_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_pkey PRIMARY KEY (id_tabulador_gas);


--
-- Name: tabulador_gas_residencial tabulador_gas_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_pkey PRIMARY KEY (id_tabulador_gas_residencial);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_pkey PRIMARY KEY (id_tipo_aviso_propaganda);


--
-- Name: tipo_multa tipo_multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_multa
    ADD CONSTRAINT tipo_multa_pkey PRIMARY KEY (id_tipo_multa);


--
-- Name: usuario_enlazado usuario_enlazado_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_pkey PRIMARY KEY (id_usuario_enlazado);


--
-- Name: usuario_inmueble usuario_inmueble_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_inmueble
    ADD CONSTRAINT usuario_inmueble_pkey PRIMARY KEY (id_usuario_inmueble);


--
-- Name: verificacion_email verificacion_email_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_pkey PRIMARY KEY (id_verificacion_email);


--
-- Name: verificacion_telefono verificacion_telefono_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_pkey PRIMARY KEY (id_verificacion_telefono);


--
-- Name: banco bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.banco
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- Name: campo campos_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.campo
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- Name: cargo cargo_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_pkey PRIMARY KEY (id_cargo);


--
-- Name: caso_social casos_sociales_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_pkey PRIMARY KEY (id_caso);


--
-- Name: certificado certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id_certificado);


--
-- Name: cuenta_funcionario cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: datos_google datos_google_id_google_key; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);


--
-- Name: datos_google datos_google_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);


--
-- Name: evento_multa evento_multa_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_pkey PRIMARY KEY (id_evento_multa);


--
-- Name: evento_tramite eventos_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_pkey PRIMARY KEY (id_evento_tramite);


--
-- Name: factura_tramite facturas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_pkey PRIMARY KEY (id_factura);


--
-- Name: inmueble_urbano inmueble_urbano_cod_catastral_key; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_cod_catastral_key UNIQUE (cod_catastral);


--
-- Name: inmueble_urbano inmueble_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_pkey PRIMARY KEY (id_inmueble);


--
-- Name: institucion instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.institucion
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- Name: notificacion notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.notificacion
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- Name: operacion operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.operacion
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- Name: ordenanza ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_pkey PRIMARY KEY (id_ordenanza);


--
-- Name: ordenanza_tramite ordenanzas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_pkey PRIMARY KEY (id_ordenanza_tramite);


--
-- Name: pago pago_id_banco_referencia_metodo_pago_key; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_id_banco_referencia_metodo_pago_key UNIQUE (id_banco, referencia, metodo_pago);


--
-- Name: pago_manual pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- Name: pago pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- Name: parroquia parroquia_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.parroquia
    ADD CONSTRAINT parroquia_pkey PRIMARY KEY (id);


--
-- Name: permiso_de_acceso permiso_de_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_pkey PRIMARY KEY (id_permiso);


--
-- Name: propietario propietario_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);


--
-- Name: propietario_inmueble propietarios_inmuebles_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_pkey PRIMARY KEY (id_propietario_inmueble);


--
-- Name: recaudo recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.recaudo
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- Name: recuperacion recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_pkey PRIMARY KEY (id_recuperacion);


--
-- Name: seccion secciones_pk; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.seccion
    ADD CONSTRAINT secciones_pk PRIMARY KEY (id_seccion);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_pkey PRIMARY KEY (id_tarifa);


--
-- Name: template_certificado templates_certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_pkey PRIMARY KEY (id_template_certificado);


--
-- Name: tipo_tramite tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- Name: tipo_usuario tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_usuario
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- Name: tramite tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- Name: usuario usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- Name: usuario usuarios_nombre_de_usuario_key; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_nombre_de_usuario_key UNIQUE (nombre_de_usuario);


--
-- Name: usuario usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: valor valores_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.valor
    ADD CONSTRAINT valores_pkey PRIMARY KEY (id_valor);


--
-- Name: variable_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- Name: variable_ordenanza variables_ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable_ordenanza
    ADD CONSTRAINT variables_ordenanzas_pkey PRIMARY KEY (id_variable);


--
-- Name: variable variables_pkey; Type: CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- Name: base_task base_task_name_key; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_name_key UNIQUE (name);


--
-- Name: base_task base_task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_pkey PRIMARY KEY (task_id);


--
-- Name: chain_execution_config chain_execution_config_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_name_key UNIQUE (chain_name);


--
-- Name: chain_execution_config chain_execution_config_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_pkey PRIMARY KEY (chain_execution_config);


--
-- Name: chain_execution_parameters chain_execution_parameters_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_pkey PRIMARY KEY (chain_execution_config, chain_id, order_id);


--
-- Name: database_connection database_connection_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.database_connection
    ADD CONSTRAINT database_connection_pkey PRIMARY KEY (database_connection);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: run_status run_status_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.run_status
    ADD CONSTRAINT run_status_pkey PRIMARY KEY (run_status);


--
-- Name: task_chain task_chain_parent_id_key; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_key UNIQUE (parent_id);


--
-- Name: task_chain task_chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_pkey PRIMARY KEY (chain_id);


--
-- Name: ano ano_fiscal_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.ano
    ADD CONSTRAINT ano_fiscal_pkey PRIMARY KEY (id);


--
-- Name: construccion construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_pkey PRIMARY KEY (id);


--
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- Name: terreno terreno_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_pkey PRIMARY KEY (id);


--
-- Name: tipo_construccion tipo_construccion_descripcion_key; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_descripcion_key UNIQUE (descripcion);


--
-- Name: tipo_construccion tipo_construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_pkey PRIMARY KEY (id);


--
-- Name: evento_fraccion eventos_fraccion_trigger; Type: TRIGGER; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TRIGGER eventos_fraccion_trigger BEFORE INSERT ON impuesto.evento_fraccion FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_fraccion_trigger_func();


--
-- Name: evento_solicitud eventos_solicitud_trigger; Type: TRIGGER; Schema: impuesto; Owner: pooijyzcnnfrso
--

CREATE TRIGGER eventos_solicitud_trigger BEFORE INSERT ON impuesto.evento_solicitud FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_solicitud_trigger_func();


--
-- Name: tramite codigo_tramite_trg; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER codigo_tramite_trg BEFORE INSERT ON public.tramite FOR EACH ROW EXECUTE FUNCTION public.codigo_tramite();


--
-- Name: caso_social codigos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER codigos_casos_sociales_trigger BEFORE INSERT ON public.caso_social FOR EACH ROW EXECUTE FUNCTION public.codigo_caso();


--
-- Name: multa codigos_multas_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER codigos_multas_trigger BEFORE INSERT ON public.multa FOR EACH ROW EXECUTE FUNCTION public.codigo_multa();


--
-- Name: evento_caso_social eventos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER eventos_casos_sociales_trigger BEFORE INSERT ON public.evento_caso_social FOR EACH ROW EXECUTE FUNCTION public.eventos_casos_sociales_trigger_func();


--
-- Name: evento_multa eventos_multa_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER eventos_multa_trigger BEFORE INSERT ON public.evento_multa FOR EACH ROW EXECUTE FUNCTION public.eventos_multa_trigger_func();


--
-- Name: evento_tramite eventos_tramite_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER eventos_tramite_trigger BEFORE INSERT ON public.evento_tramite FOR EACH ROW EXECUTE FUNCTION public.eventos_tramite_trigger_func();


--
-- Name: notificacion insert_notificaciones_trigger; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER insert_notificaciones_trigger BEFORE INSERT ON public.notificacion FOR EACH ROW EXECUTE FUNCTION public.insert_notificacion_trigger_func();


--
-- Name: valor tipos_tramites_costo_petro_trig; Type: TRIGGER; Schema: public; Owner: pooijyzcnnfrso
--

CREATE TRIGGER tipos_tramites_costo_petro_trig AFTER UPDATE ON public.valor FOR EACH ROW WHEN (((new.descripcion)::text = 'PETRO'::text)) EXECUTE FUNCTION public.tipos_tramites_costo_petro_trigger_func();


--
-- Name: base_task trig_task_chain_fixer; Type: TRIGGER; Schema: timetable; Owner: pooijyzcnnfrso
--

CREATE TRIGGER trig_task_chain_fixer BEFORE DELETE ON timetable.base_task FOR EACH ROW EXECUTE FUNCTION timetable.trig_chain_fixer();


--
-- Name: actividad_economica_sucursal actividad_economica_contribuyente_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_sucursal
    ADD CONSTRAINT actividad_economica_contribuyente_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: actividad_economica_sucursal actividad_economica_contribuyente_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_sucursal
    ADD CONSTRAINT actividad_economica_contribuyente_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: avaluo_inmueble avaluo_inmueble_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: contribuyente contribuyente_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: convenio convenio_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: detalle_retencion detalle_retencion_id_liquidacion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.detalle_retencion
    ADD CONSTRAINT detalle_retencion_id_liquidacion_fkey FOREIGN KEY (id_liquidacion) REFERENCES impuesto.liquidacion(id_liquidacion);


--
-- Name: evento_fraccion evento_fraccion_id_fraccion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_id_fraccion_fkey FOREIGN KEY (id_fraccion) REFERENCES impuesto.fraccion(id_fraccion) ON DELETE CASCADE;


--
-- Name: evento_solicitud evento_solicitud_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud) ON DELETE CASCADE;


--
-- Name: fraccion fraccion_id_convenio_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_id_convenio_fkey FOREIGN KEY (id_convenio) REFERENCES impuesto.convenio(id_convenio);


--
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: liquidacion_descuento liquidacion_descuento_id_liquidacion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_id_liquidacion_fkey FOREIGN KEY (id_liquidacion) REFERENCES impuesto.liquidacion(id_liquidacion);


--
-- Name: liquidacion liquidacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: liquidacion liquidacion_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: liquidacion liquidacion_id_subramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_subramo_fkey FOREIGN KEY (id_subramo) REFERENCES impuesto.subramo(id_subramo);


--
-- Name: multa multa_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: multa multa_id_tipo_multa_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_tipo_multa_fkey FOREIGN KEY (id_tipo_multa) REFERENCES impuesto.tipo_multa(id_tipo_multa);


--
-- Name: ramo_exoneracion procedimiento_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: ramo_exoneracion ramo_exoneracion_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT ramo_exoneracion_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- Name: registro_municipal registro_municipal_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_verificacion_telefono_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_verificacion_telefono_fkey FOREIGN KEY (id_verificacion_telefono) REFERENCES impuesto.verificacion_telefono(id_verificacion_telefono) ON DELETE CASCADE;


--
-- Name: solicitud solicitud_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: solicitud solicitud_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: solicitud solicitud_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: subramo subramo_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: tabulador_gas tabulador_gas_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: tabulador_gas_residencial tabulador_gas_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_categoria_propaganda_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_categoria_propaganda_fkey FOREIGN KEY (id_categoria_propaganda) REFERENCES impuesto.categoria_propaganda(id_categoria_propaganda);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_valor_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- Name: usuario_enlazado usuario_enlazado_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: usuario_inmueble usuario_inmueble_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_inmueble
    ADD CONSTRAINT usuario_inmueble_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: usuario_inmueble usuario_inmueble_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.usuario_inmueble
    ADD CONSTRAINT usuario_inmueble_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: verificacion_email verificacion_email_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: verificacion_telefono verificacion_telefono_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: campo_tramite campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campo(id_campo);


--
-- Name: campo_tramite campos_tramites_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES public.seccion(id_seccion) NOT VALID;


--
-- Name: campo_tramite campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: cargo cargo_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: cargo cargo_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- Name: caso_social casos_sociales_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: caso_social casos_sociales_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: certificado certificados_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_cargo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_cargo_fkey FOREIGN KEY (id_cargo) REFERENCES public.cargo(id_cargo);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: datos_facebook datos_facebook_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.datos_facebook
    ADD CONSTRAINT datos_facebook_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: detalle_factura detalles_facturas_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT detalles_facturas_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.factura_tramite(id_factura);


--
-- Name: evento_multa evento_multa_id_multa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_id_multa_fkey FOREIGN KEY (id_multa) REFERENCES public.multa(id_multa);


--
-- Name: evento_tramite eventos_tramite_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite) ON DELETE CASCADE;


--
-- Name: factura_tramite facturas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: inmueble_urbano inmueble_urbano_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: inmueble_urbano inmueble_urbano_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: institucion_banco instituciones_bancos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: institucion_banco instituciones_bancos_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: multa multa_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: multa multa_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: ordenanza ordenanzas_id_valor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tarifa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tarifa_fkey FOREIGN KEY (id_tarifa) REFERENCES public.tarifa_inspeccion(id_tarifa);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: pago pago_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: pago pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: pago_manual pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pago(id_pago);


--
-- Name: pago_manual pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuenta_funcionario(id_usuario);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: propietario_inmueble propietarios_inmuebles_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: propietario_inmueble propietarios_inmuebles_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);


--
-- Name: recuperacion recuperacion_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_ordenanza_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_ordenanza_fkey FOREIGN KEY (id_ordenanza) REFERENCES public.ordenanza(id_ordenanza);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_variable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_variable_fkey FOREIGN KEY (id_variable) REFERENCES public.variable_ordenanza(id_variable);


--
-- Name: template_certificado templates_certificados_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tipo_tramite tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudo(id_recaudo);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite_archivo_recaudo tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tramite_archivo_recaudo
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: tramite tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite tramites_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: usuario usuario_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: usuario usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- Name: variable_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operacion(id_operacion);


--
-- Name: variable_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: chain_execution_config chain_execution_config_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_execution_config_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_execution_config_fkey FOREIGN KEY (chain_execution_config) REFERENCES timetable.chain_execution_config(chain_execution_config) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_database_connection_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_database_connection_fkey FOREIGN KEY (database_connection) REFERENCES timetable.database_connection(database_connection) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_parent_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.base_task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: construccion construccion_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: construccion construccion_tipo_construccion_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_tipo_construccion_id_fkey FOREIGN KEY (tipo_construccion_id) REFERENCES valores_fiscales.tipo_construccion(id);


--
-- Name: sector sector_parroquia_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_parroquia_id_fkey FOREIGN KEY (parroquia_id) REFERENCES public.parroquia(id);


--
-- Name: terreno terreno_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: terreno terreno_sector_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: pooijyzcnnfrso
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES valores_fiscales.sector(id);


--
-- Name: LANGUAGE plpgsql; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON LANGUAGE plpgsql TO pooijyzcnnfrso;


--
-- PostgreSQL database dump complete
--

