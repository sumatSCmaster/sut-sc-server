--
-- PostgreSQL database dump
--

-- Dumped from database version 12.1
-- Dumped by pg_dump version 12.1

-- Started on 2020-02-21 13:27:37

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
-- TOC entry 202 (class 1259 OID 18317)
-- Name: bancos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bancos (
    id_banco integer NOT NULL,
    nombre character varying
);


--
-- TOC entry 203 (class 1259 OID 18323)
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
-- TOC entry 3069 (class 0 OID 0)
-- Dependencies: 203
-- Name: bancos_id_banco_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.bancos.id_banco;


--
-- TOC entry 204 (class 1259 OID 18325)
-- Name: campos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campos (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying
);


--
-- TOC entry 205 (class 1259 OID 18331)
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
-- TOC entry 3070 (class 0 OID 0)
-- Dependencies: 205
-- Name: campos_id_campo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campos.id_campo;


--
-- TOC entry 206 (class 1259 OID 18333)
-- Name: campos_tramites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campos_tramites (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado integer
);


--
-- TOC entry 207 (class 1259 OID 18336)
-- Name: cuentas_funcionarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cuentas_funcionarios (
    id_usuario integer NOT NULL,
    password character varying,
    id_institucion integer
);


--
-- TOC entry 208 (class 1259 OID 18342)
-- Name: datos_google; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);


--
-- TOC entry 209 (class 1259 OID 18348)
-- Name: instituciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instituciones (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);


--
-- TOC entry 210 (class 1259 OID 18354)
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
-- TOC entry 3071 (class 0 OID 0)
-- Dependencies: 210
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.instituciones.id_institucion;


--
-- TOC entry 211 (class 1259 OID 18356)
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: -
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


--
-- TOC entry 212 (class 1259 OID 18362)
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
-- TOC entry 3072 (class 0 OID 0)
-- Dependencies: 212
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificaciones.id_notificacion;


--
-- TOC entry 213 (class 1259 OID 18364)
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operaciones_id_operacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 214 (class 1259 OID 18366)
-- Name: operaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operaciones (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);


--
-- TOC entry 215 (class 1259 OID 18373)
-- Name: pagos; Type: TABLE; Schema: public; Owner: -
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


--
-- TOC entry 216 (class 1259 OID 18379)
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
-- TOC entry 3073 (class 0 OID 0)
-- Dependencies: 216
-- Name: pagos_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pagos.id_pago;


--
-- TOC entry 217 (class 1259 OID 18381)
-- Name: pagos_manuales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pagos_manuales (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);


--
-- TOC entry 218 (class 1259 OID 18384)
-- Name: parroquias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parroquias (
    id_parroquia integer NOT NULL,
    nombre character varying
);


--
-- TOC entry 219 (class 1259 OID 18390)
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parroquias_id_parroquia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3074 (class 0 OID 0)
-- Dependencies: 219
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parroquias_id_parroquia_seq OWNED BY public.parroquias.id_parroquia;


--
-- TOC entry 220 (class 1259 OID 18392)
-- Name: recaudos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recaudos (
    id_recaudo integer NOT NULL,
    descripcion character varying
);


--
-- TOC entry 221 (class 1259 OID 18398)
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
-- TOC entry 3075 (class 0 OID 0)
-- Dependencies: 221
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudos.id_recaudo;


--
-- TOC entry 222 (class 1259 OID 18400)
-- Name: status_tramites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status_tramites (
    id_status_tramite integer NOT NULL,
    descripcion character varying
);


--
-- TOC entry 223 (class 1259 OID 18406)
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.status_tramites_id_status_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3076 (class 0 OID 0)
-- Dependencies: 223
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.status_tramites_id_status_tramite_seq OWNED BY public.status_tramites.id_status_tramite;


--
-- TOC entry 224 (class 1259 OID 18408)
-- Name: telefonos_usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.telefonos_usuarios (
    id_telefono integer NOT NULL,
    id_usuario integer,
    numero character varying
);


--
-- TOC entry 225 (class 1259 OID 18414)
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.telefonos_usuarios_id_telefono_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3077 (class 0 OID 0)
-- Dependencies: 225
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telefonos_usuarios_id_telefono_seq OWNED BY public.telefonos_usuarios.id_telefono;


--
-- TOC entry 226 (class 1259 OID 18416)
-- Name: tipos_tramites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_tramites (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo_base numeric
);


--
-- TOC entry 227 (class 1259 OID 18422)
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
-- TOC entry 3078 (class 0 OID 0)
-- Dependencies: 227
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipos_tramites.id_tipo_tramite;


--
-- TOC entry 228 (class 1259 OID 18424)
-- Name: tipos_tramites_recaudos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_tramites_recaudos (
    id_tipo_tramite integer,
    id_recaudo integer
);


--
-- TOC entry 229 (class 1259 OID 18427)
-- Name: tipos_usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_usuarios (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);


--
-- TOC entry 230 (class 1259 OID 18433)
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
-- TOC entry 3079 (class 0 OID 0)
-- Dependencies: 230
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipos_usuarios.id_tipo_usuario;


--
-- TOC entry 231 (class 1259 OID 18435)
-- Name: tramites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tramites (
    id_tramite integer NOT NULL,
    id_tipo_tramite integer,
    id_google character varying,
    id_status_tramite integer,
    datos json
);


--
-- TOC entry 232 (class 1259 OID 18441)
-- Name: tramites_archivos_recaudos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tramites_archivos_recaudos (
    id_tramite integer,
    url_archivo_recaudo character varying
);


--
-- TOC entry 233 (class 1259 OID 18447)
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
-- TOC entry 3080 (class 0 OID 0)
-- Dependencies: 233
-- Name: tramites_id_tramite_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramites.id_tramite;


--
-- TOC entry 234 (class 1259 OID 18449)
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
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


--
-- TOC entry 235 (class 1259 OID 18456)
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
-- TOC entry 3081 (class 0 OID 0)
-- Dependencies: 235
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


--
-- TOC entry 236 (class 1259 OID 18458)
-- Name: variables_id_var_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variables_id_var_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 237 (class 1259 OID 18460)
-- Name: variables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variables (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);


--
-- TOC entry 238 (class 1259 OID 18467)
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variables_de_costo_id_variable_de_costo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 239 (class 1259 OID 18469)
-- Name: variables_de_costo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variables_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);


--
-- TOC entry 2820 (class 2604 OID 18476)
-- Name: bancos id_banco; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bancos ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);


--
-- TOC entry 2821 (class 2604 OID 18477)
-- Name: campos id_campo; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campos ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);


--
-- TOC entry 2822 (class 2604 OID 18478)
-- Name: instituciones id_institucion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instituciones ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);


--
-- TOC entry 2823 (class 2604 OID 18479)
-- Name: notificaciones id_notificacion; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);


--
-- TOC entry 2825 (class 2604 OID 18480)
-- Name: pagos id_pago; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);


--
-- TOC entry 2826 (class 2604 OID 18481)
-- Name: parroquias id_parroquia; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parroquias ALTER COLUMN id_parroquia SET DEFAULT nextval('public.parroquias_id_parroquia_seq'::regclass);


--
-- TOC entry 2827 (class 2604 OID 18482)
-- Name: recaudos id_recaudo; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recaudos ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);


--
-- TOC entry 2828 (class 2604 OID 18483)
-- Name: status_tramites id_status_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_tramites ALTER COLUMN id_status_tramite SET DEFAULT nextval('public.status_tramites_id_status_tramite_seq'::regclass);


--
-- TOC entry 2829 (class 2604 OID 18484)
-- Name: telefonos_usuarios id_telefono; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telefonos_usuarios ALTER COLUMN id_telefono SET DEFAULT nextval('public.telefonos_usuarios_id_telefono_seq'::regclass);


--
-- TOC entry 2830 (class 2604 OID 18485)
-- Name: tipos_tramites id_tipo_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_tramites ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);


--
-- TOC entry 2831 (class 2604 OID 18486)
-- Name: tipos_usuarios id_tipo_usuario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_usuarios ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);


--
-- TOC entry 2832 (class 2604 OID 18487)
-- Name: tramites id_tramite; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);


--
-- TOC entry 2833 (class 2604 OID 18488)
-- Name: usuarios id_usuario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- TOC entry 3026 (class 0 OID 18317)
-- Dependencies: 202
-- Data for Name: bancos; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.bancos VALUES (1, 'Banco Occidental de Descuento');
INSERT INTO public.bancos VALUES (2, 'Banesco');


--
-- TOC entry 3028 (class 0 OID 18325)
-- Dependencies: 204
-- Data for Name: campos; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.campos VALUES (1, 'Nombre Completo', 'string');
INSERT INTO public.campos VALUES (2, 'Cedula', 'number');
INSERT INTO public.campos VALUES (3, 'Ganas de Vivir', 'number');


--
-- TOC entry 3030 (class 0 OID 18333)
-- Dependencies: 206
-- Data for Name: campos_tramites; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.campos_tramites VALUES (1, 1, 1, 1);
INSERT INTO public.campos_tramites VALUES (1, 1, 1, 2);
INSERT INTO public.campos_tramites VALUES (2, 1, 2, 1);
INSERT INTO public.campos_tramites VALUES (2, 1, 2, 2);
INSERT INTO public.campos_tramites VALUES (3, 1, 3, 2);
INSERT INTO public.campos_tramites VALUES (3, 1, 3, 1);
INSERT INTO public.campos_tramites VALUES (1, 2, 1, 1);
INSERT INTO public.campos_tramites VALUES (1, 2, 1, 2);
INSERT INTO public.campos_tramites VALUES (2, 2, 2, 1);
INSERT INTO public.campos_tramites VALUES (2, 2, 2, 2);
INSERT INTO public.campos_tramites VALUES (3, 2, 3, 1);
INSERT INTO public.campos_tramites VALUES (1, 3, 1, 1);
INSERT INTO public.campos_tramites VALUES (1, 3, 1, 2);


--
-- TOC entry 3031 (class 0 OID 18336)
-- Dependencies: 207
-- Data for Name: cuentas_funcionarios; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3032 (class 0 OID 18342)
-- Dependencies: 208
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3033 (class 0 OID 18348)
-- Dependencies: 209
-- Data for Name: instituciones; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.instituciones VALUES (1, 'Comandancia de Bomberos de Maracaibo', 'CMB');


--
-- TOC entry 3035 (class 0 OID 18356)
-- Dependencies: 211
-- Data for Name: notificaciones; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3038 (class 0 OID 18366)
-- Dependencies: 214
-- Data for Name: operaciones; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3039 (class 0 OID 18373)
-- Dependencies: 215
-- Data for Name: pagos; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3041 (class 0 OID 18381)
-- Dependencies: 217
-- Data for Name: pagos_manuales; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3042 (class 0 OID 18384)
-- Dependencies: 218
-- Data for Name: parroquias; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3044 (class 0 OID 18392)
-- Dependencies: 220
-- Data for Name: recaudos; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3046 (class 0 OID 18400)
-- Dependencies: 222
-- Data for Name: status_tramites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3048 (class 0 OID 18408)
-- Dependencies: 224
-- Data for Name: telefonos_usuarios; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3050 (class 0 OID 18416)
-- Dependencies: 226
-- Data for Name: tipos_tramites; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tipos_tramites VALUES (1, 1, 'primer tramite', 200);
INSERT INTO public.tipos_tramites VALUES (2, 1, 'segundo tramite', 201);
INSERT INTO public.tipos_tramites VALUES (3, 1, 'tercer tramite', 200);


--
-- TOC entry 3052 (class 0 OID 18424)
-- Dependencies: 228
-- Data for Name: tipos_tramites_recaudos; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3053 (class 0 OID 18427)
-- Dependencies: 229
-- Data for Name: tipos_usuarios; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tipos_usuarios VALUES (1, 'Superuser');
INSERT INTO public.tipos_usuarios VALUES (2, 'Administrador');
INSERT INTO public.tipos_usuarios VALUES (3, 'Funcionario');
INSERT INTO public.tipos_usuarios VALUES (4, 'Usuario externo');


--
-- TOC entry 3055 (class 0 OID 18435)
-- Dependencies: 231
-- Data for Name: tramites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3056 (class 0 OID 18441)
-- Dependencies: 232
-- Data for Name: tramites_archivos_recaudos; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3058 (class 0 OID 18449)
-- Dependencies: 234
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3061 (class 0 OID 18460)
-- Dependencies: 237
-- Data for Name: variables; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3063 (class 0 OID 18469)
-- Dependencies: 239
-- Data for Name: variables_de_costo; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- TOC entry 3082 (class 0 OID 0)
-- Dependencies: 203
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 2, true);


--
-- TOC entry 3083 (class 0 OID 0)
-- Dependencies: 205
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 1, false);


--
-- TOC entry 3084 (class 0 OID 0)
-- Dependencies: 210
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- TOC entry 3085 (class 0 OID 0)
-- Dependencies: 212
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1, false);


--
-- TOC entry 3086 (class 0 OID 0)
-- Dependencies: 213
-- Name: operaciones_id_operacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);


--
-- TOC entry 3087 (class 0 OID 0)
-- Dependencies: 216
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 1, false);


--
-- TOC entry 3088 (class 0 OID 0)
-- Dependencies: 219
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parroquias_id_parroquia_seq', 1, true);


--
-- TOC entry 3089 (class 0 OID 0)
-- Dependencies: 221
-- Name: recaudos_id_recaudo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, false);


--
-- TOC entry 3090 (class 0 OID 0)
-- Dependencies: 223
-- Name: status_tramites_id_status_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.status_tramites_id_status_tramite_seq', 1, false);


--
-- TOC entry 3091 (class 0 OID 0)
-- Dependencies: 225
-- Name: telefonos_usuarios_id_telefono_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.telefonos_usuarios_id_telefono_seq', 4, true);


--
-- TOC entry 3092 (class 0 OID 0)
-- Dependencies: 227
-- Name: tipos_tramites_id_tipo_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 1, false);


--
-- TOC entry 3093 (class 0 OID 0)
-- Dependencies: 230
-- Name: tipos_usuarios_id_tipo_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);


--
-- TOC entry 3094 (class 0 OID 0)
-- Dependencies: 233
-- Name: tramites_id_tramite_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 1, false);


--
-- TOC entry 3095 (class 0 OID 0)
-- Dependencies: 235
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 15, true);


--
-- TOC entry 3096 (class 0 OID 0)
-- Dependencies: 238
-- Name: variables_de_costo_id_variable_de_costo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);


--
-- TOC entry 3097 (class 0 OID 0)
-- Dependencies: 236
-- Name: variables_id_var_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);


--
-- TOC entry 2838 (class 2606 OID 18490)
-- Name: bancos bancos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);


--
-- TOC entry 2840 (class 2606 OID 18492)
-- Name: campos campos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campos
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);


--
-- TOC entry 2842 (class 2606 OID 18494)
-- Name: cuentas_funcionarios cuentas_funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 2844 (class 2606 OID 18496)
-- Name: datos_google datos_google_id_google_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);


--
-- TOC entry 2846 (class 2606 OID 18498)
-- Name: datos_google datos_google_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);


--
-- TOC entry 2848 (class 2606 OID 18500)
-- Name: instituciones instituciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instituciones
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);


--
-- TOC entry 2850 (class 2606 OID 18502)
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);


--
-- TOC entry 2852 (class 2606 OID 18504)
-- Name: operaciones operacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operaciones
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);


--
-- TOC entry 2856 (class 2606 OID 18506)
-- Name: pagos_manuales pagos_manuales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);


--
-- TOC entry 2854 (class 2606 OID 18508)
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- TOC entry 2858 (class 2606 OID 18510)
-- Name: parroquias parroquias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parroquias
    ADD CONSTRAINT parroquias_pkey PRIMARY KEY (id_parroquia);


--
-- TOC entry 2860 (class 2606 OID 18512)
-- Name: recaudos recaudos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recaudos
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);


--
-- TOC entry 2862 (class 2606 OID 18514)
-- Name: status_tramites status_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_tramites
    ADD CONSTRAINT status_tramites_pkey PRIMARY KEY (id_status_tramite);


--
-- TOC entry 2864 (class 2606 OID 18516)
-- Name: telefonos_usuarios telefonos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_pkey PRIMARY KEY (id_telefono);


--
-- TOC entry 2866 (class 2606 OID 18518)
-- Name: tipos_tramites tipos_tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);


--
-- TOC entry 2868 (class 2606 OID 18520)
-- Name: tipos_usuarios tipos_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_usuarios
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);


--
-- TOC entry 2870 (class 2606 OID 18522)
-- Name: tramites tramites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);


--
-- TOC entry 2872 (class 2606 OID 18524)
-- Name: usuarios usuarios_cedula_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);


--
-- TOC entry 2874 (class 2606 OID 18526)
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- TOC entry 2878 (class 2606 OID 18528)
-- Name: variables_de_costo variable_de_costo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);


--
-- TOC entry 2876 (class 2606 OID 18530)
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);


--
-- TOC entry 2879 (class 2606 OID 18531)
-- Name: campos_tramites campos_tramites_id_campo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campos(id_campo);


--
-- TOC entry 2880 (class 2606 OID 18536)
-- Name: campos_tramites campos_tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- TOC entry 2881 (class 2606 OID 18541)
-- Name: cuentas_funcionarios cuentas_funcionarios_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- TOC entry 2882 (class 2606 OID 18546)
-- Name: cuentas_funcionarios cuentas_funcionarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- TOC entry 2883 (class 2606 OID 18551)
-- Name: datos_google datos_google_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- TOC entry 2884 (class 2606 OID 18556)
-- Name: notificaciones notificaciones_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- TOC entry 2885 (class 2606 OID 18561)
-- Name: pagos pagos_id_banco_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.bancos(id_banco);


--
-- TOC entry 2886 (class 2606 OID 18566)
-- Name: pagos pagos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- TOC entry 2887 (class 2606 OID 18571)
-- Name: pagos_manuales pagos_manuales_id_pago_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pagos(id_pago);


--
-- TOC entry 2888 (class 2606 OID 18576)
-- Name: pagos_manuales pagos_manuales_id_usuario_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuentas_funcionarios(id_usuario);


--
-- TOC entry 2889 (class 2606 OID 18581)
-- Name: telefonos_usuarios telefonos_usuarios_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- TOC entry 2890 (class 2606 OID 18586)
-- Name: tipos_tramites tipos_tramites_id_institucion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);


--
-- TOC entry 2891 (class 2606 OID 18591)
-- Name: tipos_tramites_recaudos tipos_tramites_recaudos_id_recaudo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudos(id_recaudo);


--
-- TOC entry 2892 (class 2606 OID 18596)
-- Name: tipos_tramites_recaudos tipos_tramites_recaudos_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- TOC entry 2896 (class 2606 OID 18601)
-- Name: tramites_archivos_recaudos tramites_archivos_recaudos_id_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites_archivos_recaudos
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);


--
-- TOC entry 2893 (class 2606 OID 18606)
-- Name: tramites tramites_id_google_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_google_fkey FOREIGN KEY (id_google) REFERENCES public.datos_google(id_google);


--
-- TOC entry 2894 (class 2606 OID 18611)
-- Name: tramites tramites_id_status_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_status_tramite_fkey FOREIGN KEY (id_status_tramite) REFERENCES public.status_tramites(id_status_tramite);


--
-- TOC entry 2895 (class 2606 OID 18616)
-- Name: tramites tramites_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


--
-- TOC entry 2897 (class 2606 OID 18621)
-- Name: usuarios usuarios_id_tipo_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipos_usuarios(id_tipo_usuario);


--
-- TOC entry 2898 (class 2606 OID 18626)
-- Name: variables_de_costo variable_de_costo_id_operacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operaciones(id_operacion);


--
-- TOC entry 2899 (class 2606 OID 18631)
-- Name: variables_de_costo variable_de_costo_id_tipo_tramite_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);


-- Completed on 2020-02-21 13:27:48

--
-- PostgreSQL database dump complete
--

