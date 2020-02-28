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
-- Data for Name: bancos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bancos (id_banco, nombre) FROM stdin;
\.


--
-- Data for Name: campos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos (id_campo, nombre, tipo) FROM stdin;
\.


--
-- Data for Name: instituciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instituciones (id_institucion, nombre_completo, nombre_corto) FROM stdin;
\.


--
-- Data for Name: tipos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites (id_tipo_tramite, id_institucion, nombre_tramite, costo) FROM stdin;
\.


--
-- Data for Name: campos_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.campos_tramites (id_campo, id_tipo_tramite) FROM stdin;
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
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id_usuario, nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, rif, id_tipo_usuario) FROM stdin;
\.


--
-- Data for Name: cuentas_funcionarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cuentas_funcionarios (id_usuario, password) FROM stdin;
\.


--
-- Data for Name: datos_google; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.datos_google (id_usuario, id_google) FROM stdin;
\.


--
-- Data for Name: status_tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.status_tramites (id_status_tramite, descripcion) FROM stdin;
\.


--
-- Data for Name: tramites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramites (id_tramite, id_tipo_tramite, id_google, id_status_tramite, datos) FROM stdin;
\.


--
-- Data for Name: notificaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notificaciones (id_notificacion, id_tramite, emisor, receptor, descripcion, status, fecha) FROM stdin;
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
-- Data for Name: telefonos_usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.telefonos_usuarios (id_telefono, id_usuario, numero) FROM stdin;
\.


--
-- Data for Name: tipos_tramites_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_tramites_recaudos (id_tipo_tramite, id_recaudo) FROM stdin;
\.


--
-- Data for Name: tramites_archivos_recaudos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tramites_archivos_recaudos (id_tramite, url_archivo_recaudo) FROM stdin;
\.


--
-- Name: bancos_id_banco_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bancos_id_banco_seq', 1, false);


--
-- Name: campos_id_campo_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.campos_id_campo_seq', 1, false);


--
-- Name: instituciones_id_institucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);


--
-- Name: notificaciones_id_notificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1, false);


--
-- Name: pagos_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_id_pago_seq', 1, false);


--
-- Name: parroquias_id_parroquia_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parroquias_id_parroquia_seq', 1, false);


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

SELECT pg_catalog.setval('public.telefonos_usuarios_id_telefono_seq', 1, false);


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
-- PostgreSQL database dump complete
--

