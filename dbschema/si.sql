--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3 (Ubuntu 12.3-1.pgdg18.04+1)
-- Dumped by pg_dump version 12.3 (Ubuntu 12.3-1.pgdg18.04+1)

-- Started on 2020-07-01 16:23:12 -04

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
-- TOC entry 7 (class 2615 OID 53255)
-- Name: impuesto; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA impuesto;


ALTER SCHEMA impuesto OWNER TO postgres;

--
-- TOC entry 5 (class 2615 OID 53256)
-- Name: timetable; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA timetable;


ALTER SCHEMA timetable OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 53257)
-- Name: valores_fiscales; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA valores_fiscales;


ALTER SCHEMA valores_fiscales OWNER TO postgres;

--
-- TOC entry 773 (class 1247 OID 53259)
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: postgres
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK ((((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR (VALUE = '@reboot'::text) OR (VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text)));


ALTER DOMAIN timetable.cron OWNER TO postgres;

--
-- TOC entry 777 (class 1247 OID 53262)
-- Name: execution_status; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.execution_status AS ENUM (
    'STARTED',
    'CHAIN_FAILED',
    'CHAIN_DONE',
    'DEAD'
);


ALTER TYPE timetable.execution_status OWNER TO postgres;

--
-- TOC entry 865 (class 1247 OID 53272)
-- Name: log_type; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.log_type AS ENUM (
    'DEBUG',
    'NOTICE',
    'LOG',
    'ERROR',
    'PANIC',
    'USER'
);


ALTER TYPE timetable.log_type OWNER TO postgres;

--
-- TOC entry 868 (class 1247 OID 53286)
-- Name: task_kind; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.task_kind AS ENUM (
    'SQL',
    'SHELL',
    'BUILTIN'
);


ALTER TYPE timetable.task_kind OWNER TO postgres;

--
-- TOC entry 448 (class 1255 OID 53293)
-- Name: complete_fraccion_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text) OWNER TO postgres;

--
-- TOC entry 450 (class 1255 OID 53294)
-- Name: complete_fraccion_state(integer, text, boolean); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.complete_fraccion_state(_id_fraccion integer, event text, _aprobado boolean) OWNER TO postgres;

--
-- TOC entry 396 (class 1255 OID 53295)
-- Name: complete_solicitud_state(integer, text, json, boolean); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.complete_solicitud_state(_id_solicitud integer, event text, _datos json, _aprobado boolean) OWNER TO postgres;

--
-- TOC entry 451 (class 1255 OID 53296)
-- Name: eventos_fraccion_trigger_func(); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.eventos_fraccion_trigger_func() OWNER TO postgres;

--
-- TOC entry 397 (class 1255 OID 53297)
-- Name: eventos_solicitud_trigger_func(); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.eventos_solicitud_trigger_func() OWNER TO postgres;

--
-- TOC entry 447 (class 1255 OID 53298)
-- Name: fraccion_transicion(text, text); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.fraccion_transicion(state text, event text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 205 (class 1259 OID 53299)
-- Name: fraccion; Type: TABLE; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.fraccion OWNER TO postgres;

--
-- TOC entry 415 (class 1255 OID 53306)
-- Name: insert_fraccion(integer, numeric, integer, date); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.insert_fraccion(_id_convenio integer, _monto numeric, _porcion integer, _fecha date) OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 53307)
-- Name: solicitud; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.solicitud (
    id_solicitud integer NOT NULL,
    id_usuario integer,
    aprobado boolean DEFAULT false,
    fecha date,
    fecha_aprobado date,
    id_tipo_tramite integer,
    id_contribuyente integer,
    tipo_solicitud character varying
);


ALTER TABLE impuesto.solicitud OWNER TO postgres;

--
-- TOC entry 410 (class 1255 OID 53314)
-- Name: insert_solicitud(integer, integer, integer); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.insert_solicitud(_id_usuario integer, _id_tipo_tramite integer, _id_contribuyente integer) OWNER TO postgres;

--
-- TOC entry 411 (class 1255 OID 53315)
-- Name: solicitud_transicion(text, text); Type: FUNCTION; Schema: impuesto; Owner: postgres
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


ALTER FUNCTION impuesto.solicitud_transicion(state text, event text) OWNER TO postgres;

--
-- TOC entry 449 (class 1255 OID 53316)
-- Name: update_fraccion_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: postgres
--

CREATE FUNCTION impuesto.update_fraccion_state(_id_fraccion integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_fraccion values (default, _id_fraccion, event, now());
          
        RETURN QUERY SELECT ss.state FROM impuesto.fraccion_state ss WHERE id = _id_fraccion;
                  
			
    END;
$$;


ALTER FUNCTION impuesto.update_fraccion_state(_id_fraccion integer, event text) OWNER TO postgres;

--
-- TOC entry 412 (class 1255 OID 53317)
-- Name: update_solicitud_state(integer, text); Type: FUNCTION; Schema: impuesto; Owner: postgres
--

CREATE FUNCTION impuesto.update_solicitud_state(_id_solicitud integer, event text) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO impuesto.evento_solicitud values (default, _id_solicitud, event, now());
          
        RETURN QUERY SELECT ss.state FROM impuesto.solicitud_state ss WHERE id = _id_solicitud;
                  
			
    END;
$$;


ALTER FUNCTION impuesto.update_solicitud_state(_id_solicitud integer, event text) OWNER TO postgres;

--
-- TOC entry 413 (class 1255 OID 53318)
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
-- TOC entry 414 (class 1255 OID 53319)
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


ALTER FUNCTION public.codigo_caso() OWNER TO postgres;

--
-- TOC entry 416 (class 1255 OID 53320)
-- Name: codigo_multa(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.codigo_multa() OWNER TO postgres;

--
-- TOC entry 417 (class 1255 OID 53321)
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


ALTER FUNCTION public.codigo_tramite() OWNER TO postgres;

--
-- TOC entry 418 (class 1255 OID 53322)
-- Name: complete_multa_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.complete_multa_state(_id_multa integer, event text, _datos json, _url_certificado character varying, _aprobado boolean) OWNER TO postgres;

--
-- TOC entry 419 (class 1255 OID 53323)
-- Name: complete_tramite_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.complete_tramite_state(_id_tramite integer, event text, _datos json, _url_certificado character varying, _aprobado boolean) OWNER TO postgres;

--
-- TOC entry 420 (class 1255 OID 53324)
-- Name: evento_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.evento_tramite_trigger_func() OWNER TO postgres;

--
-- TOC entry 421 (class 1255 OID 53325)
-- Name: eventos_casos_sociales_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.eventos_casos_sociales_trigger_func() OWNER TO postgres;

--
-- TOC entry 422 (class 1255 OID 53326)
-- Name: eventos_multa_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.eventos_multa_trigger_func() OWNER TO postgres;

--
-- TOC entry 394 (class 1255 OID 53327)
-- Name: eventos_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.eventos_tramite_trigger_func() OWNER TO postgres;

--
-- TOC entry 1352 (class 1255 OID 53328)
-- Name: caso_social_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.caso_social_fsm(text) (
    SFUNC = public.casos_sociales_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.caso_social_fsm(text) OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 53329)
-- Name: caso_social; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.caso_social OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 53336)
-- Name: evento_caso_social; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.evento_caso_social (
    id_evento_caso integer NOT NULL,
    id_caso integer NOT NULL,
    event text,
    "time" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.evento_caso_social OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 53343)
-- Name: institucion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institucion (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


ALTER TABLE public.institucion OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 53349)
-- Name: tipo_tramite; Type: TABLE; Schema: public; Owner: postgres
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
    costo_utmm numeric,
    planilla_rechazo text
);


ALTER TABLE public.tipo_tramite OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 53355)
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
   FROM (((public.caso_social cs
     JOIN public.tipo_tramite tt ON ((cs.id_tipo_tramite = tt.id_tipo_tramite)))
     JOIN public.institucion i ON ((i.id_institucion = tt.id_institucion)))
     JOIN ( SELECT evento_caso_social.id_caso,
            public.caso_social_fsm(evento_caso_social.event ORDER BY evento_caso_social.id_evento_caso) AS state
           FROM public.evento_caso_social
          GROUP BY evento_caso_social.id_caso) ev ON ((cs.id_caso = ev.id_caso)));


ALTER TABLE public.casos_sociales_state OWNER TO postgres;

--
-- TOC entry 395 (class 1255 OID 53360)
-- Name: insert_caso(integer, json, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.insert_caso(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 53361)
-- Name: liquidacion; Type: TABLE; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.liquidacion OWNER TO postgres;

--
-- TOC entry 423 (class 1255 OID 53369)
-- Name: insert_liquidacion(integer, numeric, character varying, json, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.insert_liquidacion(_id_solicitud integer, _monto numeric, _ramo character varying, _datos json, _fecha date, _id_registro_municipal integer) OWNER TO postgres;

--
-- TOC entry 424 (class 1255 OID 53370)
-- Name: multa_transicion(text, text); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.multa_transicion(state text, event text) OWNER TO postgres;

--
-- TOC entry 1353 (class 1255 OID 53371)
-- Name: multa_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.multa_fsm(text) (
    SFUNC = public.multa_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.multa_fsm(text) OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 53372)
-- Name: evento_multa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.evento_multa (
    id_evento_multa integer NOT NULL,
    id_multa integer NOT NULL,
    event character varying NOT NULL,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.evento_multa OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 53379)
-- Name: multa; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.multa OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 53388)
-- Name: multa_state; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.multa_state OWNER TO postgres;

--
-- TOC entry 425 (class 1255 OID 53393)
-- Name: insert_multa(integer, json, character varying, bigint, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.insert_multa(_id_tipo_tramite integer, datos json, _nacionalidad character varying, _cedula bigint, _id_usuario integer) OWNER TO postgres;

--
-- TOC entry 426 (class 1255 OID 53394)
-- Name: insert_notificacion_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.insert_notificacion_trigger_func() OWNER TO postgres;

--
-- TOC entry 427 (class 1255 OID 53395)
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
			WHEN 'aprobar_lae' THEN 'finalizado'
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
            WHEN 'ingresardatos_ompu' THEN 'ingresardatos'
            WHEN 'rechazar_ompu' THEN 'enproceso'
            WHEN 'aprobar_bc' THEN 'finalizado'
            WHEN 'rechazar_bc' THEN 'finalizado'
            ELSE 'error'        
        END
    ELSE 'error'
END
$$;


ALTER FUNCTION public.tramites_eventos_transicion(state text, event text) OWNER TO postgres;

--
-- TOC entry 1354 (class 1255 OID 53396)
-- Name: tramite_evento_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.tramite_evento_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.tramite_evento_fsm(text) OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 53397)
-- Name: evento_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.evento_tramite (
    id_evento_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    event text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.evento_tramite OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 53404)
-- Name: tramite; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.tramite OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 53412)
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


ALTER TABLE public.tramites_state_with_resources OWNER TO postgres;

--
-- TOC entry 428 (class 1255 OID 53417)
-- Name: insert_tramite(integer, json, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) OWNER TO postgres;

--
-- TOC entry 429 (class 1255 OID 53418)
-- Name: revisar_pagos_fin_de_dia(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.revisar_pagos_fin_de_dia() OWNER TO postgres;

--
-- TOC entry 430 (class 1255 OID 53419)
-- Name: tipos_tramites_costo_utmm_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.tipos_tramites_costo_utmm_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuevoCosto numeric;
    BEGIN
        nuevoCosto = NEW.valor_en_bs;
        UPDATE tipo_tramite SET costo_base = (nuevoCosto * costo_utmm) WHERE costo_utmm IS NOT NULL;
        RETURN NEW;
    END
$$;


ALTER FUNCTION public.tipos_tramites_costo_utmm_trigger_func() OWNER TO postgres;

--
-- TOC entry 431 (class 1255 OID 53420)
-- Name: tramite_eventos_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.tramite_eventos_trigger_func() OWNER TO postgres;

--
-- TOC entry 432 (class 1255 OID 53421)
-- Name: update_caso_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.update_caso_state(_id_caso integer, event text, _datos json) OWNER TO postgres;

--
-- TOC entry 433 (class 1255 OID 53422)
-- Name: update_multa_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json) OWNER TO postgres;

--
-- TOC entry 434 (class 1255 OID 53423)
-- Name: update_multa_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.update_multa_state(_id_multa integer, event text, _datos json, _costo numeric, _url_boleta character varying) OWNER TO postgres;

--
-- TOC entry 435 (class 1255 OID 53424)
-- Name: update_tramite_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json, _costo numeric, _url_planilla character varying) OWNER TO postgres;

--
-- TOC entry 436 (class 1255 OID 53425)
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

        SELECT id_pago::int into idPago FROM pago
        WHERE aprobado = false
        AND id_banco = inputBanco
        AND referencia = (inputRow ->> 'Referencia') 
        AND monto <= (inputRow ->> 'Monto')::numeric
        AND fecha_de_pago = (inputRow ->> 'Fecha')::date;

        IF idPago IS NOT NULL THEN
            --aprueba el pago y guarda el momento en que se aprobo el pago
            UPDATE pago SET aprobado = true, fecha_de_aprobacion = (SELECT NOW()::timestamptz) WHERE id_pago = idPago;

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
    
                IF (SELECT (SELECT SUM(monto) FROM impuesto.fraccion WHERE id_convenio = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago)) <= (SELECT SUM(monto) FROM pago WHERE id_procedimiento = (SELECT id_procedimiento FROM pago WHERE id_pago = idPago) AND aprobado = true)) THEN 
                    UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = NOW() WHERE id_solicitud = (SELECT s.id_solicitud FROM pago INNER JOIN impuesto.convenio c ON p.id_procedimiento = c.id_convenio INNER JOIN impuesto.solicitud s ON c.id_solicitud = s.id_solicitud WHERE id_pago = idPago);
                END IF;

                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, solicitud.id_solicitud AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, contribuyente.documento from pago 
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


ALTER FUNCTION public.validate_payments(inputcsvjson jsonb, OUT outputjson jsonb) OWNER TO postgres;

--
-- TOC entry 437 (class 1255 OID 53426)
-- Name: _validate_json_schema_type(text, jsonb); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable._validate_json_schema_type(type text, data jsonb) OWNER TO postgres;

--
-- TOC entry 438 (class 1255 OID 53427)
-- Name: cron_element_to_array(text, text); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.cron_element_to_array(element text, element_type text) OWNER TO postgres;

--
-- TOC entry 439 (class 1255 OID 53428)
-- Name: get_running_jobs(bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.get_running_jobs(bigint) OWNER TO postgres;

--
-- TOC entry 440 (class 1255 OID 53429)
-- Name: get_task_id(text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.get_task_id(task_name text) RETURNS bigint
    LANGUAGE sql STRICT
    AS $_$
	SELECT task_id FROM timetable.base_task WHERE name = $1;
$_$;


ALTER FUNCTION timetable.get_task_id(task_name text) OWNER TO postgres;

--
-- TOC entry 441 (class 1255 OID 53430)
-- Name: insert_base_task(text, bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.insert_base_task(task_name text, parent_task_id bigint) OWNER TO postgres;

--
-- TOC entry 442 (class 1255 OID 53431)
-- Name: is_cron_in_time(timetable.cron, timestamp with time zone); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.is_cron_in_time(run_at timetable.cron, ts timestamp with time zone) OWNER TO postgres;

--
-- TOC entry 443 (class 1255 OID 53432)
-- Name: job_add(text, text, text, timetable.task_kind, timetable.cron, integer, boolean, boolean); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.job_add(task_name text, task_function text, client_name text, task_type timetable.task_kind, run_at timetable.cron, max_instances integer, live boolean, self_destruct boolean) OWNER TO postgres;

--
-- TOC entry 444 (class 1255 OID 53433)
-- Name: task_chain_delete(bigint, bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.task_chain_delete(config_ bigint, chain_id_ bigint) OWNER TO postgres;

--
-- TOC entry 445 (class 1255 OID 53434)
-- Name: trig_chain_fixer(); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.trig_chain_fixer() OWNER TO postgres;

--
-- TOC entry 446 (class 1255 OID 53435)
-- Name: validate_json_schema(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: timetable; Owner: postgres
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


ALTER FUNCTION timetable.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb) OWNER TO postgres;

--
-- TOC entry 1355 (class 1255 OID 53437)
-- Name: fraccion_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: postgres
--

CREATE AGGREGATE impuesto.fraccion_fsm(text) (
    SFUNC = impuesto.fraccion_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.fraccion_fsm(text) OWNER TO postgres;

--
-- TOC entry 1356 (class 1255 OID 53438)
-- Name: solicitud_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: postgres
--

CREATE AGGREGATE impuesto.solicitud_fsm(text) (
    SFUNC = impuesto.solicitud_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.solicitud_fsm(text) OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 53439)
-- Name: actividad_economica; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.actividad_economica (
    id_actividad_economica integer NOT NULL,
    numero_referencia integer,
    descripcion character varying,
    alicuota numeric,
    minimo_tributable integer
);


ALTER TABLE impuesto.actividad_economica OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 53445)
-- Name: actividad_economica_contribuyente; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.actividad_economica_contribuyente (
    id_actividad_economica_contribuyente integer NOT NULL,
    id_contribuyente integer NOT NULL,
    numero_referencia integer NOT NULL
);


ALTER TABLE impuesto.actividad_economica_contribuyente OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 53448)
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq OWNER TO postgres;

--
-- TOC entry 4410 (class 0 OID 0)
-- Dependencies: 221
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq OWNED BY impuesto.actividad_economica_contribuyente.id_actividad_economica_contribuyente;


--
-- TOC entry 222 (class 1259 OID 53450)
-- Name: actividad_economica_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.actividad_economica_exoneracion (
    id_actividad_economica_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_actividad_economica integer
);


ALTER TABLE impuesto.actividad_economica_exoneracion OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 53453)
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq OWNER TO postgres;

--
-- TOC entry 4411 (class 0 OID 0)
-- Dependencies: 223
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq OWNED BY impuesto.actividad_economica_exoneracion.id_actividad_economica_exoneracion;


--
-- TOC entry 224 (class 1259 OID 53455)
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.actividad_economica_id_actividad_economica_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.actividad_economica_id_actividad_economica_seq OWNER TO postgres;

--
-- TOC entry 4412 (class 0 OID 0)
-- Dependencies: 224
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_id_actividad_economica_seq OWNED BY impuesto.actividad_economica.id_actividad_economica;


--
-- TOC entry 225 (class 1259 OID 53457)
-- Name: avaluo_inmueble; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.avaluo_inmueble (
    id_avaluo_inmueble integer NOT NULL,
    id_inmueble integer NOT NULL,
    avaluo numeric NOT NULL,
    anio integer
);


ALTER TABLE impuesto.avaluo_inmueble OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 53463)
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq OWNER TO postgres;

--
-- TOC entry 4413 (class 0 OID 0)
-- Dependencies: 226
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq OWNED BY impuesto.avaluo_inmueble.id_avaluo_inmueble;


--
-- TOC entry 227 (class 1259 OID 53465)
-- Name: categoria_propaganda; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.categoria_propaganda (
    id_categoria_propaganda integer NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE impuesto.categoria_propaganda OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 53471)
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.categoria_propaganda_id_categoria_propaganda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.categoria_propaganda_id_categoria_propaganda_seq OWNER TO postgres;

--
-- TOC entry 4414 (class 0 OID 0)
-- Dependencies: 228
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.categoria_propaganda_id_categoria_propaganda_seq OWNED BY impuesto.categoria_propaganda.id_categoria_propaganda;


--
-- TOC entry 229 (class 1259 OID 53473)
-- Name: contribuyente; Type: TABLE; Schema: impuesto; Owner: postgres
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
    tipo_contribuyente character varying
);


ALTER TABLE impuesto.contribuyente OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 53479)
-- Name: contribuyente_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.contribuyente_exoneracion (
    id_contribuyente_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer NOT NULL,
    id_contribuyente integer NOT NULL,
    id_actividad_economica integer
);


ALTER TABLE impuesto.contribuyente_exoneracion OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 53482)
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq OWNER TO postgres;

--
-- TOC entry 4415 (class 0 OID 0)
-- Dependencies: 231
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq OWNED BY impuesto.contribuyente_exoneracion.id_contribuyente_exoneracion;


--
-- TOC entry 232 (class 1259 OID 53484)
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.contribuyente_id_contribuyente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.contribuyente_id_contribuyente_seq OWNER TO postgres;

--
-- TOC entry 4416 (class 0 OID 0)
-- Dependencies: 232
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.contribuyente_id_contribuyente_seq OWNED BY impuesto.contribuyente.id_contribuyente;


--
-- TOC entry 233 (class 1259 OID 53486)
-- Name: convenio; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.convenio (
    id_convenio integer NOT NULL,
    id_solicitud integer NOT NULL,
    cantidad integer NOT NULL
);


ALTER TABLE impuesto.convenio OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 53489)
-- Name: convenio_id_convenio_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.convenio_id_convenio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.convenio_id_convenio_seq OWNER TO postgres;

--
-- TOC entry 4417 (class 0 OID 0)
-- Dependencies: 234
-- Name: convenio_id_convenio_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.convenio_id_convenio_seq OWNED BY impuesto.convenio.id_convenio;


--
-- TOC entry 235 (class 1259 OID 53491)
-- Name: credito_fiscal; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.credito_fiscal (
    id_credito_fiscal integer NOT NULL,
    id_persona integer NOT NULL,
    concepto character varying NOT NULL,
    credito numeric NOT NULL
);


ALTER TABLE impuesto.credito_fiscal OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 53497)
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.credito_fiscal_id_credito_fiscal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.credito_fiscal_id_credito_fiscal_seq OWNER TO postgres;

--
-- TOC entry 4418 (class 0 OID 0)
-- Dependencies: 236
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.credito_fiscal_id_credito_fiscal_seq OWNED BY impuesto.credito_fiscal.id_credito_fiscal;


--
-- TOC entry 237 (class 1259 OID 53499)
-- Name: dias_feriados; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.dias_feriados (
    id_dia_feriado integer NOT NULL,
    dia date,
    descripcion character varying
);


ALTER TABLE impuesto.dias_feriados OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 53505)
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.dias_feriados_id_dia_feriado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.dias_feriados_id_dia_feriado_seq OWNER TO postgres;

--
-- TOC entry 4419 (class 0 OID 0)
-- Dependencies: 238
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.dias_feriados_id_dia_feriado_seq OWNED BY impuesto.dias_feriados.id_dia_feriado;


--
-- TOC entry 239 (class 1259 OID 53507)
-- Name: evento_fraccion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.evento_fraccion (
    id_evento_fraccion integer NOT NULL,
    id_fraccion integer NOT NULL,
    event character varying,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE impuesto.evento_fraccion OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 53514)
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.evento_fraccion_id_evento_fraccion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.evento_fraccion_id_evento_fraccion_seq OWNER TO postgres;

--
-- TOC entry 4420 (class 0 OID 0)
-- Dependencies: 240
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.evento_fraccion_id_evento_fraccion_seq OWNED BY impuesto.evento_fraccion.id_evento_fraccion;


--
-- TOC entry 241 (class 1259 OID 53516)
-- Name: evento_solicitud; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.evento_solicitud (
    id_evento_solicitud integer NOT NULL,
    id_solicitud integer NOT NULL,
    event character varying,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE impuesto.evento_solicitud OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 53523)
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.evento_solicitud_id_evento_solicitud_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.evento_solicitud_id_evento_solicitud_seq OWNER TO postgres;

--
-- TOC entry 4421 (class 0 OID 0)
-- Dependencies: 242
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.evento_solicitud_id_evento_solicitud_seq OWNED BY impuesto.evento_solicitud.id_evento_solicitud;


--
-- TOC entry 243 (class 1259 OID 53525)
-- Name: factor; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.factor (
    id_factor integer NOT NULL,
    descripcion character varying,
    valor numeric
);


ALTER TABLE impuesto.factor OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 53531)
-- Name: factor_id_factor_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.factor_id_factor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.factor_id_factor_seq OWNER TO postgres;

--
-- TOC entry 4422 (class 0 OID 0)
-- Dependencies: 244
-- Name: factor_id_factor_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.factor_id_factor_seq OWNED BY impuesto.factor.id_factor;


--
-- TOC entry 245 (class 1259 OID 53533)
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.fraccion_id_fraccion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.fraccion_id_fraccion_seq OWNER TO postgres;

--
-- TOC entry 4423 (class 0 OID 0)
-- Dependencies: 245
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.fraccion_id_fraccion_seq OWNED BY impuesto.fraccion.id_fraccion;


--
-- TOC entry 246 (class 1259 OID 53535)
-- Name: fraccion_state; Type: VIEW; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.fraccion_state OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 53539)
-- Name: inmueble_contribuyente_natural; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.inmueble_contribuyente_natural (
    id_inmueble_contribuyente integer NOT NULL,
    id_inmueble integer NOT NULL,
    id_contribuyente integer NOT NULL
);


ALTER TABLE impuesto.inmueble_contribuyente_natural OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 53542)
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq OWNER TO postgres;

--
-- TOC entry 4424 (class 0 OID 0)
-- Dependencies: 248
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq OWNED BY impuesto.inmueble_contribuyente_natural.id_inmueble_contribuyente;


--
-- TOC entry 249 (class 1259 OID 53544)
-- Name: liquidacion_descuento; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.liquidacion_descuento (
    id_liquidacion_descuento integer NOT NULL,
    id_liquidacion integer NOT NULL,
    porcentaje_descuento numeric NOT NULL
);


ALTER TABLE impuesto.liquidacion_descuento OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 53550)
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq OWNER TO postgres;

--
-- TOC entry 4425 (class 0 OID 0)
-- Dependencies: 250
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq OWNED BY impuesto.liquidacion_descuento.id_liquidacion_descuento;


--
-- TOC entry 251 (class 1259 OID 53552)
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.liquidacion_id_liquidacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.liquidacion_id_liquidacion_seq OWNER TO postgres;

--
-- TOC entry 4426 (class 0 OID 0)
-- Dependencies: 251
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.liquidacion_id_liquidacion_seq OWNED BY impuesto.liquidacion.id_liquidacion;


--
-- TOC entry 252 (class 1259 OID 53554)
-- Name: multa; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.multa (
    id_multa integer NOT NULL,
    id_solicitud integer NOT NULL,
    id_tipo_multa integer NOT NULL,
    monto numeric,
    mes character varying,
    anio integer
);


ALTER TABLE impuesto.multa OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 53560)
-- Name: multa_id_multa_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.multa_id_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.multa_id_multa_seq OWNER TO postgres;

--
-- TOC entry 4427 (class 0 OID 0)
-- Dependencies: 253
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.multa_id_multa_seq OWNED BY impuesto.multa.id_multa;


--
-- TOC entry 254 (class 1259 OID 53562)
-- Name: notificacion; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.notificacion OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 53570)
-- Name: notificacion_impuesto_view; Type: VIEW; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.notificacion_impuesto_view OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 53575)
-- Name: plazo_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.plazo_exoneracion (
    id_plazo_exoneracion integer NOT NULL,
    fecha_inicio date,
    fecha_fin date
);


ALTER TABLE impuesto.plazo_exoneracion OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 53578)
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq OWNER TO postgres;

--
-- TOC entry 4428 (class 0 OID 0)
-- Dependencies: 257
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq OWNED BY impuesto.plazo_exoneracion.id_plazo_exoneracion;


--
-- TOC entry 258 (class 1259 OID 53580)
-- Name: ramo_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.ramo_exoneracion (
    id_ramo_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_ramo integer
);


ALTER TABLE impuesto.ramo_exoneracion OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 53583)
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq OWNER TO postgres;

--
-- TOC entry 4429 (class 0 OID 0)
-- Dependencies: 259
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq OWNED BY impuesto.ramo_exoneracion.id_ramo_exoneracion;


--
-- TOC entry 260 (class 1259 OID 53585)
-- Name: ramo; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.ramo (
    id_ramo integer NOT NULL,
    codigo character varying NOT NULL,
    descripcion character varying NOT NULL,
    descripcion_corta character varying
);


ALTER TABLE impuesto.ramo OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 53591)
-- Name: ramo_id_ramo_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.ramo_id_ramo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.ramo_id_ramo_seq OWNER TO postgres;

--
-- TOC entry 4430 (class 0 OID 0)
-- Dependencies: 261
-- Name: ramo_id_ramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.ramo_id_ramo_seq OWNED BY impuesto.ramo.id_ramo;


--
-- TOC entry 262 (class 1259 OID 53593)
-- Name: registro_municipal_referencia_municipal_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.registro_municipal_referencia_municipal_seq
    START WITH 8000000000
    INCREMENT BY 1
    MINVALUE 8000000000
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.registro_municipal_referencia_municipal_seq OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 53595)
-- Name: registro_municipal; Type: TABLE; Schema: impuesto; Owner: postgres
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
    actualizado boolean DEFAULT false
);


ALTER TABLE impuesto.registro_municipal OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 53603)
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.registro_municipal_id_registro_municipal_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.registro_municipal_id_registro_municipal_seq OWNER TO postgres;

--
-- TOC entry 4431 (class 0 OID 0)
-- Dependencies: 264
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.registro_municipal_id_registro_municipal_seq OWNED BY impuesto.registro_municipal.id_registro_municipal;


--
-- TOC entry 265 (class 1259 OID 53605)
-- Name: registro_municipal_verificacion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.registro_municipal_verificacion (
    id_registro_municipal integer NOT NULL,
    id_verificacion_telefono integer NOT NULL
);


ALTER TABLE impuesto.registro_municipal_verificacion OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 53608)
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.solicitud_id_solicitud_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.solicitud_id_solicitud_seq OWNER TO postgres;

--
-- TOC entry 4432 (class 0 OID 0)
-- Dependencies: 266
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.solicitud_id_solicitud_seq OWNED BY impuesto.solicitud.id_solicitud;


--
-- TOC entry 267 (class 1259 OID 53610)
-- Name: solicitud_state; Type: VIEW; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.solicitud_state OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 53615)
-- Name: subramo; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.subramo (
    id_subramo integer NOT NULL,
    id_ramo integer NOT NULL,
    subindice character varying,
    descripcion character varying
);


ALTER TABLE impuesto.subramo OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 53621)
-- Name: solicitud_view; Type: VIEW; Schema: impuesto; Owner: postgres
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
    c.verificado
   FROM ((((impuesto.solicitud s
     JOIN impuesto.contribuyente c ON ((s.id_contribuyente = c.id_contribuyente)))
     JOIN impuesto.liquidacion l ON ((s.id_solicitud = l.id_solicitud)))
     JOIN impuesto.subramo sr ON ((sr.id_subramo = l.id_subramo)))
     JOIN impuesto.ramo r ON ((r.id_ramo = sr.id_subramo)));


ALTER TABLE impuesto.solicitud_view OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 53626)
-- Name: subramo_id_subramo_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.subramo_id_subramo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.subramo_id_subramo_seq OWNER TO postgres;

--
-- TOC entry 4433 (class 0 OID 0)
-- Dependencies: 270
-- Name: subramo_id_subramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.subramo_id_subramo_seq OWNED BY impuesto.subramo.id_subramo;


--
-- TOC entry 271 (class 1259 OID 53628)
-- Name: tabulador_aseo_actividad_economica; Type: TABLE; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.tabulador_aseo_actividad_economica OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 53635)
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq OWNER TO postgres;

--
-- TOC entry 4434 (class 0 OID 0)
-- Dependencies: 272
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq OWNED BY impuesto.tabulador_aseo_actividad_economica.id_tabulador_aseo_actividad_economica;


--
-- TOC entry 273 (class 1259 OID 53637)
-- Name: tabulador_aseo_residencial; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tabulador_aseo_residencial (
    id_tabulador_aseo_residencial integer NOT NULL,
    id_usuario integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_aseo_residencial OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 53644)
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq OWNER TO postgres;

--
-- TOC entry 4435 (class 0 OID 0)
-- Dependencies: 274
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq OWNED BY impuesto.tabulador_aseo_residencial.id_tabulador_aseo_residencial;


--
-- TOC entry 275 (class 1259 OID 53646)
-- Name: tabulador_gas; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tabulador_gas (
    id_tabulador_gas integer NOT NULL,
    id_actividad_economica integer,
    monto numeric
);


ALTER TABLE impuesto.tabulador_gas OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 53652)
-- Name: tabulador_gas_actividad_economica; Type: TABLE; Schema: impuesto; Owner: postgres
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


ALTER TABLE impuesto.tabulador_gas_actividad_economica OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 53659)
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq OWNER TO postgres;

--
-- TOC entry 4436 (class 0 OID 0)
-- Dependencies: 277
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq OWNED BY impuesto.tabulador_gas_actividad_economica.id_tabulador_gas_actividad_economica;


--
-- TOC entry 278 (class 1259 OID 53661)
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tabulador_gas_id_tabulador_gas_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_id_tabulador_gas_seq OWNER TO postgres;

--
-- TOC entry 4437 (class 0 OID 0)
-- Dependencies: 278
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_id_tabulador_gas_seq OWNED BY impuesto.tabulador_gas.id_tabulador_gas;


--
-- TOC entry 279 (class 1259 OID 53663)
-- Name: tabulador_gas_residencial; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tabulador_gas_residencial (
    id_tabulador_gas_residencial integer NOT NULL,
    id_usuario integer NOT NULL,
    monto numeric,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desde date,
    fecha_hasta date
);


ALTER TABLE impuesto.tabulador_gas_residencial OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 53670)
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq OWNER TO postgres;

--
-- TOC entry 4438 (class 0 OID 0)
-- Dependencies: 280
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq OWNED BY impuesto.tabulador_gas_residencial.id_tabulador_gas_residencial;


--
-- TOC entry 281 (class 1259 OID 53672)
-- Name: tipo_aviso_propaganda; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tipo_aviso_propaganda (
    id_tipo_aviso_propaganda integer NOT NULL,
    id_categoria_propaganda integer NOT NULL,
    descripcion character varying NOT NULL,
    parametro character varying NOT NULL,
    monto numeric NOT NULL,
    id_valor integer DEFAULT 2
);


ALTER TABLE impuesto.tipo_aviso_propaganda OWNER TO postgres;

--
-- TOC entry 282 (class 1259 OID 53679)
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq OWNER TO postgres;

--
-- TOC entry 4439 (class 0 OID 0)
-- Dependencies: 282
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq OWNED BY impuesto.tipo_aviso_propaganda.id_tipo_aviso_propaganda;


--
-- TOC entry 283 (class 1259 OID 53681)
-- Name: tipo_multa; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tipo_multa (
    id_tipo_multa integer NOT NULL,
    descripcion character varying
);


ALTER TABLE impuesto.tipo_multa OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 53687)
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.tipo_multa_id_tipo_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.tipo_multa_id_tipo_multa_seq OWNER TO postgres;

--
-- TOC entry 4440 (class 0 OID 0)
-- Dependencies: 284
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tipo_multa_id_tipo_multa_seq OWNED BY impuesto.tipo_multa.id_tipo_multa;


--
-- TOC entry 285 (class 1259 OID 53689)
-- Name: usuario_enlazado; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.usuario_enlazado (
    id_usuario_enlazado integer NOT NULL,
    id_contribuyente integer NOT NULL,
    email character varying NOT NULL
);


ALTER TABLE impuesto.usuario_enlazado OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 53695)
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.usuario_enlazado_id_usuario_enlazado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.usuario_enlazado_id_usuario_enlazado_seq OWNER TO postgres;

--
-- TOC entry 4441 (class 0 OID 0)
-- Dependencies: 286
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.usuario_enlazado_id_usuario_enlazado_seq OWNED BY impuesto.usuario_enlazado.id_usuario_enlazado;


--
-- TOC entry 287 (class 1259 OID 53697)
-- Name: verificacion_email; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.verificacion_email (
    id_verificacion_email integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    codigo_recuperacion character varying,
    fecha_recuperacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    verificado boolean DEFAULT false
);


ALTER TABLE impuesto.verificacion_email OWNER TO postgres;

--
-- TOC entry 288 (class 1259 OID 53705)
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.verificacion_email_id_verificacion_email_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.verificacion_email_id_verificacion_email_seq OWNER TO postgres;

--
-- TOC entry 4442 (class 0 OID 0)
-- Dependencies: 288
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.verificacion_email_id_verificacion_email_seq OWNED BY impuesto.verificacion_email.id_verificacion_email;


--
-- TOC entry 289 (class 1259 OID 53707)
-- Name: verificacion_telefono; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.verificacion_telefono (
    id_verificacion_telefono integer NOT NULL,
    codigo_verificacion character varying,
    fecha_verificacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    verificado boolean DEFAULT false,
    id_usuario integer,
    telefono character varying
);


ALTER TABLE impuesto.verificacion_telefono OWNER TO postgres;

--
-- TOC entry 290 (class 1259 OID 53715)
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE; Schema: impuesto; Owner: postgres
--

CREATE SEQUENCE impuesto.verificacion_telefono_id_verificacion_telefono_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE impuesto.verificacion_telefono_id_verificacion_telefono_seq OWNER TO postgres;

--
-- TOC entry 4443 (class 0 OID 0)
-- Dependencies: 290
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.verificacion_telefono_id_verificacion_telefono_seq OWNED BY impuesto.verificacion_telefono.id_verificacion_telefono;


--
-- TOC entry 291 (class 1259 OID 53717)
-- Name: banco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.banco (
    id_banco integer NOT NULL,
    nombre character varying,
    validador boolean DEFAULT false
);


ALTER TABLE public.banco OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 53724)
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
-- TOC entry 4444 (class 0 OID 0)
-- Dependencies: 292
-- Name: bancos_id_banco_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.banco.id_banco;


--
-- TOC entry 293 (class 1259 OID 53726)
-- Name: campo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campo (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying,
    validacion character varying,
    col integer
);


ALTER TABLE public.campo OWNER TO postgres;

--
-- TOC entry 294 (class 1259 OID 53732)
-- Name: campo_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.campo_tramite (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado character varying,
    id_seccion integer,
    CONSTRAINT campos_tramites_estado_check CHECK (((estado)::text = ANY (ARRAY['iniciado'::text, 'validando'::text, 'enproceso'::text, 'ingresardatos'::text, 'validando'::text, 'finalizado'::text])))
);


ALTER TABLE public.campo_tramite OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 53739)
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
-- TOC entry 4445 (class 0 OID 0)
-- Dependencies: 295
-- Name: campos_id_campo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campo.id_campo;


--
-- TOC entry 296 (class 1259 OID 53741)
-- Name: cargo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cargo (
    id_cargo integer NOT NULL,
    id_tipo_usuario integer,
    id_institucion integer,
    descripcion character varying
);


ALTER TABLE public.cargo OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 53747)
-- Name: cargo_id_cargo_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cargo_id_cargo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cargo_id_cargo_seq OWNER TO postgres;

--
-- TOC entry 4446 (class 0 OID 0)
-- Dependencies: 297
-- Name: cargo_id_cargo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cargo_id_cargo_seq OWNED BY public.cargo.id_cargo;


--
-- TOC entry 298 (class 1259 OID 53749)
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
-- TOC entry 4447 (class 0 OID 0)
-- Dependencies: 298
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.casos_sociales_id_caso_seq OWNED BY public.caso_social.id_caso;


--
-- TOC entry 299 (class 1259 OID 53751)
-- Name: certificado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificado (
    id_certificado integer NOT NULL,
    id_tramite integer,
    url_certificado character varying
);


ALTER TABLE public.certificado OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 53757)
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
-- TOC entry 4448 (class 0 OID 0)
-- Dependencies: 300
-- Name: certificados_id_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificados_id_certificado_seq OWNED BY public.certificado.id_certificado;


--
-- TOC entry 301 (class 1259 OID 53759)
-- Name: cuenta_funcionario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cuenta_funcionario (
    id_usuario integer NOT NULL,
    id_cargo integer
);


ALTER TABLE public.cuenta_funcionario OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 53762)
-- Name: datos_facebook; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datos_facebook (
    id_usuario integer NOT NULL,
    id_facebook character varying NOT NULL
);


ALTER TABLE public.datos_facebook OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 53768)
-- Name: datos_google; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


ALTER TABLE public.datos_google OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 53774)
-- Name: detalle_factura; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_factura (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    nombre character varying,
    costo numeric
);


ALTER TABLE public.detalle_factura OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 53780)
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
-- TOC entry 4449 (class 0 OID 0)
-- Dependencies: 305
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalles_facturas_id_detalle_seq OWNED BY public.detalle_factura.id_detalle;


--
-- TOC entry 306 (class 1259 OID 53782)
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.evento_multa_id_evento_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evento_multa_id_evento_multa_seq OWNER TO postgres;

--
-- TOC entry 4450 (class 0 OID 0)
-- Dependencies: 306
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.evento_multa_id_evento_multa_seq OWNED BY public.evento_multa.id_evento_multa;


--
-- TOC entry 307 (class 1259 OID 53784)
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
-- TOC entry 4451 (class 0 OID 0)
-- Dependencies: 307
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq OWNED BY public.evento_caso_social.id_evento_caso;


--
-- TOC entry 308 (class 1259 OID 53786)
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
-- TOC entry 4452 (class 0 OID 0)
-- Dependencies: 308
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventos_tramite_id_evento_tramite_seq OWNED BY public.evento_tramite.id_evento_tramite;


--
-- TOC entry 309 (class 1259 OID 53788)
-- Name: factura_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.factura_tramite (
    id_factura integer NOT NULL,
    id_tramite integer
);


ALTER TABLE public.factura_tramite OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 53791)
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
-- TOC entry 4453 (class 0 OID 0)
-- Dependencies: 310
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.facturas_tramites_id_factura_seq OWNED BY public.factura_tramite.id_factura;


--
-- TOC entry 311 (class 1259 OID 53793)
-- Name: inmueble_urbano; Type: TABLE; Schema: public; Owner: postgres
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
    id_registro_municipal integer
);


ALTER TABLE public.inmueble_urbano OWNER TO postgres;

--
-- TOC entry 312 (class 1259 OID 53801)
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
-- TOC entry 4454 (class 0 OID 0)
-- Dependencies: 312
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inmueble_urbano_id_inmueble_seq OWNED BY public.inmueble_urbano.id_inmueble;


--
-- TOC entry 313 (class 1259 OID 53803)
-- Name: parroquia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.parroquia OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 53809)
-- Name: inmueble_urbano_view; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.inmueble_urbano_view OWNER TO postgres;

--
-- TOC entry 315 (class 1259 OID 53813)
-- Name: institucion_banco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institucion_banco (
    id_institucion integer NOT NULL,
    id_banco integer NOT NULL,
    numero_cuenta character varying,
    nombre_titular character varying,
    documento_de_identificacion character varying,
    id_institucion_banco numeric DEFAULT 0
);


ALTER TABLE public.institucion_banco OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 53820)
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
-- TOC entry 4455 (class 0 OID 0)
-- Dependencies: 316
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.institucion.id_institucion;


--
-- TOC entry 317 (class 1259 OID 53822)
-- Name: multa_id_multa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.multa_id_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.multa_id_multa_seq OWNER TO postgres;

--
-- TOC entry 4456 (class 0 OID 0)
-- Dependencies: 317
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.multa_id_multa_seq OWNED BY public.multa.id_multa;


--
-- TOC entry 318 (class 1259 OID 53824)
-- Name: notificacion_impuesto_view; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.notificacion_impuesto_view OWNER TO postgres;

--
-- TOC entry 319 (class 1259 OID 53829)
-- Name: notificacion_multa_view; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.notificacion_multa_view OWNER TO postgres;

--
-- TOC entry 320 (class 1259 OID 53834)
-- Name: notificacion_tramite_view; Type: VIEW; Schema: public; Owner: postgres
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


ALTER TABLE public.notificacion_tramite_view OWNER TO postgres;

--
-- TOC entry 321 (class 1259 OID 53839)
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
-- TOC entry 4457 (class 0 OID 0)
-- Dependencies: 321
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificacion.id_notificacion;


--
-- TOC entry 322 (class 1259 OID 53841)
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
-- TOC entry 323 (class 1259 OID 53843)
-- Name: operacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operacion (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


ALTER TABLE public.operacion OWNER TO postgres;

--
-- TOC entry 324 (class 1259 OID 53850)
-- Name: operatividad_terminal; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.operatividad_terminal OWNER TO postgres;

--
-- TOC entry 325 (class 1259 OID 53859)
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operatividad_terminal_id_operatividad_terminal_seq OWNER TO postgres;

--
-- TOC entry 4458 (class 0 OID 0)
-- Dependencies: 325
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq OWNED BY public.operatividad_terminal.id_operatividad_terminal;


--
-- TOC entry 326 (class 1259 OID 53861)
-- Name: ordenanza; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordenanza (
    id_ordenanza integer NOT NULL,
    descripcion character varying NOT NULL,
    tarifa character varying,
    id_valor integer,
    habilitado boolean DEFAULT true
);


ALTER TABLE public.ordenanza OWNER TO postgres;

--
-- TOC entry 327 (class 1259 OID 53868)
-- Name: ordenanza_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ordenanza_tramite (
    id_ordenanza_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    id_tarifa integer NOT NULL,
    utmm numeric,
    valor_calc numeric,
    factor character varying,
    factor_value numeric,
    costo_ordenanza numeric
);


ALTER TABLE public.ordenanza_tramite OWNER TO postgres;

--
-- TOC entry 328 (class 1259 OID 53874)
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordenanzas_id_ordenanza_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordenanzas_id_ordenanza_seq OWNER TO postgres;

--
-- TOC entry 4459 (class 0 OID 0)
-- Dependencies: 328
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordenanzas_id_ordenanza_seq OWNED BY public.ordenanza.id_ordenanza;


--
-- TOC entry 329 (class 1259 OID 53876)
-- Name: tarifa_inspeccion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tarifa_inspeccion (
    id_tarifa integer NOT NULL,
    id_ordenanza integer NOT NULL,
    id_tipo_tramite integer NOT NULL,
    formula character varying,
    utiliza_codcat boolean,
    id_variable integer
);


ALTER TABLE public.tarifa_inspeccion OWNER TO postgres;

--
-- TOC entry 330 (class 1259 OID 53882)
-- Name: ordenanzas_instancias_tramites; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.ordenanzas_instancias_tramites AS
 SELECT ot.id_ordenanza_tramite AS id,
    ot.id_tramite AS "idTramite",
    o.descripcion AS ordenanza,
    ot.factor,
    ot.factor_value AS "factorValue",
    ot.utmm,
    ot.valor_calc AS "valorCalc",
    ot.costo_ordenanza AS "costoOrdenanza"
   FROM ((public.ordenanza_tramite ot
     JOIN public.tarifa_inspeccion ti ON ((ot.id_tarifa = ti.id_tarifa)))
     JOIN public.ordenanza o ON ((o.id_ordenanza = ti.id_ordenanza)));


ALTER TABLE public.ordenanzas_instancias_tramites OWNER TO postgres;

--
-- TOC entry 331 (class 1259 OID 53887)
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNER TO postgres;

--
-- TOC entry 4460 (class 0 OID 0)
-- Dependencies: 331
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNED BY public.ordenanza_tramite.id_ordenanza_tramite;


--
-- TOC entry 332 (class 1259 OID 53889)
-- Name: pago; Type: TABLE; Schema: public; Owner: postgres
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
    CONSTRAINT pago_concepto_check CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text, 'IMPUESTO'::text, 'CONVENIO'::text]))),
    CONSTRAINT pago_metodo_pago_check CHECK (((metodo_pago)::text = ANY (ARRAY['TRANSFERENCIA'::text, 'EFECTIVO'::text, 'CHEQUE'::text, 'PUNTO DE VENTA'::text])))
);


ALTER TABLE public.pago OWNER TO postgres;

--
-- TOC entry 333 (class 1259 OID 53900)
-- Name: pago_manual; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pago_manual (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


ALTER TABLE public.pago_manual OWNER TO postgres;

--
-- TOC entry 334 (class 1259 OID 53903)
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
-- TOC entry 4461 (class 0 OID 0)
-- Dependencies: 334
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pago.id_pago;


--
-- TOC entry 335 (class 1259 OID 53905)
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
-- TOC entry 4462 (class 0 OID 0)
-- Dependencies: 335
-- Name: parroquias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parroquias_id_seq OWNED BY public.parroquia.id;


--
-- TOC entry 336 (class 1259 OID 53907)
-- Name: permiso_de_acceso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permiso_de_acceso (
    id_permiso integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_tramite integer NOT NULL
);


ALTER TABLE public.permiso_de_acceso OWNER TO postgres;

--
-- TOC entry 337 (class 1259 OID 53910)
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
-- TOC entry 4463 (class 0 OID 0)
-- Dependencies: 337
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permiso_de_acceso_id_permiso_seq OWNED BY public.permiso_de_acceso.id_permiso;


--
-- TOC entry 338 (class 1259 OID 53912)
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
-- TOC entry 339 (class 1259 OID 53918)
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
-- TOC entry 4464 (class 0 OID 0)
-- Dependencies: 339
-- Name: propietario_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.propietario_id_propietario_seq OWNED BY public.propietario.id_propietario;


--
-- TOC entry 340 (class 1259 OID 53920)
-- Name: propietario_inmueble; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietario_inmueble (
    id_propietario_inmueble integer NOT NULL,
    id_propietario integer NOT NULL,
    id_inmueble integer NOT NULL
);


ALTER TABLE public.propietario_inmueble OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 53923)
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
-- TOC entry 4465 (class 0 OID 0)
-- Dependencies: 341
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNED BY public.propietario_inmueble.id_propietario_inmueble;


--
-- TOC entry 342 (class 1259 OID 53925)
-- Name: recaudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recaudo (
    id_recaudo integer NOT NULL,
    nombre_largo character varying,
    nombre_corto character varying,
    obligatorio boolean DEFAULT false,
    planilla text,
    extension text DEFAULT 'image/*'::text
);


ALTER TABLE public.recaudo OWNER TO postgres;

--
-- TOC entry 343 (class 1259 OID 53933)
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
-- TOC entry 4466 (class 0 OID 0)
-- Dependencies: 343
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudo.id_recaudo;


--
-- TOC entry 344 (class 1259 OID 53935)
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
-- TOC entry 345 (class 1259 OID 53942)
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
-- TOC entry 4467 (class 0 OID 0)
-- Dependencies: 345
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.recuperacion_id_recuperacion_seq OWNED BY public.recuperacion.id_recuperacion;


--
-- TOC entry 346 (class 1259 OID 53944)
-- Name: seccion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seccion (
    id_seccion integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.seccion OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 53950)
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tarifas_inspeccion_id_tarifa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tarifas_inspeccion_id_tarifa_seq OWNER TO postgres;

--
-- TOC entry 4468 (class 0 OID 0)
-- Dependencies: 347
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tarifas_inspeccion_id_tarifa_seq OWNED BY public.tarifa_inspeccion.id_tarifa;


--
-- TOC entry 348 (class 1259 OID 53952)
-- Name: template_certificado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.template_certificado (
    id_template_certificado integer NOT NULL,
    id_tipo_tramite integer,
    link character varying
);


ALTER TABLE public.template_certificado OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 53958)
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
-- TOC entry 4469 (class 0 OID 0)
-- Dependencies: 349
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_certificados_id_template_certificado_seq OWNED BY public.template_certificado.id_template_certificado;


--
-- TOC entry 350 (class 1259 OID 53960)
-- Name: tipo_tramite_recaudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_tramite_recaudo (
    id_tipo_tramite integer,
    id_recaudo integer,
    fisico boolean
);


ALTER TABLE public.tipo_tramite_recaudo OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 53963)
-- Name: tipo_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_usuario (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


ALTER TABLE public.tipo_usuario OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 53969)
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
-- TOC entry 4470 (class 0 OID 0)
-- Dependencies: 352
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipo_tramite.id_tipo_tramite;


--
-- TOC entry 353 (class 1259 OID 53971)
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
-- TOC entry 4471 (class 0 OID 0)
-- Dependencies: 353
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipo_usuario.id_tipo_usuario;


--
-- TOC entry 354 (class 1259 OID 53973)
-- Name: tramite_archivo_recaudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tramite_archivo_recaudo (
    id_tramite integer,
    url_archivo_recaudo character varying
);


ALTER TABLE public.tramite_archivo_recaudo OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 53979)
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
-- TOC entry 4472 (class 0 OID 0)
-- Dependencies: 355
-- Name: tramites_id_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramite.id_tramite;


--
-- TOC entry 356 (class 1259 OID 53981)
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
    ev.state,
    t.aprobado,
    t.fecha_culminacion AS fechaculminacion
   FROM (public.tramite t
     JOIN ( SELECT evento_tramite.id_tramite,
            public.tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
           FROM public.evento_tramite
          GROUP BY evento_tramite.id_tramite) ev ON ((t.id_tramite = ev.id_tramite)));


ALTER TABLE public.tramites_state OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 53986)
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
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
    CONSTRAINT usuarios_nacionalidad_check CHECK ((nacionalidad = ANY (ARRAY['V'::bpchar, 'E'::bpchar])))
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- TOC entry 358 (class 1259 OID 53993)
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
-- TOC entry 4473 (class 0 OID 0)
-- Dependencies: 358
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuario.id_usuario;


--
-- TOC entry 359 (class 1259 OID 53995)
-- Name: valor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.valor (
    id_valor integer NOT NULL,
    descripcion character varying NOT NULL,
    valor_en_bs numeric NOT NULL
);


ALTER TABLE public.valor OWNER TO postgres;

--
-- TOC entry 360 (class 1259 OID 54001)
-- Name: valores_id_valor_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.valores_id_valor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.valores_id_valor_seq OWNER TO postgres;

--
-- TOC entry 4474 (class 0 OID 0)
-- Dependencies: 360
-- Name: valores_id_valor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.valores_id_valor_seq OWNED BY public.valor.id_valor;


--
-- TOC entry 361 (class 1259 OID 54003)
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
-- TOC entry 362 (class 1259 OID 54005)
-- Name: variable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variable (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


ALTER TABLE public.variable OWNER TO postgres;

--
-- TOC entry 363 (class 1259 OID 54012)
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
-- TOC entry 364 (class 1259 OID 54014)
-- Name: variable_de_costo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variable_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);


ALTER TABLE public.variable_de_costo OWNER TO postgres;

--
-- TOC entry 365 (class 1259 OID 54021)
-- Name: variable_ordenanza; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variable_ordenanza (
    id_variable integer NOT NULL,
    nombre character varying NOT NULL,
    nombre_plural character varying NOT NULL
);


ALTER TABLE public.variable_ordenanza OWNER TO postgres;

--
-- TOC entry 366 (class 1259 OID 54027)
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.variables_ordenanzas_id_variable_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.variables_ordenanzas_id_variable_seq OWNER TO postgres;

--
-- TOC entry 4475 (class 0 OID 0)
-- Dependencies: 366
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variables_ordenanzas_id_variable_seq OWNED BY public.variable_ordenanza.id_variable;


--
-- TOC entry 367 (class 1259 OID 54029)
-- Name: base_task; Type: TABLE; Schema: timetable; Owner: postgres
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


ALTER TABLE timetable.base_task OWNER TO postgres;

--
-- TOC entry 368 (class 1259 OID 54037)
-- Name: base_task_task_id_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.base_task_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.base_task_task_id_seq OWNER TO postgres;

--
-- TOC entry 4476 (class 0 OID 0)
-- Dependencies: 368
-- Name: base_task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.base_task_task_id_seq OWNED BY timetable.base_task.task_id;


--
-- TOC entry 369 (class 1259 OID 54039)
-- Name: chain_execution_config; Type: TABLE; Schema: timetable; Owner: postgres
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


ALTER TABLE timetable.chain_execution_config OWNER TO postgres;

--
-- TOC entry 370 (class 1259 OID 54048)
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.chain_execution_config_chain_execution_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.chain_execution_config_chain_execution_config_seq OWNER TO postgres;

--
-- TOC entry 4477 (class 0 OID 0)
-- Dependencies: 370
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.chain_execution_config_chain_execution_config_seq OWNED BY timetable.chain_execution_config.chain_execution_config;


--
-- TOC entry 371 (class 1259 OID 54050)
-- Name: chain_execution_parameters; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.chain_execution_parameters (
    chain_execution_config bigint NOT NULL,
    chain_id bigint NOT NULL,
    order_id integer NOT NULL,
    value jsonb,
    CONSTRAINT chain_execution_parameters_order_id_check CHECK ((order_id > 0))
);


ALTER TABLE timetable.chain_execution_parameters OWNER TO postgres;

--
-- TOC entry 372 (class 1259 OID 54057)
-- Name: database_connection; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.database_connection (
    database_connection bigint NOT NULL,
    connect_string text NOT NULL,
    comment text
);


ALTER TABLE timetable.database_connection OWNER TO postgres;

--
-- TOC entry 373 (class 1259 OID 54063)
-- Name: database_connection_database_connection_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.database_connection_database_connection_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.database_connection_database_connection_seq OWNER TO postgres;

--
-- TOC entry 4478 (class 0 OID 0)
-- Dependencies: 373
-- Name: database_connection_database_connection_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.database_connection_database_connection_seq OWNED BY timetable.database_connection.database_connection;


--
-- TOC entry 374 (class 1259 OID 54065)
-- Name: execution_log; Type: TABLE; Schema: timetable; Owner: postgres
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


ALTER TABLE timetable.execution_log OWNER TO postgres;

--
-- TOC entry 375 (class 1259 OID 54072)
-- Name: log; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now(),
    client_name text,
    pid integer NOT NULL,
    log_level timetable.log_type NOT NULL,
    message text
);


ALTER TABLE timetable.log OWNER TO postgres;

--
-- TOC entry 376 (class 1259 OID 54079)
-- Name: log_id_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.log_id_seq OWNER TO postgres;

--
-- TOC entry 4479 (class 0 OID 0)
-- Dependencies: 376
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.log_id_seq OWNED BY timetable.log.id;


--
-- TOC entry 377 (class 1259 OID 54081)
-- Name: migrations; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.migrations (
    id bigint NOT NULL,
    version text NOT NULL
);


ALTER TABLE timetable.migrations OWNER TO postgres;

--
-- TOC entry 378 (class 1259 OID 54087)
-- Name: run_status; Type: TABLE; Schema: timetable; Owner: postgres
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


ALTER TABLE timetable.run_status OWNER TO postgres;

--
-- TOC entry 379 (class 1259 OID 54091)
-- Name: run_status_run_status_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.run_status_run_status_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.run_status_run_status_seq OWNER TO postgres;

--
-- TOC entry 4480 (class 0 OID 0)
-- Dependencies: 379
-- Name: run_status_run_status_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.run_status_run_status_seq OWNED BY timetable.run_status.run_status;


--
-- TOC entry 380 (class 1259 OID 54093)
-- Name: task_chain; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.task_chain (
    chain_id bigint NOT NULL,
    parent_id bigint,
    task_id bigint NOT NULL,
    run_uid text,
    database_connection bigint,
    ignore_error boolean DEFAULT false
);


ALTER TABLE timetable.task_chain OWNER TO postgres;

--
-- TOC entry 381 (class 1259 OID 54100)
-- Name: task_chain_chain_id_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.task_chain_chain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE timetable.task_chain_chain_id_seq OWNER TO postgres;

--
-- TOC entry 4481 (class 0 OID 0)
-- Dependencies: 381
-- Name: task_chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.task_chain_chain_id_seq OWNED BY timetable.task_chain.chain_id;


--
-- TOC entry 382 (class 1259 OID 54102)
-- Name: ano; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.ano (
    id integer NOT NULL,
    descripcion integer NOT NULL
);


ALTER TABLE valores_fiscales.ano OWNER TO postgres;

--
-- TOC entry 383 (class 1259 OID 54105)
-- Name: ano_fiscal_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: postgres
--

CREATE SEQUENCE valores_fiscales.ano_fiscal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.ano_fiscal_id_seq OWNER TO postgres;

--
-- TOC entry 4482 (class 0 OID 0)
-- Dependencies: 383
-- Name: ano_fiscal_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.ano_fiscal_id_seq OWNED BY valores_fiscales.ano.id;


--
-- TOC entry 384 (class 1259 OID 54107)
-- Name: construccion; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.construccion (
    valor_fiscal numeric(14,2) NOT NULL,
    id bigint NOT NULL,
    tipo_construccion_id integer NOT NULL,
    ano_id integer NOT NULL
);


ALTER TABLE valores_fiscales.construccion OWNER TO postgres;

--
-- TOC entry 385 (class 1259 OID 54110)
-- Name: construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: postgres
--

CREATE SEQUENCE valores_fiscales.construccion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.construccion_id_seq OWNER TO postgres;

--
-- TOC entry 4483 (class 0 OID 0)
-- Dependencies: 385
-- Name: construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.construccion_id_seq OWNED BY valores_fiscales.construccion.id;


--
-- TOC entry 386 (class 1259 OID 54112)
-- Name: tipo_construccion; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.tipo_construccion (
    descripcion text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.tipo_construccion OWNER TO postgres;

--
-- TOC entry 387 (class 1259 OID 54118)
-- Name: get_all_construcciones; Type: VIEW; Schema: valores_fiscales; Owner: postgres
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


ALTER TABLE valores_fiscales.get_all_construcciones OWNER TO postgres;

--
-- TOC entry 388 (class 1259 OID 54122)
-- Name: sector; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.sector (
    descripcion text NOT NULL,
    parroquia_id integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.sector OWNER TO postgres;

--
-- TOC entry 389 (class 1259 OID 54128)
-- Name: terreno; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.terreno (
    valor_fiscal numeric(14,2) NOT NULL,
    sector_id integer NOT NULL,
    id bigint NOT NULL,
    ano_id integer NOT NULL
);


ALTER TABLE valores_fiscales.terreno OWNER TO postgres;

--
-- TOC entry 390 (class 1259 OID 54131)
-- Name: get_all_terrenos; Type: VIEW; Schema: valores_fiscales; Owner: postgres
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


ALTER TABLE valores_fiscales.get_all_terrenos OWNER TO postgres;

--
-- TOC entry 391 (class 1259 OID 54135)
-- Name: sector_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: postgres
--

CREATE SEQUENCE valores_fiscales.sector_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.sector_id_seq OWNER TO postgres;

--
-- TOC entry 4484 (class 0 OID 0)
-- Dependencies: 391
-- Name: sector_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.sector_id_seq OWNED BY valores_fiscales.sector.id;


--
-- TOC entry 392 (class 1259 OID 54137)
-- Name: terreno_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: postgres
--

CREATE SEQUENCE valores_fiscales.terreno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.terreno_id_seq OWNER TO postgres;

--
-- TOC entry 4485 (class 0 OID 0)
-- Dependencies: 392
-- Name: terreno_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.terreno_id_seq OWNED BY valores_fiscales.terreno.id;


--
-- TOC entry 393 (class 1259 OID 54139)
-- Name: tipo_construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: postgres
--

CREATE SEQUENCE valores_fiscales.tipo_construccion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE valores_fiscales.tipo_construccion_id_seq OWNER TO postgres;

--
-- TOC entry 4486 (class 0 OID 0)
-- Dependencies: 393
-- Name: tipo_construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.tipo_construccion_id_seq OWNED BY valores_fiscales.tipo_construccion.id;


--
-- TOC entry 3681 (class 2604 OID 54141)
-- Name: actividad_economica id_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica ALTER COLUMN id_actividad_economica SET DEFAULT nextval('impuesto.actividad_economica_id_actividad_economica_seq'::regclass);


--
-- TOC entry 3682 (class 2604 OID 54142)
-- Name: actividad_economica_contribuyente id_actividad_economica_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente ALTER COLUMN id_actividad_economica_contribuyente SET DEFAULT nextval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq'::regclass);


--
-- TOC entry 3683 (class 2604 OID 54143)
-- Name: actividad_economica_exoneracion id_actividad_economica_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion ALTER COLUMN id_actividad_economica_exoneracion SET DEFAULT nextval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq'::regclass);


--
-- TOC entry 3684 (class 2604 OID 54144)
-- Name: avaluo_inmueble id_avaluo_inmueble; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble ALTER COLUMN id_avaluo_inmueble SET DEFAULT nextval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq'::regclass);


--
-- TOC entry 3685 (class 2604 OID 54145)
-- Name: categoria_propaganda id_categoria_propaganda; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.categoria_propaganda ALTER COLUMN id_categoria_propaganda SET DEFAULT nextval('impuesto.categoria_propaganda_id_categoria_propaganda_seq'::regclass);


--
-- TOC entry 3686 (class 2604 OID 54146)
-- Name: contribuyente id_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente ALTER COLUMN id_contribuyente SET DEFAULT nextval('impuesto.contribuyente_id_contribuyente_seq'::regclass);


--
-- TOC entry 3687 (class 2604 OID 54147)
-- Name: contribuyente_exoneracion id_contribuyente_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion ALTER COLUMN id_contribuyente_exoneracion SET DEFAULT nextval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq'::regclass);


--
-- TOC entry 3688 (class 2604 OID 54148)
-- Name: convenio id_convenio; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio ALTER COLUMN id_convenio SET DEFAULT nextval('impuesto.convenio_id_convenio_seq'::regclass);


--
-- TOC entry 3689 (class 2604 OID 54149)
-- Name: credito_fiscal id_credito_fiscal; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.credito_fiscal ALTER COLUMN id_credito_fiscal SET DEFAULT nextval('impuesto.credito_fiscal_id_credito_fiscal_seq'::regclass);


--
-- TOC entry 3690 (class 2604 OID 54150)
-- Name: dias_feriados id_dia_feriado; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.dias_feriados ALTER COLUMN id_dia_feriado SET DEFAULT nextval('impuesto.dias_feriados_id_dia_feriado_seq'::regclass);


--
-- TOC entry 3692 (class 2604 OID 54151)
-- Name: evento_fraccion id_evento_fraccion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion ALTER COLUMN id_evento_fraccion SET DEFAULT nextval('impuesto.evento_fraccion_id_evento_fraccion_seq'::regclass);


--
-- TOC entry 3694 (class 2604 OID 54152)
-- Name: evento_solicitud id_evento_solicitud; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud ALTER COLUMN id_evento_solicitud SET DEFAULT nextval('impuesto.evento_solicitud_id_evento_solicitud_seq'::regclass);


--
-- TOC entry 3695 (class 2604 OID 54153)
-- Name: factor id_factor; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.factor ALTER COLUMN id_factor SET DEFAULT nextval('impuesto.factor_id_factor_seq'::regclass);


--
-- TOC entry 3658 (class 2604 OID 54154)
-- Name: fraccion id_fraccion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion ALTER COLUMN id_fraccion SET DEFAULT nextval('impuesto.fraccion_id_fraccion_seq'::regclass);


--
-- TOC entry 3696 (class 2604 OID 54155)
-- Name: inmueble_contribuyente_natural id_inmueble_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural ALTER COLUMN id_inmueble_contribuyente SET DEFAULT nextval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq'::regclass);


--
-- TOC entry 3669 (class 2604 OID 54156)
-- Name: liquidacion id_liquidacion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion ALTER COLUMN id_liquidacion SET DEFAULT nextval('impuesto.liquidacion_id_liquidacion_seq'::regclass);


--
-- TOC entry 3697 (class 2604 OID 54157)
-- Name: liquidacion_descuento id_liquidacion_descuento; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento ALTER COLUMN id_liquidacion_descuento SET DEFAULT nextval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq'::regclass);


--
-- TOC entry 3698 (class 2604 OID 54158)
-- Name: multa id_multa; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa ALTER COLUMN id_multa SET DEFAULT nextval('impuesto.multa_id_multa_seq'::regclass);


--
-- TOC entry 3702 (class 2604 OID 54159)
-- Name: plazo_exoneracion id_plazo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.plazo_exoneracion ALTER COLUMN id_plazo_exoneracion SET DEFAULT nextval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq'::regclass);


--
-- TOC entry 3704 (class 2604 OID 54160)
-- Name: ramo id_ramo; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo ALTER COLUMN id_ramo SET DEFAULT nextval('impuesto.ramo_id_ramo_seq'::regclass);


--
-- TOC entry 3703 (class 2604 OID 54161)
-- Name: ramo_exoneracion id_ramo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion ALTER COLUMN id_ramo_exoneracion SET DEFAULT nextval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq'::regclass);


--
-- TOC entry 3707 (class 2604 OID 54162)
-- Name: registro_municipal id_registro_municipal; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal ALTER COLUMN id_registro_municipal SET DEFAULT nextval('impuesto.registro_municipal_id_registro_municipal_seq'::regclass);


--
-- TOC entry 3660 (class 2604 OID 54163)
-- Name: solicitud id_solicitud; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud ALTER COLUMN id_solicitud SET DEFAULT nextval('impuesto.solicitud_id_solicitud_seq'::regclass);


--
-- TOC entry 3708 (class 2604 OID 54164)
-- Name: subramo id_subramo; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo ALTER COLUMN id_subramo SET DEFAULT nextval('impuesto.subramo_id_subramo_seq'::regclass);


--
-- TOC entry 3710 (class 2604 OID 54165)
-- Name: tabulador_aseo_actividad_economica id_tabulador_aseo_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica ALTER COLUMN id_tabulador_aseo_actividad_economica SET DEFAULT nextval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq'::regclass);


--
-- TOC entry 3712 (class 2604 OID 54166)
-- Name: tabulador_aseo_residencial id_tabulador_aseo_residencial; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial ALTER COLUMN id_tabulador_aseo_residencial SET DEFAULT nextval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq'::regclass);


--
-- TOC entry 3713 (class 2604 OID 54167)
-- Name: tabulador_gas id_tabulador_gas; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas ALTER COLUMN id_tabulador_gas SET DEFAULT nextval('impuesto.tabulador_gas_id_tabulador_gas_seq'::regclass);


--
-- TOC entry 3715 (class 2604 OID 54168)
-- Name: tabulador_gas_actividad_economica id_tabulador_gas_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica ALTER COLUMN id_tabulador_gas_actividad_economica SET DEFAULT nextval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq'::regclass);


--
-- TOC entry 3717 (class 2604 OID 54169)
-- Name: tabulador_gas_residencial id_tabulador_gas_residencial; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial ALTER COLUMN id_tabulador_gas_residencial SET DEFAULT nextval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq'::regclass);


--
-- TOC entry 3719 (class 2604 OID 54170)
-- Name: tipo_aviso_propaganda id_tipo_aviso_propaganda; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda ALTER COLUMN id_tipo_aviso_propaganda SET DEFAULT nextval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq'::regclass);


--
-- TOC entry 3720 (class 2604 OID 54171)
-- Name: tipo_multa id_tipo_multa; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_multa ALTER COLUMN id_tipo_multa SET DEFAULT nextval('impuesto.tipo_multa_id_tipo_multa_seq'::regclass);


--
-- TOC entry 3721 (class 2604 OID 54172)
-- Name: usuario_enlazado id_usuario_enlazado; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado ALTER COLUMN id_usuario_enlazado SET DEFAULT nextval('impuesto.usuario_enlazado_id_usuario_enlazado_seq'::regclass);


--
-- TOC entry 3724 (class 2604 OID 54173)
-- Name: verificacion_email id_verificacion_email; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email ALTER COLUMN id_verificacion_email SET DEFAULT nextval('impuesto.verificacion_email_id_verificacion_email_seq'::regclass);


--
-- TOC entry 3727 (class 2604 OID 54174)
-- Name: verificacion_telefono id_verificacion_telefono; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono ALTER COLUMN id_verificacion_telefono SET DEFAULT nextval('impuesto.verificacion_telefono_id_verificacion_telefono_seq'::regclass);


--
-- TOC entry 3729 (class 2604 OID 54175)
-- Name: banco id_banco; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banco ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- TOC entry 3730 (class 2604 OID 54176)
-- Name: campo id_campo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- TOC entry 3732 (class 2604 OID 54177)
-- Name: cargo id_cargo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo ALTER COLUMN id_cargo SET DEFAULT nextval('public.cargo_id_cargo_seq'::regclass);


--
-- TOC entry 3662 (class 2604 OID 54178)
-- Name: caso_social id_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social ALTER COLUMN id_caso SET DEFAULT nextval('public.casos_sociales_id_caso_seq'::regclass);


--
-- TOC entry 3733 (class 2604 OID 54179)
-- Name: certificado id_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- TOC entry 3734 (class 2604 OID 54180)
-- Name: detalle_factura id_detalle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_factura ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- TOC entry 3664 (class 2604 OID 54181)
-- Name: evento_caso_social id_evento_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_caso_social ALTER COLUMN id_evento_caso SET DEFAULT nextval('public.eventos_casos_sociales_id_evento_caso_seq'::regclass);


--
-- TOC entry 3671 (class 2604 OID 54182)
-- Name: evento_multa id_evento_multa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa ALTER COLUMN id_evento_multa SET DEFAULT nextval('public.evento_multa_id_evento_multa_seq'::regclass);


--
-- TOC entry 3677 (class 2604 OID 54183)
-- Name: evento_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- TOC entry 3735 (class 2604 OID 54184)
-- Name: factura_tramite id_factura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


--
-- TOC entry 3738 (class 2604 OID 54185)
-- Name: inmueble_urbano id_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano ALTER COLUMN id_inmueble SET DEFAULT nextval('public.inmueble_urbano_id_inmueble_seq'::regclass);


--
-- TOC entry 3665 (class 2604 OID 54186)
-- Name: institucion id_institucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- TOC entry 3674 (class 2604 OID 54187)
-- Name: multa id_multa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa ALTER COLUMN id_multa SET DEFAULT nextval('public.multa_id_multa_seq'::regclass);


--
-- TOC entry 3700 (class 2604 OID 54188)
-- Name: notificacion id_notificacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificacion ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- TOC entry 3744 (class 2604 OID 54189)
-- Name: operatividad_terminal id_operatividad_terminal; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operatividad_terminal ALTER COLUMN id_operatividad_terminal SET DEFAULT nextval('public.operatividad_terminal_id_operatividad_terminal_seq'::regclass);


--
-- TOC entry 3747 (class 2604 OID 54190)
-- Name: ordenanza id_ordenanza; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza ALTER COLUMN id_ordenanza SET DEFAULT nextval('public.ordenanzas_id_ordenanza_seq'::regclass);


--
-- TOC entry 3748 (class 2604 OID 54191)
-- Name: ordenanza_tramite id_ordenanza_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite ALTER COLUMN id_ordenanza_tramite SET DEFAULT nextval('public.ordenanzas_tramites_id_ordenanza_tramite_seq'::regclass);


--
-- TOC entry 3753 (class 2604 OID 54192)
-- Name: pago id_pago; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- TOC entry 3739 (class 2604 OID 54193)
-- Name: parroquia id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquia ALTER COLUMN id SET DEFAULT nextval('public.parroquias_id_seq'::regclass);


--
-- TOC entry 3756 (class 2604 OID 54194)
-- Name: permiso_de_acceso id_permiso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso ALTER COLUMN id_permiso SET DEFAULT nextval('public.permiso_de_acceso_id_permiso_seq'::regclass);


--
-- TOC entry 3757 (class 2604 OID 54195)
-- Name: propietario id_propietario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietario_id_propietario_seq'::regclass);


--
-- TOC entry 3758 (class 2604 OID 54196)
-- Name: propietario_inmueble id_propietario_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble ALTER COLUMN id_propietario_inmueble SET DEFAULT nextval('public.propietarios_inmuebles_id_propietario_inmueble_seq'::regclass);


--
-- TOC entry 3761 (class 2604 OID 54197)
-- Name: recaudo id_recaudo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudo ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- TOC entry 3763 (class 2604 OID 54198)
-- Name: recuperacion id_recuperacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion ALTER COLUMN id_recuperacion SET DEFAULT nextval('public.recuperacion_id_recuperacion_seq'::regclass);


--
-- TOC entry 3749 (class 2604 OID 54199)
-- Name: tarifa_inspeccion id_tarifa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion ALTER COLUMN id_tarifa SET DEFAULT nextval('public.tarifas_inspeccion_id_tarifa_seq'::regclass);


--
-- TOC entry 3764 (class 2604 OID 54200)
-- Name: template_certificado id_template_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado ALTER COLUMN id_template_certificado SET DEFAULT nextval('public.templates_certificados_id_template_certificado_seq'::regclass);


--
-- TOC entry 3666 (class 2604 OID 54201)
-- Name: tipo_tramite id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- TOC entry 3765 (class 2604 OID 54202)
-- Name: tipo_usuario id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_usuario ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- TOC entry 3680 (class 2604 OID 54203)
-- Name: tramite id_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- TOC entry 3766 (class 2604 OID 54204)
-- Name: usuario id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- TOC entry 3768 (class 2604 OID 54205)
-- Name: valor id_valor; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valor ALTER COLUMN id_valor SET DEFAULT nextval('public.valores_id_valor_seq'::regclass);


--
-- TOC entry 3771 (class 2604 OID 54206)
-- Name: variable_ordenanza id_variable; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_ordenanza ALTER COLUMN id_variable SET DEFAULT nextval('public.variables_ordenanzas_id_variable_seq'::regclass);


--
-- TOC entry 3773 (class 2604 OID 54207)
-- Name: base_task task_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task ALTER COLUMN task_id SET DEFAULT nextval('timetable.base_task_task_id_seq'::regclass);


--
-- TOC entry 3778 (class 2604 OID 54208)
-- Name: chain_execution_config chain_execution_config; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config ALTER COLUMN chain_execution_config SET DEFAULT nextval('timetable.chain_execution_config_chain_execution_config_seq'::regclass);


--
-- TOC entry 3780 (class 2604 OID 54209)
-- Name: database_connection database_connection; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.database_connection ALTER COLUMN database_connection SET DEFAULT nextval('timetable.database_connection_database_connection_seq'::regclass);


--
-- TOC entry 3783 (class 2604 OID 54210)
-- Name: log id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.log ALTER COLUMN id SET DEFAULT nextval('timetable.log_id_seq'::regclass);


--
-- TOC entry 3785 (class 2604 OID 54211)
-- Name: run_status run_status; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.run_status ALTER COLUMN run_status SET DEFAULT nextval('timetable.run_status_run_status_seq'::regclass);


--
-- TOC entry 3787 (class 2604 OID 54212)
-- Name: task_chain chain_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.task_chain_chain_id_seq'::regclass);


--
-- TOC entry 3788 (class 2604 OID 54213)
-- Name: ano id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.ano ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.ano_fiscal_id_seq'::regclass);


--
-- TOC entry 3789 (class 2604 OID 54214)
-- Name: construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.construccion_id_seq'::regclass);


--
-- TOC entry 3791 (class 2604 OID 54215)
-- Name: sector id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.sector_id_seq'::regclass);


--
-- TOC entry 3792 (class 2604 OID 54216)
-- Name: terreno id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.terreno_id_seq'::regclass);


--
-- TOC entry 3790 (class 2604 OID 54217)
-- Name: tipo_construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.tipo_construccion_id_seq'::regclass);


--
-- TOC entry 4242 (class 0 OID 53439)
-- Dependencies: 219
-- Data for Name: actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
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
-- TOC entry 4243 (class 0 OID 53445)
-- Dependencies: 220
-- Data for Name: actividad_economica_contribuyente; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.actividad_economica_contribuyente (id_actividad_economica_contribuyente, id_contribuyente, numero_referencia) FROM stdin;
19	57	2005001
20	57	3053002
21	58	3001001
22	58	3010001
23	58	3062001
24	61	2047001
25	62	1004001
26	62	1008001
27	62	1017001
\.


--
-- TOC entry 4245 (class 0 OID 53450)
-- Dependencies: 222
-- Data for Name: actividad_economica_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.actividad_economica_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_actividad_economica) FROM stdin;
\.


--
-- TOC entry 4248 (class 0 OID 53457)
-- Dependencies: 225
-- Data for Name: avaluo_inmueble; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.avaluo_inmueble (id_avaluo_inmueble, id_inmueble, avaluo, anio) FROM stdin;
87	336	0	2020
88	337	0	2020
89	338	0	2020
90	339	0	2020
91	340	0	2020
92	341	0	2020
93	342	0	2020
94	343	0	2020
95	344	0	2020
96	345	0	2020
97	346	0	2020
98	347	0	2020
99	348	0	2020
100	349	0	2020
101	350	0	2020
102	351	0	2020
103	352	0	2020
104	353	0	2020
105	354	0	2020
106	355	0	2020
107	356	0	2020
108	357	0	2020
109	358	0	2020
110	359	0	2020
111	360	0	2020
112	361	0	2020
113	362	0	2020
114	363	0	2020
115	364	0	2020
116	365	0	2020
117	366	0	2020
\.


--
-- TOC entry 4250 (class 0 OID 53465)
-- Dependencies: 227
-- Data for Name: categoria_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: postgres
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
-- TOC entry 4252 (class 0 OID 53473)
-- Dependencies: 229
-- Data for Name: contribuyente; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.contribuyente (id_contribuyente, tipo_documento, documento, razon_social, denominacion_comercial, siglas, id_parroquia, sector, direccion, punto_referencia, verificado, tipo_contribuyente) FROM stdin;
57	J	304689713	CORPORACION DIGITEL, C.A.	CORPORACION GSM		\N		\N		t	JURIDICO
58	J	308620483	FARMACIA COVIDES C.A.	FARMACIA COVIDES C.A.		64	INDIO MARA	Avenida 65 Calle  22A, Local Nro.  MZN	EDIF. IPSFA	t	JURIDICO
59	V	400197520	Wak Casa de Software CA	Wak Casa de Software CA	WAK	72	Tierra Negra	Av 21 Calle 86	Diagonal CDO	t	JURIDICO
61	J	413060540	SERVICIOS INFORMATICOS WAKUPLUS CA	SERVICIOS INFORMATICOS WAKUPLUS CA	SERVICIOS INFORMATICOS WAKUPLUS CA	72	DELICIAS	Avenida 15 Y 14A-74 Calle 74, Local Nro. 7	5 DE JULIO	t	JURIDICO
62	J	303836216	COCA-COLA FEMSA DE VZLA S.A	COCA-COLA FEMSA DE VZLA S.A	COCA-COLA FEMSA DE VZLA S.A	68	ZONA INDUSTRIAL NORTE AV. 16 ENTRE CALLE 23 Y 32 NO. 23-274, SEGÚN AVALUO DCE-2142-2018	Avenida 16 Calle  23 Y 32, Local Nro. 3	FRENTE URB. MARA NORTE	t	JURIDICO
63	J	400197520	WAK CASA DE SOFTWARE, C.A.	WAK CASA DE SOFTWARE, C.A.		\N		\N		t	JURIDICO
\.


--
-- TOC entry 4253 (class 0 OID 53479)
-- Dependencies: 230
-- Data for Name: contribuyente_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_contribuyente, id_actividad_economica) FROM stdin;
\.


--
-- TOC entry 4256 (class 0 OID 53486)
-- Dependencies: 233
-- Data for Name: convenio; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.convenio (id_convenio, id_solicitud, cantidad) FROM stdin;
31	278	2
32	281	2
\.


--
-- TOC entry 4258 (class 0 OID 53491)
-- Dependencies: 235
-- Data for Name: credito_fiscal; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.credito_fiscal (id_credito_fiscal, id_persona, concepto, credito) FROM stdin;
\.


--
-- TOC entry 4260 (class 0 OID 53499)
-- Dependencies: 237
-- Data for Name: dias_feriados; Type: TABLE DATA; Schema: impuesto; Owner: postgres
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
-- TOC entry 4262 (class 0 OID 53507)
-- Dependencies: 239
-- Data for Name: evento_fraccion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.evento_fraccion (id_evento_fraccion, id_fraccion, event, "time") FROM stdin;
5	6	iniciar	2020-07-01 16:20:14.353543
6	7	iniciar	2020-07-01 16:20:14.353543
7	8	iniciar	2020-07-01 16:20:14.353543
8	9	iniciar	2020-07-01 16:20:14.353543
9	6	ingresardatos_pi	2020-07-01 16:20:14.353543
10	7	ingresardatos_pi	2020-07-01 16:20:14.353543
11	8	ingresardatos_pi	2020-07-01 16:20:14.353543
12	9	ingresardatos_pi	2020-07-01 16:20:14.353543
\.


--
-- TOC entry 4264 (class 0 OID 53516)
-- Dependencies: 241
-- Data for Name: evento_solicitud; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.evento_solicitud (id_evento_solicitud, id_solicitud, event, "time") FROM stdin;
224	172	iniciar	2020-06-26 20:37:44.78505
225	172	aprobacioncajero_pi	2020-06-26 20:37:44.78505
226	173	iniciar	2020-06-26 20:41:34.42527
227	173	ingresardatos_pi	2020-06-26 20:41:34.42527
228	173	validar_pi	2020-06-26 22:42:37.250062
229	174	iniciar	2020-06-26 22:45:58.308127
230	174	ingresardatos_pi	2020-06-26 22:45:58.308127
233	177	iniciar	2020-06-26 23:14:02.414925
234	178	iniciar	2020-06-26 23:14:02.414925
235	179	iniciar	2020-06-26 23:14:02.414925
236	180	iniciar	2020-06-26 23:14:02.414925
237	177	aprobacioncajero_pi	2020-06-26 23:14:02.414925
238	178	aprobacioncajero_pi	2020-06-26 23:14:02.414925
239	179	aprobacioncajero_pi	2020-06-26 23:14:02.414925
240	180	aprobacioncajero_pi	2020-06-26 23:14:02.414925
241	181	iniciar	2020-06-26 23:17:14.942023
242	181	ingresardatos_pi	2020-06-26 23:17:14.942023
243	181	validar_pi	2020-06-26 23:46:26.337192
245	182	iniciar	2020-06-27 00:39:26.883557
246	183	iniciar	2020-06-27 00:39:26.883557
247	182	aprobacioncajero_pi	2020-06-27 00:39:26.883557
248	183	aprobacioncajero_pi	2020-06-27 00:39:26.883557
249	184	iniciar	2020-06-27 00:39:26.883557
250	185	iniciar	2020-06-27 00:39:26.883557
251	186	iniciar	2020-06-27 00:59:40.771429
252	187	iniciar	2020-06-27 00:59:40.771429
253	188	iniciar	2020-06-27 00:59:40.771429
254	189	iniciar	2020-06-27 00:59:40.771429
255	186	aprobacioncajero_pi	2020-06-27 00:59:40.771429
256	187	aprobacioncajero_pi	2020-06-27 00:59:40.771429
257	188	aprobacioncajero_pi	2020-06-27 00:59:40.771429
258	189	aprobacioncajero_pi	2020-06-27 00:59:40.771429
259	190	iniciar	2020-06-27 00:59:40.771429
260	191	iniciar	2020-06-27 00:59:40.771429
261	192	iniciar	2020-06-27 00:59:40.771429
263	193	iniciar	2020-06-27 01:36:27.549939
264	193	ingresardatos_pi	2020-06-27 01:36:27.549939
265	194	iniciar	2020-06-27 01:51:18.474879
266	194	ingresardatos_pi	2020-06-27 01:51:18.474879
267	195	iniciar	2020-06-27 01:51:25.462511
268	195	ingresardatos_pi	2020-06-27 01:51:25.462511
275	181	finalizar_pi	2020-06-27 03:57:30.760909
278	198	iniciar	2020-06-27 04:18:41.761589
279	198	ingresardatos_pi	2020-06-27 04:18:41.761589
280	198	validar_pi	2020-06-27 04:18:59.56197
281	174	validar_pi	2020-06-27 04:30:50.793404
282	198	finalizar_pi	2020-06-27 04:44:04.819951
283	199	iniciar	2020-06-27 16:36:18.140369
284	199	ingresardatos_pi	2020-06-27 16:36:18.140369
285	199	validar_pi	2020-06-27 16:50:27.55877
286	200	iniciar	2020-06-27 17:01:41.369458
287	200	ingresardatos_pi	2020-06-27 17:01:41.369458
288	200	validar_pi	2020-06-30 12:58:42.828701
442	278	iniciar	2020-07-01 16:20:14.353543
290	202	iniciar	2020-07-01 15:55:15.769117
291	202	ingresardatos_pi	2020-07-01 15:55:15.769117
443	279	iniciar	2020-07-01 16:20:14.353543
444	280	iniciar	2020-07-01 16:20:14.353543
445	281	iniciar	2020-07-01 16:20:14.353543
446	282	iniciar	2020-07-01 16:20:14.353543
447	278	ingresardatos_pi	2020-07-01 16:20:14.353543
448	279	ingresardatos_pi	2020-07-01 16:20:14.353543
449	280	ingresardatos_pi	2020-07-01 16:20:14.353543
450	281	ingresardatos_pi	2020-07-01 16:20:14.353543
451	282	ingresardatos_pi	2020-07-01 16:20:14.353543
\.


--
-- TOC entry 4266 (class 0 OID 53525)
-- Dependencies: 243
-- Data for Name: factor; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.factor (id_factor, descripcion, valor) FROM stdin;
\.


--
-- TOC entry 4231 (class 0 OID 53299)
-- Dependencies: 205
-- Data for Name: fraccion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.fraccion (id_fraccion, id_convenio, monto, porcion, fecha, aprobado, fecha_aprobado) FROM stdin;
6	31	163158578.15	1	2020-01-07	f	\N
7	31	10000000.00	2	2020-01-07	f	\N
8	32	10000000.00	1	2020-02-07	f	\N
9	32	5000000.00	2	2020-03-07	f	\N
\.


--
-- TOC entry 4269 (class 0 OID 53539)
-- Dependencies: 247
-- Data for Name: inmueble_contribuyente_natural; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.inmueble_contribuyente_natural (id_inmueble_contribuyente, id_inmueble, id_contribuyente) FROM stdin;
\.


--
-- TOC entry 4237 (class 0 OID 53361)
-- Dependencies: 212
-- Data for Name: liquidacion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.liquidacion (id_liquidacion, id_solicitud, monto, certificado, recibo, fecha_liquidacion, id_subramo, datos, fecha_vencimiento, id_registro_municipal, remitido) FROM stdin;
715	174	0	\N	\N	2020-06-26	9	{"desglose":[{"inmueble":337,"monto":"0.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	19	f
716	174	0	\N	\N	2020-06-26	9	{"desglose":[{"inmueble":337,"monto":"0.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	19	f
717	174	0	\N	\N	2020-06-26	9	{"desglose":[{"inmueble":337,"monto":"0.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	19	f
692	172	309973947.02	\N	\N	2020-05-05	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	22	f
693	172	263158578.15	\N	\N	2020-04-28	9	{"fecha":{"month":"abril","year":2020}}	2020-06-30	22	f
694	172	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	22	f
695	172	279426342.85	\N	\N	2020-04-24	10	{"fecha":{"month":"abril","year":2020}}	2020-06-30	22	f
696	172	222170329.10	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	22	f
697	172	20228432.70	\N	\N	2020-02-14	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	22	f
698	172	186591315.09	\N	\N	2020-02-04	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	22	f
699	173	5000000	\N	\N	2020-06-26	30	{"fecha":{"month":"enero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-01-31	19	f
700	173	10000000	\N	\N	2020-06-26	30	{"fecha":{"month":"febrero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-02-29	19	f
701	173	15000000	\N	\N	2020-06-26	30	{"fecha":{"month":"marzo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-03-31	19	f
702	173	20000000	\N	\N	2020-06-26	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":40}	2020-04-30	19	f
703	173	25000000	\N	\N	2020-06-26	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":50}	2020-05-31	19	f
704	173	30000000	\N	\N	2020-06-26	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":60}	2020-06-30	19	f
705	173	3000000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":75,"montoDeclarado":"50000000.00"},{"aforo":185,"montoDeclarado":"50000000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	19	f
706	173	3000000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":75,"montoDeclarado":"50000000.00"},{"aforo":185,"montoDeclarado":"50000000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	19	f
707	173	3000000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":75,"montoDeclarado":"50000000.00"},{"aforo":185,"montoDeclarado":"50000000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	19	f
708	173	3000000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":75,"montoDeclarado":"50000000.00"},{"aforo":185,"montoDeclarado":"50000000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	19	f
709	173	3000000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":75,"montoDeclarado":"50000000.00"},{"aforo":185,"montoDeclarado":"50000000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	19	f
710	173	8932000	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":337,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	19	f
711	173	8932000	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":337,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	19	f
712	173	8932000	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":337,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	19	f
713	173	8932000	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":337,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	19	f
714	173	8932000	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":337,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	19	f
718	174	0	\N	\N	2020-06-26	9	{"desglose":[{"inmueble":337,"monto":"0.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	19	f
719	174	0	\N	\N	2020-06-26	9	{"desglose":[{"inmueble":337,"monto":"0.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	19	f
828	193	5000000	\N	\N	2020-06-27	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	28	f
829	193	10000000	\N	\N	2020-06-27	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-06-30	28	f
830	193	10000000	\N	\N	2020-06-27	10	{"desglose":[{"aforo":19,"montoDeclarado":"500000000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
831	193	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":349,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":350,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
832	193	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":349,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":350,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	28	f
859	199	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":343,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":344,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	24	f
860	199	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":343,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":344,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	24	f
861	199	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":343,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":344,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	24	f
720	177	369409.41	\N	\N	2020-04-22	52	{"fecha":{"month":"abril","year":2020}}	2020-06-30	23	f
721	177	505635.97	\N	\N	2020-03-10	52	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	23	f
722	177	0.00	\N	\N	2020-02-20	52	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	23	f
723	177	945.00	\N	\N	2020-01-30	11	{"fecha":{"month":"enero","year":2020}}	2020-06-30	23	f
724	178	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	24	f
725	178	54141217.24	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-06-30	24	f
726	178	21864572.31	\N	\N	2020-03-09	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	24	f
727	178	53360000.00	\N	\N	2020-03-09	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	24	f
728	178	5600000.00	\N	\N	2020-02-19	12	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	24	f
729	178	19818046.10	\N	\N	2020-02-05	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	24	f
730	178	13920000.00	\N	\N	2020-02-05	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	24	f
731	178	18560000.00	\N	\N	2020-01-07	66	{"fecha":{"month":"enero","year":2020}}	2020-06-30	24	f
732	179	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	25	f
733	180	22400000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	27	f
734	180	55915480.00	\N	\N	2020-03-03	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	27	f
735	181	5000000	\N	\N	2020-06-26	30	{"fecha":{"month":"enero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-01-31	27	f
736	181	10000000	\N	\N	2020-06-26	30	{"fecha":{"month":"febrero","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-02-29	27	f
737	181	15000000	\N	\N	2020-06-26	30	{"fecha":{"month":"marzo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-03-31	27	f
738	181	20000000	\N	\N	2020-06-26	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":40}	2020-04-30	27	f
739	181	25000000	\N	\N	2020-06-26	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":50}	2020-05-31	27	f
740	181	30000000	\N	\N	2020-06-26	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":60}	2020-06-30	27	f
741	181	6200000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":131,"montoDeclarado":"10000000.00"},{"aforo":140,"montoDeclarado":"10000000.00"},{"aforo":194,"montoDeclarado":"100000000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	27	f
742	181	5560000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":131,"montoDeclarado":"100000000.00"},{"aforo":140,"montoDeclarado":"50000000.00"},{"aforo":194,"montoDeclarado":"52000000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	27	f
743	181	5500000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":131,"montoDeclarado":"50000000.00"},{"aforo":140,"montoDeclarado":"50000000.00"},{"aforo":194,"montoDeclarado":"50000000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	27	f
744	181	5500000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":131,"montoDeclarado":"50000000.00"},{"aforo":140,"montoDeclarado":"50000000.00"},{"aforo":194,"montoDeclarado":"50000000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	27	f
745	181	3320000	\N	\N	2020-06-26	10	{"desglose":[{"aforo":131,"montoDeclarado":"1000000.00"},{"aforo":140,"montoDeclarado":"1000000.00"},{"aforo":194,"montoDeclarado":"10000000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	27	f
746	181	28999.999999999996	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":347,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":348,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	27	f
747	181	28999.999999999996	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":347,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":348,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	27	f
748	181	28999.999999999996	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":347,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":348,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	27	f
749	181	28999.999999999996	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":347,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":348,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	27	f
750	181	28999.999999999996	\N	\N	2020-06-26	66	{"desglose":[{"inmueble":347,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":348,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	27	f
833	194	12500000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":208,"monto":"12500000.00","cantidad":"5"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	28	f
834	194	4000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":202,"monto":"4000000.00","cantidad":"2"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	28	f
835	194	2000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":202,"monto":"2000000.00","cantidad":"1"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	28	f
836	194	66000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":206,"monto":"66000000.00","cantidad":"44"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	28	f
751	182	12754200.00	\N	\N	2020-05-06	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
752	182	1000000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
753	182	2500000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
754	182	400000.00	\N	\N	2020-02-28	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	28	f
755	183	12754200.00	\N	\N	2020-05-06	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	29	f
756	183	1000000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	29	f
757	183	2500000.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	29	f
758	183	400000.00	\N	\N	2020-02-28	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	29	f
837	194	9000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":201,"monto":"9000000.00","cantidad":"6"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
759	184	2500000.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
760	185	2500000.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	29	f
838	194	66000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":206,"monto":"66000000.00","cantidad":"44"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	28	f
839	195	12500000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":208,"monto":"12500000.00","cantidad":"5"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	28	f
840	195	4000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":202,"monto":"4000000.00","cantidad":"2"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	28	f
841	195	2000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":202,"monto":"2000000.00","cantidad":"1"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	28	f
842	195	66000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":206,"monto":"66000000.00","cantidad":"44"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	28	f
843	195	9000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":201,"monto":"9000000.00","cantidad":"6"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	28	f
844	195	66000000	\N	\N	2020-06-27	\N	{"desglose":[{"subarticulo":206,"monto":"66000000.00","cantidad":"44"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	28	f
862	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	23	f
863	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	23	f
864	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	23	f
865	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	23	f
866	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	23	f
819	189	318011124.77	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	33	f
867	200	25520000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":342,"montoAseo":16500000,"montoGas":"5500000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	23	f
845	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"enero","year":2020}}	2020-06-30	20	f
846	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	20	f
847	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	20	f
848	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	20	f
849	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	20	f
850	198	8932000	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":338,"montoAseo":4400000,"montoGas":"3300000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	20	f
761	186	823407712.33	\N	\N	2020-05-13	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
762	186	185600000.00	\N	\N	2020-05-13	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
763	186	315.00	\N	\N	2020-05-07	11	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
764	186	2475.00	\N	\N	2020-05-06	11	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
765	186	125576068.05	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
766	186	125576068.05	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
767	186	19126.84	\N	\N	2020-04-24	11	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
768	186	100400000.00	\N	\N	2020-04-23	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
769	186	100400000.00	\N	\N	2020-04-23	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
770	186	100400000.00	\N	\N	2020-04-23	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
771	186	100400000.00	\N	\N	2020-04-23	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
772	186	458756568.91	\N	\N	2020-04-20	10	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
773	186	366175332.22	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	30	f
774	186	31619815.40	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	30	f
775	186	375582497.61	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	30	f
776	186	396275691.71	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	30	f
777	186	5400.00	\N	\N	2020-02-10	11	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	30	f
778	186	6000.00	\N	\N	2020-02-10	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	30	f
779	186	12827815.40	\N	\N	2020-01-15	66	{"fecha":{"month":"enero","year":2020}}	2020-06-30	30	f
780	187	233245942.29	\N	\N	2020-05-06	52	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	31	f
781	187	4863602622.67	\N	\N	2020-04-28	52	{"fecha":{"month":"abril","year":2020}}	2020-06-30	31	f
782	187	178760471.22	\N	\N	2020-03-10	52	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	31	f
783	187	181680959.01	\N	\N	2020-02-12	52	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	31	f
784	188	10650698280.00	\N	\N	2020-05-06	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	32	f
785	188	10296000.00	\N	\N	2020-04-29	66	{"fecha":{"month":"abril","year":2020}}	2020-06-30	32	f
786	188	0.00	\N	\N	2020-04-27	66	{"fecha":{"month":"abril","year":2020}}	2020-06-30	32	f
787	188	1053.18	\N	\N	2020-04-24	11	{"fecha":{"month":"abril","year":2020}}	2020-06-30	32	f
788	188	10711438960.00	\N	\N	2020-04-07	10	{"fecha":{"month":"abril","year":2020}}	2020-06-30	32	f
789	188	7488000.00	\N	\N	2020-03-06	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	32	f
790	188	8890497680.00	\N	\N	2020-03-03	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	32	f
791	188	532313.85	\N	\N	2020-02-19	9	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
792	188	7488000.00	\N	\N	2020-02-19	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
793	188	1159855.88	\N	\N	2020-02-19	9	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
794	188	19364012.97	\N	\N	2020-02-19	9	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
795	188	1747127.80	\N	\N	2020-02-19	9	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
796	188	6596835240.00	\N	\N	2020-02-07	10	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	32	f
797	188	9449600.00	\N	\N	2020-01-27	66	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
798	188	1159855.88	\N	\N	2020-01-22	9	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
799	188	1747127.80	\N	\N	2020-01-22	9	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
800	188	432313.85	\N	\N	2020-01-22	9	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
801	188	19364012.97	\N	\N	2020-01-22	9	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
802	188	5616000.00	\N	\N	2020-01-15	66	{"fecha":{"month":"enero","year":2020}}	2020-06-30	32	f
803	189	166400000.00	\N	\N	2020-05-13	66	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	33	f
804	189	503692308.34	\N	\N	2020-05-13	10	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	33	f
805	189	7920.00	\N	\N	2020-05-06	11	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	33	f
806	189	128000000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
807	189	6075.00	\N	\N	2020-04-28	11	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
808	189	128000000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
809	189	128000000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
810	189	128000000.00	\N	\N	2020-04-28	12	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
811	189	106309307.71	\N	\N	2020-04-24	9	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
812	189	163826011.54	\N	\N	2020-04-20	10	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
813	189	14976000.00	\N	\N	2020-03-10	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	33	f
814	189	340243897.25	\N	\N	2020-03-10	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	33	f
815	189	300427412.47	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	33	f
816	189	2640463158.80	\N	\N	2020-03-02	10	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	33	f
817	189	14976000.00	\N	\N	2020-03-02	66	{"fecha":{"month":"marzo","year":2020}}	2020-03-31	33	f
818	189	7488000.00	\N	\N	2020-02-10	66	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	33	f
820	189	7577600.00	\N	\N	2020-01-15	66	{"fecha":{"month":"enero","year":2020}}	2020-06-30	33	f
851	199	5000000	\N	\N	2020-06-27	30	{"fecha":{"month":"marzo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-03-31	24	f
852	199	10000000	\N	\N	2020-06-27	30	{"fecha":{"month":"abril","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-04-30	24	f
853	199	15000000	\N	\N	2020-06-27	30	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":30}	2020-05-31	24	f
854	199	20000000	\N	\N	2020-06-27	30	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":40}	2020-06-30	24	f
855	199	19000000	\N	\N	2020-06-27	10	{"desglose":[{"aforo":131,"montoDeclarado":"30000000.00"},{"aforo":140,"montoDeclarado":"50000000.00"},{"aforo":194,"montoDeclarado":"500000000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	24	f
821	190	6000.00	\N	\N	\N	\N	{"fecha":{"month":"febrero","year":2020}}	2020-02-29	30	f
822	190	21252.04	\N	\N	\N	\N	{"fecha":{"month":"abril","year":2020}}	2020-06-30	30	f
823	190	2750.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
824	190	350.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	30	f
825	191	1170.20	\N	\N	\N	\N	{"fecha":{"month":"abril","year":2020}}	2020-06-30	32	f
826	192	6750.00	\N	\N	\N	\N	{"fecha":{"month":"abril","year":2020}}	2020-06-30	33	f
827	192	8800.00	\N	\N	\N	\N	{"fecha":{"month":"mayo","year":2020}}	2020-05-31	33	f
856	199	5950000	\N	\N	2020-06-27	10	{"desglose":[{"aforo":131,"montoDeclarado":"5000000.00"},{"aforo":140,"montoDeclarado":"50000000.00"},{"aforo":194,"montoDeclarado":"65000000.00"}],"fecha":{"month":"abril","year":2020}}	2020-06-30	24	f
857	199	12930000	\N	\N	2020-06-27	10	{"desglose":[{"aforo":131,"montoDeclarado":"650000000.00"},{"aforo":140,"montoDeclarado":"65000000.00"},{"aforo":194,"montoDeclarado":"56000000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	24	f
858	199	28999.999999999996	\N	\N	2020-06-27	66	{"desglose":[{"inmueble":343,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":344,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	24	f
868	281	5000000.00	\N	\N	2020-07-01	101	{"fecha":{"month":"mayo","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":10}	2020-05-31	22	f
869	281	10000000.00	\N	\N	2020-07-01	101	{"fecha":{"month":"junio","year":2020},"descripcion":"Multa por Declaracion Fuera de Plazo","monto":20}	2020-06-30	22	f
870	279	36938523723.69	\N	\N	2020-07-01	10	{"desglose":[{"aforo":75,"montoDeclarado":"123412312.00"},{"aforo":185,"montoDeclarado":"1231234124123.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	22	f
871	279	371737023.69	\N	\N	2020-07-01	10	{"desglose":[{"aforo":75,"montoDeclarado":"123412341.00"},{"aforo":185,"montoDeclarado":"12341234123.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	22	f
875	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"mayo","year":2020}}	2020-05-31	22	f
876	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"junio","year":2020}}	2020-06-30	22	f
872	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"febrero","year":2020}}	2020-02-29	22	f
873	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"marzo","year":2020}}	2020-03-31	22	f
874	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"abril","year":2020}}	2020-07-31	22	f
877	282	29000.00	\N	\N	2020-07-01	66	{"desglose":[{"inmueble":340,"montoAseo":18000,"montoGas":"7000.00"},{"inmueble":341,"montoAseo":18000,"montoGas":"7000.00"}],"fecha":{"month":"julio","year":2020}}	2020-07-31	22	f
\.


--
-- TOC entry 4271 (class 0 OID 53544)
-- Dependencies: 249
-- Data for Name: liquidacion_descuento; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.liquidacion_descuento (id_liquidacion_descuento, id_liquidacion, porcentaje_descuento) FROM stdin;
\.


--
-- TOC entry 4274 (class 0 OID 53554)
-- Dependencies: 252
-- Data for Name: multa; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.multa (id_multa, id_solicitud, id_tipo_multa, monto, mes, anio) FROM stdin;
\.


--
-- TOC entry 4277 (class 0 OID 53575)
-- Dependencies: 256
-- Data for Name: plazo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.plazo_exoneracion (id_plazo_exoneracion, fecha_inicio, fecha_fin) FROM stdin;
21	2020-06-26	\N
22	2020-06-26	\N
23	2020-06-26	\N
\.


--
-- TOC entry 4281 (class 0 OID 53585)
-- Dependencies: 260
-- Data for Name: ramo; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.ramo (id_ramo, codigo, descripcion, descripcion_corta) FROM stdin;
29	501	MULTAS	MUL
2	101	SITUADO CONSTITUCIONAL	\N
9	112	ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES	AE
8	111	PROPIEDAD INMOBILIARIA	IU
11	114	PROPAGANDAS Y AVISOS COMERCIALES	PM
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
47	910	REPAROS FISCALES	\N
48	911	REPAROS FISCALES (IND. Y COM.)	\N
49	912	REPARO POR RETENCIONES NO ENTERADAS	\N
50	915	RETENCIONES DECRETO 048	\N
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
1	236	TASA ADMINISTRATIVA DE SOLVENCIA DE AE	\N
\.


--
-- TOC entry 4279 (class 0 OID 53580)
-- Dependencies: 258
-- Data for Name: ramo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.ramo_exoneracion (id_ramo_exoneracion, id_plazo_exoneracion, id_ramo) FROM stdin;
\.


--
-- TOC entry 4284 (class 0 OID 53595)
-- Dependencies: 263
-- Data for Name: registro_municipal; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.registro_municipal (id_registro_municipal, id_contribuyente, referencia_municipal, fecha_aprobacion, telefono_celular, telefono_habitacion, email, denominacion_comercial, nombre_representante, actualizado) FROM stdin;
19	57	2900014139	2020-06-26	4129661659	\N	orderleep@gmail.com	CORPORACION DIGITEL, C.A.	ROBERTO JOSE ORTA	t
20	57	2900013536	2020-06-26	4129661659	\N	romayjj@gmail.com	CORPORACION DIGITEL, C.A.  PALACIO DE EVENTOS	FRANCISCO  HUNG	t
21	57	2900026280	2020-06-26	4129661659	\N	ffrazo@gmail.com	CORPORACION DIGITEL, C.A.	DEMERIS RUIZ	t
27	58	2900013829	2020-06-26	4129661659	\N	orderleep@gmail.com	FARMACIA COVIDES, C.A. ( LOCATEL BELLA VISTA )	LILIANA SANCHEZ	t
28	61	7000002467	2020-06-27	4146224064	\N	wakapluswakuplus@gmail.com	SERVICIOS INFORMATICOS WAKUPLUS CA	MANUEL MARULANDA	t
29	61	7000002467	2020-06-27	4146224064	\N	wakapluswakuplus@gmail.com	SERVICIOS INFORMATICOS WAKUPLUS CA	MANUEL MARULANDA	t
30	62	7000002164	2020-06-27	4247134807	\N	lismar.guerrero@kof.com.mx	COCA-COLA FEMSA DE VZLA S.A	Daniel Salas	t
31	62	AR00000030	2020-06-27	4140646227	\N	natalie.rodriguez@kof.com.mx	COCA COLA	0	f
32	62	2000060814	2020-06-27	261	\N	natalie.rodriguez@kof.com.mx	COCA-COLA FEMSA DE VENEZUELA, S.A.		f
33	62	2900030265	2020-06-27	414	\N	maria.carrero@kof.com.mx	COCA-COLA FEMSA DE VZLA S.A	LEONDINA DELLA FIGLIUOLA	f
34	63	2900034653	2020-06-27	0	\N	0	WAK CASA DE SOFTWARE, C.A.	JHONNATHAN JOSE ROMAY CAMACHO	t
24	58	207R002131	2020-06-26	4129661659	\N	romayjj@gmail.com	FARMACIA COVIDES, C.A.  LOCATEL ( I.P.S.F.A. )	JOSE ABELD	t
25	58	207R002132	2020-06-26	2122643821	\N		RARMACIA COVIDES, C.A. ( LOCATEL I.P.S.F.A. )	JOSE ABEID	\N
26	58	207P000358	2020-06-26	02617590502	\N		FARMACIA COVIDES C.A.-	LILIANA SANCHEZ.-	\N
23	58	AR20200024	2020-06-26	1	\N		FARMACIA COVIDES C.A.	IVECO	t
18	57	2900011266	2020-06-26	4078376304	\N	snider8520@gmail.com	CORPORACION GSM	OSWALDO CISNEROS	t
22	57	2900011265	2020-06-26	4078376304	\N	snider8520@gmail.com	CORPORACION DIGITEL, C.A.	ALFRED TULIO HUNG RIVERO	t
\.


--
-- TOC entry 4286 (class 0 OID 53605)
-- Dependencies: 265
-- Data for Name: registro_municipal_verificacion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.registro_municipal_verificacion (id_registro_municipal, id_verificacion_telefono) FROM stdin;
19	81
20	82
21	83
27	84
24	85
18	86
22	86
\.


--
-- TOC entry 4232 (class 0 OID 53307)
-- Dependencies: 206
-- Data for Name: solicitud; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.solicitud (id_solicitud, id_usuario, aprobado, fecha, fecha_aprobado, id_tipo_tramite, id_contribuyente, tipo_solicitud) FROM stdin;
193	117	f	2020-06-27	\N	5	61	\N
194	117	f	2020-06-27	\N	5	61	\N
195	117	f	2020-06-27	\N	5	61	\N
172	\N	t	2020-05-05	2020-06-26	5	57	\N
173	58	f	2020-06-26	\N	5	57	\N
174	58	f	2020-06-26	\N	5	57	\N
181	122	t	2020-06-26	2020-06-27	5	58	\N
177	\N	t	2020-04-22	2020-06-26	5	58	\N
178	\N	t	2020-04-28	2020-06-26	5	58	\N
179	\N	t	2020-04-28	2020-06-26	5	58	\N
180	122	t	2020-04-28	2020-06-26	5	58	\N
198	58	t	2020-06-27	2020-06-27	5	57	\N
199	124	f	2020-06-27	\N	5	58	\N
200	116	f	2020-06-27	\N	5	58	\N
182	117	t	2020-05-06	2020-06-27	5	61	\N
183	117	t	2020-05-06	2020-06-27	5	61	\N
184	117	f	2020-05-06	\N	5	61	\N
185	117	f	2020-05-06	\N	5	61	\N
186	117	t	2020-05-13	2020-06-27	5	62	\N
187	\N	t	2020-05-06	2020-06-27	5	62	\N
188	\N	t	2020-05-06	2020-06-27	5	62	\N
189	\N	t	2020-05-13	2020-06-27	5	62	\N
190	117	f	2020-05-13	\N	5	62	\N
191	\N	f	2020-05-06	\N	5	62	\N
192	\N	f	2020-05-13	\N	5	62	\N
202	125	f	2020-07-01	\N	5	57	\N
279	\N	f	2020-07-01	\N	5	57	\N
280	\N	f	2020-07-01	\N	5	57	\N
282	\N	f	2020-07-01	\N	5	57	\N
278	\N	f	2020-07-01	\N	5	57	CONVENIO
281	\N	f	2020-07-01	\N	5	57	CONVENIO
\.


--
-- TOC entry 4288 (class 0 OID 53615)
-- Dependencies: 268
-- Data for Name: subramo; Type: TABLE DATA; Schema: impuesto; Owner: postgres
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
\.


--
-- TOC entry 4290 (class 0 OID 53628)
-- Dependencies: 271
-- Data for Name: tabulador_aseo_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_aseo_actividad_economica (id_tabulador_aseo_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	1001001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
2	83	1002001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
3	83	1003001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
4	83	1004001	9900000.00	2020-06-11 00:00:00-04	2020-06-11	\N
5	83	1005001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
6	83	1006001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
7	83	1007001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
8	83	1008001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
9	83	1009001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
10	83	1010001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
11	83	1011001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
12	83	1012001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
13	83	1013001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
14	83	1014001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
15	83	1015001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
16	83	1016001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
17	83	1017001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
18	83	1018001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
19	83	1019001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
20	83	1020001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
21	83	1021001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
22	83	1022001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
23	83	1023001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
24	83	1024001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
25	83	1025001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
26	83	1026001	6600000.00	2020-06-11 00:00:00-04	2020-06-11	\N
27	83	1027001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
28	83	1028001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
29	83	1029001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
30	83	1030001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
31	83	1033001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
32	83	1034001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
33	83	1036001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
34	83	1037001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
35	83	1038001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
36	83	1039001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
37	83	1040001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
38	83	1041001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
39	83	1042001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
40	83	1043001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
41	83	1044001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
42	83	1045001	6600000.00	2020-06-11 00:00:00-04	2020-06-11	\N
43	83	1046001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
44	83	1047001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
45	83	1048001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
46	83	2001001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
47	83	2002001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
48	83	2003001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
49	83	2004001	6600000.00	2020-06-11 00:00:00-04	2020-06-11	\N
50	83	2005001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
51	83	2006001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
52	83	2007001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
53	83	2008001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
54	83	2009001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
55	83	2010001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
56	83	2011001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
57	83	2012001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
58	83	2013001	33000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
59	83	2014001	16500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
60	83	2016001	8250000.00	2020-06-11 00:00:00-04	2020-06-11	\N
61	83	2015001	9900000.00	2020-06-11 00:00:00-04	2020-06-11	\N
62	83	2017001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
63	83	2018001	22000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
64	83	2019001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
65	83	2020001	19800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
66	83	2021001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
67	83	2022001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
68	83	2023001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
69	83	2024002	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
70	83	2025003	16500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
71	83	2026001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
72	83	2028001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
73	83	2029001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
74	83	2030001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
75	83	2031001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
76	83	2032001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
77	83	2033001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
78	83	2034001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
79	83	2035001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
80	83	2036001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
81	83	2037001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
82	83	2038001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
83	83	2039001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
84	83	2040001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
85	83	2042001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
86	83	2043002	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
87	83	2044001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
88	83	2045001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
89	83	2046001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
90	83	2047001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
91	83	2048001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
92	83	2049002	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
93	83	2051001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
94	83	2052001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
95	83	2053001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
96	83	2054001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
97	83	2055001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
98	83	2056001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
99	83	2057001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
100	83	2058001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
101	83	2059001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
102	83	2060001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
103	83	2061001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
104	83	2062001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
105	83	2063001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
106	83	2064001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
107	83	2065001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
108	83	2066001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
109	83	2067001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
110	83	2068001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
111	83	2069002	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
112	83	2070003	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
113	83	2071001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
114	83	2072001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
115	83	2073001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
116	83	3001001	16500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
117	83	3002001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
118	83	3003002	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
119	83	3004001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
120	83	3005001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
121	83	3006001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
122	83	3007001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
123	83	3008001	6050000.00	2020-06-11 00:00:00-04	2020-06-11	\N
124	83	3009001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
125	83	3010001	12100000.00	2020-06-11 00:00:00-04	2020-06-11	\N
126	83	3011001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
127	83	3012001	6050000.00	2020-06-11 00:00:00-04	2020-06-11	\N
128	83	3013001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
129	83	3014001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
130	83	3015001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
131	83	3016001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
132	83	3017002	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
133	83	3019002	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
134	83	3020001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
135	83	3021001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
136	83	3022001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
137	83	3023001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
138	83	3024001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
139	83	3025001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
140	83	3026001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
141	83	3027001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
142	83	3028001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
143	83	3030002	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
144	83	3031001	7150000.00	2020-06-11 00:00:00-04	2020-06-11	\N
145	83	3032001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
146	83	3033002	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
147	83	3034001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
148	83	3035001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
149	83	3036001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
150	83	3037001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
151	83	3038001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
152	83	3039001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
153	83	3040001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
154	83	3041001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
155	83	3042001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
156	83	3043001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
157	83	3044001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
158	83	3045002	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
159	83	3046001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
160	83	3047001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
161	83	3048001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
162	83	3049001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
163	83	3050001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
164	83	3051001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
165	83	3052001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
166	83	3053002	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
167	83	3054001	6050000.00	2020-06-11 00:00:00-04	2020-06-11	\N
168	83	3055001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
169	83	3056001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
170	83	3057001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
171	83	3058001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
172	83	3059001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
173	83	3060001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
174	83	3061001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
175	83	3062001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
176	83	3063001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
177	83	3064001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
178	83	3065001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
179	83	3066001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
180	83	3067001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
181	83	3068001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
182	83	3070001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
183	83	3072002	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
184	83	3073001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
185	83	3074001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
186	83	3075001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
187	83	3076001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
188	83	3077001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
189	83	3078001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
190	83	3079001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
191	83	3080001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
192	83	3081001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
193	83	3082001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
194	83	3083001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
195	83	20230011	16500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
196	83	20230012	22000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
197	83	20230013	33000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
198	83	20270011	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
199	83	20270012	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
200	83	30240011	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
201	83	30240012	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
202	83	30640011	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
203	83	30640012	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
204	83	1032001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
205	83	1035001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
206	83	2027001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
207	83	2041001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
208	83	2050001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
209	83	3018001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
210	83	3029001	11000000.00	2020-06-11 00:00:00-04	2020-06-11	\N
211	83	3069001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
212	83	3071001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
\.


--
-- TOC entry 4292 (class 0 OID 53637)
-- Dependencies: 273
-- Data for Name: tabulador_aseo_residencial; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_aseo_residencial (id_tabulador_aseo_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	18000	2020-06-11 13:49:10.551481-04	2020-06-11	\N
\.


--
-- TOC entry 4294 (class 0 OID 53646)
-- Dependencies: 275
-- Data for Name: tabulador_gas; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas (id_tabulador_gas, id_actividad_economica, monto) FROM stdin;
\.


--
-- TOC entry 4295 (class 0 OID 53652)
-- Dependencies: 276
-- Data for Name: tabulador_gas_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas_actividad_economica (id_tabulador_gas_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	1002001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
2	83	1003001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
3	83	1004001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
4	83	2007001	4950000.00	2020-06-11 00:00:00-04	2020-06-11	\N
5	83	1005001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
6	83	1006001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
7	83	1007001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
8	83	1008001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
9	83	1009001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
10	83	1010001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
11	83	1011001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
12	83	1012001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
13	83	1013001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
14	83	1014001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
15	83	1015001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
16	83	1016001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
17	83	1017001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
18	83	1018001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
19	83	1019001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
20	83	1020001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
21	83	1021001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
22	83	1022001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
23	83	1023001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
24	83	1024001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
25	83	1025001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
26	83	1026001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
27	83	1027001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
28	83	1028001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
29	83	1029001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
30	83	1030001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
31	83	1031001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
32	83	1032001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
33	83	1033001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
34	83	1034001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
35	83	1035001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
36	83	1036001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
37	83	1037001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
38	83	1039001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
39	83	1040001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
40	83	1041001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
41	83	1042001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
42	83	1043001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
43	83	1044001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
44	83	1045001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
45	83	1046001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
46	83	1047001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
47	83	1048001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
48	83	2001001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
49	83	2002001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
50	83	2003001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
51	83	2004001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
52	83	2005001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
53	83	2006001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
54	83	2008001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
55	83	2009001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
56	83	2010001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
57	83	2011001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
58	83	2012001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
59	83	2014001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
60	83	2015001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
61	83	2016001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
62	83	2017001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
63	83	2018001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
64	83	2019001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
65	83	2020001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
66	83	2021001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
67	83	2022001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
68	83	2023001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
69	83	2024002	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
70	83	2025003	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
71	83	2026001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
72	83	2029001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
73	83	2028001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
74	83	2027001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
75	83	2030001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
76	83	2031001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
77	83	2032001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
78	83	2033001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
79	83	2034001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
80	83	2035001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
81	83	2036001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
82	83	2037001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
83	83	2038001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
84	83	2039001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
85	83	2040001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
86	83	2041001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
87	83	2042001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
88	83	2043002	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
89	83	2045001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
90	83	2046001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
91	83	2047001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
92	83	2048001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
93	83	2049002	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
94	83	2051001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
95	83	2052001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
96	83	2053001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
97	83	2054001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
98	83	2055001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
99	83	2056001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
100	83	2057001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
101	83	2058001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
102	83	2059001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
103	83	2060001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
104	83	2061001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
105	83	2062001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
106	83	2063001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
107	83	2064001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
108	83	2065001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
109	83	2066001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
110	83	2067001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
111	83	2068001	8800000.00	2020-06-11 00:00:00-04	2020-06-11	\N
112	83	2069002	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
113	83	2070003	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
114	83	2071001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
115	83	2072001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
116	83	3001001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
117	83	3002001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
118	83	3003002	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
119	83	2073001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
120	83	3004001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
121	83	3005001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
122	83	3006001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
123	83	3007001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
124	83	3009001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
125	83	3008001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
126	83	3010001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
127	83	3011001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
128	83	3012001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
129	83	3013001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
130	83	3014001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
131	83	3015001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
132	83	3016001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
133	83	3017002	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
134	83	3019002	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
135	83	3020001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
136	83	3021001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
137	83	3022001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
138	83	3023001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
139	83	3024001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
140	83	3025001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
141	83	3026001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
142	83	3027001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
143	83	3028001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
144	83	3029001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
145	83	3030002	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
146	83	3031001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
147	83	3032001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
148	83	3033002	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
149	83	3034001	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
150	83	3035001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
151	83	3036001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
152	83	3037001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
153	83	3038001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
154	83	3039001	4400000.00	2020-06-11 00:00:00-04	2020-06-11	\N
155	83	3040001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
156	83	3041001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
157	83	3042001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
158	83	3043001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
159	83	3044001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
160	83	3045002	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
161	83	3046001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
162	83	3047001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
163	83	3048001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
164	83	3050001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
165	83	3051001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
166	83	3052001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
167	83	3053002	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
168	83	3054001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
169	83	3055001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
170	83	3056001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
171	83	3057001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
172	83	3058001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
173	83	3059001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
174	83	3060001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
175	83	3061001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
176	83	3062001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
177	83	3063001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
178	83	3064001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
179	83	3065001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
180	83	3067001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
181	83	3068001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
182	83	3069001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
183	83	3070001	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
184	83	3071001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
185	83	3072002	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
186	83	3073001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
187	83	3074001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
188	83	3075001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
189	83	3076001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
190	83	3077001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
191	83	3078001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
192	83	3079001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
193	83	3080001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
194	83	3081001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
195	83	3082001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
196	83	3083001	2640000.00	2020-06-11 00:00:00-04	2020-06-11	\N
197	83	20230011	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
198	83	20230012	6600000.00	2020-06-11 00:00:00-04	2020-06-11	\N
199	83	20230013	7700000.00	2020-06-11 00:00:00-04	2020-06-11	\N
200	83	20270011	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
201	83	20270012	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
202	83	30240011	1100000.00	2020-06-11 00:00:00-04	2020-06-11	\N
203	83	30240012	1650000.00	2020-06-11 00:00:00-04	2020-06-11	\N
204	83	30640011	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
205	83	30640012	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
206	83	1038001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
207	83	2013001	5500000.00	2020-06-11 00:00:00-04	2020-06-11	\N
208	83	2044001	3300000.00	2020-06-11 00:00:00-04	2020-06-11	\N
209	83	2050001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
210	83	3018001	2750000.00	2020-06-11 00:00:00-04	2020-06-11	\N
211	83	3049001	2200000.00	2020-06-11 00:00:00-04	2020-06-11	\N
212	83	3066001	3850000.00	2020-06-11 00:00:00-04	2020-06-11	\N
\.


--
-- TOC entry 4298 (class 0 OID 53663)
-- Dependencies: 279
-- Data for Name: tabulador_gas_residencial; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas_residencial (id_tabulador_gas_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
1	83	7000	2020-06-11 13:48:49.040513-04	2020-06-11	\N
\.


--
-- TOC entry 4300 (class 0 OID 53672)
-- Dependencies: 281
-- Data for Name: tipo_aviso_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: postgres
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
-- TOC entry 4302 (class 0 OID 53681)
-- Dependencies: 283
-- Data for Name: tipo_multa; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tipo_multa (id_tipo_multa, descripcion) FROM stdin;
1	Multa por Declaracion Tardia
\.


--
-- TOC entry 4304 (class 0 OID 53689)
-- Dependencies: 285
-- Data for Name: usuario_enlazado; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.usuario_enlazado (id_usuario_enlazado, id_contribuyente, email) FROM stdin;
\.


--
-- TOC entry 4306 (class 0 OID 53697)
-- Dependencies: 287
-- Data for Name: verificacion_email; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.verificacion_email (id_verificacion_email, id_registro_municipal, codigo_recuperacion, fecha_recuperacion, verificado) FROM stdin;
\.


--
-- TOC entry 4308 (class 0 OID 53707)
-- Dependencies: 289
-- Data for Name: verificacion_telefono; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.verificacion_telefono (id_verificacion_telefono, codigo_verificacion, fecha_verificacion, verificado, id_usuario, telefono) FROM stdin;
78	119783	2020-06-26 00:25:19.786699-04	t	118	4147212344124
81	254200	2020-06-26 16:37:44.916513-04	t	58	4129661659
82	638501	2020-06-26 19:01:55.167478-04	t	120	4129661659
83	062801	2020-06-26 19:04:24.049606-04	t	121	4129661659
84	310569	2020-06-26 19:14:02.661491-04	t	122	4129661659
85	505131	2020-06-27 12:30:31.169715-04	t	124	4129661659
86	664885	2020-07-01 15:52:21.927678-04	t	125	4078376304
\.


--
-- TOC entry 4310 (class 0 OID 53717)
-- Dependencies: 291
-- Data for Name: banco; Type: TABLE DATA; Schema: public; Owner: postgres
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
21	Banco Occidental De Descuento.	f
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
-- TOC entry 4312 (class 0 OID 53726)
-- Dependencies: 293
-- Data for Name: campo; Type: TABLE DATA; Schema: public; Owner: postgres
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
\.


--
-- TOC entry 4313 (class 0 OID 53732)
-- Dependencies: 294
-- Data for Name: campo_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
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
92	28	1	enproceso	28
\.


--
-- TOC entry 4315 (class 0 OID 53741)
-- Dependencies: 296
-- Data for Name: cargo; Type: TABLE DATA; Schema: public; Owner: postgres
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
\.


--
-- TOC entry 4233 (class 0 OID 53329)
-- Dependencies: 207
-- Data for Name: caso_social; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.caso_social (id_caso, id_tipo_tramite, costo, datos, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla) FROM stdin;
2	0	\N	{"nombreCompleto":"Funcionario SAGAS","cedula":"1231231231","fechaNacimiento":"2020-04-02T00:33:42.930Z","edad":"1","nacionalidad":"asdasd","sexo":"true","poblacionIndigena":true,"etnia":"wayuu","profesion":"asdasd","oficio":"asdasd","estadoCivil":"casado","nivelInstruccion":"analfabeto","discapacidad":false,"condicionLaboral":"publico","empleadoAlcaldia":false,"asignacionesEconomicas":"ivss","razonDeSolicitud":"asd","patologiaActual":"asd","areaDeSalud":"traumatologia","direccion":"asdasdasd","parroquia":"CACIQUE MARA","telefono":"1231231231","email":"gab_tata_tc@hotmail.com","tipoAyuda":"electrodomesticos","tipoAyudaDesc":"asdasd","referidoPor":"despacho","isMenor":false,"nacionalidadSolicitante":"V","nacionalidadMenor":"V","nacionalidadBeneficiario":"V","solicitante":{"nombreCompleto":"asdasd","cedula":"1241214215","direccion":"asdasda"},"liderDeCalle":{"nombreCompleto":"asd","telefono":"21412412414"}}	2020-04-02 20:34:14.992725-04	ABMM-09042020-0-0001	1	66	\N
\.


--
-- TOC entry 4318 (class 0 OID 53751)
-- Dependencies: 299
-- Data for Name: certificado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificado (id_certificado, id_tramite, url_certificado) FROM stdin;
\.


--
-- TOC entry 4320 (class 0 OID 53759)
-- Dependencies: 301
-- Data for Name: cuenta_funcionario; Type: TABLE DATA; Schema: public; Owner: postgres
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
\.


--
-- TOC entry 4321 (class 0 OID 53762)
-- Dependencies: 302
-- Data for Name: datos_facebook; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_facebook (id_usuario, id_facebook) FROM stdin;
\.


--
-- TOC entry 4322 (class 0 OID 53768)
-- Dependencies: 303
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
118	108908642016425978799
119	107580273557060296119
120	108579339148659696569
121	116640733044552872609
122	107391274271360553386
\.


--
-- TOC entry 4323 (class 0 OID 53774)
-- Dependencies: 304
-- Data for Name: detalle_factura; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_factura (id_detalle, id_factura, nombre, costo) FROM stdin;
\.


--
-- TOC entry 4234 (class 0 OID 53336)
-- Dependencies: 208
-- Data for Name: evento_caso_social; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_caso_social (id_evento_caso, id_caso, event, "time") FROM stdin;
2	2	iniciar	2020-04-02 20:34:14.992725-04
\.


--
-- TOC entry 4238 (class 0 OID 53372)
-- Dependencies: 213
-- Data for Name: evento_multa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_multa (id_evento_multa, id_multa, event, "time") FROM stdin;
\.


--
-- TOC entry 4240 (class 0 OID 53397)
-- Dependencies: 216
-- Data for Name: evento_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
668	298	iniciar	2020-06-26 18:49:43.696424-04
669	298	procesar_rc	2020-06-26 18:49:43.696424-04
670	298	aprobar_rc	2020-06-26 19:51:45.215522-04
671	299	iniciar	2020-07-01 15:57:12.02261-04
672	299	revisar_bc	2020-07-01 15:57:12.02261-04
673	299	aprobar_bc	2020-07-01 16:20:14.353543-04
\.


--
-- TOC entry 4328 (class 0 OID 53788)
-- Dependencies: 309
-- Data for Name: factura_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.factura_tramite (id_factura, id_tramite) FROM stdin;
\.


--
-- TOC entry 4330 (class 0 OID 53793)
-- Dependencies: 311
-- Data for Name: inmueble_urbano; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, fecha_ultimo_avaluo, tipo_inmueble, id_registro_municipal) FROM stdin;
21	231315U01004083001001P0500	Calle 73 entre Av. 3E y 3F	108	200	300	2020-03-20 16:46:01.230084-04	2020-03-20 16:46:01.230084-04	\N	\N	\N
336	\N		\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	COMERCIAL	18
337	\N		\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	COMERCIAL	19
338	\N		\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	COMERCIAL	20
339	\N	Parroquia MANUEL DAGNINO Sector   Avenida   Calle  , Local Nro.  , Pto de Ref.	\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	COMERCIAL	21
340	\N	Parroquia CHIQUINQUIRA Sector 5 DE JULIO BFERCON Avenida   Calle  , Local Nro.  , Pto de Ref.	\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	RESIDENCIAL	22
341	\N	Parroquia CHIQUINQUIRA Sector 5 DE JULIO Avenida 16 Calle 77, Local Nro. bfercom, Pto de Ref. al lado de la torre bod	\N	\N	\N	2020-06-26 16:37:44.78505-04	2020-06-26 16:37:44.78505-04	\N	COMERCIAL	22
342	\N	Parroquia CHIQUINQUIRA Sector  INDIO MARA Avenida  65 Calle  22A, Local Nro.  MZN, Pto de Ref.   EDIF. IPSFA	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	COMERCIAL	23
343	\N	Parroquia OLEGARIO VILLALOBOS Sector SCT   BELLA VISTA(OLEGARIO V) AVENIDA 4 BELLA VISTA 1684520 LOCAL 67-13 LOCAL EDF. BLITZ 67-13   FTE. CHURRASCO BAR-GRILL MBO Maracaibo ZUL Avenida 4 Calle 0, Apartamento Nro. 67-13, Pto de Ref. 0	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	RESIDENCIAL	24
344	\N	Parroquia CHIQUINQUIRA Sector INDIO MARA Avenida 22A Calle 65, Local Nro. MZN., Pto de Ref. EDIF. IPSFA	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	COMERCIAL	24
345	\N	Parroquia CHIQUINQUIRA Sector - Avenida - Calle -, Local Nro. -, Pto de Ref. -	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	COMERCIAL	25
346	\N		\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	COMERCIAL	26
347	\N	Parroquia CHIQUINQUIRA Sector SCT   PARAISO AVENIDA 22 1674040   PB PB LDO. CUARTEL LIBERTADOR MBO Maracaibo ZUL Avenida 22A Calle 65, Local Nro. P A, Pto de Ref. IPFA	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	RESIDENCIAL	27
348	\N	Parroquia OLEGARIO VILLALOBOS Sector INDIO MARA Avenida 22A Calle 65, Local Nro. 3, Pto de Ref. IPFA	\N	\N	\N	2020-06-26 19:14:02.414925-04	2020-06-26 19:14:02.414925-04	\N	COMERCIAL	27
349	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida 15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-06-26 20:39:26.883557-04	2020-06-26 20:39:26.883557-04	\N	RESIDENCIAL	28
350	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida  15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-06-26 20:39:26.883557-04	2020-06-26 20:39:26.883557-04	\N	COMERCIAL	28
351	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS Avenida 15 Y 14A-74 Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO	\N	\N	\N	2020-06-26 20:39:26.883557-04	2020-06-26 20:39:26.883557-04	\N	RESIDENCIAL	29
352	\N	Parroquia OLEGARIO VILLALOBOS Sector DELICIAS  Avenida 14A Y 15 DELICIAS Calle 74, Local Nro. 7, Pto de Ref. 5 DE JULIO CON DELICIAS	\N	\N	\N	2020-06-26 20:39:26.883557-04	2020-06-26 20:39:26.883557-04	\N	COMERCIAL	29
353	\N	Parroquia IDELFONSO VASQUEZ Sector ZONA INDUSTRIAL NORTE AV. 16 ENTRE CALLE 23 Y 32 NO. 23-274, ANTES 15J-170 SEGÚN AVALUO DCE-2142-2018 Avenida 16 Calle 23 Y 32, Local Nro. 23-274, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	30
354	\N	Parroquia IDELFONSO VASQUEZ Sector ZONA INDUSTRIAL NORTE AV. 16 ENTRE CALLE 23 Y 32 NO. 23-274, SEGÚN AVALUO DCE-2142-2018 Avenida 16 Calle  23 Y 32, Local Nro. 3, Pto de Ref. FRENTE URB. MARA NORTE	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	COMERCIAL	30
355	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA IND. NORTE Avenida 16 Calle  , Galpon Nro. 5, Pto de Ref. FRT. URB. MARA NORTE	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	COMERCIAL	31
356	\N	Parroquia LUIS HURTADO HIGUERA Sector SCT ZONA INDUSTRIAL SUR AVENIDA 62 ENTRE CALLE 146 Y AV 66 # 146-308, 256-69,146-121, 147-131 y 146-308 LDO. TROQUEMAR MBO Maracaibo ZUL Avenida 62 Y 66 Calle  146 , Local Nro.  , Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
357	\N	Parroquia IDELFONSO VASQUEZ Sector ZONA NORTE Avenida 16 Calle  , Local Nro. 23-274, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
358	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA IND. NORTE    MBO MARACAIBO ZUL Avenida  16  Calle  , Galpon Nro.  23-274, Pto de Ref. FTE URB MARA NORTE	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
359	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL SUR AV 64 CALLE 146 NO 146-121 Avenida 66 Calle 146, Casa Nro. 146-121, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
360	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL SUR  Avenida 62 Calle 147 Y 148, Casa Nro. 147-267, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
361	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL SUR  Avenida 147 Y66 Calle 62, Casa Nro. 14-308, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
362	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL SUR  Avenida 62E Calle 147, Casa Nro. 147-131, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	32
363	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL  Avenida 62 Calle 147, Local Nro. 147-267, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	COMERCIAL	32
364	\N	Parroquia LUIS HURTADO HIGUERA Sector ZONA INDUSTRIAL Avenida 146-148 Calle 66, Local Nro. 146-774., Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	RESIDENCIAL	33
365	\N	Parroquia LUIS HURTADO HIGUERA Sector     Avenida     Calle    , Local Nro. 3, Pto de Ref.	\N	\N	\N	2020-06-26 20:59:40.771429-04	2020-06-26 20:59:40.771429-04	\N	COMERCIAL	33
366	\N		\N	\N	\N	2020-06-26 21:49:59.701231-04	2020-06-26 21:49:59.701231-04	\N	COMERCIAL	34
\.


--
-- TOC entry 4235 (class 0 OID 53343)
-- Dependencies: 209
-- Data for Name: institucion; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4333 (class 0 OID 53813)
-- Dependencies: 315
-- Data for Name: institucion_banco; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4239 (class 0 OID 53379)
-- Dependencies: 214
-- Data for Name: multa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.multa (id_multa, id_tipo_tramite, datos, costo, fecha_creacion, codigo_multa, consecutivo, id_usuario, cedula, nacionalidad, url_certificado, aprobado, url_boleta) FROM stdin;
\.


--
-- TOC entry 4276 (class 0 OID 53562)
-- Dependencies: 254
-- Data for Name: notificacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notificacion (id_notificacion, id_procedimiento, emisor, receptor, descripcion, status, fecha, estado, concepto) FROM stdin;
496	276	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 15:06:07.474372-04	enrevision	TRAMITE
498	277	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 16:22:46.388248-04	enproceso	TRAMITE
500	277	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 16:22:46.927251-04	enproceso	TRAMITE
503	277	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 16:28:50.980214-04	finalizado	TRAMITE
525	288	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 21:11:08.029396-04	enproceso	TRAMITE
505	278	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 17:18:19.430757-04	enproceso	TRAMITE
507	278	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 17:18:20.035799-04	enproceso	TRAMITE
527	289	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:19:50.96666-04	enproceso	TRAMITE
509	279	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 18:07:15.597688-04	validando	TRAMITE
528	289	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:19:51.212905-04	enproceso	TRAMITE
529	289	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:19:51.471895-04	enproceso	TRAMITE
532	289	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 21:22:23.405168-04	finalizado	TRAMITE
512	278	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 18:38:38.23326-04	finalizado	TRAMITE
497	276	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 15:06:07.748238-04	enrevision	TRAMITE
499	277	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 16:22:46.677223-04	enproceso	TRAMITE
504	277	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-25 16:28:51.220302-04	finalizado	TRAMITE
506	278	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 17:18:19.70664-04	enproceso	TRAMITE
510	279	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	t	2020-06-25 18:07:15.850543-04	validando	TRAMITE
513	278	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	t	2020-06-25 18:38:38.475195-04	finalizado	TRAMITE
515	279	V-1923812093	V-1	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 19:31:43.275252-04	enproceso	TRAMITE
518	279	V-1231931298	V-1	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 19:49:31.987536-04	finalizado	TRAMITE
519	279	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Solicitud de Licencia de Actividades Económicas	f	2020-06-25 19:49:32.283486-04	finalizado	TRAMITE
520	286	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 21:02:31.651442-04	validando	TRAMITE
521	286	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 21:02:31.96821-04	validando	TRAMITE
522	288	V-27139153	V-1	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 21:08:29.126954-04	validando	TRAMITE
523	288	V-27139153	V-1923812093	Un trámite de tipo Solicitud de Licencia de Actividades Económicas ha sido creado	f	2020-06-25 21:08:29.355076-04	validando	TRAMITE
533	289	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 21:22:23.405168-04	finalizado	TRAMITE
534	290	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:41:33.008194-04	enproceso	TRAMITE
535	290	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:41:33.273263-04	enproceso	TRAMITE
536	290	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:41:33.713198-04	enproceso	TRAMITE
538	291	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:47:33.281706-04	enproceso	TRAMITE
539	291	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:47:33.541611-04	enproceso	TRAMITE
540	291	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:47:33.802821-04	enproceso	TRAMITE
542	292	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:48:49.384157-04	enproceso	TRAMITE
543	292	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:48:49.670177-04	enproceso	TRAMITE
544	292	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:48:50.298102-04	enproceso	TRAMITE
526	288	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 21:11:08.270204-04	enproceso	TRAMITE
530	289	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:19:51.727124-04	enproceso	TRAMITE
501	277	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 16:22:47.502217-04	enproceso	TRAMITE
508	278	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 17:18:20.299545-04	enproceso	TRAMITE
516	279	V-1923812093	V-1231931298	Se ha validado el pago de un trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 19:31:43.886633-04	enproceso	TRAMITE
537	290	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:41:33.977149-04	enproceso	TRAMITE
546	293	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:51:23.483567-04	enproceso	TRAMITE
547	293	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:51:23.829598-04	enproceso	TRAMITE
548	293	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:51:24.089517-04	enproceso	TRAMITE
550	294	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:52:28.345188-04	enproceso	TRAMITE
551	294	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:52:28.677247-04	enproceso	TRAMITE
552	294	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:52:28.945246-04	enproceso	TRAMITE
554	295	V-27139153	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:58:00.633268-04	enproceso	TRAMITE
555	295	V-27139153	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:58:00.888885-04	enproceso	TRAMITE
556	295	V-27139153	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-25 21:58:01.144142-04	enproceso	TRAMITE
559	295	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 22:01:05.832879-04	finalizado	TRAMITE
560	295	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-25 22:01:05.832879-04	finalizado	TRAMITE
561	163	null-null	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 00:27:20.873159-04	ingresardatos	IMPUESTO
562	163	null-null	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 00:27:20.873159-04	ingresardatos	IMPUESTO
563	296	V-1231234444	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 02:44:52.231195-04	enrevision	TRAMITE
564	296	V-1231234444	V-1923812093	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 02:44:52.45134-04	enrevision	TRAMITE
565	297	V-1231234444	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 02:47:30.627123-04	enrevision	TRAMITE
566	297	V-1231234444	V-1923812093	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-06-26 02:47:30.877198-04	enrevision	TRAMITE
524	288	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 21:11:07.448367-04	enproceso	TRAMITE
567	165	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 13:03:36.969559-04	ingresardatos	IMPUESTO
568	165	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 13:03:36.969559-04	ingresardatos	IMPUESTO
569	165	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 13:42:35.852862-04	{"state":"validando"}	IMPUESTO
570	165	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 13:42:35.852862-04	{"state":"validando"}	IMPUESTO
571	170	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 14:51:56.606695-04	ingresardatos	IMPUESTO
572	170	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 14:51:56.606695-04	ingresardatos	IMPUESTO
573	170	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 14:52:17.922487-04	{"state":"validando"}	IMPUESTO
574	170	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 14:52:17.922487-04	{"state":"validando"}	IMPUESTO
575	171	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 14:58:24.718913-04	ingresardatos	IMPUESTO
576	171	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 14:58:24.718913-04	ingresardatos	IMPUESTO
577	171	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 14:58:38.993864-04	{"state":"validando"}	IMPUESTO
578	171	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 14:58:38.993864-04	{"state":"validando"}	IMPUESTO
579	173	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 16:41:34.670731-04	ingresardatos	IMPUESTO
580	173	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 16:41:34.670731-04	ingresardatos	IMPUESTO
581	173	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 18:42:37.350341-04	{"state":"validando"}	IMPUESTO
582	173	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-26 18:42:37.350341-04	{"state":"validando"}	IMPUESTO
583	174	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 18:45:58.363933-04	ingresardatos	IMPUESTO
584	174	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-26 18:45:58.363933-04	ingresardatos	IMPUESTO
585	298	null-null	V-1	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 18:49:43.793752-04	enproceso	TRAMITE
586	298	null-null	V-1923812093	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 18:49:43.796743-04	enproceso	TRAMITE
502	277	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 16:28:50.447402-04	finalizado	TRAMITE
587	298	null-null	V-1023910231	Un trámite de tipo Registro de Contribuyente ha sido creado	f	2020-06-26 18:49:43.799291-04	enproceso	TRAMITE
589	181	null-null	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 19:17:15.038059-04	ingresardatos	IMPUESTO
590	181	null-null	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-26 19:17:15.038059-04	ingresardatos	IMPUESTO
591	181	null-null	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 19:46:26.508527-04	{"state":"validando"}	IMPUESTO
592	181	null-null	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 19:46:26.508527-04	{"state":"validando"}	IMPUESTO
594	298	V-1231931298	V-1	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-26 19:51:45.261735-04	finalizado	TRAMITE
595	298	V-1231931298	V-1923812093	Se ha procesado un trámite de tipo Registro de Contribuyente	f	2020-06-26 19:51:45.261735-04	finalizado	TRAMITE
541	291	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:47:34.061785-04	enproceso	TRAMITE
545	292	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:48:50.587436-04	enproceso	TRAMITE
549	293	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:51:24.344544-04	enproceso	TRAMITE
553	294	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:52:29.211594-04	enproceso	TRAMITE
557	295	V-27139153	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-25 21:58:01.390835-04	enproceso	TRAMITE
588	298	null-null	V-1231931298	Un trámite de tipo Registro de Contribuyente ha sido creado	t	2020-06-26 18:49:43.802474-04	enproceso	TRAMITE
593	298	V-1231931298	V-18496685	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-26 19:51:45.261735-04	finalizado	TRAMITE
596	193	V-1231931298	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-06-26 21:36:27.634336-04	ingresardatos	IMPUESTO
597	193	V-1231931298	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-413060540	f	2020-06-26 21:36:27.634336-04	ingresardatos	IMPUESTO
598	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.85305-04	finalizado	IMPUESTO
599	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.85655-04	finalizado	IMPUESTO
600	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.859712-04	finalizado	IMPUESTO
601	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.862772-04	finalizado	IMPUESTO
602	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.865981-04	finalizado	IMPUESTO
603	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.868976-04	finalizado	IMPUESTO
604	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.872054-04	finalizado	IMPUESTO
605	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.875101-04	finalizado	IMPUESTO
606	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.878243-04	finalizado	IMPUESTO
607	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.881535-04	finalizado	IMPUESTO
608	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.885247-04	finalizado	IMPUESTO
609	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.888416-04	finalizado	IMPUESTO
610	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.891417-04	finalizado	IMPUESTO
611	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.89435-04	finalizado	IMPUESTO
612	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.897347-04	finalizado	IMPUESTO
613	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.900389-04	finalizado	IMPUESTO
614	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.903499-04	finalizado	IMPUESTO
615	181	V-1923812093	V-16079142	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.906495-04	finalizado	IMPUESTO
616	181	V-1923812093	V-1	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-26 23:57:30.959002-04	finalizado	IMPUESTO
617	198	V-27139153	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-27 00:18:41.828186-04	ingresardatos	IMPUESTO
618	198	V-27139153	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-06-27 00:18:41.828186-04	ingresardatos	IMPUESTO
619	198	V-27139153	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 00:18:59.615839-04	{"state":"validando"}	IMPUESTO
620	198	V-27139153	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 00:18:59.615839-04	{"state":"validando"}	IMPUESTO
621	174	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 00:30:50.849376-04	{"state":"validando"}	IMPUESTO
622	174	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 00:30:50.849376-04	{"state":"validando"}	IMPUESTO
650	198	V-1923812093	V-1	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	f	2020-06-27 00:44:05.051233-04	finalizado	IMPUESTO
531	289	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 21:22:23.405168-04	finalizado	TRAMITE
511	278	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 18:38:37.696548-04	finalizado	TRAMITE
514	279	V-1923812093	V-27139153	Se ha validado el pago de su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 19:31:41.883319-04	enproceso	TRAMITE
517	279	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Solicitud de Licencia de Actividades Económicas	t	2020-06-25 19:49:30.702372-04	finalizado	TRAMITE
558	295	V-1231931298	V-27139153	Se ha procesado su trámite de tipo Registro de Contribuyente	t	2020-06-25 22:01:05.832879-04	finalizado	TRAMITE
623	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.878816-04	finalizado	IMPUESTO
624	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.882827-04	finalizado	IMPUESTO
625	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.886166-04	finalizado	IMPUESTO
626	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.889366-04	finalizado	IMPUESTO
627	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.892688-04	finalizado	IMPUESTO
628	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.899163-04	finalizado	IMPUESTO
629	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.902389-04	finalizado	IMPUESTO
630	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.905627-04	finalizado	IMPUESTO
631	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.908885-04	finalizado	IMPUESTO
632	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.912126-04	finalizado	IMPUESTO
633	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.918123-04	finalizado	IMPUESTO
634	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.921334-04	finalizado	IMPUESTO
635	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.927119-04	finalizado	IMPUESTO
636	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.93176-04	finalizado	IMPUESTO
637	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.934951-04	finalizado	IMPUESTO
638	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.938292-04	finalizado	IMPUESTO
639	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.941518-04	finalizado	IMPUESTO
640	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.944752-04	finalizado	IMPUESTO
641	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.947877-04	finalizado	IMPUESTO
642	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.950765-04	finalizado	IMPUESTO
643	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.953861-04	finalizado	IMPUESTO
644	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.957173-04	finalizado	IMPUESTO
645	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.960366-04	finalizado	IMPUESTO
646	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.963419-04	finalizado	IMPUESTO
647	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.966536-04	finalizado	IMPUESTO
648	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.970117-04	finalizado	IMPUESTO
649	198	V-1923812093	V-27139153	Se ha finalizado una solicitud de pago de impuestos para el contribuyente: J-304689713	t	2020-06-27 00:44:04.973424-04	finalizado	IMPUESTO
651	199	V-10555777	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 12:36:18.328194-04	ingresardatos	IMPUESTO
652	199	V-10555777	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 12:36:18.328194-04	ingresardatos	IMPUESTO
653	199	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 12:50:27.693809-04	{"state":"validando"}	IMPUESTO
654	199	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-27 12:50:27.693809-04	{"state":"validando"}	IMPUESTO
655	200	V-1023910231	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 13:01:41.466493-04	ingresardatos	IMPUESTO
656	200	V-1023910231	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-308620483	f	2020-06-27 13:01:41.466493-04	ingresardatos	IMPUESTO
657	200	V-1023910231	V-1	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-30 08:58:42.910166-04	{"state":"validando"}	IMPUESTO
658	200	V-1023910231	V-1923812093	Se han ingresado los datos de pago de una solicitud de pago de impuestos para el contribuyente: J-308620483	f	2020-06-30 08:58:42.910166-04	{"state":"validando"}	IMPUESTO
659	202	V-2190823091	V-1	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-01 15:55:15.815913-04	ingresardatos	IMPUESTO
660	202	V-2190823091	V-1923812093	Se ha iniciado una solicitud para el contribuyente con el documento de identidad: J-304689713	f	2020-07-01 15:55:15.815913-04	ingresardatos	IMPUESTO
661	299	V-1923812093	V-1	Un trámite de tipo Beneficio de Contribuyente ha sido creado	f	2020-07-01 15:57:12.152887-04	enrevision	TRAMITE
662	299	V-1923812093	V-1	Se realizó la revisión de un trámite de tipo Beneficio de Contribuyente	f	2020-07-01 16:20:14.470068-04	finalizado	TRAMITE
\.


--
-- TOC entry 4338 (class 0 OID 53843)
-- Dependencies: 323
-- Data for Name: operacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.operacion (id_operacion, nombre_op) FROM stdin;
\.


--
-- TOC entry 4339 (class 0 OID 53850)
-- Dependencies: 324
-- Data for Name: operatividad_terminal; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4341 (class 0 OID 53861)
-- Dependencies: 326
-- Data for Name: ordenanza; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4342 (class 0 OID 53868)
-- Dependencies: 327
-- Data for Name: ordenanza_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ordenanza_tramite (id_ordenanza_tramite, id_tramite, id_tarifa, utmm, valor_calc, factor, factor_value, costo_ordenanza) FROM stdin;
\.


--
-- TOC entry 4346 (class 0 OID 53889)
-- Dependencies: 332
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pago (id_pago, id_procedimiento, referencia, monto, fecha_de_pago, aprobado, id_banco, fecha_de_aprobacion, concepto, metodo_pago) FROM stdin;
235	165	29688874	100000000	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA
236	165	40000587	76960210	2020-06-26	f	2	\N	IMPUESTO	TRANSFERENCIA
237	170	1	31231241241	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA
238	171	123	123124123123123	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA
239	173	29877744	100000000	2020-06-26	f	1	\N	IMPUESTO	TRANSFERENCIA
240	173	47000000	64660000	2020-06-26	f	2	\N	IMPUESTO	TRANSFERENCIA
241	181	123456	131225000	2020-06-26	t	1	2020-06-26 23:57:30.760909-04	IMPUESTO	TRANSFERENCIA
243	174	\N	0	2020-06-29	t	\N	2020-06-27 00:30:50.793404-04	IMPUESTO	EFECTIVO
242	198	123123	60000000	2020-06-29	t	1	2020-06-27 00:44:04.819951-04	IMPUESTO	TRANSFERENCIA
244	199	\N	87995999.999999999984	2020-06-29	f	\N	2020-06-27 12:50:27.55877-04	IMPUESTO	EFECTIVO
245	200	\N	123000000	2020-07-01	t	\N	2020-06-30 08:58:42.828701-04	IMPUESTO	EFECTIVO
246	200	87999	200000000	2020-07-01	t	4	2020-06-30 08:58:42.828701-04	IMPUESTO	TRANSFERENCIA
\.


--
-- TOC entry 4347 (class 0 OID 53900)
-- Dependencies: 333
-- Data for Name: pago_manual; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pago_manual (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- TOC entry 4332 (class 0 OID 53803)
-- Dependencies: 313
-- Data for Name: parroquia; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4350 (class 0 OID 53907)
-- Dependencies: 336
-- Data for Name: permiso_de_acceso; Type: TABLE DATA; Schema: public; Owner: postgres
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
\.


--
-- TOC entry 4352 (class 0 OID 53912)
-- Dependencies: 338
-- Data for Name: propietario; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4354 (class 0 OID 53920)
-- Dependencies: 340
-- Data for Name: propietario_inmueble; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietario_inmueble (id_propietario_inmueble, id_propietario, id_inmueble) FROM stdin;
9	17	21
\.


--
-- TOC entry 4356 (class 0 OID 53925)
-- Dependencies: 342
-- Data for Name: recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
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
68	Registro de Comercio	RegistroComercio	t	\N	.pdf
69	Contrato de Arrendamiento o Titulo de Propiedad segun la condición del inmueble	Contrato	t	\N	.pdf
71	Tres primeras facturas en blanco	Facturas	t	\N	.pdf
70	Constancia de Cumplimiento de Normas Técnicas emitido por el Cuerpo de Bomberos de Maracaibo	CCNT	t	\N	image/*
72	Fotocopia legible del RIF	RIF	t	\N	.pdf
\.


--
-- TOC entry 4358 (class 0 OID 53935)
-- Dependencies: 344
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
\.


--
-- TOC entry 4360 (class 0 OID 53944)
-- Dependencies: 346
-- Data for Name: seccion; Type: TABLE DATA; Schema: public; Owner: postgres
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
\.


--
-- TOC entry 4344 (class 0 OID 53876)
-- Dependencies: 329
-- Data for Name: tarifa_inspeccion; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4362 (class 0 OID 53952)
-- Dependencies: 348
-- Data for Name: template_certificado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.template_certificado (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- TOC entry 4236 (class 0 OID 53349)
-- Dependencies: 210
-- Data for Name: tipo_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, sufijo, nombre_corto, formato, planilla, certificado, utiliza_informacion_catastral, pago_previo, costo_utmm, planilla_rechazo) FROM stdin;
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
7	2	Constancia de Servicio Persona Juridica	12000000	pa	Servicio Persona Juridica	SAGAS-003	sagas-solt-CS	sagas-cert-CS	t	t	24	\N
6	2	Constancia de Servicio Residencial	3000000	pa	Servicio Residencial	SAGAS-002	sagas-solt-CS	sagas-cert-CS	t	t	6	\N
14	3	Codigo Catastral para Casas	3000000	cr	CC	CPU-OMCAT-001	cpu-solt-CCC	cpu-cert-CC	f	t	6	\N
15	3	Codigo Catastral para Apartamentos	3000000	cr	CC	CPU-OMCAT-001	cpu-solt-CCA	cpu-cert-CC	f	t	6	\N
2	1	Constancia de Habitabilidad	100000.0	pa	Habitabilidad	CBM-002	bomberos-solt	bomberos-cert-HAB	t	t	0.2	\N
1	1	Cumplimiento de Normas Tecnicas	100000.0	pa	Normas Tecnicas	CBM-001	bomberos-solt	bomberos-cert-CCNT	t	t	0.2	\N
16	3	Solvencia de Inmuebles Urbanos	3000000	cr	SIU	CPU-OMCAT-002	cpu-solt-SIU	cpu-cert-SIU	f	t	6	\N
18	5	Apartado de Bohío	2500000	pa	Apartado de Bohío	SEDEPAR-001	sedepar-solt-AB	sedepar-cert-AB	f	t	5	\N
22	3	Constancia de Nomenclatura	200000.0	cr	NM	CPU-OMCAT-003	cpu-solt-NM	cpu-cert-NM	f	t	0.4	\N
5	9	Pago de Impuestos	\N	pi	Pago de Impuestos	\N	\N	\N	f	f	\N	\N
26	9	Beneficio de Contribuyente	\N	bc	BC	\N	\N	\N	f	f	\N	\N
27	9	Registro de Contribuyente	\N	rc	Registro de Contribuyente	\N	\N	\N	f	f	\N	\N
28	9	Solicitud de Licencia de Actividades Económicas	1000000.0	lae	Licencia de Actividades Económicas	SEDEMAT-001	sedemat-solt-LAE	sedemat-cert-LAE	f	t	2	\N
\.


--
-- TOC entry 4364 (class 0 OID 53960)
-- Dependencies: 350
-- Data for Name: tipo_tramite_recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- TOC entry 4365 (class 0 OID 53963)
-- Dependencies: 351
-- Data for Name: tipo_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_usuario (id_tipo_usuario, descripcion) FROM stdin;
1	Superuser
2	Administrador
3	Funcionario
4	Usuario externo
5	Director
\.


--
-- TOC entry 4241 (class 0 OID 53404)
-- Dependencies: 217
-- Data for Name: tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramite (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla, url_certificado, aprobado, fecha_culminacion) FROM stdin;
298	27	{"usuario":{"documentoIdentidad":"400197520","razonSocial":"Wak Casa de Software CA","denominacionComercial":"Wak Casa de Software CA","siglas":"WAK","parroquia":"OLEGARIO VILLALOBOS","sector":"Tierra Negra","direccion":"Av 21 Calle 86","puntoReferencia":"Diagonal CDO","tipoContribuyente":"JURIDICO","tipoDocumento":"J","codCat":null},"funcionario":{"documentoIdentidad":"400197520","razonSocial":"Wak Casa de Software CA","denominacionComercial":"Wak Casa de Software CA","siglas":"WAK","parroquia":"OLEGARIO VILLALOBOS","sector":"Tierra Negra","direccion":"Av 21 Calle 86","puntoReferencia":"Diagonal CDO","tipoContribuyente":"JURIDICO","tipoDocumento":"V"}}	\N	2020-06-26 18:49:43.696424-04	SEDEMAT-26062020-27-0001	1	119	\N	\N	t	2020-06-26 19:51:45.215522-04
299	26	{"funcionario":{"beneficios":[{"idRamo":"8","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":163158578.15,"fechaDePago":"01-07-2020"},{"porcion":"2","monto":10000000,"fechaDePago":"01-07-2020"}]},{"idRamo":"9","tipoBeneficio":"pagoCompleto"},{"idRamo":"11","tipoBeneficio":"pagoCompleto"},{"idRamo":"29","tipoBeneficio":"convenio","porciones":[{"porcion":"1","monto":10000000,"fechaDePago":"02-07-2020"},{"porcion":"2","monto":5000000,"fechaDePago":"03-07-2020"}]},{"idRamo":"64","tipoBeneficio":"pagoCompleto"}],"contribuyente":{"id":57,"tipoDocumento":"J","documento":"304689713","registroMunicipal":"2900011265","razonSocial":"CORPORACION DIGITEL, C.A.","denomComercial":"CORPORACION GSM","sector":"","direccion":null,"puntoReferencia":"","verificado":true,"liquidaciones":[{"id":8,"ramo":"PROPIEDAD INMOBILIARIA","monto":"263158578.15"},{"id":9,"ramo":"ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES","monto":"38308422681.44"},{"id":11,"ramo":"PROPAGANDAS Y AVISOS COMERCIALES","monto":"22400000.00"},{"id":29,"ramo":"MULTAS","monto":"15000000.00"},{"id":64,"ramo":"SERVICIOS MUNICIPALES","monto":"20402432.70"}],"totalDeuda":38629383692.29}}}	\N	2020-07-01 15:57:12.02261-04	SEDEMAT-01072020-26-0001	1	83	\N	\N	t	2020-07-01 16:20:14.353543-04
\.


--
-- TOC entry 4368 (class 0 OID 53973)
-- Dependencies: 354
-- Data for Name: tramite_archivo_recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramite_archivo_recaudo (id_tramite, url_archivo_recaudo) FROM stdin;
298	https://sut-maracaibo.s3.us-east-2.amazonaws.com/SEDEMAT-26062020-27-0001/DocIdentidad.png
\.


--
-- TOC entry 4370 (class 0 OID 53986)
-- Dependencies: 357
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono, id_contribuyente) FROM stdin;
118	Jose Andres Sanchez	jsanchez.waku@gmail.com	asdasdasd	25848973	V	4	$2a$10$Rsw1oZfuB2.u3X410AGUYedDg9W3WW89DEvBMhLvd7HJfhNcIDcoa	1231241231	\N
116	Cajero SEDEMAT	cajero@sedemat.com	SEDEMAT	1023910231	V	3	$2a$10$EUnmYqbqHl6Aw2FoUYofmOebPprOKWkHFJY3OE2GthBQhwi4pSGvO	1092831209	\N
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
82	Funcionario INTCUMA	funcionario@intcuma.com	INTCUMA	1023102938	V	3	$2a$10$qVi/NuT7X1ELSfz5mpM8e.OrMKAuSqJLPQ4H45/SB/WiwUw2TkA2i	1829038123	\N
68	Funcionario CPU	funcionario@cpu.com	CPU	1283190247	V	3	$2a$10$qLVJeDD5mKiXlhrNQEJDtOX9baIZcjY3zwMmepViWXp.VENHwaOda	9271092741	\N
83	Admin SEDEMAT	admin@sedemat.com	SEDEMAT	1923812093	V	2	$2a$10$24HQ9feMqbPag1esm.IhIOkaAYcQlTKeKlTZlU8xg78bLqeQuCCMC	1902831092	\N
117	Funcionario SEDEMAT	funcionario@sedemat.com	daidajiwjfiieajdk	1231931298	V	3	$2a$10$fbutta0xyv6uPZEaOP/D8uTRFNOl1/3eZ61SpOmqFyLSmJl31NzWy	4243828238	\N
58	External User	external@user.com	Aqui	27139153	V	4	$2a$10$1az9AKXYIZ48FrTXXnb24.QT89PZuCTh2n0zabqVW7G8YyKinYNXe	4127645681	57
120	Rafael Lares	cedgob2020@gmail.com	Av 21 Calle 86	15592914	V	4	$2a$10$z5gRrl3ezE0Ksj/Q4.A2gevmo/llADCLtfjKdDEfwL2Jv9gIMOYq6	4129661659	57
121	Brian Maldonado	bhmadolnado@gmail.com	av 16	9747320	V	4	$2a$10$lnO3K4QhVgPft.9pqZBlt.M6mfASHTHX.Fqs./8xKgC7EPd8LZIfe	4129661659	57
122	Jhon Jose Romay	jhonjromy@gmail.com	av 21	16079142	V	4	$2a$10$RcZ6dQf5Tdi0wgcq2lH8a.VG4ab4z8nx68V1ZdRwE58MHBVU3y4t.	4129661659	58
119	Jhonnatan Romay	romayjj@gmail.com	Av 21 calle 86	18496685	V	4	$2a$10$Mfw/1FYYPxQOiXzfEM19wen5RTTychOjBke778b/kYKJYv2iXhCX.	4146053291	59
124	Raul Fuentes	jj5star@hotmail.com	av 21 calle 86	10555777	V	4	$2a$10$qCFDSaIdAEZi3dH4RLXT/uQk2qQ0IQOkmES2ycbXXKH2bkJNNBUSW	4146053291	58
125	digitel	impuestos_digitel@digitel.com.ve	lkasjdkasjkdja	2190823091	V	4	$2a$10$xhMAl1K0jjqQTy7QN6zFfej9..S/yEtLcgCQPMW6Jsi3en4azy0YO	1231412341	57
\.


--
-- TOC entry 4372 (class 0 OID 53995)
-- Dependencies: 359
-- Data for Name: valor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.valor (id_valor, descripcion, valor_en_bs) FROM stdin;
1	Bolivares	1
2	UTMM	500000
\.


--
-- TOC entry 4375 (class 0 OID 54005)
-- Dependencies: 362
-- Data for Name: variable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable (id_var, nombre_variable) FROM stdin;
\.


--
-- TOC entry 4377 (class 0 OID 54014)
-- Dependencies: 364
-- Data for Name: variable_de_costo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable_de_costo (id_variable_de_costo, id_tipo_tramite, id_operacion, precedencia, aumento) FROM stdin;
\.


--
-- TOC entry 4378 (class 0 OID 54021)
-- Dependencies: 365
-- Data for Name: variable_ordenanza; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable_ordenanza (id_variable, nombre, nombre_plural) FROM stdin;
1	Plano	Planos
2	Pre Inspección	Pre Inspecciones
4	Inspección	Inspecciones
3	Vivienda	Viviendas
5	Persona jurídica	Personas jurídicas
\.


--
-- TOC entry 4380 (class 0 OID 54029)
-- Dependencies: 367
-- Data for Name: base_task; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.base_task (task_id, name, kind, script) FROM stdin;
1	Fin de dia revisar pagos	SQL	SELECT revisar_pagos_fin_de_dia()
\.


--
-- TOC entry 4382 (class 0 OID 54039)
-- Dependencies: 369
-- Data for Name: chain_execution_config; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain_execution_config (chain_execution_config, chain_id, chain_name, run_at, max_instances, live, self_destruct, exclusive_execution, excluded_execution_configs, client_name) FROM stdin;
1	1	chain_1	1 1 1 1 *	\N	f	f	f	\N	\N
\.


--
-- TOC entry 4384 (class 0 OID 54050)
-- Dependencies: 371
-- Data for Name: chain_execution_parameters; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain_execution_parameters (chain_execution_config, chain_id, order_id, value) FROM stdin;
\.


--
-- TOC entry 4385 (class 0 OID 54057)
-- Dependencies: 372
-- Data for Name: database_connection; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.database_connection (database_connection, connect_string, comment) FROM stdin;
\.


--
-- TOC entry 4387 (class 0 OID 54065)
-- Dependencies: 374
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.execution_log (chain_execution_config, chain_id, task_id, name, script, kind, last_run, finished, returncode, pid) FROM stdin;
\.


--
-- TOC entry 4388 (class 0 OID 54072)
-- Dependencies: 375
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.log (id, ts, client_name, pid, log_level, message) FROM stdin;
\.


--
-- TOC entry 4390 (class 0 OID 54081)
-- Dependencies: 377
-- Data for Name: migrations; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.migrations (id, version) FROM stdin;
\.


--
-- TOC entry 4391 (class 0 OID 54087)
-- Dependencies: 378
-- Data for Name: run_status; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.run_status (run_status, start_status, execution_status, chain_id, current_execution_element, started, last_status_update, chain_execution_config) FROM stdin;
\.


--
-- TOC entry 4393 (class 0 OID 54093)
-- Dependencies: 380
-- Data for Name: task_chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.task_chain (chain_id, parent_id, task_id, run_uid, database_connection, ignore_error) FROM stdin;
1	\N	1	\N	\N	t
\.


--
-- TOC entry 4395 (class 0 OID 54102)
-- Dependencies: 382
-- Data for Name: ano; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
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
-- TOC entry 4397 (class 0 OID 54107)
-- Dependencies: 384
-- Data for Name: construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
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
-- TOC entry 4400 (class 0 OID 54122)
-- Dependencies: 388
-- Data for Name: sector; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
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
-- TOC entry 4401 (class 0 OID 54128)
-- Dependencies: 389
-- Data for Name: terreno; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
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
-- TOC entry 4399 (class 0 OID 54112)
-- Dependencies: 386
-- Data for Name: tipo_construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
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
-- TOC entry 4487 (class 0 OID 0)
-- Dependencies: 221
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq', 27, true);


--
-- TOC entry 4488 (class 0 OID 0)
-- Dependencies: 223
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq', 1, true);


--
-- TOC entry 4489 (class 0 OID 0)
-- Dependencies: 224
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_id_actividad_economica_seq', 220, true);


--
-- TOC entry 4490 (class 0 OID 0)
-- Dependencies: 226
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq', 117, true);


--
-- TOC entry 4491 (class 0 OID 0)
-- Dependencies: 228
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.categoria_propaganda_id_categoria_propaganda_seq', 1, false);


--
-- TOC entry 4492 (class 0 OID 0)
-- Dependencies: 231
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq', 11, true);


--
-- TOC entry 4493 (class 0 OID 0)
-- Dependencies: 232
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.contribuyente_id_contribuyente_seq', 63, true);


--
-- TOC entry 4494 (class 0 OID 0)
-- Dependencies: 234
-- Name: convenio_id_convenio_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.convenio_id_convenio_seq', 32, true);


--
-- TOC entry 4495 (class 0 OID 0)
-- Dependencies: 236
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.credito_fiscal_id_credito_fiscal_seq', 1, false);


--
-- TOC entry 4496 (class 0 OID 0)
-- Dependencies: 238
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.dias_feriados_id_dia_feriado_seq', 47, true);


--
-- TOC entry 4497 (class 0 OID 0)
-- Dependencies: 240
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.evento_fraccion_id_evento_fraccion_seq', 12, true);


--
-- TOC entry 4498 (class 0 OID 0)
-- Dependencies: 242
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.evento_solicitud_id_evento_solicitud_seq', 451, true);


--
-- TOC entry 4499 (class 0 OID 0)
-- Dependencies: 244
-- Name: factor_id_factor_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.factor_id_factor_seq', 1, false);


--
-- TOC entry 4500 (class 0 OID 0)
-- Dependencies: 245
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.fraccion_id_fraccion_seq', 9, true);


--
-- TOC entry 4501 (class 0 OID 0)
-- Dependencies: 248
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq', 1, false);


--
-- TOC entry 4502 (class 0 OID 0)
-- Dependencies: 250
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq', 1, false);


--
-- TOC entry 4503 (class 0 OID 0)
-- Dependencies: 251
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.liquidacion_id_liquidacion_seq', 877, true);


--
-- TOC entry 4504 (class 0 OID 0)
-- Dependencies: 253
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.multa_id_multa_seq', 33, true);


--
-- TOC entry 4505 (class 0 OID 0)
-- Dependencies: 257
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq', 23, true);


--
-- TOC entry 4506 (class 0 OID 0)
-- Dependencies: 259
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq', 1, true);


--
-- TOC entry 4507 (class 0 OID 0)
-- Dependencies: 261
-- Name: ramo_id_ramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.ramo_id_ramo_seq', 1, true);


--
-- TOC entry 4508 (class 0 OID 0)
-- Dependencies: 264
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.registro_municipal_id_registro_municipal_seq', 34, true);


--
-- TOC entry 4509 (class 0 OID 0)
-- Dependencies: 262
-- Name: registro_municipal_referencia_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.registro_municipal_referencia_municipal_seq', 8000000003, true);


--
-- TOC entry 4510 (class 0 OID 0)
-- Dependencies: 266
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.solicitud_id_solicitud_seq', 282, true);


--
-- TOC entry 4511 (class 0 OID 0)
-- Dependencies: 270
-- Name: subramo_id_subramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.subramo_id_subramo_seq', 102, true);


--
-- TOC entry 4512 (class 0 OID 0)
-- Dependencies: 272
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq', 212, true);


--
-- TOC entry 4513 (class 0 OID 0)
-- Dependencies: 274
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq', 1, true);


--
-- TOC entry 4514 (class 0 OID 0)
-- Dependencies: 277
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq', 212, true);


--
-- TOC entry 4515 (class 0 OID 0)
-- Dependencies: 278
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_id_tabulador_gas_seq', 1, false);


--
-- TOC entry 4516 (class 0 OID 0)
-- Dependencies: 280
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq', 1, true);


--
-- TOC entry 4517 (class 0 OID 0)
-- Dependencies: 282
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq', 1, false);


--
-- TOC entry 4518 (class 0 OID 0)
-- Dependencies: 284
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tipo_multa_id_tipo_multa_seq', 1, true);


--
-- TOC entry 4519 (class 0 OID 0)
-- Dependencies: 286
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.usuario_enlazado_id_usuario_enlazado_seq', 1, false);


--
-- TOC entry 4520 (class 0 OID 0)
-- Dependencies: 288
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.verificacion_email_id_verificacion_email_seq', 5, true);


--
-- TOC entry 4521 (class 0 OID 0)
-- Dependencies: 290
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.verificacion_telefono_id_verificacion_telefono_seq', 86, true);


--
-- TOC entry 4522 (class 0 OID 0)
-- Dependencies: 292
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 36, true);


--
-- TOC entry 4523 (class 0 OID 0)
-- Dependencies: 295
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 13, true);


--
-- TOC entry 4524 (class 0 OID 0)
-- Dependencies: 297
-- Name: cargo_id_cargo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cargo_id_cargo_seq', 21, true);


--
-- TOC entry 4525 (class 0 OID 0)
-- Dependencies: 298
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.casos_sociales_id_caso_seq', 2, true);


--
-- TOC entry 4526 (class 0 OID 0)
-- Dependencies: 300
-- Name: certificados_id_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificados_id_certificado_seq', 1, false);


--
-- TOC entry 4527 (class 0 OID 0)
-- Dependencies: 305
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalles_facturas_id_detalle_seq', 1, false);


--
-- TOC entry 4528 (class 0 OID 0)
-- Dependencies: 306
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.evento_multa_id_evento_multa_seq', 41, true);


--
-- TOC entry 4529 (class 0 OID 0)
-- Dependencies: 307
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_casos_sociales_id_evento_caso_seq', 2, true);


--
-- TOC entry 4530 (class 0 OID 0)
-- Dependencies: 308
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 673, true);


--
-- TOC entry 4531 (class 0 OID 0)
-- Dependencies: 310
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, false);


--
-- TOC entry 4532 (class 0 OID 0)
-- Dependencies: 312
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inmueble_urbano_id_inmueble_seq', 366, true);


--
-- TOC entry 4533 (class 0 OID 0)
-- Dependencies: 316
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- TOC entry 4534 (class 0 OID 0)
-- Dependencies: 317
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.multa_id_multa_seq', 14, true);


--
-- TOC entry 4535 (class 0 OID 0)
-- Dependencies: 321
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 662, true);


--
-- TOC entry 4536 (class 0 OID 0)
-- Dependencies: 322
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);


--
-- TOC entry 4537 (class 0 OID 0)
-- Dependencies: 325
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.operatividad_terminal_id_operatividad_terminal_seq', 77, true);


--
-- TOC entry 4538 (class 0 OID 0)
-- Dependencies: 328
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ordenanzas_id_ordenanza_seq', 57, true);


--
-- TOC entry 4539 (class 0 OID 0)
-- Dependencies: 331
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ordenanzas_tramites_id_ordenanza_tramite_seq', 15, true);


--
-- TOC entry 4540 (class 0 OID 0)
-- Dependencies: 334
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 246, true);


--
-- TOC entry 4541 (class 0 OID 0)
-- Dependencies: 335
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 1, false);


--
-- TOC entry 4542 (class 0 OID 0)
-- Dependencies: 337
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permiso_de_acceso_id_permiso_seq', 39, true);


--
-- TOC entry 4543 (class 0 OID 0)
-- Dependencies: 339
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 18, true);


--
-- TOC entry 4544 (class 0 OID 0)
-- Dependencies: 341
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietarios_inmuebles_id_propietario_inmueble_seq', 10, true);


--
-- TOC entry 4545 (class 0 OID 0)
-- Dependencies: 343
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, true);


--
-- TOC entry 4546 (class 0 OID 0)
-- Dependencies: 345
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 1, false);


--
-- TOC entry 4547 (class 0 OID 0)
-- Dependencies: 347
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tarifas_inspeccion_id_tarifa_seq', 57, true);


--
-- TOC entry 4548 (class 0 OID 0)
-- Dependencies: 349
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_certificados_id_template_certificado_seq', 1, false);


--
-- TOC entry 4549 (class 0 OID 0)
-- Dependencies: 352
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 28, true);


--
-- TOC entry 4550 (class 0 OID 0)
-- Dependencies: 353
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- TOC entry 4551 (class 0 OID 0)
-- Dependencies: 355
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 299, true);


--
-- TOC entry 4552 (class 0 OID 0)
-- Dependencies: 358
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 125, true);


--
-- TOC entry 4553 (class 0 OID 0)
-- Dependencies: 360
-- Name: valores_id_valor_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.valores_id_valor_seq', 2, true);


--
-- TOC entry 4554 (class 0 OID 0)
-- Dependencies: 363
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- TOC entry 4555 (class 0 OID 0)
-- Dependencies: 361
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- TOC entry 4556 (class 0 OID 0)
-- Dependencies: 366
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_ordenanzas_id_variable_seq', 5, true);


--
-- TOC entry 4557 (class 0 OID 0)
-- Dependencies: 368
-- Name: base_task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.base_task_task_id_seq', 1, true);


--
-- TOC entry 4558 (class 0 OID 0)
-- Dependencies: 370
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.chain_execution_config_chain_execution_config_seq', 1, true);


--
-- TOC entry 4559 (class 0 OID 0)
-- Dependencies: 373
-- Name: database_connection_database_connection_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.database_connection_database_connection_seq', 1, false);


--
-- TOC entry 4560 (class 0 OID 0)
-- Dependencies: 376
-- Name: log_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.log_id_seq', 1, false);


--
-- TOC entry 4561 (class 0 OID 0)
-- Dependencies: 379
-- Name: run_status_run_status_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.run_status_run_status_seq', 1, false);


--
-- TOC entry 4562 (class 0 OID 0)
-- Dependencies: 381
-- Name: task_chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.task_chain_chain_id_seq', 1, true);


--
-- TOC entry 4563 (class 0 OID 0)
-- Dependencies: 383
-- Name: ano_fiscal_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.ano_fiscal_id_seq', 6, true);


--
-- TOC entry 4564 (class 0 OID 0)
-- Dependencies: 385
-- Name: construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.construccion_id_seq', 305, true);


--
-- TOC entry 4565 (class 0 OID 0)
-- Dependencies: 391
-- Name: sector_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.sector_id_seq', 220, true);


--
-- TOC entry 4566 (class 0 OID 0)
-- Dependencies: 392
-- Name: terreno_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.terreno_id_seq', 1315, true);


--
-- TOC entry 4567 (class 0 OID 0)
-- Dependencies: 393
-- Name: tipo_construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.tipo_construccion_id_seq', 50, true);


--
-- TOC entry 3818 (class 2606 OID 54219)
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_pkey PRIMARY KEY (id_actividad_economica_contribuyente);


--
-- TOC entry 3820 (class 2606 OID 54221)
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_pkey PRIMARY KEY (id_actividad_economica_exoneracion);


--
-- TOC entry 3814 (class 2606 OID 54223)
-- Name: actividad_economica actividad_economica_numero_referencia_key; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_numero_referencia_key UNIQUE (numero_referencia);


--
-- TOC entry 3816 (class 2606 OID 54225)
-- Name: actividad_economica actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_pkey PRIMARY KEY (id_actividad_economica);


--
-- TOC entry 3822 (class 2606 OID 54227)
-- Name: avaluo_inmueble avaluo_inmueble_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_pkey PRIMARY KEY (id_avaluo_inmueble);


--
-- TOC entry 3824 (class 2606 OID 54229)
-- Name: categoria_propaganda categoria_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.categoria_propaganda
    ADD CONSTRAINT categoria_propaganda_pkey PRIMARY KEY (id_categoria_propaganda);


--
-- TOC entry 3830 (class 2606 OID 54231)
-- Name: contribuyente_exoneracion contribuyente_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_pkey PRIMARY KEY (id_contribuyente_exoneracion);


--
-- TOC entry 3826 (class 2606 OID 54233)
-- Name: contribuyente contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_pkey PRIMARY KEY (id_contribuyente);


--
-- TOC entry 3828 (class 2606 OID 54235)
-- Name: contribuyente contribuyente_tipo_documento_documento_key; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_tipo_documento_documento_key UNIQUE (tipo_documento, documento);


--
-- TOC entry 3832 (class 2606 OID 54237)
-- Name: convenio convenio_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_pkey PRIMARY KEY (id_convenio);


--
-- TOC entry 3834 (class 2606 OID 54239)
-- Name: credito_fiscal credito_fiscal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.credito_fiscal
    ADD CONSTRAINT credito_fiscal_pkey PRIMARY KEY (id_credito_fiscal);


--
-- TOC entry 3836 (class 2606 OID 54241)
-- Name: dias_feriados dias_feriados_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.dias_feriados
    ADD CONSTRAINT dias_feriados_pkey PRIMARY KEY (id_dia_feriado);


--
-- TOC entry 3838 (class 2606 OID 54243)
-- Name: evento_fraccion evento_fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_pkey PRIMARY KEY (id_evento_fraccion);


--
-- TOC entry 3840 (class 2606 OID 54245)
-- Name: evento_solicitud evento_solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_pkey PRIMARY KEY (id_evento_solicitud);


--
-- TOC entry 3842 (class 2606 OID 54247)
-- Name: factor factor_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.factor
    ADD CONSTRAINT factor_pkey PRIMARY KEY (id_factor);


--
-- TOC entry 3794 (class 2606 OID 54249)
-- Name: fraccion fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_pkey PRIMARY KEY (id_fraccion);


--
-- TOC entry 3844 (class 2606 OID 54251)
-- Name: liquidacion_descuento liquidacion_descuento_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_pkey PRIMARY KEY (id_liquidacion_descuento);


--
-- TOC entry 3804 (class 2606 OID 54253)
-- Name: liquidacion liquidacion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_pkey PRIMARY KEY (id_liquidacion);


--
-- TOC entry 3846 (class 2606 OID 54255)
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- TOC entry 3850 (class 2606 OID 54257)
-- Name: plazo_exoneracion plazo_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.plazo_exoneracion
    ADD CONSTRAINT plazo_exoneracion_pkey PRIMARY KEY (id_plazo_exoneracion);


--
-- TOC entry 3852 (class 2606 OID 54259)
-- Name: ramo_exoneracion procedimiento_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_pkey PRIMARY KEY (id_ramo_exoneracion);


--
-- TOC entry 3854 (class 2606 OID 54261)
-- Name: ramo ramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo
    ADD CONSTRAINT ramo_pkey PRIMARY KEY (id_ramo);


--
-- TOC entry 3856 (class 2606 OID 54263)
-- Name: registro_municipal registro_municipal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_pkey PRIMARY KEY (id_registro_municipal);


--
-- TOC entry 3796 (class 2606 OID 54265)
-- Name: solicitud solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_pkey PRIMARY KEY (id_solicitud);


--
-- TOC entry 3858 (class 2606 OID 54267)
-- Name: subramo subramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_pkey PRIMARY KEY (id_subramo);


--
-- TOC entry 3860 (class 2606 OID 54269)
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_pkey PRIMARY KEY (id_tabulador_aseo_actividad_economica);


--
-- TOC entry 3862 (class 2606 OID 54271)
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_pkey PRIMARY KEY (id_tabulador_aseo_residencial);


--
-- TOC entry 3866 (class 2606 OID 54273)
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_pkey PRIMARY KEY (id_tabulador_gas_actividad_economica);


--
-- TOC entry 3864 (class 2606 OID 54275)
-- Name: tabulador_gas tabulador_gas_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_pkey PRIMARY KEY (id_tabulador_gas);


--
-- TOC entry 3868 (class 2606 OID 54277)
-- Name: tabulador_gas_residencial tabulador_gas_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_pkey PRIMARY KEY (id_tabulador_gas_residencial);


--
-- TOC entry 3870 (class 2606 OID 54279)
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_pkey PRIMARY KEY (id_tipo_aviso_propaganda);


--
-- TOC entry 3872 (class 2606 OID 54281)
-- Name: tipo_multa tipo_multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_multa
    ADD CONSTRAINT tipo_multa_pkey PRIMARY KEY (id_tipo_multa);


--
-- TOC entry 3874 (class 2606 OID 54283)
-- Name: usuario_enlazado usuario_enlazado_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_pkey PRIMARY KEY (id_usuario_enlazado);


--
-- TOC entry 3876 (class 2606 OID 54285)
-- Name: verificacion_email verificacion_email_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_pkey PRIMARY KEY (id_verificacion_email);


--
-- TOC entry 3878 (class 2606 OID 54287)
-- Name: verificacion_telefono verificacion_telefono_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_pkey PRIMARY KEY (id_verificacion_telefono);


--
-- TOC entry 3880 (class 2606 OID 54289)
-- Name: banco bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banco
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- TOC entry 3882 (class 2606 OID 54291)
-- Name: campo campos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- TOC entry 3884 (class 2606 OID 54293)
-- Name: cargo cargo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_pkey PRIMARY KEY (id_cargo);


--
-- TOC entry 3798 (class 2606 OID 54295)
-- Name: caso_social casos_sociales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_pkey PRIMARY KEY (id_caso);


--
-- TOC entry 3886 (class 2606 OID 54297)
-- Name: certificado certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id_certificado);


--
-- TOC entry 3888 (class 2606 OID 54299)
-- Name: cuenta_funcionario cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 3890 (class 2606 OID 54301)
-- Name: datos_google datos_google_id_google_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);


--
-- TOC entry 3892 (class 2606 OID 54303)
-- Name: datos_google datos_google_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);


--
-- TOC entry 3806 (class 2606 OID 54305)
-- Name: evento_multa evento_multa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_pkey PRIMARY KEY (id_evento_multa);


--
-- TOC entry 3810 (class 2606 OID 54307)
-- Name: evento_tramite eventos_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_pkey PRIMARY KEY (id_evento_tramite);


--
-- TOC entry 3894 (class 2606 OID 54309)
-- Name: factura_tramite facturas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_pkey PRIMARY KEY (id_factura);


--
-- TOC entry 3896 (class 2606 OID 54311)
-- Name: inmueble_urbano inmueble_urbano_cod_catastral_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_cod_catastral_key UNIQUE (cod_catastral);


--
-- TOC entry 3898 (class 2606 OID 54313)
-- Name: inmueble_urbano inmueble_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_pkey PRIMARY KEY (id_inmueble);


--
-- TOC entry 3800 (class 2606 OID 54315)
-- Name: institucion instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- TOC entry 3808 (class 2606 OID 54317)
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- TOC entry 3848 (class 2606 OID 54319)
-- Name: notificacion notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificacion
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- TOC entry 3902 (class 2606 OID 54321)
-- Name: operacion operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacion
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- TOC entry 3904 (class 2606 OID 54323)
-- Name: ordenanza ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_pkey PRIMARY KEY (id_ordenanza);


--
-- TOC entry 3906 (class 2606 OID 54325)
-- Name: ordenanza_tramite ordenanzas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_pkey PRIMARY KEY (id_ordenanza_tramite);


--
-- TOC entry 3910 (class 2606 OID 54327)
-- Name: pago pagos_id_banco_referencia_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_referencia_key UNIQUE (id_banco, referencia);


--
-- TOC entry 3914 (class 2606 OID 54329)
-- Name: pago_manual pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- TOC entry 3912 (class 2606 OID 54331)
-- Name: pago pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- TOC entry 3900 (class 2606 OID 54333)
-- Name: parroquia parroquia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquia
    ADD CONSTRAINT parroquia_pkey PRIMARY KEY (id);


--
-- TOC entry 3916 (class 2606 OID 54335)
-- Name: permiso_de_acceso permiso_de_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_pkey PRIMARY KEY (id_permiso);


--
-- TOC entry 3918 (class 2606 OID 54337)
-- Name: propietario propietario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);


--
-- TOC entry 3920 (class 2606 OID 54339)
-- Name: propietario_inmueble propietarios_inmuebles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_pkey PRIMARY KEY (id_propietario_inmueble);


--
-- TOC entry 3922 (class 2606 OID 54341)
-- Name: recaudo recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudo
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- TOC entry 3924 (class 2606 OID 54343)
-- Name: recuperacion recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_pkey PRIMARY KEY (id_recuperacion);


--
-- TOC entry 3926 (class 2606 OID 54345)
-- Name: seccion secciones_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seccion
    ADD CONSTRAINT secciones_pk PRIMARY KEY (id_seccion);


--
-- TOC entry 3908 (class 2606 OID 54347)
-- Name: tarifa_inspeccion tarifas_inspeccion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_pkey PRIMARY KEY (id_tarifa);


--
-- TOC entry 3928 (class 2606 OID 54349)
-- Name: template_certificado templates_certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_pkey PRIMARY KEY (id_template_certificado);


--
-- TOC entry 3802 (class 2606 OID 54351)
-- Name: tipo_tramite tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- TOC entry 3930 (class 2606 OID 54353)
-- Name: tipo_usuario tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_usuario
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- TOC entry 3812 (class 2606 OID 54355)
-- Name: tramite tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- TOC entry 3932 (class 2606 OID 54357)
-- Name: usuario usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- TOC entry 3934 (class 2606 OID 54359)
-- Name: usuario usuarios_nombre_de_usuario_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_nombre_de_usuario_key UNIQUE (nombre_de_usuario);


--
-- TOC entry 3936 (class 2606 OID 54361)
-- Name: usuario usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 3938 (class 2606 OID 54363)
-- Name: valor valores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valor
    ADD CONSTRAINT valores_pkey PRIMARY KEY (id_valor);


--
-- TOC entry 3942 (class 2606 OID 54365)
-- Name: variable_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- TOC entry 3944 (class 2606 OID 54367)
-- Name: variable_ordenanza variables_ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_ordenanza
    ADD CONSTRAINT variables_ordenanzas_pkey PRIMARY KEY (id_variable);


--
-- TOC entry 3940 (class 2606 OID 54369)
-- Name: variable variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- TOC entry 3946 (class 2606 OID 54371)
-- Name: base_task base_task_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_name_key UNIQUE (name);


--
-- TOC entry 3948 (class 2606 OID 54373)
-- Name: base_task base_task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_pkey PRIMARY KEY (task_id);


--
-- TOC entry 3950 (class 2606 OID 54375)
-- Name: chain_execution_config chain_execution_config_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_name_key UNIQUE (chain_name);


--
-- TOC entry 3952 (class 2606 OID 54377)
-- Name: chain_execution_config chain_execution_config_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_pkey PRIMARY KEY (chain_execution_config);


--
-- TOC entry 3954 (class 2606 OID 54379)
-- Name: chain_execution_parameters chain_execution_parameters_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_pkey PRIMARY KEY (chain_execution_config, chain_id, order_id);


--
-- TOC entry 3956 (class 2606 OID 54381)
-- Name: database_connection database_connection_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.database_connection
    ADD CONSTRAINT database_connection_pkey PRIMARY KEY (database_connection);


--
-- TOC entry 3958 (class 2606 OID 54383)
-- Name: log log_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- TOC entry 3960 (class 2606 OID 54385)
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 3962 (class 2606 OID 54387)
-- Name: run_status run_status_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.run_status
    ADD CONSTRAINT run_status_pkey PRIMARY KEY (run_status);


--
-- TOC entry 3964 (class 2606 OID 54389)
-- Name: task_chain task_chain_parent_id_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_key UNIQUE (parent_id);


--
-- TOC entry 3966 (class 2606 OID 54391)
-- Name: task_chain task_chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_pkey PRIMARY KEY (chain_id);


--
-- TOC entry 3968 (class 2606 OID 54393)
-- Name: ano ano_fiscal_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.ano
    ADD CONSTRAINT ano_fiscal_pkey PRIMARY KEY (id);


--
-- TOC entry 3970 (class 2606 OID 54395)
-- Name: construccion construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_pkey PRIMARY KEY (id);


--
-- TOC entry 3976 (class 2606 OID 54397)
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- TOC entry 3978 (class 2606 OID 54399)
-- Name: terreno terreno_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_pkey PRIMARY KEY (id);


--
-- TOC entry 3972 (class 2606 OID 54401)
-- Name: tipo_construccion tipo_construccion_descripcion_key; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_descripcion_key UNIQUE (descripcion);


--
-- TOC entry 3974 (class 2606 OID 54403)
-- Name: tipo_construccion tipo_construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_pkey PRIMARY KEY (id);


--
-- TOC entry 4085 (class 2620 OID 54404)
-- Name: evento_fraccion eventos_fraccion_trigger; Type: TRIGGER; Schema: impuesto; Owner: postgres
--

CREATE TRIGGER eventos_fraccion_trigger BEFORE INSERT ON impuesto.evento_fraccion FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_fraccion_trigger_func();


--
-- TOC entry 4086 (class 2620 OID 54405)
-- Name: evento_solicitud eventos_solicitud_trigger; Type: TRIGGER; Schema: impuesto; Owner: postgres
--

CREATE TRIGGER eventos_solicitud_trigger BEFORE INSERT ON impuesto.evento_solicitud FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_solicitud_trigger_func();


--
-- TOC entry 4084 (class 2620 OID 54406)
-- Name: tramite codigo_tramite_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigo_tramite_trg BEFORE INSERT ON public.tramite FOR EACH ROW EXECUTE FUNCTION public.codigo_tramite();


--
-- TOC entry 4079 (class 2620 OID 54407)
-- Name: caso_social codigos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigos_casos_sociales_trigger BEFORE INSERT ON public.caso_social FOR EACH ROW EXECUTE FUNCTION public.codigo_caso();


--
-- TOC entry 4082 (class 2620 OID 54408)
-- Name: multa codigos_multas_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigos_multas_trigger BEFORE INSERT ON public.multa FOR EACH ROW EXECUTE FUNCTION public.codigo_multa();


--
-- TOC entry 4080 (class 2620 OID 54409)
-- Name: evento_caso_social eventos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_casos_sociales_trigger BEFORE INSERT ON public.evento_caso_social FOR EACH ROW EXECUTE FUNCTION public.eventos_casos_sociales_trigger_func();


--
-- TOC entry 4081 (class 2620 OID 54410)
-- Name: evento_multa eventos_multa_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_multa_trigger BEFORE INSERT ON public.evento_multa FOR EACH ROW EXECUTE FUNCTION public.eventos_multa_trigger_func();


--
-- TOC entry 4083 (class 2620 OID 54411)
-- Name: evento_tramite eventos_tramite_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_tramite_trigger BEFORE INSERT ON public.evento_tramite FOR EACH ROW EXECUTE FUNCTION public.eventos_tramite_trigger_func();


--
-- TOC entry 4087 (class 2620 OID 54412)
-- Name: notificacion insert_notificaciones_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_notificaciones_trigger BEFORE INSERT ON public.notificacion FOR EACH ROW EXECUTE FUNCTION public.insert_notificacion_trigger_func();


--
-- TOC entry 4088 (class 2620 OID 54413)
-- Name: valor tipos_tramites_costo_utmm_trig; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tipos_tramites_costo_utmm_trig AFTER UPDATE ON public.valor FOR EACH ROW WHEN (((new.descripcion)::text = 'UTMM'::text)) EXECUTE FUNCTION public.tipos_tramites_costo_utmm_trigger_func();


--
-- TOC entry 4089 (class 2620 OID 54414)
-- Name: base_task trig_task_chain_fixer; Type: TRIGGER; Schema: timetable; Owner: postgres
--

CREATE TRIGGER trig_task_chain_fixer BEFORE DELETE ON timetable.base_task FOR EACH ROW EXECUTE FUNCTION timetable.trig_chain_fixer();


--
-- TOC entry 3995 (class 2606 OID 54415)
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 3996 (class 2606 OID 54420)
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- TOC entry 3997 (class 2606 OID 54425)
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- TOC entry 3998 (class 2606 OID 54430)
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- TOC entry 3999 (class 2606 OID 54435)
-- Name: avaluo_inmueble avaluo_inmueble_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- TOC entry 4001 (class 2606 OID 54440)
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- TOC entry 4002 (class 2606 OID 54445)
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 4003 (class 2606 OID 54450)
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- TOC entry 4000 (class 2606 OID 54455)
-- Name: contribuyente contribuyente_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- TOC entry 4004 (class 2606 OID 54460)
-- Name: convenio convenio_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- TOC entry 4005 (class 2606 OID 54465)
-- Name: evento_fraccion evento_fraccion_id_fraccion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_id_fraccion_fkey FOREIGN KEY (id_fraccion) REFERENCES impuesto.fraccion(id_fraccion) ON DELETE CASCADE;


--
-- TOC entry 4006 (class 2606 OID 54470)
-- Name: evento_solicitud evento_solicitud_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud) ON DELETE CASCADE;


--
-- TOC entry 3979 (class 2606 OID 54475)
-- Name: fraccion fraccion_id_convenio_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_id_convenio_fkey FOREIGN KEY (id_convenio) REFERENCES impuesto.convenio(id_convenio);


--
-- TOC entry 4007 (class 2606 OID 54480)
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 4008 (class 2606 OID 54485)
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- TOC entry 4009 (class 2606 OID 54490)
-- Name: liquidacion_descuento liquidacion_descuento_id_liquidacion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_id_liquidacion_fkey FOREIGN KEY (id_liquidacion) REFERENCES impuesto.liquidacion(id_liquidacion);


--
-- TOC entry 3986 (class 2606 OID 54495)
-- Name: liquidacion liquidacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- TOC entry 3987 (class 2606 OID 54500)
-- Name: liquidacion liquidacion_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- TOC entry 3988 (class 2606 OID 54505)
-- Name: liquidacion liquidacion_id_subramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_subramo_fkey FOREIGN KEY (id_subramo) REFERENCES impuesto.subramo(id_subramo);


--
-- TOC entry 4010 (class 2606 OID 54510)
-- Name: multa multa_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- TOC entry 4011 (class 2606 OID 54515)
-- Name: multa multa_id_tipo_multa_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_tipo_multa_fkey FOREIGN KEY (id_tipo_multa) REFERENCES impuesto.tipo_multa(id_tipo_multa);


--
-- TOC entry 4012 (class 2606 OID 54520)
-- Name: ramo_exoneracion procedimiento_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- TOC entry 4013 (class 2606 OID 54525)
-- Name: ramo_exoneracion ramo_exoneracion_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT ramo_exoneracion_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- TOC entry 4014 (class 2606 OID 54530)
-- Name: registro_municipal registro_municipal_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 4015 (class 2606 OID 54535)
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- TOC entry 4016 (class 2606 OID 54540)
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_verificacion_telefono_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_verificacion_telefono_fkey FOREIGN KEY (id_verificacion_telefono) REFERENCES impuesto.verificacion_telefono(id_verificacion_telefono) ON DELETE CASCADE;


--
-- TOC entry 3980 (class 2606 OID 54545)
-- Name: solicitud solicitud_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 3981 (class 2606 OID 54550)
-- Name: solicitud solicitud_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 3982 (class 2606 OID 54555)
-- Name: solicitud solicitud_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4017 (class 2606 OID 54560)
-- Name: subramo subramo_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- TOC entry 4018 (class 2606 OID 54565)
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4019 (class 2606 OID 54570)
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- TOC entry 4020 (class 2606 OID 54575)
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4022 (class 2606 OID 54580)
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4023 (class 2606 OID 54585)
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- TOC entry 4021 (class 2606 OID 54590)
-- Name: tabulador_gas tabulador_gas_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- TOC entry 4024 (class 2606 OID 54595)
-- Name: tabulador_gas_residencial tabulador_gas_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4025 (class 2606 OID 54600)
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_categoria_propaganda_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_categoria_propaganda_fkey FOREIGN KEY (id_categoria_propaganda) REFERENCES impuesto.categoria_propaganda(id_categoria_propaganda);


--
-- TOC entry 4026 (class 2606 OID 54605)
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_valor_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- TOC entry 4027 (class 2606 OID 54610)
-- Name: usuario_enlazado usuario_enlazado_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 4028 (class 2606 OID 54615)
-- Name: verificacion_email verificacion_email_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- TOC entry 4029 (class 2606 OID 54620)
-- Name: verificacion_telefono verificacion_telefono_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4030 (class 2606 OID 54625)
-- Name: campo_tramite campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campo(id_campo);


--
-- TOC entry 4031 (class 2606 OID 54630)
-- Name: campo_tramite campos_tramites_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES public.seccion(id_seccion) NOT VALID;


--
-- TOC entry 4032 (class 2606 OID 54635)
-- Name: campo_tramite campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 4033 (class 2606 OID 54640)
-- Name: cargo cargo_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- TOC entry 4034 (class 2606 OID 54645)
-- Name: cargo cargo_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- TOC entry 3983 (class 2606 OID 54650)
-- Name: caso_social casos_sociales_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 3984 (class 2606 OID 54655)
-- Name: caso_social casos_sociales_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4035 (class 2606 OID 54660)
-- Name: certificado certificados_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- TOC entry 4036 (class 2606 OID 54665)
-- Name: cuenta_funcionario cuentas_funcionarios_id_cargo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_cargo_fkey FOREIGN KEY (id_cargo) REFERENCES public.cargo(id_cargo);


--
-- TOC entry 4037 (class 2606 OID 54670)
-- Name: cuenta_funcionario cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- TOC entry 4038 (class 2606 OID 54675)
-- Name: datos_facebook datos_facebook_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_facebook
    ADD CONSTRAINT datos_facebook_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4039 (class 2606 OID 54680)
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- TOC entry 4040 (class 2606 OID 54685)
-- Name: detalle_factura detalles_facturas_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT detalles_facturas_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.factura_tramite(id_factura);


--
-- TOC entry 3989 (class 2606 OID 54690)
-- Name: evento_multa evento_multa_id_multa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_id_multa_fkey FOREIGN KEY (id_multa) REFERENCES public.multa(id_multa);


--
-- TOC entry 3992 (class 2606 OID 54695)
-- Name: evento_tramite eventos_tramite_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite) ON DELETE CASCADE;


--
-- TOC entry 4041 (class 2606 OID 54700)
-- Name: factura_tramite facturas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- TOC entry 4042 (class 2606 OID 54705)
-- Name: inmueble_urbano inmueble_urbano_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- TOC entry 4043 (class 2606 OID 54710)
-- Name: inmueble_urbano inmueble_urbano_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- TOC entry 4044 (class 2606 OID 54715)
-- Name: institucion_banco instituciones_bancos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- TOC entry 4045 (class 2606 OID 54720)
-- Name: institucion_banco instituciones_bancos_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- TOC entry 3990 (class 2606 OID 54725)
-- Name: multa multa_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 3991 (class 2606 OID 54730)
-- Name: multa multa_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- TOC entry 4046 (class 2606 OID 54735)
-- Name: ordenanza ordenanzas_id_valor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- TOC entry 4047 (class 2606 OID 54740)
-- Name: ordenanza_tramite ordenanzas_tramites_id_tarifa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tarifa_fkey FOREIGN KEY (id_tarifa) REFERENCES public.tarifa_inspeccion(id_tarifa);


--
-- TOC entry 4048 (class 2606 OID 54745)
-- Name: ordenanza_tramite ordenanzas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- TOC entry 4052 (class 2606 OID 54750)
-- Name: pago pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- TOC entry 4053 (class 2606 OID 54755)
-- Name: pago_manual pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pago(id_pago);


--
-- TOC entry 4054 (class 2606 OID 54760)
-- Name: pago_manual pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuenta_funcionario(id_usuario);


--
-- TOC entry 4055 (class 2606 OID 54765)
-- Name: permiso_de_acceso permiso_de_acceso_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 4056 (class 2606 OID 54770)
-- Name: permiso_de_acceso permiso_de_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- TOC entry 4057 (class 2606 OID 54775)
-- Name: propietario_inmueble propietarios_inmuebles_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- TOC entry 4058 (class 2606 OID 54780)
-- Name: propietario_inmueble propietarios_inmuebles_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);


--
-- TOC entry 4059 (class 2606 OID 54785)
-- Name: recuperacion recuperacion_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- TOC entry 4049 (class 2606 OID 54790)
-- Name: tarifa_inspeccion tarifas_inspeccion_id_ordenanza_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_ordenanza_fkey FOREIGN KEY (id_ordenanza) REFERENCES public.ordenanza(id_ordenanza);


--
-- TOC entry 4050 (class 2606 OID 54795)
-- Name: tarifa_inspeccion tarifas_inspeccion_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 4051 (class 2606 OID 54800)
-- Name: tarifa_inspeccion tarifas_inspeccion_id_variable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_variable_fkey FOREIGN KEY (id_variable) REFERENCES public.variable_ordenanza(id_variable);


--
-- TOC entry 4060 (class 2606 OID 54805)
-- Name: template_certificado templates_certificados_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 3985 (class 2606 OID 54810)
-- Name: tipo_tramite tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- TOC entry 4061 (class 2606 OID 54815)
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudo(id_recaudo);


--
-- TOC entry 4062 (class 2606 OID 54820)
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 4063 (class 2606 OID 54825)
-- Name: tramite_archivo_recaudo tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite_archivo_recaudo
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- TOC entry 3993 (class 2606 OID 54830)
-- Name: tramite tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 3994 (class 2606 OID 54835)
-- Name: tramite tramites_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- TOC entry 4064 (class 2606 OID 54840)
-- Name: usuario usuario_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- TOC entry 4065 (class 2606 OID 54845)
-- Name: usuario usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- TOC entry 4066 (class 2606 OID 54850)
-- Name: variable_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operacion(id_operacion);


--
-- TOC entry 4067 (class 2606 OID 54855)
-- Name: variable_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- TOC entry 4068 (class 2606 OID 54860)
-- Name: chain_execution_config chain_execution_config_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4069 (class 2606 OID 54865)
-- Name: chain_execution_parameters chain_execution_parameters_chain_execution_config_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_execution_config_fkey FOREIGN KEY (chain_execution_config) REFERENCES timetable.chain_execution_config(chain_execution_config) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4070 (class 2606 OID 54870)
-- Name: chain_execution_parameters chain_execution_parameters_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4071 (class 2606 OID 54875)
-- Name: task_chain task_chain_database_connection_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_database_connection_fkey FOREIGN KEY (database_connection) REFERENCES timetable.database_connection(database_connection) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4072 (class 2606 OID 54880)
-- Name: task_chain task_chain_parent_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4073 (class 2606 OID 54885)
-- Name: task_chain task_chain_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.base_task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4074 (class 2606 OID 54890)
-- Name: construccion construccion_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- TOC entry 4075 (class 2606 OID 54895)
-- Name: construccion construccion_tipo_construccion_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_tipo_construccion_id_fkey FOREIGN KEY (tipo_construccion_id) REFERENCES valores_fiscales.tipo_construccion(id);


--
-- TOC entry 4076 (class 2606 OID 54900)
-- Name: sector sector_parroquia_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_parroquia_id_fkey FOREIGN KEY (parroquia_id) REFERENCES public.parroquia(id);


--
-- TOC entry 4077 (class 2606 OID 54905)
-- Name: terreno terreno_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- TOC entry 4078 (class 2606 OID 54910)
-- Name: terreno terreno_sector_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES valores_fiscales.sector(id);


-- Completed on 2020-07-01 16:23:12 -04

--
-- PostgreSQL database dump complete
--

