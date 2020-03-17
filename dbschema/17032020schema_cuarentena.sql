--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2
-- Dumped by pg_dump version 12.2

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
-- Name: casos_sociales_transicion(text, text); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.casos_sociales_transicion(state text, event text) OWNER TO postgres;

--
-- Name: codigo_caso(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.codigo_caso() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 DECLARE
     valor int;
     nombre_inst text;
BEGIN
     SELECT COALESCE(MAX(consecutivo) + 1, 1) INTO NEW.consecutivo
     FROM public.casos_sociales t
     WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
     AND CURRENT_DATE = DATE(t.fecha_creacion);

     SELECT i.nombre_corto INTO nombre_inst
     FROM public.instituciones i
     INNER JOIN public.tipos_tramites tt ON tt.id_institucion = i.id_institucion
     WHERE tt.id_tipo_tramite = NEW.id_tipo_tramite;

     NEW.codigo_tramite = nombre_inst || '-'
     || to_char(current_date, 'DDMMYYYY') || '-'
     || (NEW.id_tipo_tramite)::TEXT || '-'
     || lpad((NEW.consecutivo)::text, 4, '0');

     RAISE NOTICE '% % % %', nombre_inst, to_char(current_date, 'DDMMYYYY'), (NEW.id_tipo_tramite)::TEXT, lpad((NEW.consecutivo)::text, 4, '0'); 
     RETURN NEW;                                                                                                                                 


 END;
 $$;


ALTER FUNCTION public.codigo_caso() OWNER TO postgres;

--
-- Name: codigo_tramite(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.codigo_tramite() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    valor int;
    nombre_inst text;
BEGIN
    SELECT COALESCE(MAX(consecutivo) + 1, 1) INTO NEW.consecutivo
    FROM public.tramites t
    WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
    AND CURRENT_DATE = DATE(t.fecha_creacion);

    SELECT i.nombre_corto INTO nombre_inst 
    FROM public.instituciones i
    INNER JOIN public.tipos_tramites tt ON tt.id_institucion = i.id_institucion
    WHERE tt.id_tipo_tramite = NEW.id_tipo_tramite;

    NEW.codigo_tramite = nombre_inst || '-' 
    || to_char(current_date, 'DDMMYYYY') || '-' 
    || (NEW.id_tipo_tramite)::TEXT || '-'
    || lpad((NEW.consecutivo)::text, 4, '0');

    RAISE NOTICE '% % % %', nombre_inst, to_char(current_date, 'DDMMYYYY'), (NEW.id_tipo_tramite)::TEXT, lpad((NEW.consecutivo)::text, 4, '0');

    RETURN NEW;
    

END;
$$;


ALTER FUNCTION public.codigo_tramite() OWNER TO postgres;

--
-- Name: complete_tramite_state(integer, text, json, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _url_certificado character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO eventos_tramite values (default, _id_tramite, event, now());
          
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramites SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _url_certificado IS NOT NULL THEN
                                      UPDATE tramites SET url_certificado = _url_certificado WHERE id_tramite = _id_tramite;
                                              END IF;
                                                      END;
                                                              $$;


ALTER FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json, _url_certificado character varying) OWNER TO postgres;

--
-- Name: eventos_casos_sociales_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.eventos_casos_sociales_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
BEGIN
  SELECT casos_sociales_fsm(event ORDER BY id_evento_caso)
  FROM (
    SELECT id_evento_caso, event FROM eventos_casos_sociales WHERE id_caso = new.id_caso
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


ALTER FUNCTION public.eventos_casos_sociales_trigger_func() OWNER TO postgres;

--
-- Name: eventos_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.eventos_tramite_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT public.tramites_eventos_fsm(event ORDER BY id_evento_tramite)
      FROM (
          SELECT id_evento_tramite, event FROM public.eventos_tramite WHERE id_tramite = new.id_tramite
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


ALTER FUNCTION public.eventos_tramite_trigger_func() OWNER TO postgres;

--
-- Name: casos_sociales_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.casos_sociales_fsm(text) (
    SFUNC = public.casos_sociales_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.casos_sociales_fsm(text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: casos_sociales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.casos_sociales (
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


ALTER TABLE public.casos_sociales OWNER TO postgres;

--
-- Name: eventos_casos_sociales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventos_casos_sociales (
    id_evento_caso integer NOT NULL,
    id_caso integer NOT NULL,
    event text,
    "time" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.eventos_casos_sociales OWNER TO postgres;

--
-- Name: instituciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instituciones (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


ALTER TABLE public.instituciones OWNER TO postgres;

--
-- Name: tipos_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_tramites (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo_base numeric,
    sufijo character varying,
    nombre_corto character varying,
    formato character varying,
    planilla character varying,
    certificado character varying,
    utiliza_informacion_catastral boolean
);


ALTER TABLE public.tipos_tramites OWNER TO postgres;

--
-- Name: casos_sociales_state; Type: VIEW; Schema: public; Owner: postgres
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
   FROM (((public.casos_sociales cs
     JOIN public.tipos_tramites tt ON ((cs.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.instituciones i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT eventos_casos_sociales.id_caso,
            public.casos_sociales_fsm(eventos_casos_sociales.event ORDER BY eventos_casos_sociales.id_evento_caso) AS state
           FROM public.eventos_casos_sociales
          GROUP BY eventos_casos_sociales.id_caso) ev ON ((cs.id_caso = ev.id_caso)));


ALTER TABLE public.casos_sociales_state OWNER TO postgres;

--
-- Name: insert_caso(integer, json, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.casos_sociales_state
    LANGUAGE plpgsql
    AS $$
DECLARE
    caso casos_sociales%ROWTYPE;
	response casos_sociales_state%ROWTYPE;
    BEGIN
        INSERT INTO casos_sociales (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into caso;
        
            INSERT INTO eventos_casos_sociales values (default, caso.id_caso, 'iniciar', now());
            
                RETURN QUERY SELECT * FROM casos_sociales_state WHERE id=caso.id_caso ORDER BY casos_sociales_state.fechacreacion;
                
                    RETURN;
                    END;
                    $$;


ALTER FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO postgres;

--
-- Name: tramites_eventos_transicion(text, text); Type: FUNCTION; Schema: public; Owner: postgres
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
                                                                                                                        WHEN 'enproceso_pd' THEN 'enproceso'
                                                                                                                                        ELSE 'error'
                                                                                                                                                    END
                                                                                                                                                            WHEN 'validando' THEN
                                                                                                                                                                        CASE event
                                                                                                                                                                                        WHEN 'enproceso_pa' THEN 'enproceso'
                                                                                                                                                                                                        WHEN 'finalizar' THEN 'finalizado'
                                                                                                                                                                                                                        ELSE 'error'
                                                                                                                                                                                                                                    END
                                                                                                                                                                                                                                            WHEN 'ingresardatos' THEN
                                                                                                                                                                                                                                                        CASE event
                                                                                                                                                                                                                                                                        WHEN 'validar_pd' THEN 'validando'
                                                                                                                                                                                                                                                                                        ELSE 'error'
                                                                                                                                                                                                                                                                                                    END
                                                                                                                                                                                                                                                                                                            WHEN 'enproceso' THEN
                                                                                                                                                                                                                                                                                                                        CASE event
                                                                                                                                                                                                                                                                                                                                        WHEN 'ingresar_datos' THEN 'ingresardatos'
                                                                                                                                                                                                                                                                                                                                                        WHEN 'finalizar' THEN 'finalizado'
                                                                                                                                                                                                                                                                                                                                                                        ELSE 'error'
                                                                                                                                                                                                                                                                                                                                                                                    END
                                                                                                                                                                                                                                                                                                                                                                                            ELSE 'error'
                                                                                                                                                                                                                                                                                                                                                                                                END
                                                                                                                                                                                                                                                                                                                                                                                                $$;


ALTER FUNCTION public.tramites_eventos_transicion(state text, event text) OWNER TO postgres;

--
-- Name: tramites_eventos_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.tramites_eventos_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.tramites_eventos_fsm(text) OWNER TO postgres;

--
-- Name: eventos_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventos_tramite (
    id_evento_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    event text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.eventos_tramite OWNER TO postgres;

--
-- Name: tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tramites (
    id_tramite integer NOT NULL,
    id_tipo_tramite integer,
    datos json,
    costo numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    codigo_tramite character varying,
    consecutivo integer,
    id_usuario integer,
    url_planilla character varying,
    url_certificado character varying
);


ALTER TABLE public.tramites OWNER TO postgres;

--
-- Name: tramites_state_with_resources; Type: VIEW; Schema: public; Owner: postgres
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
    ev.state
   FROM (((public.tramites t
     JOIN public.tipos_tramites tt ON ((t.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.instituciones i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT eventos_tramite.id_tramite,
            public.tramites_eventos_fsm(eventos_tramite.event ORDER BY eventos_tramite.id_evento_tramite) AS state
           FROM public.eventos_tramite
          GROUP BY eventos_tramite.id_tramite) ev ON ((t.id_tramite = ev.id_tramite)));


ALTER TABLE public.tramites_state_with_resources OWNER TO postgres;

--
-- Name: insert_tramite(integer, json, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.tramites_state_with_resources
    LANGUAGE plpgsql
    AS $$
DECLARE
    tramite tramites%ROWTYPE;
	response tramites_state_with_resources%ROWTYPE;
    BEGIN
        INSERT INTO TRAMITES (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into tramite;
        
            INSERT INTO eventos_tramite values (default, tramite.id_tramite, 'iniciar', now());
            
                RETURN QUERY SELECT * FROM tramites_state_with_resources WHERE id=tramite.id_tramite ORDER BY tramites_state_with_resources.fechacreacion;
                
                    RETURN;
                    END;
                    $$;


ALTER FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO postgres;

--
-- Name: tramite_eventos_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.tramite_eventos_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT tramite_eventos_fsm(event ORDER BY id)
      FROM (
          SELECT id, event FROM eventos_tramites WHERE id_evento_tramite = new.id_evento_tramite
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


ALTER FUNCTION public.tramite_eventos_trigger_func() OWNER TO postgres;

--
-- Name: update_caso_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO eventos_casos_sociales values (default, _id_caso, event, now());
          
                  RETURN QUERY SELECT casos_sociales_state.state FROM casos_sociales_state WHERE id = _id_caso;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE casos_sociales SET datos = _datos WHERE id_caso = _id_caso;
                                              END IF;
                                                      END;
                                                              $$;


ALTER FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json) OWNER TO postgres;

--
-- Name: update_tramite_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json, _costo numeric DEFAULT NULL::numeric, _url_planilla character varying DEFAULT NULL::character varying) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO eventos_tramite values (default, _id_tramite, event, now());
          
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramites SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
						  IF _costo IS NOT NULL THEN
                                      UPDATE tramites SET costo = _costo WHERE id_tramite = _id_tramite;
                                              END IF;
                          IF _url_planilla IS NOT NULL THEN
                                      UPDATE tramites SET url_planilla = _url_planilla WHERE id_tramite = _id_tramite;
                                              END IF;
                                                      END;
                                                              $$;


ALTER FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json, _costo numeric, _url_planilla character varying) OWNER TO postgres;

--
-- Name: validate_payments(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
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
                                                              SELECT id_pago::int into idPago FROM pagos
                                                                    WHERE aprobado = false
                                                                          AND id_banco = inputBanco
                                                                                AND referencia = (inputRow ->> 'Referencia') 
                                                                                      AND monto = (inputRow ->> 'Monto')::numeric
                                                                                            AND fecha_de_pago = (inputRow ->> 'Fecha')::timestamptz;
                                                                                                  
                                                                                                        IF idPago IS NOT NULL THEN
                                                                                                              --aprueba el pago y guarda el momento en que se aprobo el pago
                                                                                                                        UPDATE pagos SET aprobado = true, fecha_de_aprobacion = (SELECT NOW()::timestamptz) WHERE id_pago = idPago;
                                                                                                                                  --obtiene el resultado del row y lo convierte en json 
                                                                                                                                            select row_to_json(row)::jsonb into dataPago from (select pagos.id_pago AS id, pagos.monto, pagos.aprobado, pagos.id_banco AS idBanco, pagos.id_tramite AS idTramite, pagos.referencia, pagos.fecha_de_pago AS fechaDePago, pagos.fecha_de_aprobacion AS fechaDeAprobacion, tramites.codigo_tramite AS codigoTramite, tipos_tramites.pago_previo AS pagoPrevio, tipos_tramites.id_tipo_tramite AS tipotramite  from pagos 
                                                                                                                                                      INNER JOIN tramites ON pagos.id_tramite = tramites.id_tramite 
                                                                                                                                                                INNER JOIN tipos_tramites ON tipos_tramites.id_tipo_tramite = tramites.id_tipo_tramite where pagos.id_pago = idPago) row;
                                                                                                                                                                          --agrega el json de la row y lo almacena en el array
                                                                                                                                                                                    jsonArray := array_append(jsonArray, dataPago);   
                                                                                                                                                                                              END IF;
                                                                                                                                                                                                        
                                                                                                                                                                                                                  END LOOP;
                                                                                                                                                                                                                            --devuelve el array de json
                                                                                                                                                                                                                                      outputJson := jsonb_build_object('data', jsonArray);
                                                                                                                                                                                                                                                RETURN;
                                                                                                                                                                                                                                                          END;
                                                                                                                                                                                                                                                                    $$;


ALTER FUNCTION public.validate_payments(inputcsvjson jsonb, OUT outputjson jsonb) OWNER TO postgres;

--
-- Name: bancos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bancos (
    id_banco integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.bancos OWNER TO postgres;

--
-- Name: bancos_id_banco_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bancos_id_banco_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bancos_id_banco_seq OWNER TO postgres;

--
-- Name: bancos_id_banco_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.bancos.id_banco;


--
-- Name: campos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campos (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying,
    validacion character varying,
    col integer
);


ALTER TABLE public.campos OWNER TO postgres;

--
-- Name: campos_id_campo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.campos_id_campo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campos_id_campo_seq OWNER TO postgres;

--
-- Name: campos_id_campo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campos.id_campo;


--
-- Name: campos_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campos_tramites (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado character varying,
    id_seccion integer,
    CONSTRAINT campos_tramites_estado_check CHECK (((estado)::text = ANY (ARRAY['iniciado'::text, 'validando'::text, 'enproceso'::text, 'ingresardatos'::text, 'validando'::text, 'finalizado'::text])))
);


ALTER TABLE public.campos_tramites OWNER TO postgres;

--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.casos_sociales_id_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.casos_sociales_id_caso_seq OWNER TO postgres;

--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.casos_sociales_id_caso_seq OWNED BY public.casos_sociales.id_caso;


--
-- Name: certificados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificados (
    id_certificado integer NOT NULL,
    id_tramite integer,
    url_certificado character varying
);


ALTER TABLE public.certificados OWNER TO postgres;

--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.certificados_id_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.certificados_id_certificado_seq OWNER TO postgres;

--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificados_id_certificado_seq OWNED BY public.certificados.id_certificado;


--
-- Name: cuentas_funcionarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cuentas_funcionarios (
    id_usuario integer NOT NULL,
    id_institucion integer
);


ALTER TABLE public.cuentas_funcionarios OWNER TO postgres;

--
-- Name: datos_facebook; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datos_facebook (
    id_usuario integer NOT NULL,
    id_facebook character varying NOT NULL
);


ALTER TABLE public.datos_facebook OWNER TO postgres;

--
-- Name: datos_google; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


ALTER TABLE public.datos_google OWNER TO postgres;

--
-- Name: detalles_facturas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalles_facturas (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    nombre character varying,
    costo numeric
);


ALTER TABLE public.detalles_facturas OWNER TO postgres;

--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detalles_facturas_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.detalles_facturas_id_detalle_seq OWNER TO postgres;

--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalles_facturas_id_detalle_seq OWNED BY public.detalles_facturas.id_detalle;


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_casos_sociales_id_evento_caso_seq OWNER TO postgres;

--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq OWNED BY public.eventos_casos_sociales.id_evento_caso;


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventos_tramite_id_evento_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventos_tramite_id_evento_tramite_seq OWNER TO postgres;

--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_tramite_id_evento_tramite_seq OWNED BY public.eventos_tramite.id_evento_tramite;


--
-- Name: facturas_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.facturas_tramites (
    id_factura integer NOT NULL,
    id_tramite integer
);


ALTER TABLE public.facturas_tramites OWNER TO postgres;

--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.facturas_tramites_id_factura_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facturas_tramites_id_factura_seq OWNER TO postgres;

--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.facturas_tramites_id_factura_seq OWNED BY public.facturas_tramites.id_factura;


--
-- Name: inmueble_urbano; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inmueble_urbano (
    id_inmueble integer NOT NULL,
    cod_catastral character varying NOT NULL,
    direccion character varying NOT NULL,
    id_parroquia integer NOT NULL,
    metros_construccion numeric NOT NULL,
    metros_terreno numeric NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_ultimo_avaluo timestamp with time zone
);


ALTER TABLE public.inmueble_urbano OWNER TO postgres;

--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inmueble_urbano_id_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.inmueble_urbano_id_inmueble_seq OWNER TO postgres;

--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inmueble_urbano_id_inmueble_seq OWNED BY public.inmueble_urbano.id_inmueble;


--
-- Name: instituciones_bancos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instituciones_bancos (
    id_instituciones_bancos integer NOT NULL,
    id_institucion integer NOT NULL,
    id_banco integer NOT NULL,
    numero_cuenta character varying,
    nombre_titular character varying,
    documento_de_identificacion character varying
);


ALTER TABLE public.instituciones_bancos OWNER TO postgres;

--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.instituciones_bancos_id_instituciones_bancos_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instituciones_bancos_id_instituciones_bancos_seq OWNER TO postgres;

--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.instituciones_bancos_id_instituciones_bancos_seq OWNED BY public.instituciones_bancos.id_instituciones_bancos;


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.instituciones_id_institucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instituciones_id_institucion_seq OWNER TO postgres;

--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.instituciones.id_institucion;


--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notificaciones (
    id_notificacion integer NOT NULL,
    id_tramite integer,
    emisor character varying,
    receptor character varying,
    descripcion character varying,
    status boolean,
    fecha timestamp with time zone
);


ALTER TABLE public.notificaciones OWNER TO postgres;

--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notificaciones_id_notificacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notificaciones_id_notificacion_seq OWNER TO postgres;

--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificaciones.id_notificacion;


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operaciones_id_operacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operaciones_id_operacion_seq OWNER TO postgres;

--
-- Name: operaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operaciones (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


ALTER TABLE public.operaciones OWNER TO postgres;

--
-- Name: pagos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos (
    id_pago integer NOT NULL,
    id_tramite integer,
    referencia character varying,
    monto numeric,
    fecha_de_pago date,
    aprobado boolean DEFAULT false,
    id_banco integer,
    fecha_de_aprobacion timestamp with time zone
);


ALTER TABLE public.pagos OWNER TO postgres;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pagos_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pagos_id_pago_seq OWNER TO postgres;

--
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pagos.id_pago;


--
-- Name: pagos_manuales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos_manuales (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


ALTER TABLE public.pagos_manuales OWNER TO postgres;

--
-- Name: parroquia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.parroquia OWNER TO postgres;

--
-- Name: parroquias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parroquias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parroquias_id_seq OWNER TO postgres;

--
-- Name: parroquias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parroquias_id_seq OWNED BY public.parroquia.id;


--
-- Name: permiso_de_acceso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permiso_de_acceso (
    id_permiso integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_tramite integer NOT NULL
);


ALTER TABLE public.permiso_de_acceso OWNER TO postgres;

--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.permiso_de_acceso_id_permiso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.permiso_de_acceso_id_permiso_seq OWNER TO postgres;

--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permiso_de_acceso_id_permiso_seq OWNED BY public.permiso_de_acceso.id_permiso;


--
-- Name: propietario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietario (
    id_propietario integer NOT NULL,
    razon_social character varying NOT NULL,
    cedula character varying,
    rif character varying,
    email character varying
);


ALTER TABLE public.propietario OWNER TO postgres;

--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.propietario_id_propietario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propietario_id_propietario_seq OWNER TO postgres;

--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.propietario_id_propietario_seq OWNED BY public.propietario.id_propietario;


--
-- Name: propietarios_inmuebles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietarios_inmuebles (
    id_propietario_inmueble integer NOT NULL,
    id_propietario integer NOT NULL,
    id_inmueble integer NOT NULL
);


ALTER TABLE public.propietarios_inmuebles OWNER TO postgres;

--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNER TO postgres;

--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNED BY public.propietarios_inmuebles.id_propietario_inmueble;


--
-- Name: recaudos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recaudos (
    id_recaudo integer NOT NULL,
    nombre_largo character varying,
    nombre_corto character varying
);


ALTER TABLE public.recaudos OWNER TO postgres;

--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.recaudos_id_recaudo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.recaudos_id_recaudo_seq OWNER TO postgres;

--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudos.id_recaudo;


--
-- Name: recuperacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recuperacion (
    id_recuperacion integer NOT NULL,
    id_usuario integer,
    token_recuperacion character varying,
    usado boolean,
    fecha_recuperacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.recuperacion OWNER TO postgres;

--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.recuperacion_id_recuperacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.recuperacion_id_recuperacion_seq OWNER TO postgres;

--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.recuperacion_id_recuperacion_seq OWNED BY public.recuperacion.id_recuperacion;


--
-- Name: secciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.secciones (
    id_seccion integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.secciones OWNER TO postgres;

--
-- Name: templates_certificados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_certificados (
    id_template_certificado integer NOT NULL,
    id_tipo_tramite integer,
    link character varying
);


ALTER TABLE public.templates_certificados OWNER TO postgres;

--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.templates_certificados_id_template_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.templates_certificados_id_template_certificado_seq OWNER TO postgres;

--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_certificados_id_template_certificado_seq OWNED BY public.templates_certificados.id_template_certificado;


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_tramites_id_tipo_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_tramites_id_tipo_tramite_seq OWNER TO postgres;

--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipos_tramites.id_tipo_tramite;


--
-- Name: tipos_tramites_recaudos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_tramites_recaudos (
    id_tipo_tramite integer,
    id_recaudo integer,
    fisico boolean
);


ALTER TABLE public.tipos_tramites_recaudos OWNER TO postgres;

--
-- Name: tipos_usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_usuarios (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


ALTER TABLE public.tipos_usuarios OWNER TO postgres;

--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tipos_usuarios_id_tipo_usuario_seq OWNER TO postgres;

--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipos_usuarios.id_tipo_usuario;


--
-- Name: tramites_archivos_recaudos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tramites_archivos_recaudos (
    id_tramite integer,
    url_archivo_recaudo character varying
);


ALTER TABLE public.tramites_archivos_recaudos OWNER TO postgres;

--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tramites_id_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tramites_id_tramite_seq OWNER TO postgres;

--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramites.id_tramite;


--
-- Name: tramites_state; Type: VIEW; Schema: public; Owner: postgres
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
    ev.state
   FROM (public.tramites t
     JOIN ( SELECT eventos_tramite.id_tramite,
            public.tramites_eventos_fsm(eventos_tramite.event ORDER BY eventos_tramite.id_evento_tramite) AS state
           FROM public.eventos_tramite
          GROUP BY eventos_tramite.id_tramite) ev ON ((t.id_tramite = ev.id_tramite)));


ALTER TABLE public.tramites_state OWNER TO postgres;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    nombre_completo character varying,
    nombre_de_usuario character varying,
    direccion character varying,
    cedula bigint,
    nacionalidad character(1),
    id_tipo_usuario integer,
    password character varying,
    telefono character varying,
    CONSTRAINT usuarios_nacionalidad_check CHECK ((nacionalidad = ANY (ARRAY['V'::bpchar, 'E'::bpchar])))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usuarios_id_usuario_seq OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


--
-- Name: variables_id_var_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variables_id_var_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_id_var_seq OWNER TO postgres;

--
-- Name: variables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variables (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


ALTER TABLE public.variables OWNER TO postgres;

--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variables_de_costo_id_variable_de_costo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_de_costo_id_variable_de_costo_seq OWNER TO postgres;

--
-- Name: variables_de_costo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variables_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);


ALTER TABLE public.variables_de_costo OWNER TO postgres;

--
-- Name: bancos id_banco; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- Name: campos id_campo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- Name: casos_sociales id_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casos_sociales ALTER COLUMN id_caso SET DEFAULT nextval('public.casos_sociales_id_caso_seq'::regclass);


--
-- Name: certificados id_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificados ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- Name: detalles_facturas id_detalle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_facturas ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- Name: eventos_casos_sociales id_evento_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_casos_sociales ALTER COLUMN id_evento_caso SET DEFAULT nextval('public.eventos_casos_sociales_id_evento_caso_seq'::regclass);


--
-- Name: eventos_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- Name: facturas_tramites id_factura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas_tramites ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


--
-- Name: inmueble_urbano id_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano ALTER COLUMN id_inmueble SET DEFAULT nextval('public.inmueble_urbano_id_inmueble_seq'::regclass);


--
-- Name: instituciones id_institucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- Name: instituciones_bancos id_instituciones_bancos; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones_bancos ALTER COLUMN id_instituciones_bancos SET DEFAULT nextval('public.instituciones_bancos_id_instituciones_bancos_seq'::regclass);


--
-- Name: notificaciones id_notificacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- Name: pagos id_pago; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- Name: parroquia id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquia ALTER COLUMN id SET DEFAULT nextval('public.parroquias_id_seq'::regclass);


--
-- Name: permiso_de_acceso id_permiso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso ALTER COLUMN id_permiso SET DEFAULT nextval('public.permiso_de_acceso_id_permiso_seq'::regclass);


--
-- Name: propietario id_propietario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietario_id_propietario_seq'::regclass);


--
-- Name: propietarios_inmuebles id_propietario_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_inmuebles ALTER COLUMN id_propietario_inmueble SET DEFAULT nextval('public.propietarios_inmuebles_id_propietario_inmueble_seq'::regclass);


--
-- Name: recaudos id_recaudo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudos ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- Name: recuperacion id_recuperacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion ALTER COLUMN id_recuperacion SET DEFAULT nextval('public.recuperacion_id_recuperacion_seq'::regclass);


--
-- Name: templates_certificados id_template_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_certificados ALTER COLUMN id_template_certificado SET DEFAULT nextval('public.templates_certificados_id_template_certificado_seq'::regclass);


--
-- Name: tipos_tramites id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_tramites ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- Name: tipos_usuarios id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_usuarios ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- Name: tramites id_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- Name: usuarios id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Data for Name: bancos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bancos (id_banco, nombre) FROM stdin;
1	Banco Occidental de Descuento
2	Banesco
\.


--
-- Data for Name: campos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos (id_campo, nombre, tipo, validacion, col) FROM stdin;
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
23	Observaciones	string	observaciones	24
22	Nombre de la Obra	string	nombreObra	8
24	Codigo de Permiso de Construcción	string	codigoPermisoConstruccion	7
25	Fecha de Permiso de Construcción	string	fechaPermisoConstruccion	7
26	Aforo	number	aforo	6
27	Informe	string	informe	24
\.


--
-- Data for Name: campos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos_tramites (id_campo, id_tipo_tramite, orden, estado, id_seccion) FROM stdin;
21	10	1	iniciado	4
16	10	2	iniciado	4
18	10	3	iniciado	4
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
18	6	3	iniciado	4
17	6	3	iniciado	4
10	6	3	iniciado	4
21	7	1	iniciado	4
16	7	2	iniciado	4
18	7	3	iniciado	4
17	7	3	iniciado	4
10	7	3	iniciado	4
21	8	1	iniciado	4
16	8	2	iniciado	4
18	8	3	iniciado	4
17	8	3	iniciado	4
10	8	3	iniciado	4
22	8	1	enproceso	5
5	8	2	enproceso	5
6	8	2	enproceso	5
23	8	3	enproceso	5
22	6	1	enproceso	5
5	6	2	enproceso	5
6	6	2	enproceso	5
23	6	3	enproceso	5
22	7	1	enproceso	5
5	7	2	enproceso	5
6	7	2	enproceso	5
23	7	3	enproceso	5
21	11	1	iniciado	4
16	11	2	iniciado	4
18	11	3	iniciado	4
17	11	3	iniciado	4
10	11	3	iniciado	4
21	12	1	iniciado	4
16	12	2	iniciado	4
18	12	3	iniciado	4
17	12	3	iniciado	4
10	12	3	iniciado	4
21	13	1	iniciado	4
16	13	2	iniciado	4
18	13	3	iniciado	4
17	13	3	iniciado	4
10	13	3	iniciado	4
22	10	1	enproceso	6
5	10	2	enproceso	6
6	10	2	enproceso	6
24	10	2	enproceso	6
25	10	2	enproceso	6
22	11	1	enproceso	6
5	11	2	enproceso	6
6	11	2	enproceso	6
24	11	2	enproceso	6
25	11	2	enproceso	6
16	10	2	enproceso	6
16	11	2	enproceso	6
16	1	1	enproceso	7
18	1	3	enproceso	7
5	1	3	enproceso	7
26	1	2	enproceso	7
6	1	3	enproceso	7
27	3	1	enproceso	8
22	12	1	enproceso	7
22	13	1	enproceso	7
16	12	2	enproceso	7
16	13	2	enproceso	7
6	12	2	enproceso	7
5	13	2	enproceso	7
1	2	1	iniciado	1
2	2	2	iniciado	1
5	12	2	enproceso	7
6	13	2	enproceso	7
3	2	3	iniciado	1
4	2	4	iniciado	1
5	2	5	iniciado	1
6	2	6	iniciado	1
7	2	7	iniciado	1
8	2	8	iniciado	2
9	2	9	iniciado	2
10	2	10	iniciado	2
11	2	11	iniciado	2
12	2	12	iniciado	2
13	2	13	iniciado	2
2	1	2	iniciado	1
3	1	3	iniciado	1
4	1	4	iniciado	1
5	1	5	iniciado	1
6	1	6	iniciado	1
7	1	7	iniciado	1
8	1	8	iniciado	2
9	1	9	iniciado	2
10	1	10	iniciado	2
11	1	11	iniciado	2
12	1	12	iniciado	2
13	1	13	iniciado	2
1	3	1	iniciado	1
2	3	2	iniciado	1
3	3	3	iniciado	1
4	3	4	iniciado	1
5	3	5	iniciado	1
6	3	6	iniciado	1
7	3	7	iniciado	1
8	3	8	iniciado	2
9	3	9	iniciado	2
10	3	10	iniciado	2
11	3	11	iniciado	2
12	3	12	iniciado	2
13	3	13	iniciado	2
1	1	1	iniciado	1
\.


--
-- Data for Name: casos_sociales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.casos_sociales (id_caso, id_tipo_tramite, costo, datos, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla) FROM stdin;
\.


--
-- Data for Name: certificados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificados (id_certificado, id_tramite, url_certificado) FROM stdin;
\.


--
-- Data for Name: cuentas_funcionarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cuentas_funcionarios (id_usuario, id_institucion) FROM stdin;
55	1
56	1
57	1
59	2
65	2
66	0
\.


--
-- Data for Name: datos_facebook; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_facebook (id_usuario, id_facebook) FROM stdin;
\.


--
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
\.


--
-- Data for Name: detalles_facturas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalles_facturas (id_detalle, id_factura, nombre, costo) FROM stdin;
\.


--
-- Data for Name: eventos_casos_sociales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.eventos_casos_sociales (id_evento_caso, id_caso, event, "time") FROM stdin;
\.


--
-- Data for Name: eventos_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.eventos_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
121	56	iniciar	2020-03-14 14:00:07.333991-04
122	56	enproceso_pd	2020-03-14 14:00:07.333991-04
123	57	iniciar	2020-03-14 14:00:20.060403-04
124	57	enproceso_pd	2020-03-14 14:00:20.060403-04
125	57	ingresar_datos	2020-03-14 14:00:35.893386-04
126	57	validar_pd	2020-03-14 14:07:24.137671-04
127	57	finalizar	2020-03-14 14:08:12.99913-04
\.


--
-- Data for Name: facturas_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.facturas_tramites (id_factura, id_tramite) FROM stdin;
\.


--
-- Data for Name: inmueble_urbano; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, fecha_ultimo_avaluo) FROM stdin;
2	aaaaaaaaaaaaaaaa	por ahi	1	500.2	650	2020-03-17 09:00:03.999703-04	2020-03-17 09:00:03.999703-04	\N
3	bbbbbbbbbbbbbbbb	por ahi 2	1	500.2	650	2020-03-17 09:06:36.01732-04	2020-03-17 09:06:36.01732-04	\N
\.


--
-- Data for Name: instituciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones (id_institucion, nombre_completo, nombre_corto) FROM stdin;
1	Bomberos de Maracaibo	CBM
2	Servicio Autonomo para el Suministro de Gas	SAGAS
0	Alcaldia del Municipio de Maracaibo	ABMM
\.


--
-- Data for Name: instituciones_bancos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones_bancos (id_instituciones_bancos, id_institucion, id_banco, numero_cuenta, nombre_titular, documento_de_identificacion) FROM stdin;
1	1	1	0116-0049-87-0001456787	Jose Sanchez	cedula:V-25.304.089
2	2	1	0116–0126–03–0018874177	SAGAS	rif:G-20005358-5
\.


--
-- Data for Name: notificaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notificaciones (id_notificacion, id_tramite, emisor, receptor, descripcion, status, fecha) FROM stdin;
\.


--
-- Data for Name: operaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.operaciones (id_operacion, nombre_op) FROM stdin;
\.


--
-- Data for Name: pagos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pagos (id_pago, id_tramite, referencia, monto, fecha_de_pago, aprobado, id_banco, fecha_de_aprobacion) FROM stdin;
22	57	123	1	2020-03-01	t	1	2020-03-14 14:08:12.99309-04
\.


--
-- Data for Name: pagos_manuales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pagos_manuales (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- Data for Name: parroquia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parroquia (id, nombre) FROM stdin;
1	Coquivacoa
60	ANTONIO B. ROMERO
61	BOLIVAR
62	CACIQUE MARA
63	CECILIO ACOSTA
64	CHIQUINQUIRA
65	COQUIVACOA
66	CRISTO DE ARANZA
67	FRANCISCO E. BUSTAMANTE
68	IDELFONSO VASQUEZ
69	JUANA DE AVILA
70	LUIS HURTADO HIGUERA
71	MANUEL DAGNINO
72	OLEGARIO VILLALOBOS
73	RAUL LEONI
74	SAN ISIDRO
75	SANTA LUCIA
76	VENANCIO PULGAR
77	CARRACCIOLO P. PEREZ
108	ANTONIO BORJAS ROMERO
109	CARACCIOLO PARRA PEREZ
110	FRANCISCO EUGENIO BUSTAMANTE
\.


--
-- Data for Name: permiso_de_acceso; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.permiso_de_acceso (id_permiso, id_usuario, id_tipo_tramite) FROM stdin;
\.


--
-- Data for Name: propietario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietario (id_propietario, razon_social, cedula, rif, email) FROM stdin;
1	pepe	27548785	v-AAAAA	@
2	pepe2	27548745	v-AAAAAb	@
3	pepe3	27548745	v-AAAAAb	@
\.


--
-- Data for Name: propietarios_inmuebles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietarios_inmuebles (id_propietario_inmueble, id_propietario, id_inmueble) FROM stdin;
1	1	2
2	2	2
3	3	3
\.


--
-- Data for Name: recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recaudos (id_recaudo, nombre_largo, nombre_corto) FROM stdin;
4	Documento de Propiedad del Terreno Notariado y Registrado (copia)	DocumentoDePropiedad
5	Original y copia del Plano de Mensura Catastrado en tamaño original, firmado y sellado por la Dirección de Catastro (original)	PlanoMensura
6	Copia del RIF del Propietario	RIFPropietario
7	Copia de Cedula de Identidad Legible del Propietario	CedulaPropietario
8	Autorización para Trámites a Terceros (si el caso lo amerita)	AutorizacionTramitesTerceros
9	Copia de Cedula Legible del Tramitante o Tercero (si el caso lo amerita)	CedulaTercero
10	Planos del Proyecto de Instalaciones de Gas (en CD)	PlanosInstalacionGas
11	Detalles del Proyecto de Instalaciones de Gas (Tanquilla Principal de Seccionamiento, Detalle de zanja, Detalle de Válvulas de Equipos, Detalle de Sistema de Regulación, Detalle de Ductos de Gas, Detalle de Venteo, Detalle de Soportes, Isometría de Gas, Especificaciones) (en CD)	DetalleProyecto
13	Memoria descriptiva del proyecto de Gas (en CD)	MemoriaDesc
14	Memoria del cálculo del sistema de Gas (en CD)	MemoriaCalculo
15	Especificaciones técnicas del Proyecto de Gas (en CD)	EspecificacionesTecnicas
16	3 Juegos de Planos del Proyecto de Gas Impresos de Cada Nivel de Arquitectura (90cm. x 60cm.)	JuegoPlanos
18	3 Juegos de Planos de Detalles de Gas (90cm. x 60cm.)	JuegoPlanos
19	3 Juegos de Memoria de Cálculo del Proyecto de Gas (90cm. x 60cm.)	JuegoPlanos
20	3 Juegos de Especificaciones Técnicas del Proyecto de Gas (90cm x. 60cm.)	JuegoPlanos
12	Capas cargadas de los Siguientes Servicios: Aguas Servidas, Aguas Blancas, Aguas de Lluvia, Electricidad u Otros Servicios (en CD)	CapasServicios
17	3 Juegos de Planos de Detalles de Gas (90cm. x 60cm.)	JuegoPlanos
21	Copia de Constancia de Servicio SAGAS actualizada	ConstanciaSAGAS
22	Copia de Variables Urbanas expedida por la Alcaldía de Maracaibo	VariablesUrb
23	Tener en Expediente SAGAS: Inspecciones de las instalaciones de Gas	ExpSAGAS
24	Tener en Expediente SAGAS: Inspecciones de Pruebas de Hermeticidad con Carta de Registro Original firmada y sellada	ExpSAGAS
25	Tener en Expediente SAGAS: Inspección Final de las Instalaciones de Gas	ExpSAGAS
26	Un (1) Juego de Planos Impresos de Arquitectura	PlanosArq
27	Tener en Expediente SAGAS: Inspección Final de la Obra, para constatar que no posee Servicio de Gas	ExpSAGAS
28	Copia de Permiso de Construcción SAGAS	ConstSAGAS
29	Documento Notariado donde se especifica que el inmueble no contará con instalaciones del servicio de gas	DocNot
\.


--
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
\.


--
-- Data for Name: secciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.secciones (id_seccion, nombre) FROM stdin;
1	Datos del Solicitante
2	Solicitud de Inspeccion
3	Datos de Inspeccion
4	Datos del Propietario o Tramitante
5	Datos de Permiso de Construccion
6	Datos de Permiso de Habitabilidad
7	Datos Técnicos
8	Datos del Informe
\.


--
-- Data for Name: templates_certificados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_certificados (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- Data for Name: tipos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, sufijo, nombre_corto, formato, planilla, certificado, utiliza_informacion_catastral) FROM stdin;
0	0	Casos Sociales	\N	false	Casos Sociales	ABMM-001	\N	\N	\N
6	2	Constancia de Servicio Residencial	500	true	Servicio Residencial	SAGAS-002	sagas-solt-CS	sagas-cert-CS	\N
7	2	Constancia de Servicio Persona Juridica	500	true	Servicio Persona Juridica	SAGAS-003	sagas-solt-CS	sagas-cert-CS	\N
2	1	Constancia de Habitabilidad	\N	false	Habitabilidad	CBM-002	bomberos-solt	bomberos-cert-HAB	\N
3	1	Instalacion de Plantas Electricas	\N	false	Plantas Electricas	CBM-003	bomberos-solt	bomberos-cert-IPE	\N
8	2	Permiso de Construccion	\N	false	Permiso de Construccion	SAGAS-004	sagas-solt-PC	sagas-cert-PC	\N
1	1	Cumplimiento de Normas Tecnicas	\N	false	Normas Tecnicas	CBM-001	bomberos-solt	bomberos-cert-CCNT	\N
10	2	Permiso de Habitabilidad con Instalaciones de Servicio de Gas	\N	false	Habitabilidad con Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	\N
11	2	Permiso de Habitabilidad sin Instalaciones de Servicio de Gas	\N	false	Habitabilidad sin Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	\N
12	2	Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas	\N	false	Condiciones Habitables con Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	\N
13	2	Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas	\N	false	Condiciones Habitables sin Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	\N
\.


--
-- Data for Name: tipos_tramites_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites_recaudos (id_tipo_tramite, id_recaudo, fisico) FROM stdin;
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
\.


--
-- Data for Name: tipos_usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_usuarios (id_tipo_usuario, descripcion) FROM stdin;
1	Superuser
2	Administrador
3	Funcionario
4	Usuario externo
\.


--
-- Data for Name: tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramites (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla, url_certificado) FROM stdin;
56	8	{"usuario":{"nombre":"aaaaa","ubicadoEn":"asdasdasd","telefono":"1231231231","tipoOcupacion":"123123","areaConstruccion":"123123"}}	\N	2020-03-14 14:00:07.333991-04	SAGAS-14032020-8-0001	1	58	http://localhost:5000/SAGAS-14032020-8-0001.pdf	\N
57	8	{"usuario":{"usuario":{"nombre":"aaaaa","ubicadoEn":"asdasdasd","telefono":"1231231231","tipoOcupacion":"123123","areaConstruccion":"123123"}},"funcionario":{"nombreObra":"asdas","sector":"asdasd","parroquia":"asdasda","observaciones":"sdasd"}}	1	2020-03-14 14:00:20.060403-04	SAGAS-14032020-8-0002	2	58	http://localhost:5000/SAGAS-14032020-8-0002.pdf	http://localhost:5000/SAGAS-14032020-8-0002-certificado.pdf
\.


--
-- Data for Name: tramites_archivos_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramites_archivos_recaudos (id_tramite, url_archivo_recaudo) FROM stdin;
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono) FROM stdin;
55	Super Usuario	super@user.com	Super Usuario	1	V	1	$2a$10$VVT8CHvO3jEEoj/djKK4Z.CGPO9JAHw1NMUIK6QwM3BEwElf68kUW	\N
56	Administrador Bomberos	admin@bomberos.com	Bomberos	1231231231	V	2	$2a$10$nqEy4iyMTQJLAN.BOQ2GuuWioAwRcnXY7ClFbJtmp4svHLg9os/8m	1231231231
57	Funcionario Bomberos	funcionario@bomberos.com	Bomberos	123123123	V	3	$2a$10$fFZ3EHbzdimZ9tDvrGod9ureMPkROVtzScEd0pO/piaQh6RLmedMG	1231231233
58	External User	external@user.com	Aqui	27139153	V	4	$2a$10$1az9AKXYIZ48FrTXXnb24.QT89PZuCTh2n0zabqVW7G8YyKinYNXe	4127645681
59	Administrador SAGAS	admin@sagas.com	SAGAS	123123	V	2	$2a$10$.avdkJGtcLhgw/UydHdZf.QEeiSoAjUxRM/xLiTA1gQLUDkDy4lfm	1231231231
65	Funcionario SAGAS	funcionario@sagas.com	SAGAS	123133333	V	3	$2a$10$Na8DEr4PxMVxAQXgeAGkR.DjVx7YX/8/FJIhPeePIrPzKItJvTscy	1231231231
66	Administrador Alcaldia	admin@alcaldia.com	Alcaldia	99999999	V	2	$2a$10$OtCHXU7MOIa6a5K2dt.soOa4AvzrKvp5qY1RtYTaCQqpV2.KTsOyu	8123814877
\.


--
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variables (id_var, nombre_variable) FROM stdin;
\.


--
-- Data for Name: variables_de_costo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variables_de_costo (id_variable_de_costo, id_tipo_tramite, id_operacion, precedencia, aumento) FROM stdin;
\.


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 2, true);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 13, true);


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.casos_sociales_id_caso_seq', 1, false);


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificados_id_certificado_seq', 1, false);


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalles_facturas_id_detalle_seq', 1, false);


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_casos_sociales_id_evento_caso_seq', 1, false);


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 127, true);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, false);


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inmueble_urbano_id_inmueble_seq', 3, true);


--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_bancos_id_instituciones_bancos_seq', 1, false);


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1, false);


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 22, true);


--
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 1, true);


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permiso_de_acceso_id_permiso_seq', 1, false);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 3, true);


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietarios_inmuebles_id_propietario_inmueble_seq', 3, true);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, true);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 1, false);


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_certificados_id_template_certificado_seq', 1, false);


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 4, true);


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 57, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 66, true);


--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- Name: bancos bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- Name: campos campos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- Name: casos_sociales casos_sociales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casos_sociales
    ADD CONSTRAINT casos_sociales_pkey PRIMARY KEY (id_caso);


--
-- Name: certificados certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificados
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id_certificado);


--
-- Name: cuentas_funcionarios cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: datos_google datos_google_id_google_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);


--
-- Name: datos_google datos_google_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);


--
-- Name: eventos_tramite eventos_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_tramite
    ADD CONSTRAINT eventos_tramite_pkey PRIMARY KEY (id_evento_tramite);


--
-- Name: facturas_tramites facturas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas_tramites
    ADD CONSTRAINT facturas_tramites_pkey PRIMARY KEY (id_factura);


--
-- Name: inmueble_urbano inmueble_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_pkey PRIMARY KEY (id_inmueble);


--
-- Name: instituciones_bancos instituciones_bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones_bancos
    ADD CONSTRAINT instituciones_bancos_pkey PRIMARY KEY (id_instituciones_bancos);


--
-- Name: instituciones instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- Name: operaciones operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operaciones
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- Name: pagos pagos_id_banco_referencia_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_banco_referencia_key UNIQUE (id_banco, referencia);


--
-- Name: pagos_manuales pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- Name: parroquia parroquia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquia
    ADD CONSTRAINT parroquia_pkey PRIMARY KEY (id);


--
-- Name: permiso_de_acceso permiso_de_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_pkey PRIMARY KEY (id_permiso);


--
-- Name: propietario propietario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);


--
-- Name: propietarios_inmuebles propietarios_inmuebles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_inmuebles
    ADD CONSTRAINT propietarios_inmuebles_pkey PRIMARY KEY (id_propietario_inmueble);


--
-- Name: recaudos recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudos
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- Name: recuperacion recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_pkey PRIMARY KEY (id_recuperacion);


--
-- Name: secciones secciones_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.secciones
    ADD CONSTRAINT secciones_pk PRIMARY KEY (id_seccion);


--
-- Name: templates_certificados templates_certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_certificados
    ADD CONSTRAINT templates_certificados_pkey PRIMARY KEY (id_template_certificado);


--
-- Name: tipos_tramites tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- Name: tipos_usuarios tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_usuarios
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- Name: tramites tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- Name: usuarios usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- Name: usuarios usuarios_nombre_de_usuario_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_nombre_de_usuario_key UNIQUE (nombre_de_usuario);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: variables_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- Name: tramites codigo_tramite_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigo_tramite_trg BEFORE INSERT ON public.tramites FOR EACH ROW EXECUTE FUNCTION public.codigo_tramite();


--
-- Name: casos_sociales codigos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigos_casos_sociales_trigger BEFORE INSERT ON public.casos_sociales FOR EACH ROW EXECUTE FUNCTION public.codigo_caso();


--
-- Name: eventos_casos_sociales eventos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_casos_sociales_trigger BEFORE INSERT ON public.eventos_casos_sociales FOR EACH ROW EXECUTE FUNCTION public.eventos_casos_sociales_trigger_func();


--
-- Name: eventos_tramite eventos_tramite_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_tramite_trigger BEFORE INSERT ON public.eventos_tramite FOR EACH ROW EXECUTE FUNCTION public.eventos_tramite_trigger_func();


--
-- Name: campos_tramites campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campos(id_campo);


--
-- Name: campos_tramites campos_tramites_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES public.secciones(id_seccion) NOT VALID;


--
-- Name: campos_tramites campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: casos_sociales casos_sociales_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casos_sociales
    ADD CONSTRAINT casos_sociales_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: casos_sociales casos_sociales_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casos_sociales
    ADD CONSTRAINT casos_sociales_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: certificados certificados_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificados
    ADD CONSTRAINT certificados_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- Name: cuentas_funcionarios cuentas_funcionarios_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- Name: cuentas_funcionarios cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: datos_facebook datos_facebook_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_facebook
    ADD CONSTRAINT datos_facebook_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: detalles_facturas detalles_facturas_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_facturas
    ADD CONSTRAINT detalles_facturas_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.facturas_tramites(id_factura);


--
-- Name: eventos_tramite eventos_tramite_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_tramite
    ADD CONSTRAINT eventos_tramite_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite) ON DELETE CASCADE;


--
-- Name: facturas_tramites facturas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas_tramites
    ADD CONSTRAINT facturas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- Name: inmueble_urbano inmueble_urbano_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: instituciones_bancos instituciones_bancos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones_bancos
    ADD CONSTRAINT instituciones_bancos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.bancos(id_banco);


--
-- Name: instituciones_bancos instituciones_bancos_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones_bancos
    ADD CONSTRAINT instituciones_bancos_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- Name: notificaciones notificaciones_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- Name: pagos pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.bancos(id_banco);


--
-- Name: pagos pagos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- Name: pagos_manuales pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pagos(id_pago);


--
-- Name: pagos_manuales pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuentas_funcionarios(id_usuario);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: propietarios_inmuebles propietarios_inmuebles_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_inmuebles
    ADD CONSTRAINT propietarios_inmuebles_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: propietarios_inmuebles propietarios_inmuebles_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietarios_inmuebles
    ADD CONSTRAINT propietarios_inmuebles_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);


--
-- Name: recuperacion recuperacion_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: templates_certificados templates_certificados_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_certificados
    ADD CONSTRAINT templates_certificados_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: tipos_tramites tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- Name: tipos_tramites_recaudos tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudos(id_recaudo);


--
-- Name: tipos_tramites_recaudos tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: tramites_archivos_recaudos tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites_archivos_recaudos
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- Name: tramites tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: tramites tramites_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipos_usuarios(id_tipo_usuario);


--
-- Name: variables_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operaciones(id_operacion);


--
-- Name: variables_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- PostgreSQL database dump complete
--

