/*
  Orden de secciones:
  Creates
  Reads
    -Validaciones
  Updates
  Deletes

*/

const queries = {
  // USUARIO
  CREATE_USER: `INSERT INTO usuarios (nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
  ADD_PASSWORD: 'INSERT INTO cuentas_funcionarios (id_usuario, password) VALUES ($1, $2);',
  ADD_OFFICIAL_DATA: 'INSERT INTO cuentas_funcionarios (id_usuario, id_institucion) VALUES ($1, $2);',
  INSERT_GOOGLE_USER: 'INSERT INTO datos_google VALUES ($1, $2)',
  INSERT_FACEBOOK_USER: 'INSERT INTO datos_facebook VALUES ($1, $2)',
  EXTERNAL_USER_INIT: 'INSERT INTO USUARIOS (nombre_completo, id_tipo_usuario) VALUES ($1, 4) RETURNING *',
  SIGN_UP_WITH_LOCAL_STRATEGY:
    'INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
  nacionalidad,id_tipo_usuario, password, telefono) VALUES ($1,$2,$3,$4,$5,4,$6, $7) RETURNING *',
  ADD_PASSWORD_RECOVERY:
    'WITH usuario AS (SELECT id_usuario FROM usuarios WHERE nombre_de_usuario = $1) \
       INSERT INTO recuperacion (id_usuario, token_recuperacion, usado) VALUES ((SELECT id_usuario FROM usuario), $2, false) RETURNING token_recuperacion;',
  GET_USER_BY_USERNAME: 'SELECT * FROM usuarios WHERE nombre_de_usuario = $1;',
  GET_USER_BY_ID: 'SELECT * FROM datos_usuario WHERE cedula = $1',
  GET_USER_INFO_BY_ID:
    'SELECT nombre_completo as "nombreCompleto", nombre_de_usuario AS "nombreUsuario", direccion, cedula, nacionalidad FROM usuarios WHERE id_usuario = $1;',
  GET_PHONES_FROM_USERNAME:
    'SELECT numero FROM telefonos_usuarios tu \
    INNER JOIN usuarios u ON tu.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_USER_TYPE_FROM_USERNAME:
    'SELECT tu.* FROM tipos_usuarios tu \
    INNER JOIN usuarios u ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE U.nombre_de_usuario = $1;',
  GET_GOOGLE_DATA_FROM_USERNAME:
    'SELECT dg.* FROM datos_google dg \
    INNER JOIN usuarios u ON dg.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1',
  GET_OFFICIAL_DATA_FROM_USERNAME:
    'SELECT cf.* FROM cuentas_funcionarios cf \
    INNER JOIN usuarios u ON u.id_usuario = cf.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_ADMIN:
    "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
  (SELECT id FROM rol WHERE nombre = 'Administrador')",
  GET_OAUTH_USER:
    'SELECT usr.* FROM USUARIOS usr LEFT JOIN datos_facebook df ON usr.id_usuario=df.id_usuario\
  LEFT JOIN datos_google dg ON usr.id_usuario = dg.id_usuario\
  WHERE dg.id_google = $1 OR df.id_facebook=$1',
  GET_EXTERNAL_USER: 'SELECT * FROM usuarios WHERE id_usuario = $1',
  GET_ADMIN_INSTITUTE:
    'SELECT i.* FROM instituciones i INNER JOIN cuentas_funcionarios cf ON i.id_institucion = cf.id_institucion \
    WHERE cf.id_usuario = $1;',
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
  VALIDATE_TOKEN: "SELECT 1 FROM recuperacion WHERE token_recuperacion = $1 AND usado = false AND CURRENT_TIMESTAMP - fecha_recuperacion < '20 minutes';",
  EMAIL_EXISTS: 'SELECT 1 FROM usuarios u WHERE nombre_de_usuario = $1;',
  EXTERNAL_USER_COMPLETE:
    'UPDATE USUARIOS SET direccion = $1, cedula = $2, nacionalidad = $3, nombre_de_usuario = $4, password=$5, nombre_completo=$6, telefono=$7 WHERE id_usuario = $8 RETURNING *',
  DISABLE_TOKEN: 'UPDATE recuperacion SET usado = true WHERE token_recuperacion = $1',
  UPDATE_PASSWORD:
    'WITH usuario AS (SELECT u.id_usuario FROM usuarios u INNER JOIN recuperacion r ON r.id_usuario = u.id_usuario WHERE token_recuperacion = $1) \
      UPDATE usuarios SET password = $2 WHERE id_usuario = (SELECT id_usuario FROM usuario)',

  //BANKS
  INSERT_PAYMENT: 'INSERT INTO pagos (id_tramite, referencia, monto, id_banco, fecha_de_pago) VALUES ($1, $2, $3, $4, $5) RETURNING *;',
  GET_ALL_BANKS: 'SELECT id_banco as id, nombre  FROM BANCOS',
  VALIDATE_PAYMENTS: 'SELECT validate_payments($1);',
  GET_BANK_ACCOUNTS_FOR_INSTITUTION:
    'SELECT id_instituciones_bancos AS id, id_institucion AS institucion, id_banco AS banco, \
    numero_cuenta AS numerocuenta, nombre_titular AS nombretitular, documento_de_identificacion AS documento FROM instituciones_bancos WHERE id_institucion = $1',

  //OFFICIALS
  CREATE_OFFICIAL:
    'WITH funcionario AS (INSERT INTO USUARIOS (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, 3, $6, $7) RETURNING id_usuario)\
    INSERT INTO cuentas_funcionarios VALUES((SELECT id_usuario from funcionario), $8) RETURNING *',
  GET_OFFICIAL:
    'SELECT usr.* from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_institucion = $2',
  GET_OFFICIALS_BY_INSTITUTION:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
    from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
    usr.id_usuario=cf.id_usuario WHERE cf.id_institucion = $1 AND usr.id_usuario != $2 AND usr.id_tipo_usuario!=1',
  GET_ALL_OFFICIALS:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
    from USUARIOS usr INNER JOIN CUENTAS_FUNCIONARIOS cf ON\
    usr.id_usuario=cf.id_usuario WHERE usr.id_tipo_usuario!=1',
  GET_ALL_INSTITUTION: 'SELECT * FROM INSTITUCIONES',
  GET_ONE_INSTITUTION: 'SELECT * FROM INSTITUCIONES WHERE id_institucion = $1',
  GET_ONE_INSTITUTION_INFO:
    'SELECT id_institucion AS id, nombre_completo AS "nombreCompleto", nombre_corto AS "nombreCorto" FROM instituciones WHERE id_institucion = $1;',
  UPDATE_OFFICIAL:
    'UPDATE usuarios SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, telefono =$6 WHERE id_usuario = $7 RETURNING *',
  DELETE_OFFICIAL:
    'DELETE FROM USUARIOS usr USING CUENTAS_FUNCIONARIOS cf WHERE\
    usr.id_usuario = cf.id_usuario AND usr.id_usuario = $1\
    AND cf.id_institucion = $2 RETURNING *;',
  DELETE_OFFICIAL_AS_SUPERUSER: 'DELETE FROM usuarios WHERE usuarios.id_usuario = $1 RETURNING *;',

  //Tramites
  PROCEDURE_INIT: 'SELECT * FROM insert_tramite($1, $2, $3);',
  CREATE_RECEIPT: 'INSERT INTO facturas_tramites (id_factura, id_tramite) VALUES (default, $1) RETURNING *;',
  ADD_ITEM_TO_RECEIPT: 'INSERT INTO detalles_facturas (id_detalle, id_factura, nombre, costo) VALUES (default, $1, $2, $3)',
  GET_SECTIONS_BY_PROCEDURE:
    'SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  CAMPOS_TRAMITES ct RIGHT JOIN SECCIONES sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1 ORDER BY sect.id_seccion',
  GET_PROCEDURE_BY_INSTITUTION:
    'SELECT id_tipo_tramite, nombre_tramite, costo_base, pago_previo FROM tipos_tramites tt WHERE id_institucion = $1 ORDER BY id_tipo_tramite',
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campos_tramites ct INNER JOIN\
    campos camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_BY_SECTION_FOR_OFFICIALS:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campos_tramites ct INNER JOIN\
    campos camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND NOT (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_FOR_SOCIAL_CASE:
    'SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campos_tramites ct INNER JOIN\
  campos camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 ORDER BY ct.orden',
  GET_TAKINGS_BY_PROCEDURE:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto,\
  ttr.fisico FROM RECAUDOS rec INNER JOIN tipos_tramites_recaudos ttr ON rec.id_recaudo=ttr.id_recaudo\
  WHERE ttr.id_tipo_tramite=$1 ORDER BY rec.id_recaudo',
  GET_TAKINGS_FOR_VALIDATION:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto, \
ttr.fisico FROM RECAUDOS rec INNER JOIN tipos_tramites_recaudos ttr ON rec.id_recaudo=ttr.id_recaudo \
WHERE ttr.id_tipo_tramite=$1 AND ttr.fisico = false ORDER BY rec.id_recaudo',
  GET_TAKINGS_OF_INSTANCES: 'SELECT * FROM tramites_archivos_recaudos WHERE id_tramite = ANY( $1::int[] );',
  INSERT_TAKINGS_IN_PROCEDURE: 'INSERT INTO tramites_archivos_recaudos VALUES ($1,$2)',
  GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID:
    'SELECT tramites_state.*, instituciones.nombre_completo AS nombrelargo, instituciones.nombre_corto AS \
    nombrecorto, tipos_tramites.nombre_tramite AS nombretramitelargo, tipos_tramites.nombre_corto AS nombretramitecorto FROM tramites_state INNER JOIN tipos_tramites ON tramites_state.tipotramite = \
    tipos_tramites.id_tipo_tramite INNER JOIN instituciones ON instituciones.id_institucion = \
    tipos_tramites.id_institucion WHERE tipos_tramites.id_institucion = $1 ORDER BY tramites_state.fechacreacion;',
  GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION:
    "SELECT tramites_state.*, instituciones.nombre_completo AS nombrelargo, instituciones.nombre_corto AS \
    nombrecorto, tipos_tramites.nombre_tramite AS nombretramitelargo, tipos_tramites.nombre_corto AS nombretramitecorto FROM tramites_state INNER JOIN tipos_tramites ON tramites_state.tipotramite = \
    tipos_tramites.id_tipo_tramite INNER JOIN instituciones ON instituciones.id_institucion = \
    tipos_tramites.id_institucion WHERE tipos_tramites.id_institucion = $1 AND tramites_state.state='enproceso' ORDER BY tramites_state.fechacreacion;",
  GET_ONE_PROCEDURE: 'SELECT * FROM tipos_tramites WHERE id_tipo_tramite = $1',
  GET_ONE_PROCEDURE_INFO:
    'SELECT id_tipo_tramite as id, id_institucion AS "idInstitucion", nombre_tramite AS "nombre", costo_base as costo, nombre_corto as "nombreCorto"  FROM tipos_tramites WHERE id_tipo_tramite = $1;',
  UPDATE_PROCEDURE_COST: 'UPDATE tipos_tramites SET costo_base = $2 WHERE id_tipo_tramite = $1 RETURNING *',
  VALIDATE_FIELDS_FROM_PROCEDURE:
    'SELECT DISTINCT camp.validacion, camp.tipo FROM CAMPOS_TRAMITES ct INNER JOIN CAMPOS camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=$2',
  GET_RESOURCES_FOR_PROCEDURE:
    'SELECT DISTINCT tt.pago_previo, tt.costo_base, usr.nombre_completo as nombrecompleto, \
    usr.nombre_de_usuario as nombreusuario FROM tipos_tramites tt INNER JOIN tramites tr ON\
    tt.id_tipo_tramite=tr.id_tipo_tramite INNER JOIN usuarios usr ON tr.id_usuario=usr.id_usuario\
    WHERE tt.id_tipo_tramite=$1',
  GET_PROCEDURE_STATES:
    'SELECT id_tramite AS id, tramites_eventos_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM eventos_tramite \
  GROUP BY id_tramite;',
  GET_PROCEDURE_STATE:
    'SELECT id_tramite AS id, tramites_eventos_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM eventos_tramite \
  WHERE id_tramite = $1 \
  GROUP BY id_tramite;', //tramite
  UPDATE_STATE: 'SELECT update_tramite_state($1, $2, $3, $4, $5) as state;', //tramite, evento
  UPDATE_PROCEDURE_INSTANCE_COST: 'UPDATE tramites SET costo = $1 WHERE id_tramite = $2',
  GET_PROCEDURE_BY_ID: 'SELECT * FROM tramites_state_with_resources WHERE id=$1',
  GET_CERTIFICATE_BY_PROCEDURE_ID: 'SELECT url_certificado AS "urlCertificado" FROM certificados WHERE id_tramite = $1',
  GET_PROCEDURE_INSTANCES_FOR_USER: 'SELECT * FROM tramites_state_with_resources WHERE usuario = $1 ORDER BY fechacreacion;',
  GET_ALL_PROCEDURE_INSTANCES: 'SELECT * FROM tramites_state_with_resources ORDER BY fechacreacion;',

  //Parroquias
  GET_PARROQUIAS: 'SELECT * FROM parroquia;',
};

export default queries;
