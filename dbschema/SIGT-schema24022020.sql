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
    id_tipo_tramite integer,
    orden integer,
    estado integer
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
    costo_base numeric
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
-- Data for Name: bancos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bancos (id_banco, nombre) FROM stdin;
1	Banco Occidental de Descuento
2	Banesco
\.


--
-- Data for Name: campos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos (id_campo, nombre, tipo) FROM stdin;
\.


--
-- Data for Name: campos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos_tramites (id_campo, id_tipo_tramite, orden, estado) FROM stdin;
\.


--
-- Data for Name: cuentas_funcionarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cuentas_funcionarios (id_usuario, password, id_institucion) FROM stdin;
\.


--
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
\.


--
-- Data for Name: instituciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones (id_institucion, nombre_completo, nombre_corto) FROM stdin;
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
\.


--
-- Data for Name: pagos_manuales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pagos_manuales (id_pago, id_usuario_funcionario) FROM stdin;
\.


--
-- Data for Name: parroquias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parroquias (id_parroquia, nombre) FROM stdin;
\.


--
-- Data for Name: recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recaudos (id_recaudo, descripcion) FROM stdin;
\.


--
-- Data for Name: status_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.status_tramites (id_status_tramite, descripcion) FROM stdin;
\.


--
-- Data for Name: telefonos_usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.telefonos_usuarios (id_telefono, id_usuario, numero) FROM stdin;
\.


--
-- Data for Name: tipos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites (id_tipo_tramite, id_institucion, nombre_tramite, costo_base) FROM stdin;
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

COPY public.tramites (id_tramite, id_tipo_tramite, id_google, id_status_tramite, datos) FROM stdin;
\.


--
-- Data for Name: tramites_archivos_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramites_archivos_recaudos (id_tramite, url_archivo_recaudo) FROM stdin;
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, rif, id_tipo_usuario) FROM stdin;
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
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 2, true);


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

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 1, false);


--
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_parroquia_seq', 1, true);


--
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, false);


--
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.status_tramites_id_status_tramite_seq', 1, false);


--
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.telefonos_usuarios_id_telefono_seq', 12, true);


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

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 24, true);


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
-- Name: operaciones operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.operaciones
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


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
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


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
    ADD CONSTRAINT telefonos_usuarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


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

