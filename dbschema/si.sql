--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3
-- Dumped by pg_dump version 12.3

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
-- Name: impuesto; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA impuesto;


ALTER SCHEMA impuesto OWNER TO postgres;

--
-- Name: timetable; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA timetable;


ALTER SCHEMA timetable OWNER TO postgres;

--
-- Name: valores_fiscales; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA valores_fiscales;


ALTER SCHEMA valores_fiscales OWNER TO postgres;

--
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: postgres
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK ((((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR (VALUE = '@reboot'::text) OR (VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text)));


ALTER DOMAIN timetable.cron OWNER TO postgres;

--
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
-- Name: task_kind; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.task_kind AS ENUM (
    'SQL',
    'SHELL',
    'BUILTIN'
);


ALTER TYPE timetable.task_kind OWNER TO postgres;

--
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
    SELECT id_evento_fraccion, event FROM evento_fraccion WHERE id_fraccion = new.id_fraccion
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
-- Name: solicitud; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.solicitud (
    id_solicitud integer NOT NULL,
    id_usuario integer,
    aprobado boolean DEFAULT false,
    fecha date,
    fecha_aprobado date,
    id_tipo_tramite integer,
    id_contribuyente integer
);


ALTER TABLE impuesto.solicitud OWNER TO postgres;

--
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


ALTER FUNCTION impuesto.solicitud_transicion(state text, event text) OWNER TO postgres;

--
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
-- Name: caso_social_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.caso_social_fsm(text) (
    SFUNC = public.casos_sociales_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.caso_social_fsm(text) OWNER TO postgres;

--
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
-- Name: institucion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institucion (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


ALTER TABLE public.institucion OWNER TO postgres;

--
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
-- Name: multa_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.multa_fsm(text) (
    SFUNC = public.multa_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.multa_fsm(text) OWNER TO postgres;

--
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
-- Name: tramite_evento_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.tramite_evento_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.tramite_evento_fsm(text) OWNER TO postgres;

--
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
-- Name: get_task_id(text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.get_task_id(task_name text) RETURNS bigint
    LANGUAGE sql STRICT
    AS $_$
	SELECT task_id FROM timetable.base_task WHERE name = $1;
$_$;


ALTER FUNCTION timetable.get_task_id(task_name text) OWNER TO postgres;

--
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
-- Name: fraccion_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: postgres
--

CREATE AGGREGATE impuesto.fraccion_fsm(text) (
    SFUNC = impuesto.fraccion_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.fraccion_fsm(text) OWNER TO postgres;

--
-- Name: solicitud_fsm(text); Type: AGGREGATE; Schema: impuesto; Owner: postgres
--

CREATE AGGREGATE impuesto.solicitud_fsm(text) (
    SFUNC = impuesto.solicitud_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE impuesto.solicitud_fsm(text) OWNER TO postgres;

--
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
-- Name: actividad_economica_contribuyente; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.actividad_economica_contribuyente (
    id_actividad_economica_contribuyente integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    numero_referencia integer NOT NULL
);


ALTER TABLE impuesto.actividad_economica_contribuyente OWNER TO postgres;

--
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
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq OWNED BY impuesto.actividad_economica_contribuyente.id_actividad_economica_contribuyente;


--
-- Name: actividad_economica_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.actividad_economica_exoneracion (
    id_actividad_economica_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_actividad_economica integer
);


ALTER TABLE impuesto.actividad_economica_exoneracion OWNER TO postgres;

--
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
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq OWNED BY impuesto.actividad_economica_exoneracion.id_actividad_economica_exoneracion;


--
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
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.actividad_economica_id_actividad_economica_seq OWNED BY impuesto.actividad_economica.id_actividad_economica;


--
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
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.avaluo_inmueble_id_avaluo_inmueble_seq OWNED BY impuesto.avaluo_inmueble.id_avaluo_inmueble;


--
-- Name: categoria_propaganda; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.categoria_propaganda (
    id_categoria_propaganda integer NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE impuesto.categoria_propaganda OWNER TO postgres;

--
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
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.categoria_propaganda_id_categoria_propaganda_seq OWNED BY impuesto.categoria_propaganda.id_categoria_propaganda;


--
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
-- Name: contribuyente_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.contribuyente_exoneracion (
    id_contribuyente_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer NOT NULL,
    id_registro_municipal integer NOT NULL,
    id_actividad_economica integer
);


ALTER TABLE impuesto.contribuyente_exoneracion OWNER TO postgres;

--
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
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq OWNED BY impuesto.contribuyente_exoneracion.id_contribuyente_exoneracion;


--
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
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.contribuyente_id_contribuyente_seq OWNED BY impuesto.contribuyente.id_contribuyente;


--
-- Name: convenio; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.convenio (
    id_convenio integer NOT NULL,
    id_solicitud integer NOT NULL,
    cantidad integer NOT NULL
);


ALTER TABLE impuesto.convenio OWNER TO postgres;

--
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
-- Name: convenio_id_convenio_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.convenio_id_convenio_seq OWNED BY impuesto.convenio.id_convenio;


--
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
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.credito_fiscal_id_credito_fiscal_seq OWNED BY impuesto.credito_fiscal.id_credito_fiscal;


--
-- Name: dias_feriados; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.dias_feriados (
    id_dia_feriado integer NOT NULL,
    dia date,
    descripcion character varying
);


ALTER TABLE impuesto.dias_feriados OWNER TO postgres;

--
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
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.dias_feriados_id_dia_feriado_seq OWNED BY impuesto.dias_feriados.id_dia_feriado;


--
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
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.evento_fraccion_id_evento_fraccion_seq OWNED BY impuesto.evento_fraccion.id_evento_fraccion;


--
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
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.evento_solicitud_id_evento_solicitud_seq OWNED BY impuesto.evento_solicitud.id_evento_solicitud;


--
-- Name: factor; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.factor (
    id_factor integer NOT NULL,
    descripcion character varying,
    valor numeric
);


ALTER TABLE impuesto.factor OWNER TO postgres;

--
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
-- Name: factor_id_factor_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.factor_id_factor_seq OWNED BY impuesto.factor.id_factor;


--
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
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.fraccion_id_fraccion_seq OWNED BY impuesto.fraccion.id_fraccion;


--
-- Name: inmueble_contribuyente_natural; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.inmueble_contribuyente_natural (
    id_inmueble_contribuyente integer NOT NULL,
    id_inmueble integer NOT NULL,
    id_contribuyente integer NOT NULL
);


ALTER TABLE impuesto.inmueble_contribuyente_natural OWNER TO postgres;

--
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
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq OWNED BY impuesto.inmueble_contribuyente_natural.id_inmueble_contribuyente;


--
-- Name: liquidacion_descuento; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.liquidacion_descuento (
    id_liquidacion_descuento integer NOT NULL,
    id_liquidacion integer NOT NULL,
    porcentaje_descuento numeric NOT NULL
);


ALTER TABLE impuesto.liquidacion_descuento OWNER TO postgres;

--
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
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.liquidacion_descuento_id_liquidacion_descuento_seq OWNED BY impuesto.liquidacion_descuento.id_liquidacion_descuento;


--
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
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.liquidacion_id_liquidacion_seq OWNED BY impuesto.liquidacion.id_liquidacion;


--
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
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.multa_id_multa_seq OWNED BY impuesto.multa.id_multa;


--
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
-- Name: plazo_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.plazo_exoneracion (
    id_plazo_exoneracion integer NOT NULL,
    fecha_inicio date,
    fecha_fin date
);


ALTER TABLE impuesto.plazo_exoneracion OWNER TO postgres;

--
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
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.plazo_exoneracion_id_plazo_exoneracion_seq OWNED BY impuesto.plazo_exoneracion.id_plazo_exoneracion;


--
-- Name: ramo_exoneracion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.ramo_exoneracion (
    id_ramo_exoneracion integer NOT NULL,
    id_plazo_exoneracion integer,
    id_ramo integer
);


ALTER TABLE impuesto.ramo_exoneracion OWNER TO postgres;

--
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
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq OWNED BY impuesto.ramo_exoneracion.id_ramo_exoneracion;


--
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
-- Name: ramo_id_ramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.ramo_id_ramo_seq OWNED BY impuesto.ramo.id_ramo;


--
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
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.registro_municipal_id_registro_municipal_seq OWNED BY impuesto.registro_municipal.id_registro_municipal;


--
-- Name: registro_municipal_verificacion; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.registro_municipal_verificacion (
    id_registro_municipal integer NOT NULL,
    id_verificacion_telefono integer NOT NULL
);


ALTER TABLE impuesto.registro_municipal_verificacion OWNER TO postgres;

--
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
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.solicitud_id_solicitud_seq OWNED BY impuesto.solicitud.id_solicitud;


--
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
    c.verificado,
    c.tipo_contribuyente AS "tipoContribuyente",
    r.descripcion_corta AS "descripcionCortaRamo"
   FROM ((((impuesto.solicitud s
     JOIN impuesto.contribuyente c ON ((s.id_contribuyente = c.id_contribuyente)))
     JOIN impuesto.liquidacion l ON ((s.id_solicitud = l.id_solicitud)))
     JOIN impuesto.subramo sr ON ((sr.id_subramo = l.id_subramo)))
     JOIN impuesto.ramo r ON ((r.id_ramo = sr.id_ramo)));


ALTER TABLE impuesto.solicitud_view OWNER TO postgres;

--
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
-- Name: subramo_id_subramo_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.subramo_id_subramo_seq OWNED BY impuesto.subramo.id_subramo;


--
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
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq OWNED BY impuesto.tabulador_aseo_actividad_economica.id_tabulador_aseo_actividad_economica;


--
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
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq OWNED BY impuesto.tabulador_aseo_residencial.id_tabulador_aseo_residencial;


--
-- Name: tabulador_gas; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tabulador_gas (
    id_tabulador_gas integer NOT NULL,
    id_actividad_economica integer,
    monto numeric
);


ALTER TABLE impuesto.tabulador_gas OWNER TO postgres;

--
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
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq OWNED BY impuesto.tabulador_gas_actividad_economica.id_tabulador_gas_actividad_economica;


--
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
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_id_tabulador_gas_seq OWNED BY impuesto.tabulador_gas.id_tabulador_gas;


--
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
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq OWNED BY impuesto.tabulador_gas_residencial.id_tabulador_gas_residencial;


--
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
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq OWNED BY impuesto.tipo_aviso_propaganda.id_tipo_aviso_propaganda;


--
-- Name: tipo_multa; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.tipo_multa (
    id_tipo_multa integer NOT NULL,
    descripcion character varying
);


ALTER TABLE impuesto.tipo_multa OWNER TO postgres;

--
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
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.tipo_multa_id_tipo_multa_seq OWNED BY impuesto.tipo_multa.id_tipo_multa;


--
-- Name: usuario_enlazado; Type: TABLE; Schema: impuesto; Owner: postgres
--

CREATE TABLE impuesto.usuario_enlazado (
    id_usuario_enlazado integer NOT NULL,
    id_contribuyente integer NOT NULL,
    email character varying NOT NULL
);


ALTER TABLE impuesto.usuario_enlazado OWNER TO postgres;

--
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
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.usuario_enlazado_id_usuario_enlazado_seq OWNED BY impuesto.usuario_enlazado.id_usuario_enlazado;


--
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
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.verificacion_email_id_verificacion_email_seq OWNED BY impuesto.verificacion_email.id_verificacion_email;


--
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
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE OWNED BY; Schema: impuesto; Owner: postgres
--

ALTER SEQUENCE impuesto.verificacion_telefono_id_verificacion_telefono_seq OWNED BY impuesto.verificacion_telefono.id_verificacion_telefono;


--
-- Name: banco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.banco (
    id_banco integer NOT NULL,
    nombre character varying,
    validador boolean DEFAULT false
);


ALTER TABLE public.banco OWNER TO postgres;

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

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.banco.id_banco;


--
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

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campo.id_campo;


--
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
-- Name: cargo_id_cargo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cargo_id_cargo_seq OWNED BY public.cargo.id_cargo;


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

ALTER SEQUENCE public.casos_sociales_id_caso_seq OWNED BY public.caso_social.id_caso;


--
-- Name: certificado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificado (
    id_certificado integer NOT NULL,
    id_tramite integer,
    url_certificado character varying
);


ALTER TABLE public.certificado OWNER TO postgres;

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

ALTER SEQUENCE public.certificados_id_certificado_seq OWNED BY public.certificado.id_certificado;


--
-- Name: cuenta_funcionario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cuenta_funcionario (
    id_usuario integer NOT NULL,
    id_cargo integer
);


ALTER TABLE public.cuenta_funcionario OWNER TO postgres;

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

ALTER SEQUENCE public.detalles_facturas_id_detalle_seq OWNED BY public.detalle_factura.id_detalle;


--
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
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.evento_multa_id_evento_multa_seq OWNED BY public.evento_multa.id_evento_multa;


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

ALTER SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq OWNED BY public.evento_caso_social.id_evento_caso;


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

ALTER SEQUENCE public.eventos_tramite_id_evento_tramite_seq OWNED BY public.evento_tramite.id_evento_tramite;


--
-- Name: factura_tramite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.factura_tramite (
    id_factura integer NOT NULL,
    id_tramite integer
);


ALTER TABLE public.factura_tramite OWNER TO postgres;

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

ALTER SEQUENCE public.facturas_tramites_id_factura_seq OWNED BY public.factura_tramite.id_factura;


--
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
-- Name: parroquia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);


ALTER TABLE public.parroquia OWNER TO postgres;

--
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

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.institucion.id_institucion;


--
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
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.multa_id_multa_seq OWNED BY public.multa.id_multa;


--
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

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificacion.id_notificacion;


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
-- Name: operacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operacion (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


ALTER TABLE public.operacion OWNER TO postgres;

--
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
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq OWNED BY public.operatividad_terminal.id_operatividad_terminal;


--
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
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordenanzas_id_ordenanza_seq OWNED BY public.ordenanza.id_ordenanza;


--
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
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNED BY public.ordenanza_tramite.id_ordenanza_tramite;


--
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
-- Name: pago_manual; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pago_manual (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


ALTER TABLE public.pago_manual OWNER TO postgres;

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

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pago.id_pago;


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
-- Name: propietario_inmueble; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.propietario_inmueble (
    id_propietario_inmueble integer NOT NULL,
    id_propietario integer NOT NULL,
    id_inmueble integer NOT NULL
);


ALTER TABLE public.propietario_inmueble OWNER TO postgres;

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

ALTER SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNED BY public.propietario_inmueble.id_propietario_inmueble;


--
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

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudo.id_recaudo;


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
-- Name: seccion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seccion (
    id_seccion integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.seccion OWNER TO postgres;

--
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
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tarifas_inspeccion_id_tarifa_seq OWNED BY public.tarifa_inspeccion.id_tarifa;


--
-- Name: template_certificado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.template_certificado (
    id_template_certificado integer NOT NULL,
    id_tipo_tramite integer,
    link character varying
);


ALTER TABLE public.template_certificado OWNER TO postgres;

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

ALTER SEQUENCE public.templates_certificados_id_template_certificado_seq OWNED BY public.template_certificado.id_template_certificado;


--
-- Name: tipo_tramite_recaudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_tramite_recaudo (
    id_tipo_tramite integer,
    id_recaudo integer,
    fisico boolean
);


ALTER TABLE public.tipo_tramite_recaudo OWNER TO postgres;

--
-- Name: tipo_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_usuario (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


ALTER TABLE public.tipo_usuario OWNER TO postgres;

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

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipo_tramite.id_tipo_tramite;


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

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipo_usuario.id_tipo_usuario;


--
-- Name: tramite_archivo_recaudo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tramite_archivo_recaudo (
    id_tramite integer,
    url_archivo_recaudo character varying
);


ALTER TABLE public.tramite_archivo_recaudo OWNER TO postgres;

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

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramite.id_tramite;


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

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuario.id_usuario;


--
-- Name: valor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.valor (
    id_valor integer NOT NULL,
    descripcion character varying NOT NULL,
    valor_en_bs numeric NOT NULL
);


ALTER TABLE public.valor OWNER TO postgres;

--
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
-- Name: valores_id_valor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.valores_id_valor_seq OWNED BY public.valor.id_valor;


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
-- Name: variable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variable (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


ALTER TABLE public.variable OWNER TO postgres;

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
-- Name: variable_ordenanza; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.variable_ordenanza (
    id_variable integer NOT NULL,
    nombre character varying NOT NULL,
    nombre_plural character varying NOT NULL
);


ALTER TABLE public.variable_ordenanza OWNER TO postgres;

--
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
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.variables_ordenanzas_id_variable_seq OWNED BY public.variable_ordenanza.id_variable;


--
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
-- Name: base_task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.base_task_task_id_seq OWNED BY timetable.base_task.task_id;


--
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
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.chain_execution_config_chain_execution_config_seq OWNED BY timetable.chain_execution_config.chain_execution_config;


--
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
-- Name: database_connection; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.database_connection (
    database_connection bigint NOT NULL,
    connect_string text NOT NULL,
    comment text
);


ALTER TABLE timetable.database_connection OWNER TO postgres;

--
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
-- Name: database_connection_database_connection_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.database_connection_database_connection_seq OWNED BY timetable.database_connection.database_connection;


--
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
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.log_id_seq OWNED BY timetable.log.id;


--
-- Name: migrations; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.migrations (
    id bigint NOT NULL,
    version text NOT NULL
);


ALTER TABLE timetable.migrations OWNER TO postgres;

--
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
-- Name: run_status_run_status_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.run_status_run_status_seq OWNED BY timetable.run_status.run_status;


--
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
-- Name: task_chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.task_chain_chain_id_seq OWNED BY timetable.task_chain.chain_id;


--
-- Name: ano; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.ano (
    id integer NOT NULL,
    descripcion integer NOT NULL
);


ALTER TABLE valores_fiscales.ano OWNER TO postgres;

--
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
-- Name: ano_fiscal_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.ano_fiscal_id_seq OWNED BY valores_fiscales.ano.id;


--
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
-- Name: construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.construccion_id_seq OWNED BY valores_fiscales.construccion.id;


--
-- Name: tipo_construccion; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.tipo_construccion (
    descripcion text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.tipo_construccion OWNER TO postgres;

--
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
-- Name: sector; Type: TABLE; Schema: valores_fiscales; Owner: postgres
--

CREATE TABLE valores_fiscales.sector (
    descripcion text NOT NULL,
    parroquia_id integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE valores_fiscales.sector OWNER TO postgres;

--
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
-- Name: sector_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.sector_id_seq OWNED BY valores_fiscales.sector.id;


--
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
-- Name: terreno_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.terreno_id_seq OWNED BY valores_fiscales.terreno.id;


--
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
-- Name: tipo_construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: postgres
--

ALTER SEQUENCE valores_fiscales.tipo_construccion_id_seq OWNED BY valores_fiscales.tipo_construccion.id;


--
-- Name: actividad_economica id_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica ALTER COLUMN id_actividad_economica SET DEFAULT nextval('impuesto.actividad_economica_id_actividad_economica_seq'::regclass);


--
-- Name: actividad_economica_contribuyente id_actividad_economica_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente ALTER COLUMN id_actividad_economica_contribuyente SET DEFAULT nextval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq'::regclass);


--
-- Name: actividad_economica_exoneracion id_actividad_economica_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion ALTER COLUMN id_actividad_economica_exoneracion SET DEFAULT nextval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq'::regclass);


--
-- Name: avaluo_inmueble id_avaluo_inmueble; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble ALTER COLUMN id_avaluo_inmueble SET DEFAULT nextval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq'::regclass);


--
-- Name: categoria_propaganda id_categoria_propaganda; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.categoria_propaganda ALTER COLUMN id_categoria_propaganda SET DEFAULT nextval('impuesto.categoria_propaganda_id_categoria_propaganda_seq'::regclass);


--
-- Name: contribuyente id_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente ALTER COLUMN id_contribuyente SET DEFAULT nextval('impuesto.contribuyente_id_contribuyente_seq'::regclass);


--
-- Name: contribuyente_exoneracion id_contribuyente_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion ALTER COLUMN id_contribuyente_exoneracion SET DEFAULT nextval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq'::regclass);


--
-- Name: convenio id_convenio; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio ALTER COLUMN id_convenio SET DEFAULT nextval('impuesto.convenio_id_convenio_seq'::regclass);


--
-- Name: credito_fiscal id_credito_fiscal; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.credito_fiscal ALTER COLUMN id_credito_fiscal SET DEFAULT nextval('impuesto.credito_fiscal_id_credito_fiscal_seq'::regclass);


--
-- Name: dias_feriados id_dia_feriado; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.dias_feriados ALTER COLUMN id_dia_feriado SET DEFAULT nextval('impuesto.dias_feriados_id_dia_feriado_seq'::regclass);


--
-- Name: evento_fraccion id_evento_fraccion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion ALTER COLUMN id_evento_fraccion SET DEFAULT nextval('impuesto.evento_fraccion_id_evento_fraccion_seq'::regclass);


--
-- Name: evento_solicitud id_evento_solicitud; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud ALTER COLUMN id_evento_solicitud SET DEFAULT nextval('impuesto.evento_solicitud_id_evento_solicitud_seq'::regclass);


--
-- Name: factor id_factor; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.factor ALTER COLUMN id_factor SET DEFAULT nextval('impuesto.factor_id_factor_seq'::regclass);


--
-- Name: fraccion id_fraccion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion ALTER COLUMN id_fraccion SET DEFAULT nextval('impuesto.fraccion_id_fraccion_seq'::regclass);


--
-- Name: inmueble_contribuyente_natural id_inmueble_contribuyente; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural ALTER COLUMN id_inmueble_contribuyente SET DEFAULT nextval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq'::regclass);


--
-- Name: liquidacion id_liquidacion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion ALTER COLUMN id_liquidacion SET DEFAULT nextval('impuesto.liquidacion_id_liquidacion_seq'::regclass);


--
-- Name: liquidacion_descuento id_liquidacion_descuento; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento ALTER COLUMN id_liquidacion_descuento SET DEFAULT nextval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq'::regclass);


--
-- Name: multa id_multa; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa ALTER COLUMN id_multa SET DEFAULT nextval('impuesto.multa_id_multa_seq'::regclass);


--
-- Name: plazo_exoneracion id_plazo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.plazo_exoneracion ALTER COLUMN id_plazo_exoneracion SET DEFAULT nextval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq'::regclass);


--
-- Name: ramo id_ramo; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo ALTER COLUMN id_ramo SET DEFAULT nextval('impuesto.ramo_id_ramo_seq'::regclass);


--
-- Name: ramo_exoneracion id_ramo_exoneracion; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion ALTER COLUMN id_ramo_exoneracion SET DEFAULT nextval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq'::regclass);


--
-- Name: registro_municipal id_registro_municipal; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal ALTER COLUMN id_registro_municipal SET DEFAULT nextval('impuesto.registro_municipal_id_registro_municipal_seq'::regclass);


--
-- Name: solicitud id_solicitud; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud ALTER COLUMN id_solicitud SET DEFAULT nextval('impuesto.solicitud_id_solicitud_seq'::regclass);


--
-- Name: subramo id_subramo; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo ALTER COLUMN id_subramo SET DEFAULT nextval('impuesto.subramo_id_subramo_seq'::regclass);


--
-- Name: tabulador_aseo_actividad_economica id_tabulador_aseo_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica ALTER COLUMN id_tabulador_aseo_actividad_economica SET DEFAULT nextval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq'::regclass);


--
-- Name: tabulador_aseo_residencial id_tabulador_aseo_residencial; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial ALTER COLUMN id_tabulador_aseo_residencial SET DEFAULT nextval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq'::regclass);


--
-- Name: tabulador_gas id_tabulador_gas; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas ALTER COLUMN id_tabulador_gas SET DEFAULT nextval('impuesto.tabulador_gas_id_tabulador_gas_seq'::regclass);


--
-- Name: tabulador_gas_actividad_economica id_tabulador_gas_actividad_economica; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica ALTER COLUMN id_tabulador_gas_actividad_economica SET DEFAULT nextval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq'::regclass);


--
-- Name: tabulador_gas_residencial id_tabulador_gas_residencial; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial ALTER COLUMN id_tabulador_gas_residencial SET DEFAULT nextval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq'::regclass);


--
-- Name: tipo_aviso_propaganda id_tipo_aviso_propaganda; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda ALTER COLUMN id_tipo_aviso_propaganda SET DEFAULT nextval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq'::regclass);


--
-- Name: tipo_multa id_tipo_multa; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_multa ALTER COLUMN id_tipo_multa SET DEFAULT nextval('impuesto.tipo_multa_id_tipo_multa_seq'::regclass);


--
-- Name: usuario_enlazado id_usuario_enlazado; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado ALTER COLUMN id_usuario_enlazado SET DEFAULT nextval('impuesto.usuario_enlazado_id_usuario_enlazado_seq'::regclass);


--
-- Name: verificacion_email id_verificacion_email; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email ALTER COLUMN id_verificacion_email SET DEFAULT nextval('impuesto.verificacion_email_id_verificacion_email_seq'::regclass);


--
-- Name: verificacion_telefono id_verificacion_telefono; Type: DEFAULT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono ALTER COLUMN id_verificacion_telefono SET DEFAULT nextval('impuesto.verificacion_telefono_id_verificacion_telefono_seq'::regclass);


--
-- Name: banco id_banco; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banco ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- Name: campo id_campo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- Name: cargo id_cargo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo ALTER COLUMN id_cargo SET DEFAULT nextval('public.cargo_id_cargo_seq'::regclass);


--
-- Name: caso_social id_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social ALTER COLUMN id_caso SET DEFAULT nextval('public.casos_sociales_id_caso_seq'::regclass);


--
-- Name: certificado id_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- Name: detalle_factura id_detalle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_factura ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- Name: evento_caso_social id_evento_caso; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_caso_social ALTER COLUMN id_evento_caso SET DEFAULT nextval('public.eventos_casos_sociales_id_evento_caso_seq'::regclass);


--
-- Name: evento_multa id_evento_multa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa ALTER COLUMN id_evento_multa SET DEFAULT nextval('public.evento_multa_id_evento_multa_seq'::regclass);


--
-- Name: evento_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- Name: factura_tramite id_factura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


--
-- Name: inmueble_urbano id_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano ALTER COLUMN id_inmueble SET DEFAULT nextval('public.inmueble_urbano_id_inmueble_seq'::regclass);


--
-- Name: institucion id_institucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- Name: multa id_multa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa ALTER COLUMN id_multa SET DEFAULT nextval('public.multa_id_multa_seq'::regclass);


--
-- Name: notificacion id_notificacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificacion ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- Name: operatividad_terminal id_operatividad_terminal; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operatividad_terminal ALTER COLUMN id_operatividad_terminal SET DEFAULT nextval('public.operatividad_terminal_id_operatividad_terminal_seq'::regclass);


--
-- Name: ordenanza id_ordenanza; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza ALTER COLUMN id_ordenanza SET DEFAULT nextval('public.ordenanzas_id_ordenanza_seq'::regclass);


--
-- Name: ordenanza_tramite id_ordenanza_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite ALTER COLUMN id_ordenanza_tramite SET DEFAULT nextval('public.ordenanzas_tramites_id_ordenanza_tramite_seq'::regclass);


--
-- Name: pago id_pago; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


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
-- Name: propietario_inmueble id_propietario_inmueble; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble ALTER COLUMN id_propietario_inmueble SET DEFAULT nextval('public.propietarios_inmuebles_id_propietario_inmueble_seq'::regclass);


--
-- Name: recaudo id_recaudo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudo ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- Name: recuperacion id_recuperacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion ALTER COLUMN id_recuperacion SET DEFAULT nextval('public.recuperacion_id_recuperacion_seq'::regclass);


--
-- Name: tarifa_inspeccion id_tarifa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion ALTER COLUMN id_tarifa SET DEFAULT nextval('public.tarifas_inspeccion_id_tarifa_seq'::regclass);


--
-- Name: template_certificado id_template_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado ALTER COLUMN id_template_certificado SET DEFAULT nextval('public.templates_certificados_id_template_certificado_seq'::regclass);


--
-- Name: tipo_tramite id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- Name: tipo_usuario id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_usuario ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- Name: tramite id_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- Name: usuario id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Name: valor id_valor; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valor ALTER COLUMN id_valor SET DEFAULT nextval('public.valores_id_valor_seq'::regclass);


--
-- Name: variable_ordenanza id_variable; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_ordenanza ALTER COLUMN id_variable SET DEFAULT nextval('public.variables_ordenanzas_id_variable_seq'::regclass);


--
-- Name: base_task task_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task ALTER COLUMN task_id SET DEFAULT nextval('timetable.base_task_task_id_seq'::regclass);


--
-- Name: chain_execution_config chain_execution_config; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config ALTER COLUMN chain_execution_config SET DEFAULT nextval('timetable.chain_execution_config_chain_execution_config_seq'::regclass);


--
-- Name: database_connection database_connection; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.database_connection ALTER COLUMN database_connection SET DEFAULT nextval('timetable.database_connection_database_connection_seq'::regclass);


--
-- Name: log id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.log ALTER COLUMN id SET DEFAULT nextval('timetable.log_id_seq'::regclass);


--
-- Name: run_status run_status; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.run_status ALTER COLUMN run_status SET DEFAULT nextval('timetable.run_status_run_status_seq'::regclass);


--
-- Name: task_chain chain_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.task_chain_chain_id_seq'::regclass);


--
-- Name: ano id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.ano ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.ano_fiscal_id_seq'::regclass);


--
-- Name: construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.construccion_id_seq'::regclass);


--
-- Name: sector id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.sector_id_seq'::regclass);


--
-- Name: terreno id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.terreno_id_seq'::regclass);


--
-- Name: tipo_construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.tipo_construccion_id_seq'::regclass);


--
-- Data for Name: actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.actividad_economica (id_actividad_economica, numero_referencia, descripcion, alicuota, minimo_tributable) FROM stdin;
\.


--
-- Data for Name: actividad_economica_contribuyente; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.actividad_economica_contribuyente (id_actividad_economica_contribuyente, id_registro_municipal, numero_referencia) FROM stdin;
\.


--
-- Data for Name: actividad_economica_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.actividad_economica_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_actividad_economica) FROM stdin;
\.


--
-- Data for Name: avaluo_inmueble; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.avaluo_inmueble (id_avaluo_inmueble, id_inmueble, avaluo, anio) FROM stdin;
\.


--
-- Data for Name: categoria_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.categoria_propaganda (id_categoria_propaganda, descripcion) FROM stdin;
\.


--
-- Data for Name: contribuyente; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.contribuyente (id_contribuyente, tipo_documento, documento, razon_social, denominacion_comercial, siglas, id_parroquia, sector, direccion, punto_referencia, verificado, tipo_contribuyente) FROM stdin;
\.


--
-- Data for Name: contribuyente_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_registro_municipal, id_actividad_economica) FROM stdin;
\.


--
-- Data for Name: convenio; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.convenio (id_convenio, id_solicitud, cantidad) FROM stdin;
\.


--
-- Data for Name: credito_fiscal; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.credito_fiscal (id_credito_fiscal, id_persona, concepto, credito) FROM stdin;
\.


--
-- Data for Name: dias_feriados; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.dias_feriados (id_dia_feriado, dia, descripcion) FROM stdin;
\.


--
-- Data for Name: evento_fraccion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.evento_fraccion (id_evento_fraccion, id_fraccion, event, "time") FROM stdin;
\.


--
-- Data for Name: evento_solicitud; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.evento_solicitud (id_evento_solicitud, id_solicitud, event, "time") FROM stdin;
\.


--
-- Data for Name: factor; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.factor (id_factor, descripcion, valor) FROM stdin;
\.


--
-- Data for Name: fraccion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.fraccion (id_fraccion, id_convenio, monto, porcion, fecha, aprobado, fecha_aprobado) FROM stdin;
\.


--
-- Data for Name: inmueble_contribuyente_natural; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.inmueble_contribuyente_natural (id_inmueble_contribuyente, id_inmueble, id_contribuyente) FROM stdin;
\.


--
-- Data for Name: liquidacion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.liquidacion (id_liquidacion, id_solicitud, monto, certificado, recibo, fecha_liquidacion, id_subramo, datos, fecha_vencimiento, id_registro_municipal, remitido) FROM stdin;
\.


--
-- Data for Name: liquidacion_descuento; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.liquidacion_descuento (id_liquidacion_descuento, id_liquidacion, porcentaje_descuento) FROM stdin;
\.


--
-- Data for Name: multa; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.multa (id_multa, id_solicitud, id_tipo_multa, monto, mes, anio) FROM stdin;
\.


--
-- Data for Name: plazo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.plazo_exoneracion (id_plazo_exoneracion, fecha_inicio, fecha_fin) FROM stdin;
\.


--
-- Data for Name: ramo; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.ramo (id_ramo, codigo, descripcion, descripcion_corta) FROM stdin;
\.


--
-- Data for Name: ramo_exoneracion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.ramo_exoneracion (id_ramo_exoneracion, id_plazo_exoneracion, id_ramo) FROM stdin;
\.


--
-- Data for Name: registro_municipal; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.registro_municipal (id_registro_municipal, id_contribuyente, referencia_municipal, fecha_aprobacion, telefono_celular, telefono_habitacion, email, denominacion_comercial, nombre_representante, actualizado) FROM stdin;
\.


--
-- Data for Name: registro_municipal_verificacion; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.registro_municipal_verificacion (id_registro_municipal, id_verificacion_telefono) FROM stdin;
\.


--
-- Data for Name: solicitud; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.solicitud (id_solicitud, id_usuario, aprobado, fecha, fecha_aprobado, id_tipo_tramite, id_contribuyente) FROM stdin;
\.


--
-- Data for Name: subramo; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.subramo (id_subramo, id_ramo, subindice, descripcion) FROM stdin;
\.


--
-- Data for Name: tabulador_aseo_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_aseo_actividad_economica (id_tabulador_aseo_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
\.


--
-- Data for Name: tabulador_aseo_residencial; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_aseo_residencial (id_tabulador_aseo_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
\.


--
-- Data for Name: tabulador_gas; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas (id_tabulador_gas, id_actividad_economica, monto) FROM stdin;
\.


--
-- Data for Name: tabulador_gas_actividad_economica; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas_actividad_economica (id_tabulador_gas_actividad_economica, id_usuario, numero_referencia, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
\.


--
-- Data for Name: tabulador_gas_residencial; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tabulador_gas_residencial (id_tabulador_gas_residencial, id_usuario, monto, fecha_creacion, fecha_desde, fecha_hasta) FROM stdin;
\.


--
-- Data for Name: tipo_aviso_propaganda; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tipo_aviso_propaganda (id_tipo_aviso_propaganda, id_categoria_propaganda, descripcion, parametro, monto, id_valor) FROM stdin;
\.


--
-- Data for Name: tipo_multa; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.tipo_multa (id_tipo_multa, descripcion) FROM stdin;
\.


--
-- Data for Name: usuario_enlazado; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.usuario_enlazado (id_usuario_enlazado, id_contribuyente, email) FROM stdin;
\.


--
-- Data for Name: verificacion_email; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.verificacion_email (id_verificacion_email, id_registro_municipal, codigo_recuperacion, fecha_recuperacion, verificado) FROM stdin;
\.


--
-- Data for Name: verificacion_telefono; Type: TABLE DATA; Schema: impuesto; Owner: postgres
--

COPY impuesto.verificacion_telefono (id_verificacion_telefono, codigo_verificacion, fecha_verificacion, verificado, id_usuario, telefono) FROM stdin;
\.


--
-- Data for Name: banco; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.banco (id_banco, nombre, validador) FROM stdin;
\.


--
-- Data for Name: campo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campo (id_campo, nombre, tipo, validacion, col) FROM stdin;
\.


--
-- Data for Name: campo_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campo_tramite (id_campo, id_tipo_tramite, orden, estado, id_seccion) FROM stdin;
\.


--
-- Data for Name: cargo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cargo (id_cargo, id_tipo_usuario, id_institucion, descripcion) FROM stdin;
\.


--
-- Data for Name: caso_social; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.caso_social (id_caso, id_tipo_tramite, costo, datos, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla) FROM stdin;
\.


--
-- Data for Name: certificado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificado (id_certificado, id_tramite, url_certificado) FROM stdin;
\.


--
-- Data for Name: cuenta_funcionario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cuenta_funcionario (id_usuario, id_cargo) FROM stdin;
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
-- Data for Name: detalle_factura; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_factura (id_detalle, id_factura, nombre, costo) FROM stdin;
\.


--
-- Data for Name: evento_caso_social; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_caso_social (id_evento_caso, id_caso, event, "time") FROM stdin;
\.


--
-- Data for Name: evento_multa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_multa (id_evento_multa, id_multa, event, "time") FROM stdin;
\.


--
-- Data for Name: evento_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.evento_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
\.


--
-- Data for Name: factura_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.factura_tramite (id_factura, id_tramite) FROM stdin;
\.


--
-- Data for Name: inmueble_urbano; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, fecha_ultimo_avaluo, tipo_inmueble, id_registro_municipal) FROM stdin;
\.


--
-- Data for Name: institucion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.institucion (id_institucion, nombre_completo, nombre_corto) FROM stdin;
\.


--
-- Data for Name: institucion_banco; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.institucion_banco (id_institucion, id_banco, numero_cuenta, nombre_titular, documento_de_identificacion, id_institucion_banco) FROM stdin;
\.


--
-- Data for Name: multa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.multa (id_multa, id_tipo_tramite, datos, costo, fecha_creacion, codigo_multa, consecutivo, id_usuario, cedula, nacionalidad, url_certificado, aprobado, url_boleta) FROM stdin;
\.


--
-- Data for Name: notificacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notificacion (id_notificacion, id_procedimiento, emisor, receptor, descripcion, status, fecha, estado, concepto) FROM stdin;
\.


--
-- Data for Name: operacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.operacion (id_operacion, nombre_op) FROM stdin;
\.


--
-- Data for Name: operatividad_terminal; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.operatividad_terminal (id_operatividad_terminal, destino, tipo, monto, tasa, habilitado) FROM stdin;
\.


--
-- Data for Name: ordenanza; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ordenanza (id_ordenanza, descripcion, tarifa, id_valor, habilitado) FROM stdin;
\.


--
-- Data for Name: ordenanza_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ordenanza_tramite (id_ordenanza_tramite, id_tramite, id_tarifa, utmm, valor_calc, factor, factor_value, costo_ordenanza) FROM stdin;
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pago (id_pago, id_procedimiento, referencia, monto, fecha_de_pago, aprobado, id_banco, fecha_de_aprobacion, concepto, metodo_pago) FROM stdin;
\.


--
-- Data for Name: pago_manual; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pago_manual (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- Data for Name: parroquia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parroquia (id, nombre) FROM stdin;
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
\.


--
-- Data for Name: propietario_inmueble; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.propietario_inmueble (id_propietario_inmueble, id_propietario, id_inmueble) FROM stdin;
\.


--
-- Data for Name: recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recaudo (id_recaudo, nombre_largo, nombre_corto, obligatorio, planilla, extension) FROM stdin;
\.


--
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
\.


--
-- Data for Name: seccion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.seccion (id_seccion, nombre) FROM stdin;
\.


--
-- Data for Name: tarifa_inspeccion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tarifa_inspeccion (id_tarifa, id_ordenanza, id_tipo_tramite, formula, utiliza_codcat, id_variable) FROM stdin;
\.


--
-- Data for Name: template_certificado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.template_certificado (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- Data for Name: tipo_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, sufijo, nombre_corto, formato, planilla, certificado, utiliza_informacion_catastral, pago_previo, costo_utmm, planilla_rechazo) FROM stdin;
\.


--
-- Data for Name: tipo_tramite_recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_tramite_recaudo (id_tipo_tramite, id_recaudo, fisico) FROM stdin;
\.


--
-- Data for Name: tipo_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_usuario (id_tipo_usuario, descripcion) FROM stdin;
\.


--
-- Data for Name: tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramite (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla, url_certificado, aprobado, fecha_culminacion) FROM stdin;
\.


--
-- Data for Name: tramite_archivo_recaudo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramite_archivo_recaudo (id_tramite, url_archivo_recaudo) FROM stdin;
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono, id_contribuyente) FROM stdin;
\.


--
-- Data for Name: valor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.valor (id_valor, descripcion, valor_en_bs) FROM stdin;
\.


--
-- Data for Name: variable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable (id_var, nombre_variable) FROM stdin;
\.


--
-- Data for Name: variable_de_costo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable_de_costo (id_variable_de_costo, id_tipo_tramite, id_operacion, precedencia, aumento) FROM stdin;
\.


--
-- Data for Name: variable_ordenanza; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.variable_ordenanza (id_variable, nombre, nombre_plural) FROM stdin;
\.


--
-- Data for Name: base_task; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.base_task (task_id, name, kind, script) FROM stdin;
\.


--
-- Data for Name: chain_execution_config; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain_execution_config (chain_execution_config, chain_id, chain_name, run_at, max_instances, live, self_destruct, exclusive_execution, excluded_execution_configs, client_name) FROM stdin;
\.


--
-- Data for Name: chain_execution_parameters; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain_execution_parameters (chain_execution_config, chain_id, order_id, value) FROM stdin;
\.


--
-- Data for Name: database_connection; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.database_connection (database_connection, connect_string, comment) FROM stdin;
\.


--
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.execution_log (chain_execution_config, chain_id, task_id, name, script, kind, last_run, finished, returncode, pid) FROM stdin;
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.log (id, ts, client_name, pid, log_level, message) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.migrations (id, version) FROM stdin;
\.


--
-- Data for Name: run_status; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.run_status (run_status, start_status, execution_status, chain_id, current_execution_element, started, last_status_update, chain_execution_config) FROM stdin;
\.


--
-- Data for Name: task_chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.task_chain (chain_id, parent_id, task_id, run_uid, database_connection, ignore_error) FROM stdin;
\.


--
-- Data for Name: ano; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
--

COPY valores_fiscales.ano (id, descripcion) FROM stdin;
\.


--
-- Data for Name: construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
--

COPY valores_fiscales.construccion (valor_fiscal, id, tipo_construccion_id, ano_id) FROM stdin;
\.


--
-- Data for Name: sector; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
--

COPY valores_fiscales.sector (descripcion, parroquia_id, id) FROM stdin;
\.


--
-- Data for Name: terreno; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
--

COPY valores_fiscales.terreno (valor_fiscal, sector_id, id, ano_id) FROM stdin;
\.


--
-- Data for Name: tipo_construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: postgres
--

COPY valores_fiscales.tipo_construccion (descripcion, id) FROM stdin;
\.


--
-- Name: actividad_economica_contribuy_id_actividad_economica_contri_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_contribuy_id_actividad_economica_contri_seq', 1, false);


--
-- Name: actividad_economica_exoneraci_id_actividad_economica_exoner_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_exoneraci_id_actividad_economica_exoner_seq', 1, false);


--
-- Name: actividad_economica_id_actividad_economica_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.actividad_economica_id_actividad_economica_seq', 1, false);


--
-- Name: avaluo_inmueble_id_avaluo_inmueble_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.avaluo_inmueble_id_avaluo_inmueble_seq', 1, false);


--
-- Name: categoria_propaganda_id_categoria_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.categoria_propaganda_id_categoria_propaganda_seq', 1, false);


--
-- Name: contribuyente_exoneracion_id_contribuyente_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.contribuyente_exoneracion_id_contribuyente_exoneracion_seq', 1, false);


--
-- Name: contribuyente_id_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.contribuyente_id_contribuyente_seq', 1, false);


--
-- Name: convenio_id_convenio_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.convenio_id_convenio_seq', 1, false);


--
-- Name: credito_fiscal_id_credito_fiscal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.credito_fiscal_id_credito_fiscal_seq', 1, false);


--
-- Name: dias_feriados_id_dia_feriado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.dias_feriados_id_dia_feriado_seq', 1, false);


--
-- Name: evento_fraccion_id_evento_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.evento_fraccion_id_evento_fraccion_seq', 1, false);


--
-- Name: evento_solicitud_id_evento_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.evento_solicitud_id_evento_solicitud_seq', 1, false);


--
-- Name: factor_id_factor_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.factor_id_factor_seq', 1, false);


--
-- Name: fraccion_id_fraccion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.fraccion_id_fraccion_seq', 1, false);


--
-- Name: inmueble_contribuyente_id_inmueble_contribuyente_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.inmueble_contribuyente_id_inmueble_contribuyente_seq', 1, false);


--
-- Name: liquidacion_descuento_id_liquidacion_descuento_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.liquidacion_descuento_id_liquidacion_descuento_seq', 1, false);


--
-- Name: liquidacion_id_liquidacion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.liquidacion_id_liquidacion_seq', 1, false);


--
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.multa_id_multa_seq', 1, false);


--
-- Name: plazo_exoneracion_id_plazo_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.plazo_exoneracion_id_plazo_exoneracion_seq', 1, false);


--
-- Name: procedimiento_exoneracion_id_procedimiento_exoneracion_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.procedimiento_exoneracion_id_procedimiento_exoneracion_seq', 1, false);


--
-- Name: ramo_id_ramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.ramo_id_ramo_seq', 1, false);


--
-- Name: registro_municipal_id_registro_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.registro_municipal_id_registro_municipal_seq', 1, false);


--
-- Name: registro_municipal_referencia_municipal_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.registro_municipal_referencia_municipal_seq', 8000000000, false);


--
-- Name: solicitud_id_solicitud_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.solicitud_id_solicitud_seq', 1, false);


--
-- Name: subramo_id_subramo_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.subramo_id_subramo_seq', 1, false);


--
-- Name: tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_actividad_econ_id_tabulador_aseo_actividad_e_seq', 1, false);


--
-- Name: tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_aseo_residencial_id_tabulador_aseo_residencial_seq', 1, false);


--
-- Name: tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_actividad_econo_id_tabulador_gas_actividad_ec_seq', 1, false);


--
-- Name: tabulador_gas_id_tabulador_gas_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_id_tabulador_gas_seq', 1, false);


--
-- Name: tabulador_gas_residencial_id_tabulador_gas_residencial_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tabulador_gas_residencial_id_tabulador_gas_residencial_seq', 1, false);


--
-- Name: tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tipo_aviso_propaganda_id_tipo_aviso_propaganda_seq', 1, false);


--
-- Name: tipo_multa_id_tipo_multa_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.tipo_multa_id_tipo_multa_seq', 1, false);


--
-- Name: usuario_enlazado_id_usuario_enlazado_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.usuario_enlazado_id_usuario_enlazado_seq', 1, false);


--
-- Name: verificacion_email_id_verificacion_email_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.verificacion_email_id_verificacion_email_seq', 1, false);


--
-- Name: verificacion_telefono_id_verificacion_telefono_seq; Type: SEQUENCE SET; Schema: impuesto; Owner: postgres
--

SELECT pg_catalog.setval('impuesto.verificacion_telefono_id_verificacion_telefono_seq', 1, false);


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 1, false);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 1, false);


--
-- Name: cargo_id_cargo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cargo_id_cargo_seq', 1, false);


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
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.evento_multa_id_evento_multa_seq', 1, false);


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_casos_sociales_id_evento_caso_seq', 1, false);


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 1, false);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, false);


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inmueble_urbano_id_inmueble_seq', 1, false);


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.multa_id_multa_seq', 1, false);


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1, false);


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, false);


--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.operatividad_terminal_id_operatividad_terminal_seq', 1, false);


--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ordenanzas_id_ordenanza_seq', 1, false);


--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ordenanzas_tramites_id_ordenanza_tramite_seq', 1, false);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 1, false);


--
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 1, false);


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permiso_de_acceso_id_permiso_seq', 1, false);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 1, false);


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.propietarios_inmuebles_id_propietario_inmueble_seq', 1, false);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, false);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 1, false);


--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tarifas_inspeccion_id_tarifa_seq', 1, false);


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_certificados_id_template_certificado_seq', 1, false);


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 1, false);


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 1, false);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 1, false);


--
-- Name: valores_id_valor_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.valores_id_valor_seq', 1, false);


--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.variables_ordenanzas_id_variable_seq', 1, false);


--
-- Name: base_task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.base_task_task_id_seq', 1, false);


--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.chain_execution_config_chain_execution_config_seq', 1, false);


--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.database_connection_database_connection_seq', 1, false);


--
-- Name: log_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.log_id_seq', 1, false);


--
-- Name: run_status_run_status_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.run_status_run_status_seq', 1, false);


--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.task_chain_chain_id_seq', 1, false);


--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.ano_fiscal_id_seq', 1, false);


--
-- Name: construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.construccion_id_seq', 1, false);


--
-- Name: sector_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.sector_id_seq', 1, false);


--
-- Name: terreno_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.terreno_id_seq', 1, false);


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: postgres
--

SELECT pg_catalog.setval('valores_fiscales.tipo_construccion_id_seq', 1, false);


--
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_pkey PRIMARY KEY (id_actividad_economica_contribuyente);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_pkey PRIMARY KEY (id_actividad_economica_exoneracion);


--
-- Name: actividad_economica actividad_economica_numero_referencia_key; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_numero_referencia_key UNIQUE (numero_referencia);


--
-- Name: actividad_economica actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica
    ADD CONSTRAINT actividad_economica_pkey PRIMARY KEY (id_actividad_economica);


--
-- Name: avaluo_inmueble avaluo_inmueble_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_pkey PRIMARY KEY (id_avaluo_inmueble);


--
-- Name: categoria_propaganda categoria_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.categoria_propaganda
    ADD CONSTRAINT categoria_propaganda_pkey PRIMARY KEY (id_categoria_propaganda);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_pkey PRIMARY KEY (id_contribuyente_exoneracion);


--
-- Name: contribuyente contribuyente_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_pkey PRIMARY KEY (id_contribuyente);


--
-- Name: contribuyente contribuyente_tipo_documento_documento_key; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_tipo_documento_documento_key UNIQUE (tipo_documento, documento);


--
-- Name: convenio convenio_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_pkey PRIMARY KEY (id_convenio);


--
-- Name: credito_fiscal credito_fiscal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.credito_fiscal
    ADD CONSTRAINT credito_fiscal_pkey PRIMARY KEY (id_credito_fiscal);


--
-- Name: dias_feriados dias_feriados_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.dias_feriados
    ADD CONSTRAINT dias_feriados_pkey PRIMARY KEY (id_dia_feriado);


--
-- Name: evento_fraccion evento_fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_pkey PRIMARY KEY (id_evento_fraccion);


--
-- Name: evento_solicitud evento_solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_pkey PRIMARY KEY (id_evento_solicitud);


--
-- Name: factor factor_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.factor
    ADD CONSTRAINT factor_pkey PRIMARY KEY (id_factor);


--
-- Name: fraccion fraccion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_pkey PRIMARY KEY (id_fraccion);


--
-- Name: liquidacion_descuento liquidacion_descuento_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_pkey PRIMARY KEY (id_liquidacion_descuento);


--
-- Name: liquidacion liquidacion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_pkey PRIMARY KEY (id_liquidacion);


--
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- Name: plazo_exoneracion plazo_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.plazo_exoneracion
    ADD CONSTRAINT plazo_exoneracion_pkey PRIMARY KEY (id_plazo_exoneracion);


--
-- Name: ramo_exoneracion procedimiento_exoneracion_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_pkey PRIMARY KEY (id_ramo_exoneracion);


--
-- Name: ramo ramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo
    ADD CONSTRAINT ramo_pkey PRIMARY KEY (id_ramo);


--
-- Name: registro_municipal registro_municipal_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_pkey PRIMARY KEY (id_registro_municipal);


--
-- Name: solicitud solicitud_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_pkey PRIMARY KEY (id_solicitud);


--
-- Name: subramo subramo_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_pkey PRIMARY KEY (id_subramo);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_pkey PRIMARY KEY (id_tabulador_aseo_actividad_economica);


--
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_pkey PRIMARY KEY (id_tabulador_aseo_residencial);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_pkey PRIMARY KEY (id_tabulador_gas_actividad_economica);


--
-- Name: tabulador_gas tabulador_gas_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_pkey PRIMARY KEY (id_tabulador_gas);


--
-- Name: tabulador_gas_residencial tabulador_gas_residencial_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_pkey PRIMARY KEY (id_tabulador_gas_residencial);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_pkey PRIMARY KEY (id_tipo_aviso_propaganda);


--
-- Name: tipo_multa tipo_multa_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_multa
    ADD CONSTRAINT tipo_multa_pkey PRIMARY KEY (id_tipo_multa);


--
-- Name: usuario_enlazado usuario_enlazado_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_pkey PRIMARY KEY (id_usuario_enlazado);


--
-- Name: verificacion_email verificacion_email_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_pkey PRIMARY KEY (id_verificacion_email);


--
-- Name: verificacion_telefono verificacion_telefono_pkey; Type: CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_pkey PRIMARY KEY (id_verificacion_telefono);


--
-- Name: banco bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.banco
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- Name: campo campos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- Name: cargo cargo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_pkey PRIMARY KEY (id_cargo);


--
-- Name: caso_social casos_sociales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_pkey PRIMARY KEY (id_caso);


--
-- Name: certificado certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id_certificado);


--
-- Name: cuenta_funcionario cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
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
-- Name: evento_multa evento_multa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_pkey PRIMARY KEY (id_evento_multa);


--
-- Name: evento_tramite eventos_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_pkey PRIMARY KEY (id_evento_tramite);


--
-- Name: factura_tramite facturas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_pkey PRIMARY KEY (id_factura);


--
-- Name: inmueble_urbano inmueble_urbano_cod_catastral_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_cod_catastral_key UNIQUE (cod_catastral);


--
-- Name: inmueble_urbano inmueble_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_pkey PRIMARY KEY (id_inmueble);


--
-- Name: institucion instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- Name: notificacion notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificacion
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- Name: operacion operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operacion
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- Name: ordenanza ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_pkey PRIMARY KEY (id_ordenanza);


--
-- Name: ordenanza_tramite ordenanzas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_pkey PRIMARY KEY (id_ordenanza_tramite);


--
-- Name: pago pago_id_banco_referencia_metodo_pago_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_id_banco_referencia_metodo_pago_key UNIQUE (id_banco, referencia, metodo_pago);


--
-- Name: pago_manual pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- Name: pago pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
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
-- Name: propietario_inmueble propietarios_inmuebles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_pkey PRIMARY KEY (id_propietario_inmueble);


--
-- Name: recaudo recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudo
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- Name: recuperacion recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_pkey PRIMARY KEY (id_recuperacion);


--
-- Name: seccion secciones_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seccion
    ADD CONSTRAINT secciones_pk PRIMARY KEY (id_seccion);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_pkey PRIMARY KEY (id_tarifa);


--
-- Name: template_certificado templates_certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_pkey PRIMARY KEY (id_template_certificado);


--
-- Name: tipo_tramite tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- Name: tipo_usuario tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_usuario
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- Name: tramite tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- Name: usuario usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- Name: usuario usuarios_nombre_de_usuario_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_nombre_de_usuario_key UNIQUE (nombre_de_usuario);


--
-- Name: usuario usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: valor valores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valor
    ADD CONSTRAINT valores_pkey PRIMARY KEY (id_valor);


--
-- Name: variable_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- Name: variable_ordenanza variables_ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_ordenanza
    ADD CONSTRAINT variables_ordenanzas_pkey PRIMARY KEY (id_variable);


--
-- Name: variable variables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- Name: base_task base_task_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_name_key UNIQUE (name);


--
-- Name: base_task base_task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_pkey PRIMARY KEY (task_id);


--
-- Name: chain_execution_config chain_execution_config_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_name_key UNIQUE (chain_name);


--
-- Name: chain_execution_config chain_execution_config_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_pkey PRIMARY KEY (chain_execution_config);


--
-- Name: chain_execution_parameters chain_execution_parameters_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_pkey PRIMARY KEY (chain_execution_config, chain_id, order_id);


--
-- Name: database_connection database_connection_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.database_connection
    ADD CONSTRAINT database_connection_pkey PRIMARY KEY (database_connection);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: run_status run_status_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.run_status
    ADD CONSTRAINT run_status_pkey PRIMARY KEY (run_status);


--
-- Name: task_chain task_chain_parent_id_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_key UNIQUE (parent_id);


--
-- Name: task_chain task_chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_pkey PRIMARY KEY (chain_id);


--
-- Name: ano ano_fiscal_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.ano
    ADD CONSTRAINT ano_fiscal_pkey PRIMARY KEY (id);


--
-- Name: construccion construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_pkey PRIMARY KEY (id);


--
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- Name: terreno terreno_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_pkey PRIMARY KEY (id);


--
-- Name: tipo_construccion tipo_construccion_descripcion_key; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_descripcion_key UNIQUE (descripcion);


--
-- Name: tipo_construccion tipo_construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_pkey PRIMARY KEY (id);


--
-- Name: evento_fraccion eventos_fraccion_trigger; Type: TRIGGER; Schema: impuesto; Owner: postgres
--

CREATE TRIGGER eventos_fraccion_trigger BEFORE INSERT ON impuesto.evento_fraccion FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_fraccion_trigger_func();


--
-- Name: evento_solicitud eventos_solicitud_trigger; Type: TRIGGER; Schema: impuesto; Owner: postgres
--

CREATE TRIGGER eventos_solicitud_trigger BEFORE INSERT ON impuesto.evento_solicitud FOR EACH ROW EXECUTE FUNCTION impuesto.eventos_solicitud_trigger_func();


--
-- Name: tramite codigo_tramite_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigo_tramite_trg BEFORE INSERT ON public.tramite FOR EACH ROW EXECUTE FUNCTION public.codigo_tramite();


--
-- Name: caso_social codigos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigos_casos_sociales_trigger BEFORE INSERT ON public.caso_social FOR EACH ROW EXECUTE FUNCTION public.codigo_caso();


--
-- Name: multa codigos_multas_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER codigos_multas_trigger BEFORE INSERT ON public.multa FOR EACH ROW EXECUTE FUNCTION public.codigo_multa();


--
-- Name: evento_caso_social eventos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_casos_sociales_trigger BEFORE INSERT ON public.evento_caso_social FOR EACH ROW EXECUTE FUNCTION public.eventos_casos_sociales_trigger_func();


--
-- Name: evento_multa eventos_multa_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_multa_trigger BEFORE INSERT ON public.evento_multa FOR EACH ROW EXECUTE FUNCTION public.eventos_multa_trigger_func();


--
-- Name: evento_tramite eventos_tramite_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER eventos_tramite_trigger BEFORE INSERT ON public.evento_tramite FOR EACH ROW EXECUTE FUNCTION public.eventos_tramite_trigger_func();


--
-- Name: notificacion insert_notificaciones_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_notificaciones_trigger BEFORE INSERT ON public.notificacion FOR EACH ROW EXECUTE FUNCTION public.insert_notificacion_trigger_func();


--
-- Name: valor tipos_tramites_costo_utmm_trig; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tipos_tramites_costo_utmm_trig AFTER UPDATE ON public.valor FOR EACH ROW WHEN (((new.descripcion)::text = 'UTMM'::text)) EXECUTE FUNCTION public.tipos_tramites_costo_utmm_trigger_func();


--
-- Name: base_task trig_task_chain_fixer; Type: TRIGGER; Schema: timetable; Owner: postgres
--

CREATE TRIGGER trig_task_chain_fixer BEFORE DELETE ON timetable.base_task FOR EACH ROW EXECUTE FUNCTION timetable.trig_chain_fixer();


--
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: actividad_economica_contribuyente actividad_economica_contribuyente_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_contribuyente
    ADD CONSTRAINT actividad_economica_contribuyente_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: actividad_economica_exoneracion actividad_economica_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.actividad_economica_exoneracion
    ADD CONSTRAINT actividad_economica_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: avaluo_inmueble avaluo_inmueble_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.avaluo_inmueble
    ADD CONSTRAINT avaluo_inmueble_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: contribuyente_exoneracion contribuyente_exoneracion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente_exoneracion
    ADD CONSTRAINT contribuyente_exoneracion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: contribuyente contribuyente_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.contribuyente
    ADD CONSTRAINT contribuyente_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: convenio convenio_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.convenio
    ADD CONSTRAINT convenio_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: evento_fraccion evento_fraccion_id_fraccion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_fraccion
    ADD CONSTRAINT evento_fraccion_id_fraccion_fkey FOREIGN KEY (id_fraccion) REFERENCES impuesto.fraccion(id_fraccion) ON DELETE CASCADE;


--
-- Name: evento_solicitud evento_solicitud_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.evento_solicitud
    ADD CONSTRAINT evento_solicitud_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud) ON DELETE CASCADE;


--
-- Name: fraccion fraccion_id_convenio_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.fraccion
    ADD CONSTRAINT fraccion_id_convenio_fkey FOREIGN KEY (id_convenio) REFERENCES impuesto.convenio(id_convenio);


--
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: inmueble_contribuyente_natural inmueble_contribuyente_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.inmueble_contribuyente_natural
    ADD CONSTRAINT inmueble_contribuyente_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: liquidacion_descuento liquidacion_descuento_id_liquidacion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion_descuento
    ADD CONSTRAINT liquidacion_descuento_id_liquidacion_fkey FOREIGN KEY (id_liquidacion) REFERENCES impuesto.liquidacion(id_liquidacion);


--
-- Name: liquidacion liquidacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: liquidacion liquidacion_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: liquidacion liquidacion_id_subramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.liquidacion
    ADD CONSTRAINT liquidacion_id_subramo_fkey FOREIGN KEY (id_subramo) REFERENCES impuesto.subramo(id_subramo);


--
-- Name: multa multa_id_solicitud_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_solicitud_fkey FOREIGN KEY (id_solicitud) REFERENCES impuesto.solicitud(id_solicitud);


--
-- Name: multa multa_id_tipo_multa_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.multa
    ADD CONSTRAINT multa_id_tipo_multa_fkey FOREIGN KEY (id_tipo_multa) REFERENCES impuesto.tipo_multa(id_tipo_multa);


--
-- Name: ramo_exoneracion procedimiento_exoneracion_id_plazo_exoneracion_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT procedimiento_exoneracion_id_plazo_exoneracion_fkey FOREIGN KEY (id_plazo_exoneracion) REFERENCES impuesto.plazo_exoneracion(id_plazo_exoneracion);


--
-- Name: ramo_exoneracion ramo_exoneracion_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.ramo_exoneracion
    ADD CONSTRAINT ramo_exoneracion_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- Name: registro_municipal registro_municipal_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal
    ADD CONSTRAINT registro_municipal_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: registro_municipal_verificacion registro_municipal_verificacion_id_verificacion_telefono_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.registro_municipal_verificacion
    ADD CONSTRAINT registro_municipal_verificacion_id_verificacion_telefono_fkey FOREIGN KEY (id_verificacion_telefono) REFERENCES impuesto.verificacion_telefono(id_verificacion_telefono) ON DELETE CASCADE;


--
-- Name: solicitud solicitud_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: solicitud solicitud_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: solicitud solicitud_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.solicitud
    ADD CONSTRAINT solicitud_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: subramo subramo_id_ramo_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.subramo
    ADD CONSTRAINT subramo_id_ramo_fkey FOREIGN KEY (id_ramo) REFERENCES impuesto.ramo(id_ramo);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_aseo_actividad_economica tabulador_aseo_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_actividad_economica
    ADD CONSTRAINT tabulador_aseo_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: tabulador_aseo_residencial tabulador_aseo_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_aseo_residencial
    ADD CONSTRAINT tabulador_aseo_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tabulador_gas_actividad_economica tabulador_gas_actividad_economica_numero_referencia_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_actividad_economica
    ADD CONSTRAINT tabulador_gas_actividad_economica_numero_referencia_fkey FOREIGN KEY (numero_referencia) REFERENCES impuesto.actividad_economica(numero_referencia);


--
-- Name: tabulador_gas tabulador_gas_id_actividad_economica_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas
    ADD CONSTRAINT tabulador_gas_id_actividad_economica_fkey FOREIGN KEY (id_actividad_economica) REFERENCES impuesto.actividad_economica(id_actividad_economica);


--
-- Name: tabulador_gas_residencial tabulador_gas_residencial_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tabulador_gas_residencial
    ADD CONSTRAINT tabulador_gas_residencial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_categoria_propaganda_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_categoria_propaganda_fkey FOREIGN KEY (id_categoria_propaganda) REFERENCES impuesto.categoria_propaganda(id_categoria_propaganda);


--
-- Name: tipo_aviso_propaganda tipo_aviso_propaganda_id_valor_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.tipo_aviso_propaganda
    ADD CONSTRAINT tipo_aviso_propaganda_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- Name: usuario_enlazado usuario_enlazado_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.usuario_enlazado
    ADD CONSTRAINT usuario_enlazado_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: verificacion_email verificacion_email_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_email
    ADD CONSTRAINT verificacion_email_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: verificacion_telefono verificacion_telefono_id_usuario_fkey; Type: FK CONSTRAINT; Schema: impuesto; Owner: postgres
--

ALTER TABLE ONLY impuesto.verificacion_telefono
    ADD CONSTRAINT verificacion_telefono_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: campo_tramite campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campo(id_campo);


--
-- Name: campo_tramite campos_tramites_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES public.seccion(id_seccion) NOT VALID;


--
-- Name: campo_tramite campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: cargo cargo_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: cargo cargo_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargo
    ADD CONSTRAINT cargo_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- Name: caso_social casos_sociales_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: caso_social casos_sociales_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: certificado certificados_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_cargo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_cargo_fkey FOREIGN KEY (id_cargo) REFERENCES public.cargo(id_cargo);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: datos_facebook datos_facebook_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_facebook
    ADD CONSTRAINT datos_facebook_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: detalle_factura detalles_facturas_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT detalles_facturas_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.factura_tramite(id_factura);


--
-- Name: evento_multa evento_multa_id_multa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_id_multa_fkey FOREIGN KEY (id_multa) REFERENCES public.multa(id_multa);


--
-- Name: evento_tramite eventos_tramite_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite) ON DELETE CASCADE;


--
-- Name: factura_tramite facturas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: inmueble_urbano inmueble_urbano_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: inmueble_urbano inmueble_urbano_id_registro_municipal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_registro_municipal_fkey FOREIGN KEY (id_registro_municipal) REFERENCES impuesto.registro_municipal(id_registro_municipal);


--
-- Name: institucion_banco instituciones_bancos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: institucion_banco instituciones_bancos_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: multa multa_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: multa multa_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: ordenanza ordenanzas_id_valor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tarifa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tarifa_fkey FOREIGN KEY (id_tarifa) REFERENCES public.tarifa_inspeccion(id_tarifa);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: pago pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: pago_manual pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pago(id_pago);


--
-- Name: pago_manual pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuenta_funcionario(id_usuario);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: propietario_inmueble propietarios_inmuebles_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: propietario_inmueble propietarios_inmuebles_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);


--
-- Name: recuperacion recuperacion_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_ordenanza_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_ordenanza_fkey FOREIGN KEY (id_ordenanza) REFERENCES public.ordenanza(id_ordenanza);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_variable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_variable_fkey FOREIGN KEY (id_variable) REFERENCES public.variable_ordenanza(id_variable);


--
-- Name: template_certificado templates_certificados_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tipo_tramite tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudo(id_recaudo);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite_archivo_recaudo tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite_archivo_recaudo
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: tramite tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite tramites_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: usuario usuario_id_contribuyente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_id_contribuyente_fkey FOREIGN KEY (id_contribuyente) REFERENCES impuesto.contribuyente(id_contribuyente);


--
-- Name: usuario usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- Name: variable_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operacion(id_operacion);


--
-- Name: variable_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: chain_execution_config chain_execution_config_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_execution_config_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_execution_config_fkey FOREIGN KEY (chain_execution_config) REFERENCES timetable.chain_execution_config(chain_execution_config) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_database_connection_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_database_connection_fkey FOREIGN KEY (database_connection) REFERENCES timetable.database_connection(database_connection) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_parent_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.base_task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: construccion construccion_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: construccion construccion_tipo_construccion_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_tipo_construccion_id_fkey FOREIGN KEY (tipo_construccion_id) REFERENCES valores_fiscales.tipo_construccion(id);


--
-- Name: sector sector_parroquia_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_parroquia_id_fkey FOREIGN KEY (parroquia_id) REFERENCES public.parroquia(id);


--
-- Name: terreno terreno_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: terreno terreno_sector_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: postgres
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES valores_fiscales.sector(id);


--
-- PostgreSQL database dump complete
--

