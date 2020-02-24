PGDMP             
            x            SIGT    12.1    12.1 �                0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false                       0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false                       0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false                       1262    18316    SIGT    DATABASE     �   CREATE DATABASE "SIGT" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'English_United States.1252' LC_CTYPE = 'English_United States.1252';
    DROP DATABASE "SIGT";
                postgres    false            �            1259    18317    bancos    TABLE     \   CREATE TABLE public.bancos (
    id_banco integer NOT NULL,
    nombre character varying
);
    DROP TABLE public.bancos;
       public         heap    postgres    false            �            1259    18323    bancos_id_banco_seq    SEQUENCE     �   CREATE SEQUENCE public.bancos_id_banco_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.bancos_id_banco_seq;
       public          postgres    false    202                       0    0    bancos_id_banco_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.bancos_id_banco_seq OWNED BY public.bancos.id_banco;
          public          postgres    false    203            �            1259    18325    campos    TABLE     x   CREATE TABLE public.campos (
    id_campo integer NOT NULL,
    nombre character varying,
    tipo character varying
);
    DROP TABLE public.campos;
       public         heap    postgres    false            �            1259    18331    campos_id_campo_seq    SEQUENCE     �   CREATE SEQUENCE public.campos_id_campo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.campos_id_campo_seq;
       public          postgres    false    204                       0    0    campos_id_campo_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.campos_id_campo_seq OWNED BY public.campos.id_campo;
          public          postgres    false    205            �            1259    18333    campos_tramites    TABLE     �   CREATE TABLE public.campos_tramites (
    id_campo integer,
    id_tipo_tramite integer,
    orden integer,
    estado integer
);
 #   DROP TABLE public.campos_tramites;
       public         heap    postgres    false            �            1259    18336    cuentas_funcionarios    TABLE     �   CREATE TABLE public.cuentas_funcionarios (
    id_usuario integer NOT NULL,
    password character varying,
    id_institucion integer
);
 (   DROP TABLE public.cuentas_funcionarios;
       public         heap    postgres    false            �            1259    18647    datos_facebook    TABLE     t   CREATE TABLE public.datos_facebook (
    id_usuario integer NOT NULL,
    id_facebook character varying NOT NULL
);
 "   DROP TABLE public.datos_facebook;
       public         heap    postgres    false            �            1259    18342    datos_google    TABLE     p   CREATE TABLE public.datos_google (
    id_usuario integer NOT NULL,
    id_google character varying NOT NULL
);
     DROP TABLE public.datos_google;
       public         heap    postgres    false            �            1259    18348    instituciones    TABLE     �   CREATE TABLE public.instituciones (
    id_institucion integer NOT NULL,
    nombre_completo character varying,
    nombre_corto character varying
);
 !   DROP TABLE public.instituciones;
       public         heap    postgres    false            �            1259    18354     instituciones_id_institucion_seq    SEQUENCE     �   CREATE SEQUENCE public.instituciones_id_institucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.instituciones_id_institucion_seq;
       public          postgres    false    209                       0    0     instituciones_id_institucion_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.instituciones_id_institucion_seq OWNED BY public.instituciones.id_institucion;
          public          postgres    false    210            �            1259    18356    notificaciones    TABLE     �   CREATE TABLE public.notificaciones (
    id_notificacion integer NOT NULL,
    id_tramite integer,
    emisor character varying,
    receptor character varying,
    descripcion character varying,
    status boolean,
    fecha timestamp with time zone
);
 "   DROP TABLE public.notificaciones;
       public         heap    postgres    false            �            1259    18362 "   notificaciones_id_notificacion_seq    SEQUENCE     �   CREATE SEQUENCE public.notificaciones_id_notificacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.notificaciones_id_notificacion_seq;
       public          postgres    false    211                       0    0 "   notificaciones_id_notificacion_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.notificaciones_id_notificacion_seq OWNED BY public.notificaciones.id_notificacion;
          public          postgres    false    212            �            1259    18364    operaciones_id_operacion_seq    SEQUENCE     �   CREATE SEQUENCE public.operaciones_id_operacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.operaciones_id_operacion_seq;
       public          postgres    false            �            1259    18366    operaciones    TABLE     �   CREATE TABLE public.operaciones (
    id_operacion integer DEFAULT nextval('public.operaciones_id_operacion_seq'::regclass) NOT NULL,
    nombre_op character varying
);
    DROP TABLE public.operaciones;
       public         heap    postgres    false    213            �            1259    18373    pagos    TABLE       CREATE TABLE public.pagos (
    id_pago integer NOT NULL,
    id_tramite integer,
    referencia character varying,
    monto numeric,
    fecha_de_pago timestamp with time zone,
    aprobado boolean,
    id_banco integer,
    fecha_de_aprobacion timestamp with time zone
);
    DROP TABLE public.pagos;
       public         heap    postgres    false            �            1259    18379    pagos_id_pago_seq    SEQUENCE     �   CREATE SEQUENCE public.pagos_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.pagos_id_pago_seq;
       public          postgres    false    215                       0    0    pagos_id_pago_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.pagos_id_pago_seq OWNED BY public.pagos.id_pago;
          public          postgres    false    216            �            1259    18381    pagos_manuales    TABLE     i   CREATE TABLE public.pagos_manuales (
    id_pago integer NOT NULL,
    id_usuario_funcionario integer
);
 "   DROP TABLE public.pagos_manuales;
       public         heap    postgres    false            �            1259    18384 
   parroquias    TABLE     d   CREATE TABLE public.parroquias (
    id_parroquia integer NOT NULL,
    nombre character varying
);
    DROP TABLE public.parroquias;
       public         heap    postgres    false            �            1259    18390    parroquias_id_parroquia_seq    SEQUENCE     �   CREATE SEQUENCE public.parroquias_id_parroquia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.parroquias_id_parroquia_seq;
       public          postgres    false    218            	           0    0    parroquias_id_parroquia_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.parroquias_id_parroquia_seq OWNED BY public.parroquias.id_parroquia;
          public          postgres    false    219            �            1259    18392    recaudos    TABLE     e   CREATE TABLE public.recaudos (
    id_recaudo integer NOT NULL,
    descripcion character varying
);
    DROP TABLE public.recaudos;
       public         heap    postgres    false            �            1259    18398    recaudos_id_recaudo_seq    SEQUENCE     �   CREATE SEQUENCE public.recaudos_id_recaudo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.recaudos_id_recaudo_seq;
       public          postgres    false    220            
           0    0    recaudos_id_recaudo_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.recaudos_id_recaudo_seq OWNED BY public.recaudos.id_recaudo;
          public          postgres    false    221            �            1259    18400    status_tramites    TABLE     s   CREATE TABLE public.status_tramites (
    id_status_tramite integer NOT NULL,
    descripcion character varying
);
 #   DROP TABLE public.status_tramites;
       public         heap    postgres    false            �            1259    18406 %   status_tramites_id_status_tramite_seq    SEQUENCE     �   CREATE SEQUENCE public.status_tramites_id_status_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.status_tramites_id_status_tramite_seq;
       public          postgres    false    222                       0    0 %   status_tramites_id_status_tramite_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.status_tramites_id_status_tramite_seq OWNED BY public.status_tramites.id_status_tramite;
          public          postgres    false    223            �            1259    18408    telefonos_usuarios    TABLE     �   CREATE TABLE public.telefonos_usuarios (
    id_telefono integer NOT NULL,
    id_usuario integer,
    numero character varying
);
 &   DROP TABLE public.telefonos_usuarios;
       public         heap    postgres    false            �            1259    18414 "   telefonos_usuarios_id_telefono_seq    SEQUENCE     �   CREATE SEQUENCE public.telefonos_usuarios_id_telefono_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.telefonos_usuarios_id_telefono_seq;
       public          postgres    false    224                       0    0 "   telefonos_usuarios_id_telefono_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.telefonos_usuarios_id_telefono_seq OWNED BY public.telefonos_usuarios.id_telefono;
          public          postgres    false    225            �            1259    18416    tipos_tramites    TABLE     �   CREATE TABLE public.tipos_tramites (
    id_tipo_tramite integer NOT NULL,
    id_institucion integer,
    nombre_tramite character varying,
    costo_base numeric
);
 "   DROP TABLE public.tipos_tramites;
       public         heap    postgres    false            �            1259    18422 "   tipos_tramites_id_tipo_tramite_seq    SEQUENCE     �   CREATE SEQUENCE public.tipos_tramites_id_tipo_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.tipos_tramites_id_tipo_tramite_seq;
       public          postgres    false    226                       0    0 "   tipos_tramites_id_tipo_tramite_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.tipos_tramites_id_tipo_tramite_seq OWNED BY public.tipos_tramites.id_tipo_tramite;
          public          postgres    false    227            �            1259    18424    tipos_tramites_recaudos    TABLE     e   CREATE TABLE public.tipos_tramites_recaudos (
    id_tipo_tramite integer,
    id_recaudo integer
);
 +   DROP TABLE public.tipos_tramites_recaudos;
       public         heap    postgres    false            �            1259    18427    tipos_usuarios    TABLE     p   CREATE TABLE public.tipos_usuarios (
    id_tipo_usuario integer NOT NULL,
    descripcion character varying
);
 "   DROP TABLE public.tipos_usuarios;
       public         heap    postgres    false            �            1259    18433 "   tipos_usuarios_id_tipo_usuario_seq    SEQUENCE     �   CREATE SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq;
       public          postgres    false    229                       0    0 "   tipos_usuarios_id_tipo_usuario_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.tipos_usuarios_id_tipo_usuario_seq OWNED BY public.tipos_usuarios.id_tipo_usuario;
          public          postgres    false    230            �            1259    18435    tramites    TABLE     �   CREATE TABLE public.tramites (
    id_tramite integer NOT NULL,
    id_tipo_tramite integer,
    id_google character varying,
    id_status_tramite integer,
    datos json
);
    DROP TABLE public.tramites;
       public         heap    postgres    false            �            1259    18441    tramites_archivos_recaudos    TABLE     v   CREATE TABLE public.tramites_archivos_recaudos (
    id_tramite integer,
    url_archivo_recaudo character varying
);
 .   DROP TABLE public.tramites_archivos_recaudos;
       public         heap    postgres    false            �            1259    18447    tramites_id_tramite_seq    SEQUENCE     �   CREATE SEQUENCE public.tramites_id_tramite_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.tramites_id_tramite_seq;
       public          postgres    false    231                       0    0    tramites_id_tramite_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.tramites_id_tramite_seq OWNED BY public.tramites.id_tramite;
          public          postgres    false    233            �            1259    18449    usuarios    TABLE     �  CREATE TABLE public.usuarios (
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
    DROP TABLE public.usuarios;
       public         heap    postgres    false            �            1259    18456    usuarios_id_usuario_seq    SEQUENCE     �   CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.usuarios_id_usuario_seq;
       public          postgres    false    234                       0    0    usuarios_id_usuario_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;
          public          postgres    false    235            �            1259    18458    variables_id_var_seq    SEQUENCE     }   CREATE SEQUENCE public.variables_id_var_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.variables_id_var_seq;
       public          postgres    false            �            1259    18460 	   variables    TABLE     �   CREATE TABLE public.variables (
    id_var integer DEFAULT nextval('public.variables_id_var_seq'::regclass) NOT NULL,
    nombre_variable character varying
);
    DROP TABLE public.variables;
       public         heap    postgres    false    236            �            1259    18467 +   variables_de_costo_id_variable_de_costo_seq    SEQUENCE     �   CREATE SEQUENCE public.variables_de_costo_id_variable_de_costo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 B   DROP SEQUENCE public.variables_de_costo_id_variable_de_costo_seq;
       public          postgres    false            �            1259    18469    variables_de_costo    TABLE       CREATE TABLE public.variables_de_costo (
    id_variable_de_costo integer DEFAULT nextval('public.variables_de_costo_id_variable_de_costo_seq'::regclass) NOT NULL,
    id_tipo_tramite integer,
    id_operacion integer,
    precedencia integer,
    aumento numeric
);
 &   DROP TABLE public.variables_de_costo;
       public         heap    postgres    false    238            	           2604    18476    bancos id_banco    DEFAULT     r   ALTER TABLE ONLY public.bancos ALTER COLUMN id_banco SET DEFAULT nextval('public.bancos_id_banco_seq'::regclass);
 >   ALTER TABLE public.bancos ALTER COLUMN id_banco DROP DEFAULT;
       public          postgres    false    203    202            
           2604    18477    campos id_campo    DEFAULT     r   ALTER TABLE ONLY public.campos ALTER COLUMN id_campo SET DEFAULT nextval('public.campos_id_campo_seq'::regclass);
 >   ALTER TABLE public.campos ALTER COLUMN id_campo DROP DEFAULT;
       public          postgres    false    205    204                       2604    18478    instituciones id_institucion    DEFAULT     �   ALTER TABLE ONLY public.instituciones ALTER COLUMN id_institucion SET DEFAULT nextval('public.instituciones_id_institucion_seq'::regclass);
 K   ALTER TABLE public.instituciones ALTER COLUMN id_institucion DROP DEFAULT;
       public          postgres    false    210    209                       2604    18479    notificaciones id_notificacion    DEFAULT     �   ALTER TABLE ONLY public.notificaciones ALTER COLUMN id_notificacion SET DEFAULT nextval('public.notificaciones_id_notificacion_seq'::regclass);
 M   ALTER TABLE public.notificaciones ALTER COLUMN id_notificacion DROP DEFAULT;
       public          postgres    false    212    211                       2604    18480    pagos id_pago    DEFAULT     n   ALTER TABLE ONLY public.pagos ALTER COLUMN id_pago SET DEFAULT nextval('public.pagos_id_pago_seq'::regclass);
 <   ALTER TABLE public.pagos ALTER COLUMN id_pago DROP DEFAULT;
       public          postgres    false    216    215                       2604    18481    parroquias id_parroquia    DEFAULT     �   ALTER TABLE ONLY public.parroquias ALTER COLUMN id_parroquia SET DEFAULT nextval('public.parroquias_id_parroquia_seq'::regclass);
 F   ALTER TABLE public.parroquias ALTER COLUMN id_parroquia DROP DEFAULT;
       public          postgres    false    219    218                       2604    18482    recaudos id_recaudo    DEFAULT     z   ALTER TABLE ONLY public.recaudos ALTER COLUMN id_recaudo SET DEFAULT nextval('public.recaudos_id_recaudo_seq'::regclass);
 B   ALTER TABLE public.recaudos ALTER COLUMN id_recaudo DROP DEFAULT;
       public          postgres    false    221    220                       2604    18483 !   status_tramites id_status_tramite    DEFAULT     �   ALTER TABLE ONLY public.status_tramites ALTER COLUMN id_status_tramite SET DEFAULT nextval('public.status_tramites_id_status_tramite_seq'::regclass);
 P   ALTER TABLE public.status_tramites ALTER COLUMN id_status_tramite DROP DEFAULT;
       public          postgres    false    223    222                       2604    18484    telefonos_usuarios id_telefono    DEFAULT     �   ALTER TABLE ONLY public.telefonos_usuarios ALTER COLUMN id_telefono SET DEFAULT nextval('public.telefonos_usuarios_id_telefono_seq'::regclass);
 M   ALTER TABLE public.telefonos_usuarios ALTER COLUMN id_telefono DROP DEFAULT;
       public          postgres    false    225    224                       2604    18485    tipos_tramites id_tipo_tramite    DEFAULT     �   ALTER TABLE ONLY public.tipos_tramites ALTER COLUMN id_tipo_tramite SET DEFAULT nextval('public.tipos_tramites_id_tipo_tramite_seq'::regclass);
 M   ALTER TABLE public.tipos_tramites ALTER COLUMN id_tipo_tramite DROP DEFAULT;
       public          postgres    false    227    226                       2604    18486    tipos_usuarios id_tipo_usuario    DEFAULT     �   ALTER TABLE ONLY public.tipos_usuarios ALTER COLUMN id_tipo_usuario SET DEFAULT nextval('public.tipos_usuarios_id_tipo_usuario_seq'::regclass);
 M   ALTER TABLE public.tipos_usuarios ALTER COLUMN id_tipo_usuario DROP DEFAULT;
       public          postgres    false    230    229                       2604    18487    tramites id_tramite    DEFAULT     z   ALTER TABLE ONLY public.tramites ALTER COLUMN id_tramite SET DEFAULT nextval('public.tramites_id_tramite_seq'::regclass);
 B   ALTER TABLE public.tramites ALTER COLUMN id_tramite DROP DEFAULT;
       public          postgres    false    233    231                       2604    18488    usuarios id_usuario    DEFAULT     z   ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);
 B   ALTER TABLE public.usuarios ALTER COLUMN id_usuario DROP DEFAULT;
       public          postgres    false    235    234            �          0    18317    bancos 
   TABLE DATA                 public          postgres    false    202   �       �          0    18325    campos 
   TABLE DATA                 public          postgres    false    204   �       �          0    18333    campos_tramites 
   TABLE DATA                 public          postgres    false    206   m�       �          0    18336    cuentas_funcionarios 
   TABLE DATA                 public          postgres    false    207   ��       �          0    18647    datos_facebook 
   TABLE DATA                 public          postgres    false    240   �       �          0    18342    datos_google 
   TABLE DATA                 public          postgres    false    208   c�       �          0    18348    instituciones 
   TABLE DATA                 public          postgres    false    209   õ       �          0    18356    notificaciones 
   TABLE DATA                 public          postgres    false    211   N�       �          0    18366    operaciones 
   TABLE DATA                 public          postgres    false    214   h�       �          0    18373    pagos 
   TABLE DATA                 public          postgres    false    215   ��       �          0    18381    pagos_manuales 
   TABLE DATA                 public          postgres    false    217   ��       �          0    18384 
   parroquias 
   TABLE DATA                 public          postgres    false    218   ��       �          0    18392    recaudos 
   TABLE DATA                 public          postgres    false    220   ж       �          0    18400    status_tramites 
   TABLE DATA                 public          postgres    false    222   �       �          0    18408    telefonos_usuarios 
   TABLE DATA                 public          postgres    false    224   �       �          0    18416    tipos_tramites 
   TABLE DATA                 public          postgres    false    226   �       �          0    18424    tipos_tramites_recaudos 
   TABLE DATA                 public          postgres    false    228   ��       �          0    18427    tipos_usuarios 
   TABLE DATA                 public          postgres    false    229   ��       �          0    18435    tramites 
   TABLE DATA                 public          postgres    false    231   H�       �          0    18441    tramites_archivos_recaudos 
   TABLE DATA                 public          postgres    false    232   b�       �          0    18449    usuarios 
   TABLE DATA                 public          postgres    false    234   |�       �          0    18460 	   variables 
   TABLE DATA                 public          postgres    false    237   �       �          0    18469    variables_de_costo 
   TABLE DATA                 public          postgres    false    239   �                  0    0    bancos_id_banco_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.bancos_id_banco_seq', 2, true);
          public          postgres    false    203                       0    0    campos_id_campo_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.campos_id_campo_seq', 1, false);
          public          postgres    false    205                       0    0     instituciones_id_institucion_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.instituciones_id_institucion_seq', 1, false);
          public          postgres    false    210                       0    0 "   notificaciones_id_notificacion_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.notificaciones_id_notificacion_seq', 1, false);
          public          postgres    false    212                       0    0    operaciones_id_operacion_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.operaciones_id_operacion_seq', 1, true);
          public          postgres    false    213                       0    0    pagos_id_pago_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.pagos_id_pago_seq', 1, false);
          public          postgres    false    216                       0    0    parroquias_id_parroquia_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.parroquias_id_parroquia_seq', 1, true);
          public          postgres    false    219                       0    0    recaudos_id_recaudo_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.recaudos_id_recaudo_seq', 1, false);
          public          postgres    false    221                       0    0 %   status_tramites_id_status_tramite_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.status_tramites_id_status_tramite_seq', 1, false);
          public          postgres    false    223                       0    0 "   telefonos_usuarios_id_telefono_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.telefonos_usuarios_id_telefono_seq', 4, true);
          public          postgres    false    225                       0    0 "   tipos_tramites_id_tipo_tramite_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.tipos_tramites_id_tipo_tramite_seq', 1, false);
          public          postgres    false    227                       0    0 "   tipos_usuarios_id_tipo_usuario_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.tipos_usuarios_id_tipo_usuario_seq', 1, false);
          public          postgres    false    230                       0    0    tramites_id_tramite_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.tramites_id_tramite_seq', 1, false);
          public          postgres    false    233                       0    0    usuarios_id_usuario_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 22, true);
          public          postgres    false    235                       0    0 +   variables_de_costo_id_variable_de_costo_seq    SEQUENCE SET     Z   SELECT pg_catalog.setval('public.variables_de_costo_id_variable_de_costo_seq', 1, false);
          public          postgres    false    238                        0    0    variables_id_var_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.variables_id_var_seq', 1, false);
          public          postgres    false    236                       2606    18490    bancos bancos_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.bancos
    ADD CONSTRAINT bancos_pkey PRIMARY KEY (id_banco);
 <   ALTER TABLE ONLY public.bancos DROP CONSTRAINT bancos_pkey;
       public            postgres    false    202                       2606    18492    campos campos_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.campos
    ADD CONSTRAINT campos_pkey PRIMARY KEY (id_campo);
 <   ALTER TABLE ONLY public.campos DROP CONSTRAINT campos_pkey;
       public            postgres    false    204                       2606    18494 .   cuentas_funcionarios cuentas_funcionarios_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_pkey PRIMARY KEY (id_usuario);
 X   ALTER TABLE ONLY public.cuentas_funcionarios DROP CONSTRAINT cuentas_funcionarios_pkey;
       public            postgres    false    207            !           2606    18496 '   datos_google datos_google_id_google_key 
   CONSTRAINT     g   ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_google_key UNIQUE (id_google);
 Q   ALTER TABLE ONLY public.datos_google DROP CONSTRAINT datos_google_id_google_key;
       public            postgres    false    208            #           2606    18498    datos_google datos_google_pkey 
   CONSTRAINT     o   ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_pkey PRIMARY KEY (id_usuario, id_google);
 H   ALTER TABLE ONLY public.datos_google DROP CONSTRAINT datos_google_pkey;
       public            postgres    false    208    208            %           2606    18500     instituciones instituciones_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.instituciones
    ADD CONSTRAINT instituciones_pkey PRIMARY KEY (id_institucion);
 J   ALTER TABLE ONLY public.instituciones DROP CONSTRAINT instituciones_pkey;
       public            postgres    false    209            '           2606    18502 "   notificaciones notificaciones_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id_notificacion);
 L   ALTER TABLE ONLY public.notificaciones DROP CONSTRAINT notificaciones_pkey;
       public            postgres    false    211            )           2606    18504    operaciones operacion_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.operaciones
    ADD CONSTRAINT operacion_pkey PRIMARY KEY (id_operacion);
 D   ALTER TABLE ONLY public.operaciones DROP CONSTRAINT operacion_pkey;
       public            postgres    false    214            -           2606    18506 "   pagos_manuales pagos_manuales_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_pkey PRIMARY KEY (id_pago);
 L   ALTER TABLE ONLY public.pagos_manuales DROP CONSTRAINT pagos_manuales_pkey;
       public            postgres    false    217            +           2606    18508    pagos pagos_pkey 
   CONSTRAINT     S   ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);
 :   ALTER TABLE ONLY public.pagos DROP CONSTRAINT pagos_pkey;
       public            postgres    false    215            /           2606    18510    parroquias parroquias_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.parroquias
    ADD CONSTRAINT parroquias_pkey PRIMARY KEY (id_parroquia);
 D   ALTER TABLE ONLY public.parroquias DROP CONSTRAINT parroquias_pkey;
       public            postgres    false    218            1           2606    18512    recaudos recaudos_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.recaudos
    ADD CONSTRAINT recaudos_pkey PRIMARY KEY (id_recaudo);
 @   ALTER TABLE ONLY public.recaudos DROP CONSTRAINT recaudos_pkey;
       public            postgres    false    220            3           2606    18514 $   status_tramites status_tramites_pkey 
   CONSTRAINT     q   ALTER TABLE ONLY public.status_tramites
    ADD CONSTRAINT status_tramites_pkey PRIMARY KEY (id_status_tramite);
 N   ALTER TABLE ONLY public.status_tramites DROP CONSTRAINT status_tramites_pkey;
       public            postgres    false    222            5           2606    18516 *   telefonos_usuarios telefonos_usuarios_pkey 
   CONSTRAINT     q   ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_pkey PRIMARY KEY (id_telefono);
 T   ALTER TABLE ONLY public.telefonos_usuarios DROP CONSTRAINT telefonos_usuarios_pkey;
       public            postgres    false    224            7           2606    18518 "   tipos_tramites tipos_tramites_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_pkey PRIMARY KEY (id_tipo_tramite);
 L   ALTER TABLE ONLY public.tipos_tramites DROP CONSTRAINT tipos_tramites_pkey;
       public            postgres    false    226            9           2606    18520 "   tipos_usuarios tipos_usuarios_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.tipos_usuarios
    ADD CONSTRAINT tipos_usuarios_pkey PRIMARY KEY (id_tipo_usuario);
 L   ALTER TABLE ONLY public.tipos_usuarios DROP CONSTRAINT tipos_usuarios_pkey;
       public            postgres    false    229            ;           2606    18522    tramites tramites_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_pkey PRIMARY KEY (id_tramite);
 @   ALTER TABLE ONLY public.tramites DROP CONSTRAINT tramites_pkey;
       public            postgres    false    231            =           2606    18524    usuarios usuarios_cedula_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_cedula_key UNIQUE (cedula);
 F   ALTER TABLE ONLY public.usuarios DROP CONSTRAINT usuarios_cedula_key;
       public            postgres    false    234            ?           2606    18526    usuarios usuarios_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);
 @   ALTER TABLE ONLY public.usuarios DROP CONSTRAINT usuarios_pkey;
       public            postgres    false    234            C           2606    18528 )   variables_de_costo variable_de_costo_pkey 
   CONSTRAINT     y   ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_pkey PRIMARY KEY (id_variable_de_costo);
 S   ALTER TABLE ONLY public.variables_de_costo DROP CONSTRAINT variable_de_costo_pkey;
       public            postgres    false    239            A           2606    18530    variables variables_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id_var);
 B   ALTER TABLE ONLY public.variables DROP CONSTRAINT variables_pkey;
       public            postgres    false    237            D           2606    18531 -   campos_tramites campos_tramites_id_campo_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_campo_fkey FOREIGN KEY (id_campo) REFERENCES public.campos(id_campo);
 W   ALTER TABLE ONLY public.campos_tramites DROP CONSTRAINT campos_tramites_id_campo_fkey;
       public          postgres    false    206    2845    204            E           2606    18536 4   campos_tramites campos_tramites_id_tipo_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.campos_tramites
    ADD CONSTRAINT campos_tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);
 ^   ALTER TABLE ONLY public.campos_tramites DROP CONSTRAINT campos_tramites_id_tipo_tramite_fkey;
       public          postgres    false    206    226    2871            F           2606    18541 =   cuentas_funcionarios cuentas_funcionarios_id_institucion_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);
 g   ALTER TABLE ONLY public.cuentas_funcionarios DROP CONSTRAINT cuentas_funcionarios_id_institucion_fkey;
       public          postgres    false    209    207    2853            G           2606    18642 9   cuentas_funcionarios cuentas_funcionarios_id_usuario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.cuentas_funcionarios
    ADD CONSTRAINT cuentas_funcionarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;
 c   ALTER TABLE ONLY public.cuentas_funcionarios DROP CONSTRAINT cuentas_funcionarios_id_usuario_fkey;
       public          postgres    false    207    2879    234            H           2606    18637 )   datos_google datos_google_id_usuario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.datos_google
    ADD CONSTRAINT datos_google_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;
 S   ALTER TABLE ONLY public.datos_google DROP CONSTRAINT datos_google_id_usuario_fkey;
       public          postgres    false    208    2879    234            I           2606    18556 -   notificaciones notificaciones_id_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);
 W   ALTER TABLE ONLY public.notificaciones DROP CONSTRAINT notificaciones_id_tramite_fkey;
       public          postgres    false    211    231    2875            J           2606    18561    pagos pagos_id_banco_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.bancos(id_banco);
 C   ALTER TABLE ONLY public.pagos DROP CONSTRAINT pagos_id_banco_fkey;
       public          postgres    false    202    215    2843            K           2606    18566    pagos pagos_id_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);
 E   ALTER TABLE ONLY public.pagos DROP CONSTRAINT pagos_id_tramite_fkey;
       public          postgres    false    2875    215    231            L           2606    18571 *   pagos_manuales pagos_manuales_id_pago_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.pagos(id_pago);
 T   ALTER TABLE ONLY public.pagos_manuales DROP CONSTRAINT pagos_manuales_id_pago_fkey;
       public          postgres    false    2859    215    217            M           2606    18576 9   pagos_manuales pagos_manuales_id_usuario_funcionario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pagos_manuales
    ADD CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey FOREIGN KEY (id_usuario_funcionario) REFERENCES public.cuentas_funcionarios(id_usuario);
 c   ALTER TABLE ONLY public.pagos_manuales DROP CONSTRAINT pagos_manuales_id_usuario_funcionario_fkey;
       public          postgres    false    217    207    2847            N           2606    18581 5   telefonos_usuarios telefonos_usuarios_id_usuario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.telefonos_usuarios
    ADD CONSTRAINT telefonos_usuarios_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);
 _   ALTER TABLE ONLY public.telefonos_usuarios DROP CONSTRAINT telefonos_usuarios_id_usuario_fkey;
       public          postgres    false    2879    234    224            O           2606    18586 1   tipos_tramites tipos_tramites_id_institucion_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipos_tramites
    ADD CONSTRAINT tipos_tramites_id_institucion_fkey FOREIGN KEY (id_institucion) REFERENCES public.instituciones(id_institucion);
 [   ALTER TABLE ONLY public.tipos_tramites DROP CONSTRAINT tipos_tramites_id_institucion_fkey;
       public          postgres    false    226    209    2853            P           2606    18591 ?   tipos_tramites_recaudos tipos_tramites_recaudos_id_recaudo_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey FOREIGN KEY (id_recaudo) REFERENCES public.recaudos(id_recaudo);
 i   ALTER TABLE ONLY public.tipos_tramites_recaudos DROP CONSTRAINT tipos_tramites_recaudos_id_recaudo_fkey;
       public          postgres    false    2865    228    220            Q           2606    18596 D   tipos_tramites_recaudos tipos_tramites_recaudos_id_tipo_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tipos_tramites_recaudos
    ADD CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);
 n   ALTER TABLE ONLY public.tipos_tramites_recaudos DROP CONSTRAINT tipos_tramites_recaudos_id_tipo_tramite_fkey;
       public          postgres    false    226    2871    228            U           2606    18601 E   tramites_archivos_recaudos tramites_archivos_recaudos_id_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tramites_archivos_recaudos
    ADD CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey FOREIGN KEY (id_tramite) REFERENCES public.tramites(id_tramite);
 o   ALTER TABLE ONLY public.tramites_archivos_recaudos DROP CONSTRAINT tramites_archivos_recaudos_id_tramite_fkey;
       public          postgres    false    232    231    2875            R           2606    18606     tramites tramites_id_google_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_google_fkey FOREIGN KEY (id_google) REFERENCES public.datos_google(id_google);
 J   ALTER TABLE ONLY public.tramites DROP CONSTRAINT tramites_id_google_fkey;
       public          postgres    false    208    2849    231            S           2606    18611 (   tramites tramites_id_status_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_status_tramite_fkey FOREIGN KEY (id_status_tramite) REFERENCES public.status_tramites(id_status_tramite);
 R   ALTER TABLE ONLY public.tramites DROP CONSTRAINT tramites_id_status_tramite_fkey;
       public          postgres    false    231    2867    222            T           2606    18616 &   tramites tramites_id_tipo_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.tramites
    ADD CONSTRAINT tramites_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);
 P   ALTER TABLE ONLY public.tramites DROP CONSTRAINT tramites_id_tipo_tramite_fkey;
       public          postgres    false    226    231    2871            V           2606    18621 &   usuarios usuarios_id_tipo_usuario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_tipo_usuario_fkey FOREIGN KEY (id_tipo_usuario) REFERENCES public.tipos_usuarios(id_tipo_usuario);
 P   ALTER TABLE ONLY public.usuarios DROP CONSTRAINT usuarios_id_tipo_usuario_fkey;
       public          postgres    false    234    229    2873            W           2606    18626 6   variables_de_costo variable_de_costo_id_operacion_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_operacion_fkey FOREIGN KEY (id_operacion) REFERENCES public.operaciones(id_operacion);
 `   ALTER TABLE ONLY public.variables_de_costo DROP CONSTRAINT variable_de_costo_id_operacion_fkey;
       public          postgres    false    214    2857    239            X           2606    18631 9   variables_de_costo variable_de_costo_id_tipo_tramite_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.variables_de_costo
    ADD CONSTRAINT variable_de_costo_id_tipo_tramite_fkey FOREIGN KEY (id_tipo_tramite) REFERENCES public.tipos_tramites(id_tipo_tramite);
 c   ALTER TABLE ONLY public.variables_de_costo DROP CONSTRAINT variable_de_costo_id_tipo_tramite_fkey;
       public          postgres    false    239    226    2871            �   X   x���v
Q���W((M��L�KJ�K�/Vs�	uV�0�QPw	)�''g���$�(��*��'�y���\��1����� ?�%C      �   v   x���v
Q���W((M��L�KN�-�/Vs�	uV�0�QP���M*JUp��-�I-�W
�e楫kZsy4���95�4'�3�47)��8��@��y��
)�
a�e�E�&pq �u:v      �   p   x���v
Q���W((M��L�KN�-�/�/)J��,I-Vs�	uV�0�Q�"Mk.O2������d���H���Ϙ|}�����iDfx��Fd����bLf��Å� a���      �   
   x���          �   L   x���v
Q���W((M��L�KI,�/�OKLNM���Vs�	uV�02�QP740156145�0�0�0S״��� ��v      �   P   x���v
Q���W((M��L�KI,�/�O��O�IUs�	uV�0��QP74�4461435764426�0111P״��� ��      �   {   x���v
Q���W((M��L���+.�,)M���K-Vs�	uV�0�QPw��M�KI�K�LTHIUp��MJ-�/�}��3���A�|��5��<�5������Q��1����d��o�.. ��1d      �   
   x���          �   
   x���          �   
   x���          �   
   x���          �   
   x���          �   
   x���          �   
   x���          �   
   x���          �   y   x���v
Q���W((M��L�+�,�/�/)J��,I-Vs�	uV�0�Q "������"���������5�'��A�)NM/�K�G1Ȑ$��!��%S� ��9��%�y��@&pq 4nW{      �   
   x���          �   w   x���v
Q���W((M��L�+�,�/�/-.M,��/Vs�	uV�0�QP.-H-*-N-R״��$Z�P�cJnf^fqIQbJ>�ڍ���J�3��@�i6j�*�V����� k�Q�      �   
   x���          �   
   x���          �   x   x���v
Q���W((M��L�+-.M,��/Vs�	uV�0��QP�)�,VpL.-J-�W��s�"�I鹉�9z���@Q�Pl���5�'6Mv�����WpJ,JʯJ�c*�l.. �:      �   
   x���          �   
   x���         