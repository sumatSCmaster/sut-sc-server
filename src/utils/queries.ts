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
  CREATE_USER: `INSERT INTO usuarios (nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, rif, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
  ASSIGN_ALL_PERMISSIONS:
    "INSERT INTO rol_funcion(id_rol, id_funcion) SELECT $1, id FROM funcion;",
  ADD_PASSWORD:
    "INSERT INTO cuentas_funcionarios (id_usuario, password) VALUES ($1, $2);",
  GET_ADMIN_INSTITUTE:
    "SELECT i.* FROM instituciones i INNER JOIN cuentas_funcionarios cf ON i.id_institucion = cf.id_institucion \
    WHERE cf.id_usuario = $1;",
  ADD_OFFICIAL_DATA:
    "INSERT INTO cuentas_funcionarios (id_usuario, id_institucion) VALUES ($1, $2);",
  CHECK_IF_OFFICIAL:
    "SELECT 1 FROM usuarios u \
    INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Funcionario' AND u.cedula = $1",
  CHECK_IF_ADMIN:
    "SELECT 1 FROM usuarios u \
    INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Administrador' AND u.cedula = $1",
  CHECK_IF_SUPERUSER:
    "SELECT 1 FROM usuarios u \
  INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
  WHERE tu.descripcion = 'Superuser' AND u.cedula = $1",
  ADD_PHONE:
    "INSERT INTO telefonos_usuarios (id_telefono, id_usuario, numero) VALUES (default, $1, $2) RETURNING *;",
  GET_ADMIN:
    "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
    (SELECT id FROM rol WHERE nombre = 'Administrador')",
  GET_OAUTH_USER:
    "SELECT usr.* FROM USUARIOS usr LEFT JOIN datos_facebook df ON usr.id_usuario=df.id_usuario\
  LEFT JOIN datos_google dg ON usr.id_usuario = dg.id_usuario\
  WHERE dg.id_google = $1 OR df.id_facebook=$1",
  INSERT_GOOGLE_USER: "INSERT INTO datos_google VALUES ($1, $2)",
  INSERT_FACEBOOK_USER: "INSERT INTO datos_facebook VALUES ($1, $2)",
  GET_EXTERNAL_USER: "SELECT * FROM usuarios WHERE id_usuario = $1",
  EXTERNAL_USER_INIT:
    "INSERT INTO USUARIOS (nombre_completo, id_tipo_usuario) VALUES ($1, 4) RETURNING *",
  EXTERNAL_USER_COMPLETE:
    "UPDATE USUARIOS SET direccion = $1, cedula = $2, nacionalidad = $3, rif = $4, nombre_de_usuario = $5, password=$6, nombre_completo=$7, telefono=$8 WHERE id_usuario = $9 RETURNING *",
  SIGN_UP_WITH_LOCAL_STRATEGY:
    "INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad,rif,id_tipo_usuario, password, telefono) VALUES ($1,$2,$3,$4,$5,$6,4,$7, $8) RETURNING *",
  //BANKS
  GET_ALL_BANKS: "SELECT id_banco as id, nombre  FROM BANCOS",
  VALIDATE_PAYMENTS: "SELECT validate_payments($1);",

  //OFFICIALS
  GET_OFFICIAL:
    "SELECT usr.* from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_institucion = $2",
  GET_OFFICIALS_BY_INSTITUTION:
    "SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.rif, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
      from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
      usr.id_usuario=cf.id_usuario WHERE cf.id_institucion = $1",
  CREATE_OFFICIAL:
    "WITH funcionario AS (INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, rif, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $6, 3, $7, $8) RETURNING id_usuario)\
    INSERT INTO cuentas_funcionarios VALUES((SELECT id_usuario from funcionario), $9) RETURNING *",
  UPDATE_OFFICIAL:
    "UPDATE usuarios SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, rif = $6, telefono =$7 WHERE id_usuario = $8 RETURNING id_usuario",
  DELETE_OFFICIAL:
    "DELETE FROM USUARIOS usr USING CUENTAS_FUNCIONARIOS cf WHERE\
    usr.id_usuario = cf.id_usuario AND usr.id_usuario = $1\
    AND cf.id_institucion = $2;",
  GET_SECTIONS_BY_PROCEDURE:
    "SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  CAMPOS_TRAMITES ct RIGHT JOIN SECCIONES sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1",
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campos_tramites ct INNER JOIN\
     campos camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND ct.estado=1 ORDER BY ct.orden",
  GET_PROCEDURE_BY_INSTITUTION:
    "SELECT id_tipo_tramite, nombre_tramite, costo_base FROM tipos_tramites tt WHERE id_institucion = $1",
  GET_ALL_INSTITUTION: "SELECT * FROM INSTITUCIONES",
  GET_ONE_INSTITUTION: "SELECT * FROM INSTITUCIONES WHERE id_institucion = $1",
  GET_ONE_PROCEDURE: "SELECT * FROM tipos_tramites WHERE id_tipo_tramite = $1",
  UPDATE_PROCEDURE_COST: "UPDATE tipos_tramites SET costo_base = $2 WHERE id_tipo_tramite = $1 RETURNING *",
  VALIDATE_FIELDS_FROM_PROCEDURE:
    "SELECT DISTINCT camp.validacion, camp.tipo FROM CAMPOS_TRAMITES ct INNER JOIN CAMPOS camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=1",
  PROCEDURE_INIT:
    "INSERT INTO TRAMITES (id_tipo_tramite, id_status_tramite, datos, id_usuario, fase) VALUES ($1, 1, $2, $3, 1) RETURNING *"
};

export default queries;
