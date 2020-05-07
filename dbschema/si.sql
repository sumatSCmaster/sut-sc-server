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
-- Name: timetable; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA timetable;


--
-- Name: valores_fiscales; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA valores_fiscales;


--
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: -
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK ((((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR (VALUE = '@reboot'::text) OR (VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text)));


--
-- Name: execution_status; Type: TYPE; Schema: timetable; Owner: -
--

CREATE TYPE timetable.execution_status AS ENUM (
    'STARTED',
    'CHAIN_FAILED',
    'CHAIN_DONE',
    'DEAD'
);


--
-- Name: log_type; Type: TYPE; Schema: timetable; Owner: -
--

CREATE TYPE timetable.log_type AS ENUM (
    'DEBUG',
    'NOTICE',
    'LOG',
    'ERROR',
    'PANIC',
    'USER'
);


--
-- Name: task_kind; Type: TYPE; Schema: timetable; Owner: -
--

CREATE TYPE timetable.task_kind AS ENUM (
    'SQL',
    'SHELL',
    'BUILTIN'
);


--
-- Name: casos_sociales_transicion(text, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: codigo_caso(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: codigo_multa(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: codigo_tramite(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: complete_multa_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: complete_tramite_state(integer, text, json, character varying, boolean); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: evento_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: eventos_casos_sociales_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: eventos_multa_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: eventos_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: caso_social_fsm(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.caso_social_fsm(text) (
    SFUNC = public.casos_sociales_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: caso_social; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: evento_caso_social; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evento_caso_social (
    id_evento_caso integer NOT NULL,
    id_caso integer NOT NULL,
    event text,
    "time" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: institucion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institucion (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


--
-- Name: tipo_tramite; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: casos_sociales_state; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: insert_caso(integer, json, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: multa_transicion(text, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: multa_fsm(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.multa_fsm(text) (
    SFUNC = public.multa_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


--
-- Name: evento_multa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evento_multa (
    id_evento_multa integer NOT NULL,
    id_multa integer NOT NULL,
    event character varying NOT NULL,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: multa; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: multa_state; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: insert_multa(integer, json, character varying, bigint, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: insert_notificacion_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: tramites_eventos_transicion(text, text); Type: FUNCTION; Schema: public; Owner: -
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
            WHEN 'enproceso_pd' THEN 'enproceso'
            WHEN 'enproceso_ompu' THEN 'enproceso' 
            WHEN 'finalizar_tl' THEN 'finalizado'
            ELSE 'error'
        END
    WHEN 'validando' THEN
        CASE event
            WHEN 'enproceso_pa' THEN 'enproceso'
            WHEN 'enproceso_cr' THEN 'enproceso'
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
            ELSE 'error'        
        END
    ELSE 'error'
END
$$;


--
-- Name: tramite_evento_fsm(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.tramite_evento_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


--
-- Name: evento_tramite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evento_tramite (
    id_evento_tramite integer NOT NULL,
    id_tramite integer NOT NULL,
    event text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tramite; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: tramites_state_with_resources; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: insert_tramite(integer, json, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: tipos_tramites_costo_utmm_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: tramite_eventos_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_caso_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_multa_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_multa_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_tramite_state(integer, text, json, numeric, character varying); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: validate_payments(jsonb); Type: FUNCTION; Schema: public; Owner: -
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
        AND monto = (inputRow ->> 'Monto')::numeric
        AND fecha_de_pago = (inputRow ->> 'Fecha')::timestamptz;

        IF idPago IS NOT NULL THEN
            --aprueba el pago y guarda el momento en que se aprobo el pago
            UPDATE pago SET aprobado = true, fecha_de_aprobacion = (SELECT NOW()::timestamptz) WHERE id_pago = idPago;

            --obtiene el resultado del row y lo convierte en json 
            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'TRAMITE' THEN
                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, tramite.codigo_tramite AS codigoTramite, tipo_tramite.sufijo AS sufijo, tipo_tramite.id_tipo_tramite AS tipotramite  from pago 
                INNER JOIN tramite ON pago.id_procedimiento = tramite.id_tramite 
                INNER JOIN tipo_tramite ON tipo_tramite.id_tipo_tramite = tramite.id_tipo_tramite where pago.id_pago = idPago) row;
            END IF;

            IF (SELECT concepto FROM pago WHERE id_pago = idPago) = 'MULTA' THEN
                select row_to_json(row)::jsonb into dataPago from (select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, multa.codigo_multa AS codigoMulta, tipo_tramite.sufijo AS sufijo, tipo_tramite.id_tipo_tramite AS tipotramite  from pago 
                INNER JOIN multa ON pago.id_procedimiento = multa.id_multa 
                INNER JOIN tipo_tramite ON tipo_tramite.id_tipo_tramite = multa.id_tipo_tramite where pago.id_pago = idPago) row;
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


--
-- Name: _validate_json_schema_type(text, jsonb); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: cron_element_to_array(text, text); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: get_running_jobs(bigint); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: get_task_id(text); Type: FUNCTION; Schema: timetable; Owner: -
--

CREATE FUNCTION timetable.get_task_id(task_name text) RETURNS bigint
    LANGUAGE sql STRICT
    AS $_$
	SELECT task_id FROM timetable.base_task WHERE name = $1;
$_$;


--
-- Name: insert_base_task(text, bigint); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: is_cron_in_time(timetable.cron, timestamp with time zone); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: job_add(text, text, text, timetable.task_kind, timetable.cron, integer, boolean, boolean); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: task_chain_delete(bigint, bigint); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: trig_chain_fixer(); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: validate_json_schema(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: timetable; Owner: -
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


--
-- Name: banco; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.banco (
    id_banco integer NOT NULL,
    nombre character varying
);


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bancos_id_banco_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.banco.id_banco;


--
-- Name: campo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campo (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying,
    validacion character varying,
    col integer
);


--
-- Name: campo_tramite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campo_tramite (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado character varying,
    id_seccion integer,
    CONSTRAINT campos_tramites_estado_check CHECK (((estado)::text = ANY (ARRAY['iniciado'::text, 'validando'::text, 'enproceso'::text, 'ingresardatos'::text, 'validando'::text, 'finalizado'::text])))
);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campos_id_campo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campos_id_campo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campo.id_campo;


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.casos_sociales_id_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.casos_sociales_id_caso_seq OWNED BY public.caso_social.id_caso;


--
-- Name: certificado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certificado (
    id_certificado integer NOT NULL,
    id_tramite integer,
    url_certificado character varying
);


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.certificados_id_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.certificados_id_certificado_seq OWNED BY public.certificado.id_certificado;


--
-- Name: cuenta_funcionario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cuenta_funcionario (
    id_usuario integer NOT NULL,
    id_institucion integer
);


--
-- Name: datos_facebook; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datos_facebook (
    id_usuario integer NOT NULL,
    id_facebook character varying NOT NULL
);


--
-- Name: datos_google; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


--
-- Name: detalle_factura; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detalle_factura (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    nombre character varying,
    costo numeric
);


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.detalles_facturas_id_detalle_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.detalles_facturas_id_detalle_seq OWNED BY public.detalle_factura.id_detalle;


--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evento_multa_id_evento_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evento_multa_id_evento_multa_seq OWNED BY public.evento_multa.id_evento_multa;


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.eventos_casos_sociales_id_evento_caso_seq OWNED BY public.evento_caso_social.id_evento_caso;


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.eventos_tramite_id_evento_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.eventos_tramite_id_evento_tramite_seq OWNED BY public.evento_tramite.id_evento_tramite;


--
-- Name: factura_tramite; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.factura_tramite (
    id_factura integer NOT NULL,
    id_tramite integer
);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facturas_tramites_id_factura_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facturas_tramites_id_factura_seq OWNED BY public.factura_tramite.id_factura;


--
-- Name: inmueble_urbano; Type: TABLE; Schema: public; Owner: -
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
    fecha_ultimo_avaluo timestamp with time zone,
    tipo_inmueble character varying
);


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inmueble_urbano_id_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inmueble_urbano_id_inmueble_seq OWNED BY public.inmueble_urbano.id_inmueble;


--
-- Name: parroquia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);


--
-- Name: inmueble_urbano_view; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: institucion_banco; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institucion_banco (
    id_institucion_banco integer NOT NULL,
    id_institucion integer NOT NULL,
    id_banco integer NOT NULL,
    numero_cuenta character varying,
    nombre_titular character varying,
    documento_de_identificacion character varying
);


--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instituciones_bancos_id_instituciones_bancos_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instituciones_bancos_id_instituciones_bancos_seq OWNED BY public.institucion_banco.id_institucion_banco;


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instituciones_id_institucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.institucion.id_institucion;


--
-- Name: multa_id_multa_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.multa_id_multa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: multa_id_multa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.multa_id_multa_seq OWNED BY public.multa.id_multa;


--
-- Name: notificacion; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT notificacion_concepto_check CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text]))),
    CONSTRAINT notificacion_concepto_check1 CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text]))),
    CONSTRAINT notificacion_concepto_check2 CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text])))
);


--
-- Name: notificacion_multa_view; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: notificacion_tramite_view; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notificaciones_id_notificacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificacion.id_notificacion;


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operaciones_id_operacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operacion (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


--
-- Name: operatividad_terminal; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operatividad_terminal_id_operatividad_terminal_seq OWNED BY public.operatividad_terminal.id_operatividad_terminal;


--
-- Name: ordenanza; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ordenanza (
    id_ordenanza integer NOT NULL,
    descripcion character varying NOT NULL,
    tarifa character varying,
    id_valor integer,
    habilitado boolean DEFAULT true
);


--
-- Name: ordenanza_tramite; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ordenanzas_id_ordenanza_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ordenanzas_id_ordenanza_seq OWNED BY public.ordenanza.id_ordenanza;


--
-- Name: tarifa_inspeccion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tarifa_inspeccion (
    id_tarifa integer NOT NULL,
    id_ordenanza integer NOT NULL,
    id_tipo_tramite integer NOT NULL,
    formula character varying,
    utiliza_codcat boolean,
    id_variable integer
);


--
-- Name: ordenanzas_instancias_tramites; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ordenanzas_tramites_id_ordenanza_tramite_seq OWNED BY public.ordenanza_tramite.id_ordenanza_tramite;


--
-- Name: pago; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT pago_concepto_check CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text]))),
    CONSTRAINT pago_concepto_check1 CHECK (((concepto)::text = ANY (ARRAY['TRAMITE'::text, 'MULTA'::text])))
);


--
-- Name: pago_manual; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pago_manual (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pagos_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pago.id_pago;


--
-- Name: parroquias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parroquias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parroquias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parroquias_id_seq OWNED BY public.parroquia.id;


--
-- Name: permiso_de_acceso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permiso_de_acceso (
    id_permiso integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_tramite integer NOT NULL
);


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permiso_de_acceso_id_permiso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permiso_de_acceso_id_permiso_seq OWNED BY public.permiso_de_acceso.id_permiso;


--
-- Name: propietario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.propietario (
    id_propietario integer NOT NULL,
    razon_social character varying NOT NULL,
    cedula character varying,
    rif character varying,
    email character varying
);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.propietario_id_propietario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.propietario_id_propietario_seq OWNED BY public.propietario.id_propietario;


--
-- Name: propietario_inmueble; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.propietario_inmueble (
    id_propietario_inmueble integer NOT NULL,
    id_propietario integer NOT NULL,
    id_inmueble integer NOT NULL
);


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.propietarios_inmuebles_id_propietario_inmueble_seq OWNED BY public.propietario_inmueble.id_propietario_inmueble;


--
-- Name: recaudo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recaudo (
    id_recaudo integer NOT NULL,
    nombre_largo character varying,
    nombre_corto character varying,
    obligatorio boolean DEFAULT false,
    planilla text,
    extension text DEFAULT 'image/*'::text
);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recaudos_id_recaudo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudo.id_recaudo;


--
-- Name: recuperacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recuperacion (
    id_recuperacion integer NOT NULL,
    id_usuario integer,
    token_recuperacion character varying,
    usado boolean,
    fecha_recuperacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recuperacion_id_recuperacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recuperacion_id_recuperacion_seq OWNED BY public.recuperacion.id_recuperacion;


--
-- Name: seccion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seccion (
    id_seccion integer NOT NULL,
    nombre character varying
);


--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tarifas_inspeccion_id_tarifa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tarifas_inspeccion_id_tarifa_seq OWNED BY public.tarifa_inspeccion.id_tarifa;


--
-- Name: template_certificado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.template_certificado (
    id_template_certificado integer NOT NULL,
    id_tipo_tramite integer,
    link character varying
);


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.templates_certificados_id_template_certificado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.templates_certificados_id_template_certificado_seq OWNED BY public.template_certificado.id_template_certificado;


--
-- Name: tipo_tramite_recaudo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipo_tramite_recaudo (
    id_tipo_tramite integer,
    id_recaudo integer,
    fisico boolean
);


--
-- Name: tipo_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipo_usuario (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipos_tramites_id_tipo_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipo_tramite.id_tipo_tramite;


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipo_usuario.id_tipo_usuario;


--
-- Name: tramite_archivo_recaudo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tramite_archivo_recaudo (
    id_tramite integer,
    url_archivo_recaudo character varying
);


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tramites_id_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramite.id_tramite;


--
-- Name: tramites_state; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT usuarios_nacionalidad_check CHECK ((nacionalidad = ANY (ARRAY['V'::bpchar, 'E'::bpchar])))
);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuario.id_usuario;


--
-- Name: valor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.valor (
    id_valor integer NOT NULL,
    descripcion character varying NOT NULL,
    valor_en_bs numeric NOT NULL
);


--
-- Name: valores_id_valor_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.valores_id_valor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: valores_id_valor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.valores_id_valor_seq OWNED BY public.valor.id_valor;


--
-- Name: variables_id_var_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variables_id_var_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: variable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variable (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variables_de_costo_id_variable_de_costo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: variable_de_costo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variable_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);


--
-- Name: variable_ordenanza; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variable_ordenanza (
    id_variable integer NOT NULL,
    nombre character varying NOT NULL,
    nombre_plural character varying NOT NULL
);


--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variables_ordenanzas_id_variable_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.variables_ordenanzas_id_variable_seq OWNED BY public.variable_ordenanza.id_variable;


--
-- Name: base_task; Type: TABLE; Schema: timetable; Owner: -
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


--
-- Name: base_task_task_id_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.base_task_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: base_task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.base_task_task_id_seq OWNED BY timetable.base_task.task_id;


--
-- Name: chain_execution_config; Type: TABLE; Schema: timetable; Owner: -
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


--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.chain_execution_config_chain_execution_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.chain_execution_config_chain_execution_config_seq OWNED BY timetable.chain_execution_config.chain_execution_config;


--
-- Name: chain_execution_parameters; Type: TABLE; Schema: timetable; Owner: -
--

CREATE TABLE timetable.chain_execution_parameters (
    chain_execution_config bigint NOT NULL,
    chain_id bigint NOT NULL,
    order_id integer NOT NULL,
    value jsonb,
    CONSTRAINT chain_execution_parameters_order_id_check CHECK ((order_id > 0))
);


--
-- Name: database_connection; Type: TABLE; Schema: timetable; Owner: -
--

CREATE TABLE timetable.database_connection (
    database_connection bigint NOT NULL,
    connect_string text NOT NULL,
    comment text
);


--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.database_connection_database_connection_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.database_connection_database_connection_seq OWNED BY timetable.database_connection.database_connection;


--
-- Name: execution_log; Type: TABLE; Schema: timetable; Owner: -
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


--
-- Name: log; Type: TABLE; Schema: timetable; Owner: -
--

CREATE TABLE timetable.log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now(),
    client_name text,
    pid integer NOT NULL,
    log_level timetable.log_type NOT NULL,
    message text
);


--
-- Name: log_id_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.log_id_seq OWNED BY timetable.log.id;


--
-- Name: migrations; Type: TABLE; Schema: timetable; Owner: -
--

CREATE TABLE timetable.migrations (
    id bigint NOT NULL,
    version text NOT NULL
);


--
-- Name: run_status; Type: TABLE; Schema: timetable; Owner: -
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


--
-- Name: run_status_run_status_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.run_status_run_status_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: run_status_run_status_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.run_status_run_status_seq OWNED BY timetable.run_status.run_status;


--
-- Name: task_chain; Type: TABLE; Schema: timetable; Owner: -
--

CREATE TABLE timetable.task_chain (
    chain_id bigint NOT NULL,
    parent_id bigint,
    task_id bigint NOT NULL,
    run_uid text,
    database_connection bigint,
    ignore_error boolean DEFAULT false
);


--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE; Schema: timetable; Owner: -
--

CREATE SEQUENCE timetable.task_chain_chain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: -
--

ALTER SEQUENCE timetable.task_chain_chain_id_seq OWNED BY timetable.task_chain.chain_id;


--
-- Name: ano; Type: TABLE; Schema: valores_fiscales; Owner: -
--

CREATE TABLE valores_fiscales.ano (
    id integer NOT NULL,
    descripcion integer NOT NULL
);


--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: -
--

CREATE SEQUENCE valores_fiscales.ano_fiscal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: -
--

ALTER SEQUENCE valores_fiscales.ano_fiscal_id_seq OWNED BY valores_fiscales.ano.id;


--
-- Name: construccion; Type: TABLE; Schema: valores_fiscales; Owner: -
--

CREATE TABLE valores_fiscales.construccion (
    valor_fiscal numeric(14,2) NOT NULL,
    id bigint NOT NULL,
    tipo_construccion_id integer NOT NULL,
    ano_id integer NOT NULL
);


--
-- Name: construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: -
--

CREATE SEQUENCE valores_fiscales.construccion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: -
--

ALTER SEQUENCE valores_fiscales.construccion_id_seq OWNED BY valores_fiscales.construccion.id;


--
-- Name: tipo_construccion; Type: TABLE; Schema: valores_fiscales; Owner: -
--

CREATE TABLE valores_fiscales.tipo_construccion (
    descripcion text NOT NULL,
    id integer NOT NULL
);


--
-- Name: get_all_construcciones; Type: VIEW; Schema: valores_fiscales; Owner: -
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


--
-- Name: sector; Type: TABLE; Schema: valores_fiscales; Owner: -
--

CREATE TABLE valores_fiscales.sector (
    descripcion text NOT NULL,
    parroquia_id integer NOT NULL,
    id integer NOT NULL
);


--
-- Name: terreno; Type: TABLE; Schema: valores_fiscales; Owner: -
--

CREATE TABLE valores_fiscales.terreno (
    valor_fiscal numeric(14,2) NOT NULL,
    sector_id integer NOT NULL,
    id bigint NOT NULL,
    ano_id integer NOT NULL
);


--
-- Name: get_all_terrenos; Type: VIEW; Schema: valores_fiscales; Owner: -
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


--
-- Name: sector_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: -
--

CREATE SEQUENCE valores_fiscales.sector_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sector_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: -
--

ALTER SEQUENCE valores_fiscales.sector_id_seq OWNED BY valores_fiscales.sector.id;


--
-- Name: terreno_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: -
--

CREATE SEQUENCE valores_fiscales.terreno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: terreno_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: -
--

ALTER SEQUENCE valores_fiscales.terreno_id_seq OWNED BY valores_fiscales.terreno.id;


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE; Schema: valores_fiscales; Owner: -
--

CREATE SEQUENCE valores_fiscales.tipo_construccion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE OWNED BY; Schema: valores_fiscales; Owner: -
--

ALTER SEQUENCE valores_fiscales.tipo_construccion_id_seq OWNED BY valores_fiscales.tipo_construccion.id;


--
-- Name: banco id_banco; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banco ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- Name: campo id_campo; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campo ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- Name: caso_social id_caso; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caso_social ALTER COLUMN id_caso SET DEFAULT nextval('public.casos_sociales_id_caso_seq'::regclass);


--
-- Name: certificado id_certificado; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificado ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- Name: detalle_factura id_detalle; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_factura ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- Name: evento_caso_social id_evento_caso; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_caso_social ALTER COLUMN id_evento_caso SET DEFAULT nextval('public.eventos_casos_sociales_id_evento_caso_seq'::regclass);


--
-- Name: evento_multa id_evento_multa; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_multa ALTER COLUMN id_evento_multa SET DEFAULT nextval('public.evento_multa_id_evento_multa_seq'::regclass);


--
-- Name: evento_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- Name: factura_tramite id_factura; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_tramite ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


--
-- Name: inmueble_urbano id_inmueble; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inmueble_urbano ALTER COLUMN id_inmueble SET DEFAULT nextval('public.inmueble_urbano_id_inmueble_seq'::regclass);


--
-- Name: institucion id_institucion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- Name: institucion_banco id_institucion_banco; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion_banco ALTER COLUMN id_institucion_banco SET DEFAULT nextval('public.instituciones_bancos_id_instituciones_bancos_seq'::regclass);


--
-- Name: multa id_multa; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multa ALTER COLUMN id_multa SET DEFAULT nextval('public.multa_id_multa_seq'::regclass);


--
-- Name: notificacion id_notificacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificacion ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- Name: operatividad_terminal id_operatividad_terminal; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operatividad_terminal ALTER COLUMN id_operatividad_terminal SET DEFAULT nextval('public.operatividad_terminal_id_operatividad_terminal_seq'::regclass);


--
-- Name: ordenanza id_ordenanza; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza ALTER COLUMN id_ordenanza SET DEFAULT nextval('public.ordenanzas_id_ordenanza_seq'::regclass);


--
-- Name: ordenanza_tramite id_ordenanza_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza_tramite ALTER COLUMN id_ordenanza_tramite SET DEFAULT nextval('public.ordenanzas_tramites_id_ordenanza_tramite_seq'::regclass);


--
-- Name: pago id_pago; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- Name: parroquia id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parroquia ALTER COLUMN id SET DEFAULT nextval('public.parroquias_id_seq'::regclass);


--
-- Name: permiso_de_acceso id_permiso; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso_de_acceso ALTER COLUMN id_permiso SET DEFAULT nextval('public.permiso_de_acceso_id_permiso_seq'::regclass);


--
-- Name: propietario id_propietario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietario_id_propietario_seq'::regclass);


--
-- Name: propietario_inmueble id_propietario_inmueble; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario_inmueble ALTER COLUMN id_propietario_inmueble SET DEFAULT nextval('public.propietarios_inmuebles_id_propietario_inmueble_seq'::regclass);


--
-- Name: recaudo id_recaudo; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recaudo ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- Name: recuperacion id_recuperacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recuperacion ALTER COLUMN id_recuperacion SET DEFAULT nextval('public.recuperacion_id_recuperacion_seq'::regclass);


--
-- Name: tarifa_inspeccion id_tarifa; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifa_inspeccion ALTER COLUMN id_tarifa SET DEFAULT nextval('public.tarifas_inspeccion_id_tarifa_seq'::regclass);


--
-- Name: template_certificado id_template_certificado; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_certificado ALTER COLUMN id_template_certificado SET DEFAULT nextval('public.templates_certificados_id_template_certificado_seq'::regclass);


--
-- Name: tipo_tramite id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_tramite ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- Name: tipo_usuario id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_usuario ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- Name: tramite id_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramite ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- Name: usuario id_usuario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Name: valor id_valor; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.valor ALTER COLUMN id_valor SET DEFAULT nextval('public.valores_id_valor_seq'::regclass);


--
-- Name: variable_ordenanza id_variable; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable_ordenanza ALTER COLUMN id_variable SET DEFAULT nextval('public.variables_ordenanzas_id_variable_seq'::regclass);


--
-- Name: base_task task_id; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.base_task ALTER COLUMN task_id SET DEFAULT nextval('timetable.base_task_task_id_seq'::regclass);


--
-- Name: chain_execution_config chain_execution_config; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_config ALTER COLUMN chain_execution_config SET DEFAULT nextval('timetable.chain_execution_config_chain_execution_config_seq'::regclass);


--
-- Name: database_connection database_connection; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.database_connection ALTER COLUMN database_connection SET DEFAULT nextval('timetable.database_connection_database_connection_seq'::regclass);


--
-- Name: log id; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.log ALTER COLUMN id SET DEFAULT nextval('timetable.log_id_seq'::regclass);


--
-- Name: run_status run_status; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.run_status ALTER COLUMN run_status SET DEFAULT nextval('timetable.run_status_run_status_seq'::regclass);


--
-- Name: task_chain chain_id; Type: DEFAULT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.task_chain_chain_id_seq'::regclass);


--
-- Name: ano id; Type: DEFAULT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.ano ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.ano_fiscal_id_seq'::regclass);


--
-- Name: construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.construccion_id_seq'::regclass);


--
-- Name: sector id; Type: DEFAULT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.sector ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.sector_id_seq'::regclass);


--
-- Name: terreno id; Type: DEFAULT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.terreno ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.terreno_id_seq'::regclass);


--
-- Name: tipo_construccion id; Type: DEFAULT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion ALTER COLUMN id SET DEFAULT nextval('valores_fiscales.tipo_construccion_id_seq'::regclass);


--
-- Data for Name: banco; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.banco (id_banco, nombre) FROM stdin;
1	Banco Occidental de Descuento
2	Banesco
\.


--
-- Data for Name: campo; Type: TABLE DATA; Schema: public; Owner: -
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
56	Nombre	string	nombreRepresentante	8
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
\.


--
-- Data for Name: campo_tramite; Type: TABLE DATA; Schema: public; Owner: -
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
18	8	3	iniciado	4
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
\.


--
-- Data for Name: caso_social; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.caso_social (id_caso, id_tipo_tramite, costo, datos, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla) FROM stdin;
2	0	\N	{"nombreCompleto":"Funcionario SAGAS","cedula":"1231231231","fechaNacimiento":"2020-04-02T00:33:42.930Z","edad":"1","nacionalidad":"asdasd","sexo":"true","poblacionIndigena":true,"etnia":"wayuu","profesion":"asdasd","oficio":"asdasd","estadoCivil":"casado","nivelInstruccion":"analfabeto","discapacidad":false,"condicionLaboral":"publico","empleadoAlcaldia":false,"asignacionesEconomicas":"ivss","razonDeSolicitud":"asd","patologiaActual":"asd","areaDeSalud":"traumatologia","direccion":"asdasdasd","parroquia":"CACIQUE MARA","telefono":"1231231231","email":"gab_tata_tc@hotmail.com","tipoAyuda":"electrodomesticos","tipoAyudaDesc":"asdasd","referidoPor":"despacho","isMenor":false,"nacionalidadSolicitante":"V","nacionalidadMenor":"V","nacionalidadBeneficiario":"V","solicitante":{"nombreCompleto":"asdasd","cedula":"1241214215","direccion":"asdasda"},"liderDeCalle":{"nombreCompleto":"asd","telefono":"21412412414"}}	2020-04-02 20:34:14.992725-04	ABMM-09042020-0-0001	1	66	\N
\.


--
-- Data for Name: certificado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.certificado (id_certificado, id_tramite, url_certificado) FROM stdin;
\.


--
-- Data for Name: cuenta_funcionario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cuenta_funcionario (id_usuario, id_institucion) FROM stdin;
55	1
56	1
57	1
59	2
65	2
66	0
67	3
68	3
70	3
71	0
72	4
73	4
75	5
76	5
77	7
78	7
79	6
80	6
81	8
82	8
\.


--
-- Data for Name: datos_facebook; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.datos_facebook (id_usuario, id_facebook) FROM stdin;
\.


--
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
\.


--
-- Data for Name: detalle_factura; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.detalle_factura (id_detalle, id_factura, nombre, costo) FROM stdin;
\.


--
-- Data for Name: evento_caso_social; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evento_caso_social (id_evento_caso, id_caso, event, "time") FROM stdin;
2	2	iniciar	2020-04-02 20:34:14.992725-04
\.


--
-- Data for Name: evento_multa; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evento_multa (id_evento_multa, id_multa, event, "time") FROM stdin;
\.


--
-- Data for Name: evento_tramite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evento_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
583	255	iniciar	2020-05-07 10:57:09.720038-04
584	255	validar_pa	2020-05-07 10:57:09.720038-04
586	257	iniciar	2020-05-07 10:57:38.168622-04
587	257	validar_pa	2020-05-07 10:57:38.168622-04
588	258	iniciar	2020-05-07 10:57:53.919855-04
589	258	enproceso_pd	2020-05-07 10:57:53.919855-04
590	259	iniciar	2020-05-07 10:58:28.363512-04
591	259	validar_pa	2020-05-07 10:58:28.363512-04
592	260	iniciar	2020-05-07 10:58:51.901449-04
593	260	validar_pa	2020-05-07 10:58:51.901449-04
594	261	iniciar	2020-05-07 10:58:59.049063-04
595	261	enproceso_pd	2020-05-07 10:58:59.049063-04
596	262	iniciar	2020-05-07 11:00:56.334025-04
597	262	enproceso_pd	2020-05-07 11:00:56.334025-04
598	263	iniciar	2020-05-07 11:01:07.212907-04
599	263	enproceso_pd	2020-05-07 11:01:07.212907-04
600	264	iniciar	2020-05-07 11:01:52.832256-04
601	264	enproceso_pd	2020-05-07 11:01:52.832256-04
602	265	iniciar	2020-05-07 11:02:07.106868-04
603	265	enproceso_pd	2020-05-07 11:02:07.106868-04
604	266	iniciar	2020-05-07 11:03:00.239298-04
605	266	enproceso_pd	2020-05-07 11:03:00.239298-04
606	267	iniciar	2020-05-07 11:03:37.842654-04
607	267	validar_cr	2020-05-07 11:03:37.842654-04
608	268	iniciar	2020-05-07 11:46:05.315309-04
609	268	validar_cr	2020-05-07 11:46:05.315309-04
610	269	iniciar	2020-05-07 11:46:32.804564-04
611	269	validar_cr	2020-05-07 11:46:32.804564-04
612	270	iniciar	2020-05-07 11:47:09.713907-04
613	270	validar_cr	2020-05-07 11:47:09.713907-04
614	271	iniciar	2020-05-07 11:48:02.25006-04
615	271	validar_tl	2020-05-07 11:48:02.25006-04
617	273	iniciar	2020-05-07 11:48:23.471532-04
618	273	validar_pa	2020-05-07 11:48:23.471532-04
\.


--
-- Data for Name: factura_tramite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.factura_tramite (id_factura, id_tramite) FROM stdin;
\.


--
-- Data for Name: inmueble_urbano; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, fecha_ultimo_avaluo, tipo_inmueble) FROM stdin;
21	231315U01004083001001P0500	Calle 73 entre Av. 3E y 3F	108	200	300	2020-03-20 16:46:01.230084-04	2020-03-20 16:46:01.230084-04	\N	\N
\.


--
-- Data for Name: institucion; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: institucion_banco; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.institucion_banco (id_institucion_banco, id_institucion, id_banco, numero_cuenta, nombre_titular, documento_de_identificacion) FROM stdin;
2	2	1	0116–0126–03–0018874177	SAGAS	rif:G-20005358-5
3	3	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0
4	3	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0
1	1	1	0116–0140–51–0014405090	CUERPO DE BOMBEROS DEL MUNICIPIO MARACAIBO	rif:G-20003346-0
5	4	1	0116–0101–46–0030138515	SEDETEMA	rif:G-20012866-6
6	5	1	0116–01–4054–0008937036	SEDEPAR	rif:G-20006426-9
7	7	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0
8	7	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0
11	8	1	0116–0126–06–0026593432	SEDEMAT	rif:G-20002908-0
12	8	2	0134–0001–61–0013218667	SEDEMAT	rif:G-20002908-0
9	6	1	0116–0126–0600–22777792	INSTITUTO MUNICIPAL DE AMBIENTE	rif:G-20000537-8
\.


--
-- Data for Name: multa; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.multa (id_multa, id_tipo_tramite, datos, costo, fecha_creacion, codigo_multa, consecutivo, id_usuario, cedula, nacionalidad, url_certificado, aprobado, url_boleta) FROM stdin;
\.


--
-- Data for Name: notificacion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notificacion (id_notificacion, id_procedimiento, emisor, receptor, descripcion, status, fecha, estado, concepto) FROM stdin;
412	255	V-27139153	V-1	Un trámite de tipo Cumplimiento de Normas Tecnicas ha sido creado	f	2020-05-07 10:57:13.617386-04	validando	TRAMITE
413	255	V-27139153	V-1	Un trámite de tipo Cumplimiento de Normas Tecnicas ha sido creado	f	2020-05-07 10:57:13.617386-04	validando	TRAMITE
414	255	V-27139153	V-1231231231	Un trámite de tipo Cumplimiento de Normas Tecnicas ha sido creado	f	2020-05-07 10:57:13.617386-04	validando	TRAMITE
432	263	V-27139153	V-1	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:07.728089-04	enproceso	TRAMITE
433	263	V-27139153	V-123123	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:07.728089-04	enproceso	TRAMITE
434	263	V-27139153	V-123133333	Un trámite de tipo Permiso de Habitabilidad sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:07.728089-04	enproceso	TRAMITE
435	264	V-27139153	V-1	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:53.330397-04	enproceso	TRAMITE
436	264	V-27139153	V-123123	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:53.330397-04	enproceso	TRAMITE
437	264	V-27139153	V-123133333	Un trámite de tipo Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:01:53.330397-04	enproceso	TRAMITE
438	266	V-27139153	V-1	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:03:00.859148-04	enproceso	TRAMITE
439	266	V-27139153	V-123123	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:03:00.859148-04	enproceso	TRAMITE
440	266	V-27139153	V-123133333	Un trámite de tipo Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas ha sido creado	f	2020-05-07 11:03:00.859148-04	enproceso	TRAMITE
444	268	V-27139153	V-1	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-05-07 11:46:05.980597-04	validando	TRAMITE
445	268	V-27139153	V-1231234444	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-05-07 11:46:05.980597-04	validando	TRAMITE
446	268	V-27139153	V-27139154	Un trámite de tipo Constancia de Nomenclatura ha sido creado	f	2020-05-07 11:46:05.980597-04	validando	TRAMITE
\.


--
-- Data for Name: operacion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.operacion (id_operacion, nombre_op) FROM stdin;
\.


--
-- Data for Name: operatividad_terminal; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: ordenanza; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: ordenanza_tramite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ordenanza_tramite (id_ordenanza_tramite, id_tramite, id_tarifa, utmm, valor_calc, factor, factor_value, costo_ordenanza) FROM stdin;
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pago (id_pago, id_procedimiento, referencia, monto, fecha_de_pago, aprobado, id_banco, fecha_de_aprobacion, concepto) FROM stdin;
152	14	123123123123	1200000	2020-05-01	f	2	\N	MULTA
153	254	123123	1200000	2020-05-05	t	1	2020-05-05 16:15:22.038124-04	TRAMITE
154	255	123123123	8000000	2020-05-07	f	1	\N	TRAMITE
156	257	123123123123	8000000	2020-05-07	f	1	\N	TRAMITE
157	259	1231234	240000000	2020-05-07	f	1	\N	TRAMITE
158	260	1	960000000	2020-05-07	f	1	\N	TRAMITE
159	267	132	1200000	2020-05-07	f	1	\N	TRAMITE
160	268	3	80000	2020-05-07	f	1	\N	TRAMITE
161	269	4	1200000	2020-05-07	f	1	\N	TRAMITE
162	270	5	1200000	2020-05-07	f	1	\N	TRAMITE
163	271	6	1000.0	2020-05-07	f	1	\N	TRAMITE
165	273	67	1000000	2020-05-07	f	1	\N	TRAMITE
\.


--
-- Data for Name: pago_manual; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pago_manual (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- Data for Name: parroquia; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: permiso_de_acceso; Type: TABLE DATA; Schema: public; Owner: -
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
\.


--
-- Data for Name: propietario; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: propietario_inmueble; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.propietario_inmueble (id_propietario_inmueble, id_propietario, id_inmueble) FROM stdin;
9	17	21
\.


--
-- Data for Name: recaudo; Type: TABLE DATA; Schema: public; Owner: -
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
\.


--
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
\.


--
-- Data for Name: seccion; Type: TABLE DATA; Schema: public; Owner: -
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
\.


--
-- Data for Name: tarifa_inspeccion; Type: TABLE DATA; Schema: public; Owner: -
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
-- Data for Name: template_certificado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.template_certificado (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- Data for Name: tipo_tramite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, sufijo, nombre_corto, formato, planilla, certificado, utiliza_informacion_catastral, pago_previo, costo_utmm, planilla_rechazo) FROM stdin;
8	2	Permiso de Construccion	\N	pd	Permiso de Construccion	SAGAS-004	sagas-solt-PC	sagas-cert-PC	f	f	\N	\N
10	2	Permiso de Habitabilidad con Instalaciones de Servicio de Gas	\N	pd	Habitabilidad con Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	t	f	\N	\N
11	2	Permiso de Habitabilidad sin Instalaciones de Servicio de Gas	\N	pd	Habitabilidad sin Instalacion de Servicio de Gas	SAGAS-005	sagas-solt-Hab	sagas-cert-PH	t	f	\N	\N
12	2	Permiso de Condiciones Habitables con Instalaciones de Servicio de Gas	\N	pd	Condiciones Habitables con Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	t	f	\N	\N
13	2	Permiso de Condiciones Habitables sin Instalaciones de Servicio de Gas	\N	pd	Condiciones Habitables sin Instalacion de Servicio de Gas	SAGAS-001	sagas-solt-CH	sagas-cert-PCH	t	f	\N	\N
7	2	Constancia de Servicio Persona Juridica	4800000	pa	Servicio Persona Juridica	SAGAS-003	sagas-solt-CS	sagas-cert-CS	t	t	24	\N
6	2	Constancia de Servicio Residencial	1200000	pa	Servicio Residencial	SAGAS-002	sagas-solt-CS	sagas-cert-CS	t	t	6	\N
0	0	Casos Sociales	\N	pa	Casos Sociales	ABMM-001	\N	\N	\N	f	\N	\N
17	4	Tasa de Salida de Pasajeros	\N	tl	Tasa de Salida	SEDETEMA-001	sedetema-solt-TS	sedetema-cert-TS	f	t	\N	\N
14	3	Codigo Catastral para Casas	1200000	cr	CC	CPU-OMCAT-001	cpu-solt-CCC	cpu-cert-CC	f	t	6	\N
15	3	Codigo Catastral para Apartamentos	1200000	cr	CC	CPU-OMCAT-001	cpu-solt-CCA	cpu-cert-CC	f	t	6	\N
2	1	Constancia de Habitabilidad	40000.0	pa	Habitabilidad	CBM-002	bomberos-solt	bomberos-cert-HAB	t	t	0.2	\N
3	1	Instalacion de Plantas Electricas	\N	pd	Plantas Electricas	CBM-003	bomberos-solt	bomberos-cert-IPE	f	f	\N	\N
1	1	Cumplimiento de Normas Tecnicas	40000.0	pa	Normas Tecnicas	CBM-001	bomberos-solt	bomberos-cert-CCNT	t	t	0.2	\N
16	3	Solvencia de Inmuebles Urbanos	1200000	cr	SIU	CPU-OMCAT-002	cpu-solt-SIU	cpu-cert-SIU	f	t	6	\N
18	5	Apartado de Bohío	1000000	pa	Apartado de Bohío	SEDEPAR-001	sedepar-solt-AB	sedepar-cert-AB	f	t	5	\N
19	6	Multa	\N	ml	Multa	IMA-001	\N	constancia-multas	f	f	\N	\N
20	7	Multa	\N	ml	Multa	PMM-001	\N	constancia-multas	f	f	\N	\N
25	3	Conformidad de la Edificación y Uso Locales en Centros Comerciales	\N	ompu	Uso Conforme: Locales	CPU-OMPU-AU-004	cpu-solt-UC-CC	cpu-cert-UC-CC	f	f	\N	cpu-rechazo
23	3	Conformidad de la Edificación y Uso Licencia a las Actividades Económicas Comerciales e Industriales	\N	ompu	Uso Conforme: Actividades Comerciales	CPU-OMPU-AU-001	cpu-solt-UC-AE	cpu-cert-UC-AE	t	f	\N	cpu-rechazo
22	3	Constancia de Nomenclatura	80000	cr	NM	CPU-OMCAT-003	cpu-solt-NM	cpu-cert-NM	f	t	0.4	\N
21	8	Certificación para Prestar Servicio de Transporte Público Urbano	\N	pd	Servicio Transporte Público	IMTCUMA-001	\N	imtcuma-cert-STP	f	f	\N	\N
24	3	Conformidad de la Edificación y Uso Unidades Educativas	\N	ompu	Uso Conforme: Unidades Educativas	CPU-OMPU-AU-003	cpu-solt-UC-UE	cpu-cert-UC-UE	t	f	\N	cpu-rechazo
\.


--
-- Data for Name: tipo_tramite_recaudo; Type: TABLE DATA; Schema: public; Owner: -
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
\.


--
-- Data for Name: tipo_usuario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tipo_usuario (id_tipo_usuario, descripcion) FROM stdin;
1	Superuser
2	Administrador
3	Funcionario
4	Usuario externo
5	Director
\.


--
-- Data for Name: tramite; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tramite (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario, url_planilla, url_certificado, aprobado, fecha_culminacion) FROM stdin;
270	15	{"usuario":{"nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","parroquia":"CECILIO ACOSTA","direccion":"Aqui","propietarios":[{"razonSocial":"asdasd","cedulaORif":"1241241241","nacionalidad":"V","telefono":"1241241241","direccion":"asdasdasd","correo":"asd@asd.asd","parroquia":"BOLIVAR"}],"nombreConjunto":"asd","cantidadEdificios":"1","nombreEdificio":"asd","cantidadPisos":"123123","pisoApto":"123123","cantidadAptosPiso":"1231","numeroApto":"123123","nomenclaturaEdificio":"asdasd","ubicacionEdificio":"asd","parroquiaEdificio":"IDELFONSO VASQUEZ","nacionalidad":"V","codCat":null}}	1200000	2020-05-07 11:47:09.713907-04	CPU-07052020-15-0001	1	58	http://localhost:5000/tramites/CPU-07052020-15-0001/planilla.pdf	\N	f	\N
266	13	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	\N	2020-05-07 11:03:00.239298-04	SAGAS-07052020-13-0002	2	58	http://localhost:5000/tramites/SAGAS-07052020-13-0002/planilla.pdf	\N	f	\N
268	22	{"usuario":{"nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","parroquia":"CACIQUE MARA","direccion":"Aqui","propietarios":[{"razonSocial":"asdasd","nacionalidad":"V","cedulaORif":"1241241241","telefono":"1241241241","direccion":"asdasdasd","correo":"asd@asd.asd","parroquia":"BOLIVAR"}],"ubicadoEn":"asdasdasd","puntoReferencia":"asd","finalidad":"Mismo Número","frente":"","linderoFrente":"a","linderoFondo":"b","linderoDerecha":"c","linderoIzquierda":"d","nacionalidad":"V","codCat":null}}	80000	2020-05-07 11:46:05.315309-04	CPU-07052020-22-0001	1	58	http://localhost:5000/tramites/CPU-07052020-22-0001/planilla.pdf	\N	f	\N
267	16	{"usuario":{"nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","parroquia":"CACIQUE MARA","direccion":"Aqui","propietarios":[{"razonSocial":"asdasd","cedulaORif":"1241241241","nacionalidad":"V","telefono":"1241241241","direccion":"asdasdasd","correo":"asd@asd.asd","parroquia":"BOLIVAR"}],"ubicadoEn":"asdasdasd","parroquiaEdificio":"BOLIVAR","tipoInmuebleSolvencia":"terreno","nacionalidad":"V","codCat":null}}	1200000	2020-05-07 11:03:37.842654-04	CPU-07052020-16-0001	1	58	http://localhost:5000/tramites/CPU-07052020-16-0001/planilla.pdf	\N	f	\N
269	14	{"usuario":{"nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","parroquia":"CACIQUE MARA","direccion":"Aqui","propietarios":[{"razonSocial":"asdasd","cedulaORif":"1241241241","nacionalidad":"V","telefono":"1241241241","direccion":"asdasdasd","correo":"asd@asd.asd","parroquia":"BOLIVAR"}],"ubicadoEn":"asdasdasd","parroquiaEdificio":"CACIQUE MARA","tipoInmueble":"asdasd","nacionalidad":"V","codCat":null}}	1200000	2020-05-07 11:46:32.804564-04	CPU-07052020-14-0001	1	58	http://localhost:5000/tramites/CPU-07052020-14-0001/planilla.pdf	\N	f	\N
273	18	{"usuario":{"nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","fechaApartado":"2020-05-15T15:48:06.719Z","numeroBohio":"1","nacionalidad":"V","codCat":null}}	1000000	2020-05-07 11:48:23.471532-04	SEDEPAR-07052020-18-0001	1	58	http://localhost:5000/tramites/SEDEPAR-07052020-18-0001/planilla.pdf	\N	f	\N
262	10	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	\N	2020-05-07 11:00:56.334025-04	SAGAS-07052020-10-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-10-0001/planilla.pdf	\N	f	\N
255	1	{"usuario":{"cedulaORif":"27139153","nombreORazon":"Gabriel Trompiz","direccion":"Aqui","puntoReferencia":"ASD","sector":"123","parroquia":"BOLIVAR","nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","contacto":"si","horario":"no","prefix":"V","nacionalidad":"V","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	8000000	2020-05-07 10:57:09.720038-04	CBM-07052020-1-0001	1	58	http://localhost:5000/tramites/CBM-07052020-1-0001/planilla.pdf	\N	f	\N
259	6	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	240000000	2020-05-07 10:58:28.363512-04	SAGAS-07052020-6-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-6-0001/planilla.pdf	\N	f	\N
257	2	{"usuario":{"cedulaORif":"27139153","nombreORazon":"Gabriel Trompiz","direccion":"Aqui","puntoReferencia":"asd","sector":"123","parroquia":"BOLIVAR","nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","contacto":"asd","horario":"asd","prefix":"V","nacionalidad":"V","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	8000000	2020-05-07 10:57:38.168622-04	CBM-07052020-2-0001	1	58	http://localhost:5000/tramites/CBM-07052020-2-0001/planilla.pdf	\N	f	\N
258	3	{"usuario":{"cedulaORif":"27139153","nombreORazon":"Gabriel Trompiz","direccion":"Aqui","puntoReferencia":"asd","sector":"asd","parroquia":"BOLIVAR","nombre":"External User","cedula":"27139153","telefono":"4127645681","correo":"external@user.com","contacto":"123","horario":"asd","prefix":"V","nacionalidad":"V","codCat":null}}	\N	2020-05-07 10:57:53.919855-04	CBM-07052020-3-0001	1	58	http://localhost:5000/tramites/CBM-07052020-3-0001/planilla.pdf	\N	f	\N
260	7	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	960000000	2020-05-07 10:58:51.901449-04	SAGAS-07052020-7-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-7-0001/planilla.pdf	\N	f	\N
261	8	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","areaConstruccion":"123123","codCat":null}}	\N	2020-05-07 10:58:59.049063-04	SAGAS-07052020-8-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-8-0001/planilla.pdf	\N	f	\N
263	11	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	\N	2020-05-07 11:01:07.212907-04	SAGAS-07052020-11-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-11-0001/planilla.pdf	\N	f	\N
264	12	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	\N	2020-05-07 11:01:52.832256-04	SAGAS-07052020-12-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-12-0001/planilla.pdf	\N	f	\N
265	13	{"usuario":{"nombre":"External User","ubicadoEn":"asdasdasd","telefono":"4127645681","tipoOcupacion":"123123","codCat":{"idInmueble":21,"codCatastral":"231315U01004083001001P0500","direccion":"Calle 73 entre Av. 3E y 3F","metrosConstruccion":"200","metrosTerreno":"300","fechaCreacion":"2020-03-20T20:46:01.230Z","fechaActualizacion":"2020-03-20T20:46:01.230Z","fechaUltimoAvaluo":null,"parroquia":"ANTONIO BORJAS ROMERO","propietarios":[{"idpropietario":17,"razonSocial":"asdasd","cedula":null,"rif":null,"email":null,"id_inmueble":21}]}}}	\N	2020-05-07 11:02:07.106868-04	SAGAS-07052020-13-0001	1	58	http://localhost:5000/tramites/SAGAS-07052020-13-0001/planilla.pdf	\N	f	\N
271	17	{"usuario":{"cedula":"1231231231","nombreCompleto":"Gabriel Trompiz","destino":"Baruta","metodo":"Transferencia","monto":"1.000","fechaTramite":"2020-05-07T15:48:02.205Z"}}	1000.0	2020-05-07 11:48:02.25006-04	SEDETEMA-07052020-17-0001	1	58	http://localhost:5000/tramites/SEDETEMA-07052020-17-0001/planilla.pdf	\N	f	\N
\.


--
-- Data for Name: tramite_archivo_recaudo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tramite_archivo_recaudo (id_tramite, url_archivo_recaudo) FROM stdin;
259	http://localhost:5000/tramites/SAGAS-07052020-6-0001/RIFPropietario.png
259	http://localhost:5000/tramites/SAGAS-07052020-6-0001/CedulaPropietario.png
260	http://localhost:5000/tramites/SAGAS-07052020-7-0001/RIFPropietario.png
260	http://localhost:5000/tramites/SAGAS-07052020-7-0001/CedulaPropietario.png
262	http://localhost:5000/tramites/SAGAS-07052020-10-0001/ConstanciaSAGAS.png
263	http://localhost:5000/tramites/SAGAS-07052020-11-0001/ConstanciaSAGAS.png
264	http://localhost:5000/tramites/SAGAS-07052020-12-0001/ConstanciaSAGAS.png
266	http://localhost:5000/tramites/SAGAS-07052020-13-0002/ConstanciaSAGAS.png
267	http://localhost:5000/tramites/CPU-07052020-16-0001/CedulaPropietario.png
267	http://localhost:5000/tramites/CPU-07052020-16-0001/DocumentoPropiedad.png
267	http://localhost:5000/tramites/CPU-07052020-16-0001/Nomenclatura.png
268	http://localhost:5000/tramites/CPU-07052020-22-0001/CedulaPropietario.png
269	http://localhost:5000/tramites/CPU-07052020-14-0001/CedulaPropietario.png
270	http://localhost:5000/tramites/CPU-07052020-15-0001/CedulaPropietario.png
273	http://localhost:5000/tramites/SEDEPAR-07052020-18-0001/CedulaSolicitante.png
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usuario (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono) FROM stdin;
55	Super Usuario	super@user.com	Super Usuario	1	V	1	$2a$10$VVT8CHvO3jEEoj/djKK4Z.CGPO9JAHw1NMUIK6QwM3BEwElf68kUW	\N
56	Administrador Bomberos	admin@bomberos.com	Bomberos	1231231231	V	2	$2a$10$nqEy4iyMTQJLAN.BOQ2GuuWioAwRcnXY7ClFbJtmp4svHLg9os/8m	1231231231
58	External User	external@user.com	Aqui	27139153	V	4	$2a$10$1az9AKXYIZ48FrTXXnb24.QT89PZuCTh2n0zabqVW7G8YyKinYNXe	4127645681
59	Administrador SAGAS	admin@sagas.com	SAGAS	123123	V	2	$2a$10$.avdkJGtcLhgw/UydHdZf.QEeiSoAjUxRM/xLiTA1gQLUDkDy4lfm	1231231231
66	Administrador Alcaldia	admin@alcaldia.com	Alcaldia	99999999	V	2	$2a$10$OtCHXU7MOIa6a5K2dt.soOa4AvzrKvp5qY1RtYTaCQqpV2.KTsOyu	8123814877
67	Administrador CPU	admin@cpu.com	CPU	1231234444	V	2	$2a$10$qEObA7PrDPq2vv/MsfcyFutEKZQuPdVxQnv.5cafIrxfaBnN/P0ba	1231239811
70	Director CPU	director@cpu.com	CPU	27139154	V	5	$2a$10$yBVC5M9rGWV5i.i2Nyl1fOGg1FKV2HQ0keq3jPcOvrGXtrjEra.z.	1231231231
65	Funcionario SAGAS	funcionario@sagas.com	SAGAS	123133333	V	3	$2a$10$Na8DEr4PxMVxAQXgeAGkR.DjVx7YX/8/FJIhPeePIrPzKItJvTscy	1231231231
57	Funcionario Bomberos	funcionario@bomberos.com	Bomberos	123123123	V	3	$2a$10$fFZ3EHbzdimZ9tDvrGod9ureMPkROVtzScEd0pO/piaQh6RLmedMG	1231231233
71	Funcionario Alcaldia	funcionario@alcaldia.com	Alcaldia	7878787855	V	3	$2a$10$4vosHs6BExfapyssBS5XUekAR9AUa2Be.mhjLuqqmr7i1aZCWUehu	7777777777
72	Administrador Terminal	terminal@admin.com	Terminal	128488188	V	2	$2a$10$hIeSExSylu8RY2bVPk6dPeLzKIR7Wo0yNjvRyqxR/QwZqTYEEf4wq	1723817728
73	Funcionario Terminal	funcionario@terminal.com	Terminal	1028124812	V	3	$2a$10$4oNhbsHJuAaFE.xY8bS1HOPakehWJmx6IkGbuaU57nBqro7iLsgg.	1092471093
75	Funcionario SEDEPAR	funcionario@sedepar.com	SEDEPAR	1289417241	V	3	$2a$10$8.dFFea0jSaDPFYmH4GM9urNDgGy6SawTnqALfevVvQdzodEkR7fS	1974102937
76	Administrador SEDEPAR	admin@sedepar.com	SEDEPAR	1294712034	V	2	$2a$10$mIBjS3jXMabi8XXohLECoeyKOUr.rZc8jlQXvdZcaSaZT88YLYLaG	8374198241
77	Administrador Policia	admin@policia.com	Policia	1249712091	V	2	$2a$10$P.v8kW77Xzm1ecmVsuBVuu.5avlhiv8izDmK51hW2/Jj6q/j/beNi	1029471204
78	Funcionario Policia	funcionario@policia.com	Policia	1293712049	V	3	$2a$10$e.DuvVSdwlr23z1I8B/STeX5V.8V3rhoeXgRWokiP.dEmf3A/eoPK	1927312029
79	Administrador IMA	admin@ima.com	IMA	1028310919	V	2	$2a$10$I2NhOoazRC2gF0pIdzNXrumPh0soj/9/KDA5dx1RqDNrow1fNzsbG	1923109472
80	Funcionario IMA	funcionario@ima.com	IMA	1231740197	V	3	$2a$10$eAu/NEg9vEd5nKXbjSyemODqqLt2J1nO4joWhwbDpZopJAj7N0ZSW	1902741092
81	Administrador INTCUMA	admin@intcuma.com	INTCUMA	1239812938	V	2	$2a$10$mHlp3WfgE.99gg2i2wSI2OrL29UABov9Lo4iylvngFZTwAi2gmBOa	9132801238
82	Funcionario INTCUMA	funcionario@intcuma.com	INTCUMA	1023102938	V	3	$2a$10$qVi/NuT7X1ELSfz5mpM8e.OrMKAuSqJLPQ4H45/SB/WiwUw2TkA2i	1829038123
68	Funcionario CPU	funcionario@cpu.com	CPU	1283190247	V	3	$2a$10$qLVJeDD5mKiXlhrNQEJDtOX9baIZcjY3zwMmepViWXp.VENHwaOda	9271092741
\.


--
-- Data for Name: valor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.valor (id_valor, descripcion, valor_en_bs) FROM stdin;
1	Bolivares	1
2	UTMM	200000
\.


--
-- Data for Name: variable; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.variable (id_var, nombre_variable) FROM stdin;
\.


--
-- Data for Name: variable_de_costo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.variable_de_costo (id_variable_de_costo, id_tipo_tramite, id_operacion, precedencia, aumento) FROM stdin;
\.


--
-- Data for Name: variable_ordenanza; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.variable_ordenanza (id_variable, nombre, nombre_plural) FROM stdin;
1	Plano	Planos
2	Pre Inspección	Pre Inspecciones
4	Inspección	Inspecciones
3	Vivienda	Viviendas
5	Persona jurídica	Personas jurídicas
\.


--
-- Data for Name: base_task; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.base_task (task_id, name, kind, script) FROM stdin;
\.


--
-- Data for Name: chain_execution_config; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.chain_execution_config (chain_execution_config, chain_id, chain_name, run_at, max_instances, live, self_destruct, exclusive_execution, excluded_execution_configs, client_name) FROM stdin;
\.


--
-- Data for Name: chain_execution_parameters; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.chain_execution_parameters (chain_execution_config, chain_id, order_id, value) FROM stdin;
\.


--
-- Data for Name: database_connection; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.database_connection (database_connection, connect_string, comment) FROM stdin;
\.


--
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.execution_log (chain_execution_config, chain_id, task_id, name, script, kind, last_run, finished, returncode, pid) FROM stdin;
\.


--
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.log (id, ts, client_name, pid, log_level, message) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.migrations (id, version) FROM stdin;
\.


--
-- Data for Name: run_status; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.run_status (run_status, start_status, execution_status, chain_id, current_execution_element, started, last_status_update, chain_execution_config) FROM stdin;
\.


--
-- Data for Name: task_chain; Type: TABLE DATA; Schema: timetable; Owner: -
--

COPY timetable.task_chain (chain_id, parent_id, task_id, run_uid, database_connection, ignore_error) FROM stdin;
\.


--
-- Data for Name: ano; Type: TABLE DATA; Schema: valores_fiscales; Owner: -
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
-- Data for Name: construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: -
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
-- Data for Name: sector; Type: TABLE DATA; Schema: valores_fiscales; Owner: -
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
-- Data for Name: terreno; Type: TABLE DATA; Schema: valores_fiscales; Owner: -
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
-- Data for Name: tipo_construccion; Type: TABLE DATA; Schema: valores_fiscales; Owner: -
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
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 2, true);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 13, true);


--
-- Name: casos_sociales_id_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.casos_sociales_id_caso_seq', 2, true);


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.certificados_id_certificado_seq', 1, false);


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.detalles_facturas_id_detalle_seq', 1, false);


--
-- Name: evento_multa_id_evento_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.evento_multa_id_evento_multa_seq', 41, true);


--
-- Name: eventos_casos_sociales_id_evento_caso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.eventos_casos_sociales_id_evento_caso_seq', 2, true);


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 618, true);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, false);


--
-- Name: inmueble_urbano_id_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.inmueble_urbano_id_inmueble_seq', 33, true);


--
-- Name: instituciones_bancos_id_instituciones_bancos_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instituciones_bancos_id_instituciones_bancos_seq', 1, false);


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- Name: multa_id_multa_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.multa_id_multa_seq', 14, true);


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 456, true);


--
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);


--
-- Name: operatividad_terminal_id_operatividad_terminal_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.operatividad_terminal_id_operatividad_terminal_seq', 77, true);


--
-- Name: ordenanzas_id_ordenanza_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ordenanzas_id_ordenanza_seq', 57, true);


--
-- Name: ordenanzas_tramites_id_ordenanza_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ordenanzas_tramites_id_ordenanza_tramite_seq', 15, true);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 165, true);


--
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 1, false);


--
-- Name: permiso_de_acceso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.permiso_de_acceso_id_permiso_seq', 30, true);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 18, true);


--
-- Name: propietarios_inmuebles_id_propietario_inmueble_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.propietarios_inmuebles_id_propietario_inmueble_seq', 10, true);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, true);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 1, false);


--
-- Name: tarifas_inspeccion_id_tarifa_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tarifas_inspeccion_id_tarifa_seq', 57, true);


--
-- Name: templates_certificados_id_template_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.templates_certificados_id_template_certificado_seq', 1, false);


--
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 4, true);


--
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 273, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 82, true);


--
-- Name: valores_id_valor_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.valores_id_valor_seq', 2, true);


--
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- Name: variables_ordenanzas_id_variable_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.variables_ordenanzas_id_variable_seq', 5, true);


--
-- Name: base_task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.base_task_task_id_seq', 1, false);


--
-- Name: chain_execution_config_chain_execution_config_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.chain_execution_config_chain_execution_config_seq', 1, false);


--
-- Name: database_connection_database_connection_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.database_connection_database_connection_seq', 1, false);


--
-- Name: log_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.log_id_seq', 1, false);


--
-- Name: run_status_run_status_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.run_status_run_status_seq', 1, false);


--
-- Name: task_chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: -
--

SELECT pg_catalog.setval('timetable.task_chain_chain_id_seq', 1, false);


--
-- Name: ano_fiscal_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: -
--

SELECT pg_catalog.setval('valores_fiscales.ano_fiscal_id_seq', 6, true);


--
-- Name: construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: -
--

SELECT pg_catalog.setval('valores_fiscales.construccion_id_seq', 305, true);


--
-- Name: sector_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: -
--

SELECT pg_catalog.setval('valores_fiscales.sector_id_seq', 220, true);


--
-- Name: terreno_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: -
--

SELECT pg_catalog.setval('valores_fiscales.terreno_id_seq', 1315, true);


--
-- Name: tipo_construccion_id_seq; Type: SEQUENCE SET; Schema: valores_fiscales; Owner: -
--

SELECT pg_catalog.setval('valores_fiscales.tipo_construccion_id_seq', 50, true);


--
-- Name: banco bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banco
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- Name: campo campos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campo
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- Name: caso_social casos_sociales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_pkey PRIMARY KEY (id_caso);


--
-- Name: certificado certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_pkey PRIMARY KEY (id_certificado);


--
-- Name: cuenta_funcionario cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: datos_google datos_google_id_google_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);


--
-- Name: datos_google datos_google_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);


--
-- Name: evento_multa evento_multa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_pkey PRIMARY KEY (id_evento_multa);


--
-- Name: evento_tramite eventos_tramite_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_pkey PRIMARY KEY (id_evento_tramite);


--
-- Name: factura_tramite facturas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_pkey PRIMARY KEY (id_factura);


--
-- Name: inmueble_urbano inmueble_urbano_cod_catastral_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_cod_catastral_key UNIQUE (cod_catastral);


--
-- Name: inmueble_urbano inmueble_urbano_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_pkey PRIMARY KEY (id_inmueble);


--
-- Name: institucion_banco instituciones_bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_pkey PRIMARY KEY (id_institucion_banco);


--
-- Name: institucion instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- Name: multa multa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_pkey PRIMARY KEY (id_multa);


--
-- Name: notificacion notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificacion
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- Name: operacion operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- Name: ordenanza ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_pkey PRIMARY KEY (id_ordenanza);


--
-- Name: ordenanza_tramite ordenanzas_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_pkey PRIMARY KEY (id_ordenanza_tramite);


--
-- Name: pago pagos_id_banco_referencia_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_referencia_key UNIQUE (id_banco, referencia);


--
-- Name: pago_manual pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- Name: pago pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- Name: parroquia parroquia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parroquia
    ADD CONSTRAINT parroquia_pkey PRIMARY KEY (id);


--
-- Name: permiso_de_acceso permiso_de_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_pkey PRIMARY KEY (id_permiso);


--
-- Name: propietario propietario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);


--
-- Name: propietario_inmueble propietarios_inmuebles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_pkey PRIMARY KEY (id_propietario_inmueble);


--
-- Name: recaudo recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recaudo
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- Name: recuperacion recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_pkey PRIMARY KEY (id_recuperacion);


--
-- Name: seccion secciones_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seccion
    ADD CONSTRAINT secciones_pk PRIMARY KEY (id_seccion);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_pkey PRIMARY KEY (id_tarifa);


--
-- Name: template_certificado templates_certificados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_pkey PRIMARY KEY (id_template_certificado);


--
-- Name: tipo_tramite tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- Name: tipo_usuario tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_usuario
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- Name: tramite tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- Name: usuario usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- Name: usuario usuarios_nombre_de_usuario_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_nombre_de_usuario_key UNIQUE (nombre_de_usuario);


--
-- Name: usuario usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: valor valores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.valor
    ADD CONSTRAINT valores_pkey PRIMARY KEY (id_valor);


--
-- Name: variable_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- Name: variable_ordenanza variables_ordenanzas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable_ordenanza
    ADD CONSTRAINT variables_ordenanzas_pkey PRIMARY KEY (id_variable);


--
-- Name: variable variables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- Name: base_task base_task_name_key; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_name_key UNIQUE (name);


--
-- Name: base_task base_task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.base_task
    ADD CONSTRAINT base_task_pkey PRIMARY KEY (task_id);


--
-- Name: chain_execution_config chain_execution_config_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_name_key UNIQUE (chain_name);


--
-- Name: chain_execution_config chain_execution_config_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_pkey PRIMARY KEY (chain_execution_config);


--
-- Name: chain_execution_parameters chain_execution_parameters_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_pkey PRIMARY KEY (chain_execution_config, chain_id, order_id);


--
-- Name: database_connection database_connection_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.database_connection
    ADD CONSTRAINT database_connection_pkey PRIMARY KEY (database_connection);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: run_status run_status_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.run_status
    ADD CONSTRAINT run_status_pkey PRIMARY KEY (run_status);


--
-- Name: task_chain task_chain_parent_id_key; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_key UNIQUE (parent_id);


--
-- Name: task_chain task_chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_pkey PRIMARY KEY (chain_id);


--
-- Name: ano ano_fiscal_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.ano
    ADD CONSTRAINT ano_fiscal_pkey PRIMARY KEY (id);


--
-- Name: construccion construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_pkey PRIMARY KEY (id);


--
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- Name: terreno terreno_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_pkey PRIMARY KEY (id);


--
-- Name: tipo_construccion tipo_construccion_descripcion_key; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_descripcion_key UNIQUE (descripcion);


--
-- Name: tipo_construccion tipo_construccion_pkey; Type: CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.tipo_construccion
    ADD CONSTRAINT tipo_construccion_pkey PRIMARY KEY (id);


--
-- Name: tramite codigo_tramite_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER codigo_tramite_trg BEFORE INSERT ON public.tramite FOR EACH ROW EXECUTE FUNCTION public.codigo_tramite();


--
-- Name: caso_social codigos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER codigos_casos_sociales_trigger BEFORE INSERT ON public.caso_social FOR EACH ROW EXECUTE FUNCTION public.codigo_caso();


--
-- Name: multa codigos_multas_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER codigos_multas_trigger BEFORE INSERT ON public.multa FOR EACH ROW EXECUTE FUNCTION public.codigo_multa();


--
-- Name: evento_caso_social eventos_casos_sociales_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER eventos_casos_sociales_trigger BEFORE INSERT ON public.evento_caso_social FOR EACH ROW EXECUTE FUNCTION public.eventos_casos_sociales_trigger_func();


--
-- Name: evento_multa eventos_multa_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER eventos_multa_trigger BEFORE INSERT ON public.evento_multa FOR EACH ROW EXECUTE FUNCTION public.eventos_multa_trigger_func();


--
-- Name: evento_tramite eventos_tramite_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER eventos_tramite_trigger BEFORE INSERT ON public.evento_tramite FOR EACH ROW EXECUTE FUNCTION public.eventos_tramite_trigger_func();


--
-- Name: notificacion insert_notificaciones_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER insert_notificaciones_trigger BEFORE INSERT ON public.notificacion FOR EACH ROW EXECUTE FUNCTION public.insert_notificacion_trigger_func();


--
-- Name: valor tipos_tramites_costo_utmm_trig; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tipos_tramites_costo_utmm_trig AFTER UPDATE ON public.valor FOR EACH ROW WHEN (((new.descripcion)::text = 'UTMM'::text)) EXECUTE FUNCTION public.tipos_tramites_costo_utmm_trigger_func();


--
-- Name: base_task trig_task_chain_fixer; Type: TRIGGER; Schema: timetable; Owner: -
--

CREATE TRIGGER trig_task_chain_fixer BEFORE DELETE ON timetable.base_task FOR EACH ROW EXECUTE FUNCTION timetable.trig_chain_fixer();


--
-- Name: campo_tramite campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campo(id_campo);


--
-- Name: campo_tramite campos_tramites_id_seccion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_seccion_fkey FOREIGN KEY (id_seccion) REFERENCES public.seccion(id_seccion) NOT VALID;


--
-- Name: campo_tramite campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campo_tramite
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: caso_social casos_sociales_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: caso_social casos_sociales_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caso_social
    ADD CONSTRAINT casos_sociales_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: certificado certificados_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificado
    ADD CONSTRAINT certificados_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: cuenta_funcionario cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuenta_funcionario
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: datos_facebook datos_facebook_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_facebook
    ADD CONSTRAINT datos_facebook_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: detalle_factura detalles_facturas_id_factura_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT detalles_facturas_id_factura_fkey FOREIGN KEY (id_factura) REFERENCES public.factura_tramite(id_factura);


--
-- Name: evento_multa evento_multa_id_multa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_multa
    ADD CONSTRAINT evento_multa_id_multa_fkey FOREIGN KEY (id_multa) REFERENCES public.multa(id_multa);


--
-- Name: evento_tramite eventos_tramite_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_tramite
    ADD CONSTRAINT eventos_tramite_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite) ON DELETE CASCADE;


--
-- Name: factura_tramite facturas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura_tramite
    ADD CONSTRAINT facturas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: inmueble_urbano inmueble_urbano_id_parroquia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inmueble_urbano
    ADD CONSTRAINT inmueble_urbano_id_parroquia_fkey FOREIGN KEY (id_parroquia) REFERENCES public.parroquia(id);


--
-- Name: institucion_banco instituciones_bancos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: institucion_banco instituciones_bancos_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion_banco
    ADD CONSTRAINT instituciones_bancos_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: multa multa_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: multa multa_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multa
    ADD CONSTRAINT multa_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: ordenanza ordenanzas_id_valor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza
    ADD CONSTRAINT ordenanzas_id_valor_fkey FOREIGN KEY (id_valor) REFERENCES public.valor(id_valor);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tarifa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tarifa_fkey FOREIGN KEY (id_tarifa) REFERENCES public.tarifa_inspeccion(id_tarifa);


--
-- Name: ordenanza_tramite ordenanzas_tramites_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordenanza_tramite
    ADD CONSTRAINT ordenanzas_tramites_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: pago pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.banco(id_banco);


--
-- Name: pago_manual pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pago(id_pago);


--
-- Name: pago_manual pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago_manual
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuenta_funcionario(id_usuario);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: permiso_de_acceso permiso_de_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso_de_acceso
    ADD CONSTRAINT permiso_de_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: propietario_inmueble propietarios_inmuebles_id_inmueble_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_inmueble_fkey FOREIGN KEY (id_inmueble) REFERENCES public.inmueble_urbano(id_inmueble);


--
-- Name: propietario_inmueble propietarios_inmuebles_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario_inmueble
    ADD CONSTRAINT propietarios_inmuebles_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);


--
-- Name: recuperacion recuperacion_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recuperacion
    ADD CONSTRAINT recuperacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_ordenanza_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_ordenanza_fkey FOREIGN KEY (id_ordenanza) REFERENCES public.ordenanza(id_ordenanza);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tarifa_inspeccion tarifas_inspeccion_id_variable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tarifa_inspeccion
    ADD CONSTRAINT tarifas_inspeccion_id_variable_fkey FOREIGN KEY (id_variable) REFERENCES public.variable_ordenanza(id_variable);


--
-- Name: template_certificado templates_certificados_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_certificado
    ADD CONSTRAINT templates_certificados_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tipo_tramite tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_tramite
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.institucion(id_institucion);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudo(id_recaudo);


--
-- Name: tipo_tramite_recaudo tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_tramite_recaudo
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite_archivo_recaudo tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramite_archivo_recaudo
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramite(id_tramite);


--
-- Name: tramite tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: tramite tramites_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramite
    ADD CONSTRAINT tramites_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario) ON DELETE CASCADE;


--
-- Name: usuario usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipo_usuario(id_tipo_usuario);


--
-- Name: variable_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operacion(id_operacion);


--
-- Name: variable_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variable_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipo_tramite(id_tipo_tramite);


--
-- Name: chain_execution_config chain_execution_config_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_config
    ADD CONSTRAINT chain_execution_config_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_execution_config_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_execution_config_fkey FOREIGN KEY (chain_execution_config) REFERENCES timetable.chain_execution_config(chain_execution_config) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: chain_execution_parameters chain_execution_parameters_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.chain_execution_parameters
    ADD CONSTRAINT chain_execution_parameters_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_database_connection_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_database_connection_fkey FOREIGN KEY (database_connection) REFERENCES timetable.database_connection(database_connection) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_parent_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES timetable.task_chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_chain task_chain_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: -
--

ALTER TABLE ONLY timetable.task_chain
    ADD CONSTRAINT task_chain_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.base_task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: construccion construccion_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: construccion construccion_tipo_construccion_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.construccion
    ADD CONSTRAINT construccion_tipo_construccion_id_fkey FOREIGN KEY (tipo_construccion_id) REFERENCES valores_fiscales.tipo_construccion(id);


--
-- Name: sector sector_parroquia_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.sector
    ADD CONSTRAINT sector_parroquia_id_fkey FOREIGN KEY (parroquia_id) REFERENCES public.parroquia(id);


--
-- Name: terreno terreno_ano_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_ano_id_fkey FOREIGN KEY (ano_id) REFERENCES valores_fiscales.ano(id);


--
-- Name: terreno terreno_sector_id_fkey; Type: FK CONSTRAINT; Schema: valores_fiscales; Owner: -
--

ALTER TABLE ONLY valores_fiscales.terreno
    ADD CONSTRAINT terreno_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES valores_fiscales.sector(id);


--
-- PostgreSQL database dump complete
--

