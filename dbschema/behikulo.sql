CREATE TABLE impuesto.tipo_vehiculo (
    id_tipo_vehiculo SERIAL NOT NULL,
    descripcion VARCHAR,
    PRIMARY KEY(id_tipo_vehiculo)
);

CREATE TABLE impuesto.categoria_vehiculo(
    id_categoria_vehiculo SERIAL NOT NULL,
    id_tipo_vehiculo INTEGER NOT NULL,
    descripcion VARCHAR,
    PRIMARY KEY (id_categoria_vehiculo),
    FOREIGN KEY (id_tipo_vehiculo) REFERENCES impuesto.tipo_vehiculo (id_tipo_vehiculo)
);

CREATE TABLE impuesto.subcategoria_vehiculo(
    id_subcategoria_vehiculo SERIAL NOT NULL,
    id_categoria_vehiculo INTEGER NOT NULL,
    id_valor INTEGER NOT NULL,
    descripcion VARCHAR,
    tarifa NUMERIC,
    PRIMARY KEY (id_subcategoria_vehiculo),
    FOREIGN KEY (id_categoria_vehiculo) REFERENCES impuesto.categoria_vehiculo (id_categoria_vehiculo),
    FOREIGN KEY (id_valor) REFERENCES valor (id_valor)
);

CREATE TABLE impuesto.vehiculo (
    id_vehiculo SERIAL NOT NULL,
    id_marca_vehiculo INTEGER NOT NULL,
    id_subcategoria_vehiculo INTEGER NOT NULL,
    id_usuario INTEGER NOT NULL,
    modelo_vehiculo VARCHAR,
    placa_vehiculo VARCHAR NOT NULL,
    anio_vehiculo INTEGER,
    color_vehiculo VARCHAR,
    tipo_carroceria_vehiculo VARCHAR,
    tipo_combustible_vehiculo VARCHAR,
    serial_carroceria_vehiculo VARCHAR,
    fecha_creacion TIMESTAMPTZ DEFAULT NOW() - interval '4 hours',
    fecha_ultima_actualizacion TIMESTAMPTZ DEFAULT now() - interval '4 hours',
    PRIMARY KEY (id_vehiculo),
    FOREIGN KEY (id_marca_vehiculo) REFERENCES impuesto.marca_vehiculo (id_marca_vehiculo),
    FOREIGN KEY (id_subcategoria_vehiculo) REFERENCES impuesto.subcategoria_vehiculo (id_subcategoria_vehiculo),
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

CREATE OR REPLACE FUNCTION public.tramites_eventos_transicion(state text, event text)
 RETURNS text
 LANGUAGE sql
AS $function$
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
            WHEN 'validar_veh' THEN 'validando'
            WHEN 'enproceso_pd' THEN 'enproceso'
            WHEN 'enproceso_ompu' THEN 'enproceso' 
            WHEN 'enproceso_lic' THEN 'enproceso'
            WHEN 'enproceso_lict' THEN 'enproceso'
            WHEN 'enproceso_sup' THEN 'enproceso'
            WHEN 'finalizar_tl' THEN 'finalizado'
            WHEN 'procesar_rc' THEN 'enproceso'
            WHEN 'revisar_bc' THEN 'enrevision'
            ELSE 'error'
        END
    WHEN 'validando' THEN
        CASE event
            WHEN 'revisar1_lic' THEN 'enrevision_analista'
            WHEN 'revisar1_lict' THEN 'enrevision_analista'
            WHEN 'enproceso_pa' THEN 'enproceso'
            WHEN 'enproceso_cr' THEN 'enproceso'
            WHEN 'enproceso_lae' THEN 'enproceso'
            WHEN 'ingresardatos_lae' THEN 'ingresardatos'
            WHEN 'finalizar_pd' THEN 'finalizado'
            WHEN 'finalizar_tl' THEN 'finalizado'
            WHEN 'finalizar_ompu' THEN 'finalizado'
            WHEN 'finalizar_veh' THEN 'finalizado'
            WHEN 'rebotar_cr' THEN 'ingresardatos'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    WHEN 'ingresardatos' THEN
        CASE event
            WHEN 'validar_pd' THEN 'validando'
            WHEN 'validar_ompu' THEN 'validando'
            WHEN 'validar_lic' THEN 'validando'
            WHEN 'validar_lict' THEN 'validando'
            WHEN 'validar_lae' THEN 'validando'
            ELSE 'error'
        END
    WHEN 'enproceso' THEN
        CASE event
            WHEN 'ingresardatos_pd' THEN 'ingresardatos'
            WHEN 'finalizar_pa' THEN 'finalizado'
            WHEN 'revisar_cr' THEN 'enrevision'
            WHEN 'revisar_lae' THEN 'enrevision'
            WHEN 'rechazar_lae' THEN 'finalizado'
            WHEN 'revisar_sup' THEN 'enrevision'
            WHEN 'finalizar_sup' THEN 'finalizado'
            WHEN 'rechazar_sup' THEN 'finalizado'
            WHEN 'inspeccion_lic' THEN 'inspeccion'
            WHEN 'ingresardatos_lict' THEN 'ingresardatos'
            WHEN 'aprobar_rc' THEN 'finalizado'
            WHEN 'rechazar_rc' THEN 'finalizado'
            WHEN 'rechazar_ompu' THEN 'enrevision'
            WHEN 'aprobar_ompu' THEN 'enrevision'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    WHEN 'inspeccion' THEN
        CASE event
            WHEN 'rechazar_lic' THEN 'finalizado'
            WHEN 'ingresardatos_lic' THEN 'ingresardatos'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    WHEN 'enrevision_analista' THEN
        CASE event
            WHEN 'rechazar_lic' THEN 'finalizado'
            WHEN 'rechazar_lict' THEN 'finalizado'
            WHEN 'revisar2_lic' THEN 'enrevision_gerente'
            WHEN 'revisar2_lict' THEN 'enrevision_gerente'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    WHEN 'enrevision_gerente' THEN
        CASE event
            WHEN 'rechazar_lic' THEN 'finalizado'
            WHEN 'rechazar_lict' THEN 'finalizado'
            WHEN 'revisar3_lic' THEN 'enrevision'
            WHEN 'revisar3_lict' THEN 'enrevision'
            WHEN 'rebotar_lic' THEN 'finalizado'
            WHEN 'rebotar_lict' THEN 'finalizado'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    WHEN 'enrevision' THEN
        CASE event
            WHEN 'finalizar_cr' THEN 'finalizado'
            WHEN 'rechazar_cr' THEN 'enproceso'
            WHEN 'aprobar_lae' THEN 'finalizado'
            WHEN 'rechazar_lae' THEN 'enproceso'
            WHEN 'ingresardatos_ompu' THEN 'ingresardatos'
            WHEN 'rechazar_ompu' THEN 'enproceso'
            WHEN 'aprobar_bc' THEN 'finalizado'
            WHEN 'rechazar_bc' THEN 'finalizado'
            WHEN 'rechazar_lic' THEN 'finalizado'
            WHEN 'rechazar_lict' THEN 'finalizado'
            WHEN 'rebotar_lic' THEN 'finalizado'
            WHEN 'rebotar_lict' THEN 'finalizado'
            WHEN 'aprobar_lic' THEN 'finalizado'
            WHEN 'aprobar_lict' THEN 'finalizado'
            WHEN 'aprobar_sup' THEN 'finalizado'
            WHEN 'rechazar_sup' THEN 'finalizado'
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'        
        END
    WHEN 'finalizado' THEN
        CASE event
            WHEN 'reversarpago_tramite' THEN 'ingresardatos'
            ELSE 'error'
        END
    ELSE 'error'
END
$function$;

INSERT INTO impuesto.tipo_vehiculo (descripcion) VALUES ('Vehiculos Pesados para Vias Interurbanas');
INSERT INTO impuesto.tipo_vehiculo (descripcion) VALUES ('Vehiculos de Uso Común');

INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (1, 'Categoria Nro. 1: Vehículos de Carga, Sector Alimentación'); -- 1
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (1, 'Categoria Nro. 2: Vehículos de Carga, Sector Salud'); -- 2
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (1, 'Categoria Nro. 3: Vehículos de Carga, Sector Construcción'); -- 3
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (1, 'Categoria Nro. 4: Vehículos de Carga, Otros sectores'); -- 4

INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 1'); -- 5
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 2'); -- 6
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 3'); -- 7
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 4'); -- 8
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 5'); -- 9
INSERT INTO impuesto.categoria_vehiculo (id_tipo_vehiculo, descripcion) VALUES (2, 'Categoria Nro. 6'); -- 10

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (1, 4, 'Liviano de Carga', '0.1');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (1, 4, 'Camión de Carga', '0.2');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (1, 4, 'Camión Carga Pesada', '0.5');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (1, 4, 'Camión Combinado', '0.7');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (1, 4, 'Vehículo Agrícola', '0.9');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (2, 4, 'Liviano de Carga', '0.1');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (2, 4, 'Camión de Carga', '0.2');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (2, 4, 'Camión Carga Pesada', '0.5');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (2, 4, 'Camión Combinado', '0.7');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (3, 4, 'Liviano de Carga', '0.25');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (3, 4, 'Camión de Carga', '0.3');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (3, 4, 'Camión de Carga Pesada', '0.5');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (3, 4, 'Camión Combinado', '0.7');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (3, 4, 'Vehículos de Construcción', '1');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (4, 4, 'Liviano de Carga', '0.5');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (4, 4, 'Camión de Carga', '0.7');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (4, 4, 'Camión Carga Pesada', '1');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (5, 4, 'Automóviles y Camionetas de Uso Particular', '0.1');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (6, 4, 'Camionetas de Carga abiertas, panel o pick up', '0.15');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (7, 4, 'Minibuses o Microbuses hasta 45 puestos', '0.2');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (7, 4, 'Autobuses o buses a partir de 45 puestos', '0.3');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (8, 4, 'Motos con motor hasta 250cc', '0.1');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (8, 4, 'Motos con motor superior a 250cc', '0.15');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (9, 4, 'Camiones de carga, remolques y similares de 3.5 toneladas hasta 7.5 toneladas', '0.2');
INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (9, 4, 'Camiones de carga, remolques y similares mayores de 7.5 toneladas', '0.25');

INSERT INTO impuesto.subcategoria_vehiculo (id_categoria_vehiculo, id_valor, descripcion, tarifa) VALUES (10, 4, 'Gandolas, chutos y remolques de 3 ejes en adelante', '0.4');

INSERT INTO tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, sufijo, nombre_corto, certificado, utiliza_informacion_catastral, pago_previo, id_ramo, formato) VALUES (39, 9, 'Impuesto sobre Vehículos', 'veh', 'Impuesto sobre Vehículos', 'sedemat-solvencia-VH', false, true, 10, 'VEH-001');
INSERT INTO tipo_tramite (id_tipo_tramite, id_institucion, nombre_tramite, sufijo, nombre_corto, certificado, utiliza_informacion_catastral, pago_previo, id_ramo, formato) VALUES (40, 9, 'Impuesto sobre Vehículos Pesados para Vías Interurbanas', 'veh', 'Impuesto sobre Vehículos Pesados', 'sedemat-solvencia-VH', false, true, 10, 'VEH-002');