PGDMP     
        
            x            sge     12.1 (Ubuntu 12.1-1.pgdg19.04+1)     12.1 (Ubuntu 12.1-1.pgdg19.04+1)     �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    20230    sge    DATABASE     u   CREATE DATABASE sge WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';
    DROP DATABASE sge;
                postgres    false            �            1259    37704 	   parroquia    TABLE     U   CREATE TABLE public.parroquia (
    id integer NOT NULL,
    nombre text NOT NULL
);
    DROP TABLE public.parroquia;
       public         heap    postgres    false            �            1259    37710    parroquias_id_seq    SEQUENCE     �   CREATE SEQUENCE public.parroquias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.parroquias_id_seq;
       public          postgres    false    250            �           0    0    parroquias_id_seq    SEQUENCE OWNED BY     F   ALTER SEQUENCE public.parroquias_id_seq OWNED BY public.parroquia.id;
          public          postgres    false    251                       2604    37712    parroquia id    DEFAULT     m   ALTER TABLE ONLY public.parroquia ALTER COLUMN id SET DEFAULT nextval('public.parroquias_id_seq'::regclass);
 ;   ALTER TABLE public.parroquia ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    251    250            �          0    37704 	   parroquia 
   TABLE DATA                 public          postgres    false    250   [
       �           0    0    parroquias_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.parroquias_id_seq', 110, true);
          public          postgres    false    251            
           2606    37714    parroquia parroquias_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY public.parroquia
    ADD CONSTRAINT parroquias_pkey PRIMARY KEY (id);
 C   ALTER TABLE ONLY public.parroquia DROP CONSTRAINT parroquias_pkey;
       public            postgres    false    250            �   Y  x���Ao�0���
�ؤ�j�AA;��)F!fI�7�Ҥ1$����qK�T��g罰��`;�._���t8��.��hyx��O0E=bY�)�ɖ�L�&��W�7bxD�=+�b��`��ɗHR�F�b+~�`_#�֦l���:��(4j�n9�^u:��gе�+eZ�� ��w��E�EZ�;2+�^��ם���⛀��l����Y&��upvk�e콎��y谷lӍYG����ZE�4҈O/��00��H��<Z`�]F��ٍLh9cK�e#�h�]0}F��E�U�(_��\�E�r���A���T��&�OET�+�*�z�J�K�d�1�x     