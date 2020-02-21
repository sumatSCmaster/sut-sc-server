const queries = {
  // USUARIO
  GET_USER_BY_USERNAME: "SELECT * FROM usuarios WHERE nombre_de_usuario = $1;",
  GET_USER_BY_ID: "SELECT * FROM datos_usuario WHERE cedula = $1",
  GET_PHONES_FROM_USERNAME:
    "SELECT numero FROM telefonos_usuarios tu \
    INNER JOIN usuarios u ON tu.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1;",
  GET_USER_TYPE_FROM_USERNAME:
    "SELECT tu.* FROM tipos_usuarios tu \
    INNER JOIN usuarios u ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE U.nombre_de_usuario = $1;",
  GET_GOOGLE_DATA_FROM_USERNAME:
    "SELECT dg.* FROM datos_google dg \
    INNER JOIN usuarios u ON dg.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1",
  GET_OFFICIAL_DATA_FROM_USERNAME:
    "SELECT cf.* FROM cuentas_funcionarios cf \
    INNER JOIN usuarios u ON u.id_usuario = cf.id_usuario \
    WHERE u.nombre_de_usuario = $1;",
  CREATE_USER: `INSERT INTO usuarios (nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, rif, id_tipo_usuario) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
  ASSIGN_ALL_PERMISSIONS:
    "INSERT INTO rol_funcion(id_rol, id_funcion) SELECT $1, id FROM funcion;",
  ADD_PASSWORD:
    "INSERT INTO cuentas_funcionarios (id_usuario, password) VALUES ($1, $2);",
  GET_ADMIN_INSTITUTE: 'SELECT i.* FROM instituciones i INNER JOIN cuentas_funcionarios cf ON i.id_institucion = cf.id_institucion \
    WHERE cf.id_usuario = $1;',
  ADD_OFFICIAL_DATA: 'INSERT INTO cuentas_funcionarios (id_usuario, password, id_institucion) VALUES ($1, $2, $3);',
  CHECK_IF_ADMIN: "SELECT 1 FROM usuarios u \
    INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = \'Administrador\' AND u.cedula = $1",
  CHECK_IF_SUPERUSER: "SELECT 1 FROM usuarios u \
  INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
  WHERE tu.descripcion = 'Superuser' AND u.cedula = $1",
  ADD_PHONE: 'INSERT INTO telefonos_usuarios (id_telefono, id_usuario, numero) VALUES (default, $1, $2) RETURNING *;',
  GET_ADMIN: 'SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
    (SELECT id FROM rol WHERE nombre = \'Administrador\')',
  GET_BY_GOOGLE_ID: "SELECT * FROM datos_google WHERE id_google = $1",
  INSERT_GOOGLE_USER: "INSERT INTO datos_google VALUES ($1, $2)",
  GET_EXTERNAL_USER: "SELECT * FROM usuarios WHERE id_usuario = $1",
  EXTERNAL_USER_INIT:
    "INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, id_tipo_usuario) VALUES ($1, $2, 4) RETURNING *",
  EXTERNAL_USER_COMPLETE:
    "UPDATE USUARIOS SET direccion = $1, cedula = $2, nacionalidad = $3, rif=$4 WHERE id_usuario = $5 RETURNING *",

  //BANKS
  GET_ALL_BANKS: "SELECT * FROM BANCOS",

  //OFFICIALS
  GET_OFFICIAL:
    "SELECT usr.*, cf.password from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_institucion = $2",
  GET_OFFICIAlS_BY_INSTITUTION:
    "SELECT usr.*, cf.password from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
    usr.id_usuario=cf.id_usuario WHERE cf.id_institucion = $1",
  CREATE_OFFICIAL:
    "WITH funcionario AS (INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, rif, id_tipo_usuario) VALUES ($1, $2, $3, $4, $5, $6, 3) RETURNING id_usuario)\
    INSERT INTO cuentas_funcionarios VALUES((SELECT id_usuario from funcionario), $7, $8) RETURNING *",
  UPDATE_OFFICIAL:
    "WITH updated AS (UPDATE usuarios SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, rif = $6 WHERE id_usuario = $7 RETURNING id_usuario)\
    UPDATE cuentas_funcionarios SET password = $8 WHERE id_usuario = (SELECT id_usuario from updated)",
  DELETE_OFFICIAL:
    "DELETE FROM USUARIOS usr USING CUENTAS_FUNCIONARIOS cf WHERE\
    usr.id_usuario = cf.id_usuario AND usr.id_usuario = $1\
    AND cf.id_institucion = $2;",
  GET_FIELDS_BY_PROCEDURE:
    "SELECT ct.*, camp.nombre, camp.tipo FROM campos_tramites ct INNER JOIN\
     campos camp ON ct.id_campo = camp.id_campo WHERE ct.id_tipo_tramite = $1 ORDER BY ct.orden",
  GET_PROCEDURE_BY_INSTITUTION:
    "SELECT id_tipo_tramite, nombre_tramite, costo_base FROM tipos_tramites tt WHERE id_institucion = $1",
  GET_ALL_INSTITUTION: "SELECT * FROM INSTITUCIONES"
};

export default queries;
