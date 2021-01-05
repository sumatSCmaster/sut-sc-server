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
    fecha_creacion TIMESTAMPTZ DEFAULT NOW() - interval '4 hours',
    PRIMARY KEY (id_vehiculo),
    FOREIGN KEY (id_marca_vehiculo) REFERENCES impuesto.marca_vehiculo (id_marca_vehiculo),
    FOREIGN KEY (id_usuario) REFERENCES impuesto.subcategoria_vehiculo (id_subcategoria_vehiculo),
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

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
