const queries = {
  // USUARIO
  GET_USER_BY_USERNAME: "SELECT * FROM datos_usuario WHERE username = $1;",
  GET_USER_BY_ID: "SELECT * FROM datos_usuario WHERE cedula = $1",
  CREATE_ADMIN:
    "WITH institucion_result AS (INSERT INTO institucion (descripcion) VALUES ($1) RETURNING id), \
    oficina_result AS (INSERT INTO oficina (descripcion, id_institucion) VALUES ($2, (SELECT id FROM institucion_result)) RETURNING id), \
    rol_result AS (INSERT INTO rol (nombre) VALUES ('Administrador') RETURNING id), \
    cargo_result AS (INSERT INTO cargo (nombre, index_izq, index_der) VALUES($3, 0, 1) RETURNING id) \
    INSERT INTO usuario(cedula, nombre_completo, correo_electronico, telefono, id_institucion, id_oficina, id_rol, id_cargo) \
    VALUES ($4, $5, $6, $7, (SELECT id FROM institucion_result), (SELECT id FROM oficina_result), (SELECT id FROM rol_result), (SELECT id FROM cargo_result)) \
    RETURNING *;",
  ASSIGN_ALL_PERMISSIONS:
    "INSERT INTO rol_funcion(id_rol, id_funcion) SELECT $1, id FROM funcion;",
  ADD_ACCOUNT:
    "INSERT INTO cuenta(id_usuario, username, password) VALUES($1, $2, $3);",
  CHECK_IF_ADMIN:
    "SELECT 1 FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
    (SELECT id FROM rol WHERE nombre = 'Administrador') AND u.cedula = $1;",
  REGISTER_USER:
    "INSERT INTO usuario(cedula, nombre_completo, correo_electronico, telefono, id_institucion, id_oficina, id_rol, id_cargo) \
    VALUES ($1, $2, $3, NULL, $4, $5, $6, $7) ON CONFLICT (cedula) DO NOTHING RETURNING *;",
  GET_ADMIN:
    "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
    (SELECT id FROM rol WHERE nombre = 'Administrador')",
  GET_BY_GOOGLE_ID: "SELECT * FROM datos_google WHERE id_google = $1",
  INSERT_GOOGLE_USER: "INSERT INTO datos_google VALUES ($1, $2)",
  GET_EXTERNAL_USER: "SELECT * FROM usuarios WHERE id_usuario = $1",
  EXTERNAL_USER_INIT:
    "INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, id_tipo_usuario) VALUES ($1, $2, 3) RETURNING *",
  EXTERNAL_USER_COMPLETE: "",

  //BANKS
  GET_ALL_BANKS: "SELECT * FROM BANCOS",

  //OFFICIALS
  GET_OFFICIAL:
    "SELECT usr.*, cf.password from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_institucion = $2",
  GET_OFFICIAlS_BY_INSTITUTION:
    "SELECT usr.*, cf.password from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
    usr.id_usuario=cf.id_usuario WHERE cf.id_institucion = $1",
  INSERT_OFFICIAL:
    "WITH funcionario AS (INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, rif, id_tipo_usuario) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id_usuario)\
    INSERT INTO cuentas_funcionarios VALUES((SELECT id_usuario from funcionario), $8) RETURNING *)",
  UPDATE_OFFICIAL:
    "UPDATE funcionario SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, rif = $6 WHERE id_usuario = $7\
    UPDATE cuentas_funcionario SET password = $8 WHERE id_usuario = $7",
  DELETE_OFFICIAL:
    "DELETE FROM USUARIOS usr USING CUENTAS_FUNCIONARIOS cf WHERE\
    usr.id_usuario = cf.id_usuario AND usr.id_usuario = $1\
    AND cf.id_institucion = $2;",
  FORCE_ERROR: "SELET * FROM USUARIOS"
};

export default queries;
