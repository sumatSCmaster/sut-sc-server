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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
    tipo character varying
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
    id_tipo_tramite integer
);


ALTER TABLE public.campos_tramites OWNER TO postgres;

--
-- Name: cuentas_funcionarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cuentas_funcionarios (
    id_usuario integer NOT NULL,
    password character varying,
    id_institucion integer
);


ALTER TABLE public.cuentas_funcionarios OWNER TO postgres;

--
-- Name: datos_google; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


ALTER TABLE public.datos_google OWNER TO postgres;

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
-- Name: pagos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos (
    id_pago integer NOT NULL,
    id_tramite integer,
    referencia character varying,
    monto numeric,
    fecha_de_pago timestamp with time zone,
    aprobado boolean,
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
-- Name: parroquias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parroquias (
    id_parroquia integer NOT NULL,
    nombre character varying
);


ALTER TABLE public.parroquias OWNER TO postgres;

--
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parroquias_id_parroquia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parroquias_id_parroquia_seq OWNER TO postgres;

--
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parroquias_id_parroquia_seq OWNED BY public.parroquias.id_parroquia;


--
-- Name: recaudos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recaudos (
    id_recaudo integer NOT NULL,
    descripcion character varying
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
-- Name: status_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.status_tramites (
    id_status_tramite integer NOT NULL,
    descripcion character varying
);


ALTER TABLE public.status_tramites OWNER TO postgres;

--
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.status_tramites_id_status_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.status_tramites_id_status_tramite_seq OWNER TO postgres;

--
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.status_tramites_id_status_tramite_seq OWNED BY public.status_tramites.id_status_tramite;


--
-- Name: telefonos_usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.telefonos_usuarios (
    id_telefono integer NOT NULL,
    id_usuario integer,
    numero character varying
);


ALTER TABLE public.telefonos_usuarios OWNER TO postgres;

--
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.telefonos_usuarios_id_telefono_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.telefonos_usuarios_id_telefono_seq OWNER TO postgres;

--
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.telefonos_usuarios_id_telefono_seq OWNED BY public.telefonos_usuarios.id_telefono;


--
-- Name: tipos_tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_tramites (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo numeric
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
-- Name: tramites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tramites (
    id_tramite integer NOT NULL,
    id_tipo_tramite integer,
    id_google character varying,
    id_status_tramite integer,
    datos json
);


ALTER TABLE public.tramites OWNER TO postgres;

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
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    nombre_completo character varying,
    nombre_de_usuario character varying,
    direccion character varying,
    cedula bigint,
    nacionalidad character(1),
    rif character varying,
    id_tipo_usuario integer,
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
-- Name: bancos id_banco; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bancos ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- Name: campos id_campo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- Name: instituciones id_institucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instituciones ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- Name: notificaciones id_notificacion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- Name: pagos id_pago; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- Name: parroquias id_parroquia; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquias ALTER COLUMN id_parroquia SET DEFAULT nextval('public.parroquias_id_parroquia_seq'::regclass);


--
-- Name: recaudos id_recaudo; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudos ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- Name: status_tramites id_status_tramite; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status_tramites ALTER COLUMN id_status_tramite SET DEFAULT nextval('public.status_tramites_id_status_tramite_seq'::regclass);


--
-- Name: telefonos_usuarios id_telefono; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.telefonos_usuarios ALTER COLUMN id_telefono SET DEFAULT nextval('public.telefonos_usuarios_id_telefono_seq'::regclass);


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
-- Name: parroquias parroquias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parroquias
    ADD CONSTRAINT parroquias_pkey PRIMARY KEY (id_parroquia);


--
-- Name: recaudos recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recaudos
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- Name: status_tramites status_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status_tramites
    ADD CONSTRAINT status_tramites_pkey PRIMARY KEY (id_status_tramite);


--
-- Name: telefonos_usuarios telefonos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_pkey PRIMARY KEY (id_telefono);


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
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: campos_tramites campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campos(id_campo);


--
-- Name: campos_tramites campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: cuentas_funcionarios cuentas_funcionarios_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- Name: cuentas_funcionarios cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


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
-- Name: telefonos_usuarios telefonos_usuarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


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
-- Name: tramites tramites_id_google_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_google_fkey FOREIGN KEY (id_google) REFERENCES public.datos_google(id_google);


--
-- Name: tramites tramites_id_status_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_status_tramite_fkey FOREIGN KEY (id_status_tramite) REFERENCES public.status_tramites(id_status_tramite);


--
-- Name: tramites tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- Name: usuarios usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipos_usuarios(id_tipo_usuario);


--
-- PostgreSQL database dump complete
--

