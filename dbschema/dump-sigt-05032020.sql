--
-- PostgreSQL database dump
--

-- Dumped from database version 12.1
-- Dumped by pg_dump version 12.1

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
                FROM tramites t
                    WHERE t.id_tipo_tramite = NEW.id_tipo_tramite
                        AND CURRENT_DATE = DATE(t.fecha_creacion);
                        
                            SELECT i.nombre_corto INTO nombre_inst 
                                FROM instituciones i
                                    INNER JOIN tipos_tramites tt ON tt.id_institucion = i.id_institucion
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
-- Name: eventos_tramite_trigger_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.eventos_tramite_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_state text;
  BEGIN
    SELECT tramites_eventos_fsm(event ORDER BY id_evento_tramite)
      FROM (
          SELECT id_evento_tramite, event FROM eventos_tramite WHERE id_tramite = new.id_tramite
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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
    id_usuario integer
);


ALTER TABLE public.tramites OWNER TO postgres;

--
-- Name: insert_tramite(integer, json, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_tramite(_id_tipo_tramite integer, datos json, _id_usuario integer) RETURNS SETOF public.tramites
    LANGUAGE plpgsql
    AS $$
DECLARE
    tramite tramites%ROWTYPE;
    BEGIN
        INSERT INTO TRAMITES (id_tipo_tramite, datos, id_usuario) VALUES (_id_tipo_tramite, datos, _id_usuario) RETURNING * into tramite;
        
            INSERT INTO eventos_tramite values (default, tramite.id_tramite, 'iniciar', now());
            
                RETURN QUERY SELECT * from tramites WHERE id_tramite = tramite.id_tramite;
                
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
-- Name: update_tramite_state(integer, text, json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json DEFAULT NULL::json) RETURNS TABLE(state text)
    LANGUAGE plpgsql
    AS $$
  BEGIN
          INSERT INTO eventos_tramite values (default, _id_tramite, event, now());
          
                  RETURN QUERY SELECT tramites_state.state FROM tramites_state WHERE id = _id_tramite;
                  
                          IF _datos IS NOT NULL THEN
                                      UPDATE tramites SET datos = _datos WHERE id_tramite = _id_tramite;
                                              END IF;
                                              
                                                      END;
                                                              $$;


ALTER FUNCTION public.update_tramite_state(_id_tramite integer, event text, _datos json) OWNER TO postgres;

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
                                                                                                                                            select row_to_json(row)::jsonb into dataPago from (select pagos.id_pago AS id, pagos.monto, pagos.aprobado, pagos.id_banco AS idBanco, pagos.id_tramite AS idTramite, pagos.referencia, pagos.fecha_de_pago AS fechaDePago, pagos.fecha_de_aprobacion AS fechaDeAprobacion, tramites.codigo_tramite AS codigoTramite, tipos_tramites.pago_previo AS pagoPrevio from pagos 
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
-- Name: tramites_eventos_fsm(text); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.tramites_eventos_fsm(text) (
    SFUNC = public.tramites_eventos_transicion,
    STYPE = text,
    INITCOND = 'creado'
);


ALTER AGGREGATE public.tramites_eventos_fsm(text) OWNER TO postgres;

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
-- Name: certificados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificados (
    id_certificado integer NOT NULL,
    id_tramite integer,
    link character varying
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
-- Name: instituciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instituciones (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


ALTER TABLE public.instituciones OWNER TO postgres;

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
-- Name: tipos_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_tramites (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo_base numeric,
    pago_previo boolean,
    nombre_corto character varying
);


ALTER TABLE public.tipos_tramites OWNER TO postgres;

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
    id_recaudo integer
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
-- Name: certificados id_certificado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificados ALTER COLUMN id_certificado SET DEFAULT nextval('public.certificados_id_certificado_seq'::regclass);


--
-- Name: detalles_facturas id_detalle; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_facturas ALTER COLUMN id_detalle SET DEFAULT nextval('public.detalles_facturas_id_detalle_seq'::regclass);


--
-- Name: eventos_tramite id_evento_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventos_tramite ALTER COLUMN id_evento_tramite SET DEFAULT nextval('public.eventos_tramite_id_evento_tramite_seq'::regclass);


--
-- Name: facturas_tramites id_factura; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas_tramites ALTER COLUMN id_factura SET DEFAULT nextval('public.facturas_tramites_id_factura_seq'::regclass);


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
1	Nombre Completo	string	nombre	8
2	Cedula	number	cedula	4
\.


--
-- Data for Name: campos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos_tramites (id_campo, id_tipo_tramite, orden, estado, id_seccion) FROM stdin;
1	1	1	iniciado	1
1	1	1	iniciado	1
2	1	2	iniciado	1
2	1	2	iniciado	1
1	2	1	iniciado	1
1	2	1	iniciado	1
2	2	2	iniciado	1
2	2	2	iniciado	1
1	3	1	iniciado	1
1	3	1	iniciado	1
1	1	1	iniciado	2
\.


--
-- Data for Name: certificados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificados (id_certificado, id_tramite, link) FROM stdin;
\.


--
-- Data for Name: cuentas_funcionarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cuentas_funcionarios (id_usuario, id_institucion) FROM stdin;
43	1
44	2
46	2
48	2
51	2
53	2
56	2
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
1	1	inspekcion	2000
\.


--
-- Data for Name: eventos_tramite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.eventos_tramite (id_evento_tramite, id_tramite, event, "time") FROM stdin;
37	26	iniciar	2020-03-02 07:26:53.20038-04
38	27	iniciar	2020-03-02 07:27:02.682578-04
41	27	validar_pa	2020-03-02 11:32:11.347864-04
44	27	enproceso_pa	2020-03-02 11:32:42.848604-04
45	27	finalizar	2020-03-02 11:32:52.344293-04
46	26	enproceso_pd	2020-03-03 06:32:27.031194-04
48	26	ingresar_datos	2020-03-03 06:34:16.098489-04
49	26	validar_pd	2020-03-05 10:29:49.708723-04
\.


--
-- Data for Name: facturas_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.facturas_tramites (id_factura, id_tramite) FROM stdin;
1	27
\.


--
-- Data for Name: instituciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones (id_institucion, nombre_completo, nombre_corto) FROM stdin;
1	Comandancia de Bomberos de Maracaibo	CMB
2	HOLA MATENME	HMT
\.


--
-- Data for Name: instituciones_bancos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones_bancos (id_instituciones_bancos, id_institucion, id_banco, numero_cuenta, nombre_titular, documento_de_identificacion) FROM stdin;
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
3	27	aaaa	200.00	2020-03-03	t	1	2020-03-03 08:00:36.078753-04
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
-- Data for Name: recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recaudos (id_recaudo, nombre_largo, nombre_corto) FROM stdin;
\.


--
-- Data for Name: recuperacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recuperacion (id_recuperacion, id_usuario, token_recuperacion, usado, fecha_recuperacion) FROM stdin;
4	53	4b87fba6-c4cf-42d2-8d8c-f4b521af4753	t	2020-02-29 08:35:55.255861-04
6	53	4bb7c912-3d89-4284-8fd7-e404721a5aa1	t	2020-02-29 08:39:31.790513-04
7	53	808ca94a-1fa3-4f19-a7ba-48a2bca6cbaa	t	2020-02-29 08:42:28.685605-04
\.


--
-- Data for Name: secciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.secciones (id_seccion, nombre) FROM stdin;
1	Datos Personales
2	Datos del Vehiculo
\.


--
-- Data for Name: templates_certificados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_certificados (id_template_certificado, id_tipo_tramite, link) FROM stdin;
\.


--
-- Data for Name: tipos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites (id_tipo_tramite, id_institucion, nombre_tramite, costo_base, pago_previo, nombre_corto) FROM stdin;
4	2	matenem	2000	t	matenme
1	1	primer tramite	200	f	tramite 1
2	1	segundo tramite	201	f	tramite 2
3	1	tercer tramite	200	f	tramite 3
\.


--
-- Data for Name: tipos_tramites_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites_recaudos (id_tipo_tramite, id_recaudo) FROM stdin;
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

COPY public.tramites (id_tramite, id_tipo_tramite, datos, costo, fecha_creacion, codigo_tramite, consecutivo, id_usuario) FROM stdin;
27	4	{}	2000	2020-03-02 07:27:02.682578-04	HMT-02032020-4-0002	2	51
26	4	{"cedula":123456,"nombre":"Luis Acurero","cedulaORif":3423423,"sector":"rwwe","parroquia":"soltame","metrosCuadrados":200,"telefono":"23993299","puntoReferencia":"soltame ya","direccion":"aysiya","horario":"CUANTOS DATOS SONNNNNNNNNNNN","correo":"YAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","nombreORazon":"8r48j4rj84r8j","contacto":"aeuefujujd","ganasDeVivir":1293191}	\N	2020-03-02 07:26:53.20038-04	HMT-02032020-4-0001	1	51
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
43	lusia curero	r8jeid@gamc.com	adasdjiculo	23933943	V	3	jie4jewwjiw	\N
44	Andres Marmol	admin	por ahi	1	V	1	$2a$10$POACPsN.bjhjmAdLmGiQde0z2Z6maFW1paKvY98TW/cbrlFgo1X96	\N
46	Andres Marmol	serdnam3	por ahi	123	V	2	$2a$10$j11SB/ieI5YlMWrct5aq0Oj6JrHcXqBhbUPgv6J88Z76zV3jC0YJi	\N
48	lusia curero	funci	adasdjiculo	23933945	V	3	funci	\N
51	Andres Marmol	serdnam2	por ahi	276373345	V	1	$2a$10$jFdBCuNe1/ZlDe1CY8bJauWlVmE/DyZqPA8OeZuqZTGaJtEoU5g3K	1
53	lusia curero	marcia22@ethereal.email	adasdjiculo	2393945	V	3	$2a$10$26IjsCwlX/3UmmgoV/mAPeBHo2om9GlvtyOsZMKGFjVJ/RNFkTKlq	12311341
56	Andres Marmol	hello	por ahi	22	V	1	$2a$10$XY7uDEFQqdz.qCaX8enD3ug8dMOXpBCmW1sBuTJgH0HbKji7NuQvS	\N
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

SELECT pg_catalog.setval('public.campos_id_campo_seq', 1, false);


--
-- Name: certificados_id_certificado_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificados_id_certificado_seq', 1, false);


--
-- Name: detalles_facturas_id_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalles_facturas_id_detalle_seq', 1, true);


--
-- Name: eventos_tramite_id_evento_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventos_tramite_id_evento_tramite_seq', 50, true);


--
-- Name: facturas_tramites_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facturas_tramites_id_factura_seq', 1, true);


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

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 3, true);


--
-- Name: parroquias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_seq', 110, true);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, false);


--
-- Name: recuperacion_id_recuperacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recuperacion_id_recuperacion_seq', 7, true);


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

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 27, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 56, true);


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
-- Name: pagos pagos_fecha_de_pago_referencia_id_banco_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_fecha_de_pago_referencia_id_banco_key UNIQUE (fecha_de_pago, referencia, id_banco);


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

