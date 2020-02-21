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
  ADD_ACCOUNT:
    "INSERT INTO cuenta(id_usuario, username, password) VALUES($1, $2, $3);",
  ADD_PASSWORD:
    "INSERT INTO cuentas_funcionarios (id_usuario, password) VALUES ($1, $2);",
  CHECK_IF_ADMIN:
    "SELECT 1 FROM usuarios u \
    INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Administrador' AND u.cedula = $1",
  CHECK_IF_SUPERUSER:
    "SELECT 1 FROM usuarios u \
  INNER JOIN tipos_usuarios tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
  WHERE tu.descripcion = 'Superuser' AND u.cedula = $1",
  REGISTER_USER:
    "INSERT INTO usuario(cedula, nombre_completo, correo_electronico, telefono, id_institucion, id_oficina, id_rol, id_cargo) \
    VALUES ($1, $2, $3, NULL, $4, $5, $6, $7) ON CONFLICT (cedula) DO NOTHING RETURNING *;",
  ADD_PHONE:
    "INSERT INTO telefonos_usuarios (id_telefono, id_usuario, numero) VALUES (default, $1, $2) RETURNING *;",
  GET_ADMIN:
    "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
    (SELECT id FROM rol WHERE nombre = 'Administrador')",
  // CONFIG
  INIT_CONFIG: "INSERT INTO config VALUES(FALSE, $1);",
  GET_INIT: "SELECT inicializado FROM config;",
  END_WIZARD:
    "UPDATE config SET inicializado = TRUE WHERE inicializado = FALSE RETURNING *",
  // ARBOL
  GET_TREE: "SELECT arbol_jerarquico FROM config;",
  CLEAR_INDEXES:
    "UPDATE cargo SET index_izq = -1, index_der = -1 WHERE nombre != 'Administrador';",
  INSERT_POSITION:
    "INSERT INTO cargo (index_izq, index_der, nombre) \
  VALUES ($1, $2, $3) ON CONFLICT (nombre) \
  DO UPDATE SET index_izq = $1, index_der = $2;",
  SET_TREE: "UPDATE config SET arbol_jerarquico = $1;",
  GET_CHILDREN:
    "SELECT id, nombre FROM cargo WHERE index_izq > $1 AND index_der < $2",
  GET_CHILDREN_USERS:
    "SELECT u.* FROM datos_usuario u INNER JOIN usuario x ON u.cedula = x.cedula INNER JOIN cargo c ON c.id = x.id_cargo \
    WHERE c.index_izq > $1 AND c.index_der < $2 AND x.telefono IS NOT NULL;",
  IS_UNDER_IN_TREE:
    "WITH cargo_emisor AS (SELECT c.* FROM cargo c INNER JOIN usuario u ON u.id_cargo = c.id WHERE u.cedula = $1), \
    cargo_responsable AS (SELECT c.* FROM cargo c INNER JOIN usuario u ON u.id_cargo = c.id WHERE u.cedula = $2) \
    SELECT ((SELECT index_izq FROM cargo_responsable) > (SELECT index_izq FROM cargo_emisor) \
    AND (SELECT index_der FROM cargo_responsable) < (SELECT index_der FROM cargo_emisor)) AS is_under",
  // INSTITUCIONES
  GET_ALL_INSTITUTIONS: "SELECT * FROM institucion;",
  DELETE_INSTITUTION: "DELETE FROM institucion WHERE id = $1 RETURNING *;",
  GET_INSTITUTION: "SELECT * FROM institucion WHERE id = $1;",
  CREATE_INSTITUTION:
    "INSERT INTO institucion(descripcion) VALUES($1) RETURNING *;",
  EDIT_INSTITUTION:
    "UPDATE institucion SET descripcion = $1 WHERE id = $2 RETURNING *;",
  // OFICINAS
  GET_INSTITUTION_OFFICES:
    "SELECT o.* FROM oficina o INNER JOIN institucion i ON i.id = o.id_institucion WHERE i.id = $1;",
  CREATE_OFFICE:
    "INSERT INTO oficina(descripcion, id_institucion) VALUES($1, $2) RETURNING *;",
  EDIT_OFFICE:
    "UPDATE oficina SET descripcion = $1, id_institucion = $4 WHERE id = $2 AND id_institucion = $3 RETURNING *;",
  DELETE_OFFICE:
    "DELETE FROM oficina WHERE id = $1 AND id_institucion = $2 RETURNING *;",
  // ROLES
  GET_ALL_ROLES: "SELECT * FROM rol;",
  GET_PERMISSIONS:
    "SELECT f.* FROM funcion f INNER JOIN rol_funcion rf ON rf.id_funcion = f.id WHERE rf.id_rol = $1;",
  DELETE_ROLE:
    "DELETE FROM rol WHERE id = $1 AND id != (SELECT id FROM rol WHERE nombre = 'Administrador') RETURNING *;",
  EDIT_ROLE_WITH_PERMISSIONS: "SELECT * FROM editar_rol($1, $2, $3);",
  EDIT_ROLE_WIHOUT_PERMISSIONS: "SELECT * FROM editar_rol($1, $2);",
  CREATE_ROLE: "SELECT * FROM crear_rol($1, $2);",
  GET_ROLE_BY_ID: "SELECT * FROM rol WHERE id = $1;",
  // INVITACIONES
  GET_ALL_INVITATIONS:
    "SELECT i.*, u.nombre_completo FROM invitacion i INNER JOIN usuario u ON u.correo_electronico = i.correo",
  CREATE_INVITATION:
    "INSERT INTO invitacion(correo, token) VALUES($1, $2) ON CONFLICT (correo) \
    DO NOTHING RETURNING *;",
  DELETE_INVITATION:
    "WITH inv AS (DELETE FROM invitacion WHERE id = $1 RETURNING *) \
    DELETE FROM usuario WHERE correo_electronico = (SELECT correo FROM inv) AND telefono IS NULL RETURNING *",
  ACCEPT_INVITATION:
    "WITH invite AS (DELETE FROM invitacion WHERE token = $2 AND id = $1 RETURNING *), \
    usuario_result AS (UPDATE usuario SET telefono = $3 WHERE correo_electronico = (SELECT correo FROM invite) RETURNING *) \
    INSERT INTO cuenta(id_usuario, username, password) VALUES((SELECT cedula FROM usuario_result), $4, $5) RETURNING *;",
  GET_INVITATION_DATA:
    "SELECT cedula, nombre_completo as nombre FROM usuario WHERE cedula = $1",
  CHECK_TOKEN: "SELECT * FROM invitacion WHERE token = $1 AND id = $2;",
  REFRESH_TOKEN: "UPDATE invitacion SET token = $1 WHERE id = $2 RETURNING *;",
  // TAREAS
  GET_USER_TASKS: "SELECT * FROM datos_tarea WHERE responsable = $1",
  GET_SENT_TASKS: "SELECT * FROM datos_tarea WHERE emisor = $1",
  CREATE_TASK:
    "INSERT INTO tarea(emisor, responsable, status, fecha_asignacion, fecha_entrega, descripcion, titulo) VALUES($1, $2, 1, NOW(), $3, $4, $5) RETURNING *",
  GET_TASK_BY_ID: "SELECT * FROM datos_tarea WHERE id = $1",
  DELETE_TASK: "DELETE FROM tarea WHERE id = $1",
  CHECK_TASK: "SELECT * FROM datos_tarea WHERE id = $1;",
  UPDATE_TASK_STATUS:
    "UPDATE tarea SET status = $1 WHERE id = $2 RETURNING id;",
  UPDATE_TASK_INFO:
    "WITH updated as (UPDATE tarea SET titulo = $1, descripcion = $2 WHERE id = $3) \
    SELECT * FROM datos_tarea WHERE id = $3;",
  GET_RATE_PENDING:
    "SELECT * FROM datos_tarea WHERE status = 4 AND emisor = $1;",
  RATE_TASK: "SELECT * FROM calificar_tarea($1, $2);",
  // COMENTARIOS
  CAN_COMMENT:
    "SELECT true AS can_comment FROM tarea WHERE (responsable = $1 OR emisor = $1) AND id = $2;",
  GET_TASK_COMMENTS: "SELECT * FROM comentario WHERE target = $1 AND tipo = 1",
  CREATE_COMMENT:
    "INSERT INTO comentario(emisor, target, tipo, descripcion, url_archivo) VALUES($1, $2, 1, $3, $4) RETURNING *;",
  EDIT_COMMENT:
    "UPDATE comentario SET descripcion = $1 WHERE id = $2 RETURNING *;",
  CAN_EDIT_COMMENT:
    "SELECT id FROM comentario WHERE target = $1 AND tipo = 1 AND emisor = $2",
  DELETE_COMMENT: "DELETE FROM comentario WHERE id = $1 RETURNING *;",
  // PERMISOS
  GET_ALL_PERMISSIONS: "SELECT * FROM funcion;",
  HAS_PERMISSION:
    "SELECT * FROM rol_funcion WHERE id_rol = (SELECT id_rol FROM usuario WHERE cedula = $1) AND id_funcion = $2",
  GET_USET_PERMISSIONS:
    "SELECT id_funcion FROM rol_funcion WHERE id_rol = (SELECT id_rol FROM usuario WHERE cedula = $1);",
  // NOTIFICACIONES
  GET_USER_NOTIFICATIONS:
    "SELECT * FROM datos_notificacion WHERE receptor = $1 ORDER BY fecha DESC LIMIT 100;",
  CREATE_NOTIFICATION:
    "INSERT INTO notificacion(emisor, receptor, descripcion, target, tipo) VALUES($1, $2, $3, $4, $5) RETURNING *;",
  GET_NOTIFICATION_BY_ID: "SELECT * FROM datos_notificacion WHERE id = $1;",
  HAS_UNREAD_NOTIF:
    "SELECT id FROM notificacion WHERE status = FALSE AND receptor = $1;",
  MARK_ALL_AS_READ:
    "UPDATE notificacion SET status = TRUE WHERE status = FALSE AND receptor = $1;",
  // PROYECTOS
  GET_ALL_PROJECTS: "SELECT * FROM datos_proyecto",
  GET_PROJECT_FILES: "SELECT * FROM proyecto_archivo WHERE id_proyecto = $1;",
  GET_PROJECT_ACTIVITIES: "SELECT * FROM actividad WHERE id_proyecto = $1;",
  CREATE_PROJECT:
    "INSERT INTO proyecto(fecha_culminacion, status, id_institucion, responsable, nombre, direccion, id_parroquia, longitud, latitud,\
    duracion_estimada, fecha_inicio, descripcion, costo_dolares, costo_bs, poblacion, cantidad)\
    VALUES(NULL, 1, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) RETURNING *",
  CREATE_ACTIVITY:
    "INSERT INTO actividad(id_proyecto, descripcion, duracion, status, fecha_inicio, fecha_fin, fecha_culminacion) \
    VALUES($1, $2, $3, 1, $4, $5, NULL) RETURNING *",
  INSERT_FILE:
    "INSERT INTO proyecto_archivo(id_proyecto, url_archivo) VALUES($1, $2) RETURNING *",
  GET_PROJECT_BY_ID: "SELECT * FROM datos_proyecto WHERE id_proyecto = $1",
  GET_BY_GOOGLE_ID: "SELECT * FROM datos_google WHERE id_google = $1",
  GET_BY_FACEBOOK_ID: "SELECT * FROM datos_google WHERE id_google = $1",
  INSERT_GOOGLE_USER: "INSERT INTO datos_google VALUES ($1, $2)",
  INSERT_FACEOOK_USER: "INSERT INTO datos_facebook VALUES ($1, $2)",
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
