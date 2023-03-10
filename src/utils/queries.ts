/*
  Orden de seccion:
  Creates
  Reads
    -Validaciones
  Updates
  Deletes

*/

const queries = {
  // USUARIO
  GET_USER_ID_BY_RIF: 'SELECT id_contribuyente FROM impuesto.contribuyente WHERE documento = $1 AND tipo_documento = $2;',
  CREATE_USER: `INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono) \
  VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
  ADD_PASSWORD: 'INSERT INTO cuenta_funcionario (id_usuario, password) VALUES ($1, $2);',
  ADD_OFFICIAL_DATA: 'INSERT INTO cuenta_funcionario (id_usuario, id_cargo) VALUES ($1, $2) RETURNING *;',
  ADD_OFFICIAL_PERMISSIONS: 'INSERT INTO permiso_de_acceso (id_usuario, id_tipo_tramite) VALUES ($1, $2)',
  INSERT_GOOGLE_USER: 'INSERT INTO datos_google VALUES ($1, $2)',
  INSERT_FACEBOOK_USER: 'INSERT INTO datos_facebook VALUES ($1, $2)',
  EXTERNAL_USER_INIT: 'INSERT INTO usuario (nombre_completo, id_tipo_usuario) VALUES ($1, 4) RETURNING *',
  SIGN_UP_WITH_LOCAL_STRATEGY: 'INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula,\
  nacionalidad,id_tipo_usuario, password, telefono) VALUES ($1,$2,$3,$4,$5,4,$6, $7) RETURNING *',
  ADD_PASSWORD_RECOVERY:
    'WITH usuario AS (SELECT id_usuario FROM usuario WHERE nombre_de_usuario = $1) \
       INSERT INTO recuperacion (id_usuario, token_recuperacion, usado) VALUES ((SELECT id_usuario FROM usuario), $2, false) RETURNING token_recuperacion;',
  GET_USER_BY_USERNAME: 'SELECT * FROM usuario WHERE nombre_de_usuario = $1;',
  GET_USER_BY_ID: 'SELECT * FROM datos_usuario WHERE cedula = $1',
  GET_USER_INFO_BY_ID: 'SELECT nombre_completo as "nombreCompleto", nombre_de_usuario AS "nombreUsuario", direccion, cedula, nacionalidad, telefono FROM usuario WHERE id_usuario = $1;',
  GET_PHONES_FROM_USERNAME: 'SELECT numero FROM telefonos_usuario tu \
    INNER JOIN usuario u ON tu.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_USER_TYPE_FROM_USERNAME: 'SELECT tu.* FROM tipo_usuario tu \
    INNER JOIN usuario u ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE U.nombre_de_usuario = $1;',
  GET_GOOGLE_DATA_FROM_USERNAME: 'SELECT dg.* FROM datos_google dg \
    INNER JOIN usuario u ON dg.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1',
  GET_FACEBOOK_DATA_FROM_USERNAME: 'SELECT df.* FROM datos_facebook dg \
    INNER JOIN usuario u ON df.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_OFFICIAL_DATA_FROM_USERNAME: 'SELECT cf.* FROM cuenta_funcionario cf \
    INNER JOIN usuario u ON u.id_usuario = cf.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_USER_PERMISSIONS: 'SELECT pa.id_tipo_tramite FROM permiso_de_acceso pa WHERE id_usuario = $1',
  GET_ADMIN: "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
  (SELECT id FROM rol WHERE nombre = 'Administrador')",
  GET_OAUTH_USER: 'SELECT usr.* FROM usuario usr LEFT JOIN datos_facebook df ON usr.id_usuario=df.id_usuario\
  LEFT JOIN datos_google dg ON usr.id_usuario = dg.id_usuario\
  WHERE dg.id_google = $1 OR df.id_facebook=$1',
  GET_EXTERNAL_USER: 'SELECT * FROM usuario WHERE id_usuario = $1',
  GET_ADMIN_INSTITUTE:
    'SELECT i.*, cf.bloqueado, c.descripcion AS cargo, c.id_cargo AS "idCargo" FROM institucion i INNER JOIN cargo c ON i.id_institucion = c.id_institucion INNER JOIN cuenta_funcionario cf ON c.id_cargo = cf.id_cargo \
    WHERE cf.id_usuario = $1;',
  GET_LAST_EDITOR_AND_DATE: `SELECT nombre_completo, fecha_movimiento FROM usuario JOIN movimientos USING (id_usuario) WHERE id_procedimiento = $1 ORDER BY fecha_movimiento DESC LIMIT 1;`,
  CHECK_IF_OFFICIAL: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Funcionario' AND u.cedula = $1",
  GET_APPROVED_CPU_PROCEDURE: 'SELECT 1 FROM tramite WHERE id_tipo_tramite = 16 AND aprobado = true AND codigo_tramite = $1;',
  CHECK_IF_DIRECTOR: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Director/Gerente' AND u.cedula = $1",
  CHECK_IF_ADMIN: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Administrador' AND u.cedula = $1",
  CHECK_IF_CHIEF: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Jefe de Departamento' AND u.cedula = $1",
  CHECK_IF_SUPERUSER: "SELECT 1 FROM usuario u \
  INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
  WHERE tu.descripcion = 'Superuser' AND u.cedula = $1",
  ADMIN_EXISTS: 'SELECT * FROM usuario usr inner join cuenta_funcionario cf ON usr.id_usuario \
  = cf.id_usuario WHERE id_tipo_usuario = 2 AND id_cargo = $1',
  VALIDATE_TOKEN: "SELECT 1 FROM recuperacion WHERE token_recuperacion = $1 AND usado = false AND CURRENT_TIMESTAMP - fecha_recuperacion < '20 minutes';",
  EMAIL_EXISTS: 'SELECT 1 FROM usuario u WHERE nombre_de_usuario = $1;',
  EXTERNAL_USER_COMPLETE: 'UPDATE usuario SET direccion = $1, cedula = $2, nacionalidad = $3, nombre_de_usuario = $4, password=$5, nombre_completo=$6, telefono=$7 \
    WHERE id_usuario = $8 RETURNING *',
  DISABLE_TOKEN: 'UPDATE recuperacion SET usado = true WHERE token_recuperacion = $1',
  UPDATE_PASSWORD:
    'WITH usuarioTmp AS (SELECT u.id_usuario FROM usuario u INNER JOIN recuperacion r ON r.id_usuario = u.id_usuario WHERE token_recuperacion = $1) \
      UPDATE usuario SET password = $2 WHERE id_usuario = (SELECT id_usuario FROM usuarioTmp)',
  UPDATE_USER: 'UPDATE usuario SET direccion = $1, nombre_completo = $2, telefono = $3 WHERE id_usuario = $4 RETURNING id_usuario as id, direccion, \
      nombre_completo as "nombreCompleto", telefono',
  DROP_OFFICIAL_PERMISSIONS: 'DELETE FROM permiso_de_acceso WHERE id_usuario = $1;',
  GET_USER_TYPES: 'SELECT * FROM tipo_usuario WHERE id_tipo_usuario != 1 AND id_tipo_usuario != 4',
  GET_JOBS_BY_TYPES_AND_INSTITUTION: 'SELECT id_cargo AS id, descripcion FROM cargo WHERE id_tipo_usuario = $1 AND id_institucion = $2',

  //BANKS
  INSERT_PAYMENT: 'INSERT INTO pago (id_procedimiento, referencia, monto, id_banco, fecha_de_pago, concepto, id_banco_destino, id_usuario) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *;',
  INSERT_PAYMENT_CASHIER:
    "INSERT INTO pago (id_procedimiento, referencia, monto, id_banco, fecha_de_pago, concepto, aprobado, fecha_de_aprobacion, metodo_pago, id_usuario, id_banco_destino) VALUES ($1, $2, $3, $4, $5, $6, true, (NOW() - interval '4 hours'), $7, $8, $9) RETURNING *;",

  GET_ALL_BANKS: 'SELECT id_banco as id, nombre, validador  FROM banco',
  VALIDATE_PAYMENTS: 'SELECT validate_payments($1);',
  GET_ACCOUNT_STATE_BY_BANK: `SELECT * FROM estado_cuenta WHERE id_banco = $1`,
  UPDATE_ACCOUNT_STATE: `UPDATE estado_cuenta SET data = $1 WHERE id_banco = $2`,
  SET_ACCOUNT_STATE: `INSERT INTO estado_cuenta (id_banco, data, fecha_actualizacion) VALUES ($1, $2, NOW() - interval '4 hours')`,
  GET_ALL_ACCOUNT_STATES: `SELECT * FROM estado_cuenta;`,
  GET_BANK_ACCOUNTS_FOR_INSTITUTION:
    'SELECT id_institucion_banco AS id, id_institucion AS institucion, id_banco AS banco, \
    numero_cuenta AS numerocuenta, nombre_titular AS nombretitular, documento_de_identificacion AS documento FROM institucion_banco WHERE id_institucion = $1',

  //OFFICIALS
  CREATE_OFFICIAL:
    'WITH funcionario AS (INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $9, $6, $7) RETURNING id_usuario)\
    INSERT INTO cuenta_funcionario VALUES((SELECT id_usuario from funcionario), $8) RETURNING *',
  GET_OFFICIAL: 'SELECT usr.* from usuario usr INNER JOIN cuenta_funcionario cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_cargo = $2',
  GET_OFFICIALS_BY_INSTITUTION:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono, c.id_cargo as cargo, cf.bloqueado\
    from usuario usr INNER JOIN cuenta_funcionario cf ON\
    usr.id_usuario=cf.id_usuario INNER JOIN cargo c ON cf.id_cargo = c.id_cargo WHERE c.id_institucion = $1 AND usr.id_usuario != $2 AND usr.id_tipo_usuario!=1',
  GET_ALL_OFFICIALS:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono, cf.id_cargo as cargo, cf.bloqueado\
    from usuario usr INNER JOIN cuenta_funcionario cf ON\
    usr.id_usuario=cf.id_usuario WHERE usr.id_tipo_usuario!=1',
  GET_ALL_INSTITUTION: 'SELECT * FROM institucion',
  GET_ONE_INSTITUTION: 'SELECT * FROM institucion WHERE id_institucion = $1',
  GET_ONE_INSTITUTION_INFO: 'SELECT id_institucion AS id, nombre_completo AS "nombreCompleto", nombre_corto AS "nombreCorto" FROM institucion WHERE id_institucion = $1;',
  UPDATE_OFFICIAL: 'UPDATE usuario SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, telefono =$6, id_tipo_usuario = $8 WHERE id_usuario = $7 RETURNING *',
  DELETE_OFFICIAL: 'DELETE FROM usuario usr USING cuenta_funcionario cf, cargo c WHERE\
    usr.id_usuario = cf.id_usuario AND cf.id_cargo = c.id_cargo AND usr.id_usuario = $1\
    AND c.id_institucion = $2 RETURNING *;',
  DELETE_OFFICIAL_AS_SUPERUSER: 'DELETE FROM usuario WHERE usuario.id_usuario = $1 RETURNING *;',

  //tramite
  PROCEDURE_INIT: 'SELECT * FROM insert_tramite($1, $2, $3);',
  SOCIAL_CASE_INIT: 'SELECT * FROM insert_caso(0, $1, $2);', //datos, id usuario
  CREATE_RECEIPT: 'INSERT INTO factura_tramite (id_factura, id_tramite) VALUES (default, $1) RETURNING *;',
  ADD_ITEM_TO_RECEIPT: 'INSERT INTO detalle_factura (id_detalle, id_factura, nombre, costo) VALUES (default, $1, $2, $3)',
  DELETE_PROCEDURE_TAKINGS: `DELETE FROM tramite_archivo_recaudo WHERE id_tramite = $1`,
  INSERT_TAKINGS_IN_PROCEDURE: 'INSERT INTO tramite_archivo_recaudo VALUES ($1,$2)',
  GET_SECTIONS_BY_PROCEDURE: 'SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  campo_tramite ct RIGHT JOIN seccion sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1 ORDER BY sect.id_seccion',
  GET_PROCEDURE_BY_INSTITUTION: 'SELECT id_tipo_tramite, nombre_tramite, costo_base, sufijo, pago_previo, utiliza_informacion_catastral, costo_petro \
    FROM tipo_tramite tt WHERE id_institucion = $1 ORDER BY id_tipo_tramite',
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND (ct.estado='iniciado' OR ct.estado = 'ingresardatos') \
    ORDER BY ct.orden",
  INSERT_OBSERVATION: 'INSERT INTO tramite_observaciones (id_tramite, observaciones) VALUES ($1, $2);',
  GET_FIELDS_BY_SECTION_FOR_OFFICIALS:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 \
    AND NOT (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_FOR_SOCIAL_CASE: 'SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
  campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 ORDER BY ct.orden',
  GET_TAKINGS_BY_PROCEDURE:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto, rec.obligatorio,\
  ttr.fisico, rec.planilla, rec.extension FROM recaudo rec INNER JOIN tipo_tramite_recaudo ttr ON rec.id_recaudo=ttr.id_recaudo\
  WHERE ttr.id_tipo_tramite=$1 ORDER BY rec.id_recaudo',
  GET_TAKINGS_FOR_VALIDATION:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto, rec.obligatorio,\
ttr.fisico FROM recaudo rec INNER JOIN tipo_tramite_recaudo ttr ON rec.id_recaudo=ttr.id_recaudo \
WHERE ttr.id_tipo_tramite=$1 AND ttr.fisico = false ORDER BY rec.id_recaudo',
  GET_TAKINGS_OF_INSTANCES: 'SELECT * FROM tramite_archivo_recaudo WHERE id_tramite = ANY( $1::int[] );',
  GET_PLANILLA_AND_CERTIFICATE_TYPE_PROCEDURE: 'SELECT planilla, certificado, planilla_rechazo, sufijo FROM tipo_tramite WHERE id_tipo_tramite=$1',
  GET_APPROVED_STATE_FOR_PROCEDURE: 'SELECT aprobado FROM tramite WHERE id_tramite =$1',
  GET_STATE_AND_TYPE_OF_PROCEDURE: 'SELECT state, tipotramite FROM tramites_state_with_resources WHERE id=$1',
  GET_PROCEDURE_DATA: 'SELECT datos, id_usuario as usuario, costo FROM tramite WHERE id_tramite=$1',
  GET_SOCIAL_CASES_STATE: 'SELECT * FROM CASOS_SOCIALES_STATE WHERE tipotramite=$1 ORDER BY fechacreacion DESC LIMIT 500',
  GET_ID_FROM_PROCEDURE_STATE_BY_CODE: 'SELECT id FROM TRAMITES_STATE_WITH_RESOURCES WHERE codigotramite=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION: 'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado \
  FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK:
    'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado as formatoCertificado, ttr.planilla_rechazo as formatoRechazo, ttr.sufijo \
  FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
  GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID: `
  WITH tramite_cte as (
    SELECT * FROM tramite WHERE  fecha_creacion > (NOW() - interval '6 months') AND id_tipo_tramite IN (SELECT id_tipo_tramite FROM tipo_tramite WHERE id_institucion = $1) AND id_tipo_tramite NOT IN (27, 29, 30, 31, 32, 33, 34, 35, 39, 40) ORDER BY fecha_creacion DESC FETCH FIRST 8000 ROWS ONLY
  )
  SELECT ts.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS 
      nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, 
      tipo_tramite.pago_previo AS "pagoPrevio" FROM (SELECT t.id_tramite AS id,
      t.datos,
      t.id_tipo_tramite AS tipotramite,
      t.costo,
      t.fecha_creacion AS fechacreacion,
      t.codigo_tramite AS codigotramite,
      t.id_usuario AS usuario,
      t.url_planilla AS planilla,
      t.url_certificado AS certificado,
      ev.state,
      t.aprobado,
      t.fecha_culminacion AS fechaculminacion
     FROM (SELECT * FROM tramite_cte) t
       JOIN ( SELECT evento_tramite.id_tramite,
              tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
             FROM evento_tramite
             WHERE id_tramite IN (select id_tramite from tramite_cte)
            GROUP BY evento_tramite.id_tramite) ev ON t.id_tramite = ev.id_tramite)
      ts 
      
      INNER JOIN tipo_tramite ON ts.tipotramite = 
      tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = 
      tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND state != 'denegado' ORDER BY ts.fechacreacion DESC;
`,
  GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION: `WITH condq AS (
      SELECT CASE WHEN $1 = 9 THEN '{3,9}'::int[] ELSE ARRAY[$1] END AS cond
    ),
    tramite_cte as (
      SELECT * FROM tramite WHERE  fecha_creacion > (NOW() - interval '7 months') 
      AND id_tipo_tramite IN (SELECT id_tipo_tramite FROM tipo_tramite WHERE id_institucion = ANY (SELECT unnest(cond) from condq) ) 
      ORDER BY fecha_creacion DESC FETCH FIRST 20000 ROWS ONLY
    ) 
    SELECT ts.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS 
        nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, 
        tipo_tramite.pago_previo AS "pagoPrevio" FROM (SELECT t.id_tramite AS id,
        t.datos,
        t.id_tipo_tramite AS tipotramite,
        t.costo,
        t.fecha_creacion AS fechacreacion,
        t.codigo_tramite AS codigotramite,
        t.id_usuario AS usuario,
        t.url_planilla AS planilla,
        t.url_certificado AS certificado,
        ev.state,
        t.aprobado,
        t.fecha_culminacion AS fechaculminacion
       FROM (SELECT * FROM tramite_cte) t
         JOIN ( SELECT evento_tramite.id_tramite,
                tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
               FROM evento_tramite
               WHERE id_tramite IN (select id_tramite from tramite_cte)
              GROUP BY evento_tramite.id_tramite) ev ON t.id_tramite = ev.id_tramite)
        ts 
        
        INNER JOIN tipo_tramite ON ts.tipotramite = 
        tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = 
        tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = ANY (SELECT unnest(cond) from condq) AND tS.state IN ('enproceso', 'enprocesocat', 'inspeccion', 'enrevision', 'pagocajero') ORDER BY ts.fechacreacion DESC FETCH FIRST 20000 ROWS ONLY;`,
  GET_ALL_PROCEDURES_EXCEPT_VALIDATING_ONES:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
  nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, \
  tipo_tramite.pago_previo AS "pagoPrevio"  FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
  tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
  tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND tramites_state.state!=\'validando\' ORDER BY tramites_state.fechacreacion DESC LIMIT 500;',
  GET_RESOURCES_FOR_PROCEDURE:
    'SELECT DISTINCT tt.sufijo, tt.costo_base, usr.nombre_completo as nombrecompleto, \
    usr.nombre_de_usuario as nombreusuario, tr.costo, tt.planilla, tr.id_tipo_tramite AS "tipoTramite", tt.id_ramo FROM tipo_tramite tt INNER JOIN tramite tr ON\
    tt.id_tipo_tramite=tr.id_tipo_tramite INNER JOIN usuario usr ON tr.id_usuario=usr.id_usuario\
    WHERE tr.id_tramite = $1',
  GET_PROCEDURE_STATES: 'SELECT id_tramite AS id, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM evento_tramite \
  GROUP BY id_tramite;',
  GET_PROCEDURE_STATE: 'SELECT id_tramite AS id, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM evento_tramite \
  WHERE id_tramite = $1 \
  GROUP BY id_tramite;', //tramite
  GET_PROCEDURE_STATE_FOR_SOCIAL_CASE: 'SELECT id_caso AS id, caso_social_fsm(event ORDER BY id_evento_caso) AS state  \
  FROM eventos_caso_social \
  WHERE id_caso = $1 \
  GROUP BY id_caso;',
  GET_ONE_PROCEDURE: 'SELECT * FROM tipo_tramite WHERE id_tipo_tramite = $1',
  GET_PROCEDURE_BY_ID: 'SELECT * FROM tramites_state_with_resources WHERE id=$1',
  GET_SOCIAL_CASE_BY_ID: 'SELECT * FROM casos_sociales_state WHERE id=$1',
  GET_CERTIFICATE_BY_PROCEDURE_ID: 'SELECT certificado AS "urlCertificado" FROM tramites_state_with_resources WHERE id = $1',
  GET_PROCEDURE_INSTANCES_FOR_USER: `WITH tram AS (
    SELECT * FROM tramite WHERE id_usuario = $1 ORDER BY fecha_creacion DESC limit 500
  )
  
  SELECT * 
  FROM (
    SELECT t.id_tramite AS id,
      t.datos,
      t.id_tipo_tramite AS tipotramite,
      t.costo,
      t.fecha_creacion AS fechacreacion,
      t.codigo_tramite AS codigotramite,
      t.id_usuario AS usuario,
      t.url_planilla AS planilla,
      t.url_certificado AS certificado,
      i.nombre_completo AS nombrelargo,
      i.nombre_corto AS nombrecorto,
      tt.nombre_tramite AS nombretramitelargo,
      tt.nombre_corto AS nombretramitecorto,
      ev.state,
      t.aprobado,
      tt.pago_previo AS "pagoPrevio",
      t.fecha_culminacion AS fechaculminacion
     FROM tram t
       JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
       JOIN institucion i ON i.id_institucion = tt.id_institucion
       JOIN ( SELECT et.id_tramite,
              tramite_evento_fsm(et.event ORDER BY et.id_evento_tramite) AS state
             FROM evento_tramite et
             INNER JOIN tram t ON t.id_tramite = et.id_tramite
            GROUP BY et.id_tramite) ev ON t.id_tramite = ev.id_tramite
  ) t
  
  
  WHERE usuario = $1
  
  ORDER BY fechacreacion DESC LIMIT 500;`,
  GET_ALL_PROCEDURE_INSTANCES: 'SELECT * FROM tramites_state_with_resources ORDER BY fechacreacion DESC LIMIT 500;',
  GET_ONE_PROCEDURE_INFO: 'SELECT id_tipo_tramite as id, id_institucion AS "idInstitucion", nombre_tramite AS "nombre", costo_base as costo, \
    nombre_corto as "nombreCorto"  FROM tipo_tramite WHERE id_tipo_tramite = $1;',
  VALIDATE_FIELDS_FROM_PROCEDURE: 'SELECT DISTINCT camp.validacion, camp.tipo FROM campo_tramite ct INNER JOIN campo camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=$2',
  UPDATE_PROCEDURE_COST: 'UPDATE tipo_tramite SET costo_petro = $2, costo_base = $3 WHERE id_tipo_tramite = $1 RETURNING *',
  UPDATE_STATE: 'SELECT update_tramite_state($1, $2, $3, $4, $5) as state;', //tramite, evento
  COMPLETE_STATE: 'SELECT complete_tramite_state ($1,$2,$3,$4, $5) as state',
  UPDATE_STATE_SOCIAL_CASE: 'SELECT update_caso_state($1, $2, $3) as state', //idcaso, event, datos
  UPDATE_PROCEDURE_INSTANCE_COST: 'UPDATE tramite SET costo = $1 WHERE id_tramite = $2',
  UPDATE_APPROVED_STATE_FOR_PROCEDURE: "UPDATE TRAMITE SET aprobado=$1, fecha_culminacion = (NOW() - interval '4 hours') WHERE id_tramite=$2",
  UPDATE_UNAPPROVED_STATE_FOR_PROCEDURE: 'UPDATE TRAMITE SET aprobado=$1 WHERE id_tramite=$2',

  //parroquias
  GET_PARISHES: 'SELECT * FROM parroquia;',
  GET_PARISH_BY_DESCRIPTION: 'SELECT id FROM parroquia WHERE nombre = $1',

  //Valores fiscales
  GET_SECTOR_BY_PARISH: 'SELECT id, descripcion FROM VALORES_FISCALES.SECTOR WHERE PARROQUIA_ID = (SELECT ID FROM PARROQUIA WHERE NOMBRE = $1) ORDER BY id',
  GET_YEARS: 'SELECT id, descripcion FROM VALORES_FISCALES.ANO ORDER BY DESCRIPCION DESC LIMIT 5',
  GET_LAST_YEAR: 'SELECT id, descripcion FROM VALORES_FISCALES.ANO ORDER BY DESCRIPCION DESC LIMIT 1',
  GET_CONSTRUCTION_TYPES: 'SELECT id, descripcion FROM VALORES_FISCALES.TIPO_CONSTRUCCION',
  GET_GROUND_BY_ID:
    'SELECT DISTINCT tr.valor_fiscal AS "valorFiscal", tr.id, tr.sector_id AS "idSector", se.descripcion AS \
  sector, pa.id AS "idParroquia", pa.nombre AS parroquia FROM VALORES_FISCALES.TERRENO tr INNER \
  JOIN VALORES_FISCALES.SECTOR se ON tr.sector_id = se.id INNER JOIN PARROQUIA pa ON se.parroquia_id \
  = pa.id WHERE tr.id=$1 ORDER BY tr.sector_id',
  GET_CONSTRUCTION_BY_ID:
    'SELECT DISTINCT cr.valor_fiscal AS "valorFiscal", cr.id, cr.tipo_construccion_id AS \
  "idTipoConstruccion", tc.descripcion AS "tipoConstruccion" FROM valores_fiscales.construccion cr INNER \
  JOIN valores_fiscales.tipo_construccion tc ON tc.id = cr.tipo_construccion_id WHERE cr.id = $1 \
  ORDER BY cr.tipo_construccion_id',
  GET_CONSTRUCTION_BY_YEAR:
    'SELECT DISTINCT cr.valor_fiscal AS "valorFiscal", cr.id, cr.tipo_construccion_id AS \
  "idTipoConstruccion", tc.descripcion AS "tipoConstruccion" FROM valores_fiscales.construccion cr INNER \
  JOIN valores_fiscales.tipo_construccion tc ON tc.id = cr.tipo_construccion_id WHERE ano_id = $1 \
  ORDER BY cr.tipo_construccion_id',
  GET_GROUNDS_BY_YEAR:
    'SELECT DISTINCT tr.valor_fiscal AS "valorFiscal", tr.id, tr.sector_id AS "idSector", se.descripcion AS \
    sector, pa.id AS "idParroquia", pa.nombre AS parroquia FROM VALORES_FISCALES.TERRENO tr INNER \
    JOIN VALORES_FISCALES.SECTOR se ON tr.sector_id = se.id INNER JOIN PARROQUIA pa ON se.parroquia_id \
    = pa.id WHERE tr.ano_id=$1 ORDER BY tr.sector_id',
  GET_GROUNDS_BY_PARISH_AND_SECTOR:
    'SELECT DISTINCT tr.valor_fiscal AS "valorFiscal", tr.id, tr.sector_id AS "idSector", se.descripcion AS \
  sector, pa.id AS "idParroquia", pa.nombre AS parroquia FROM VALORES_FISCALES.TERRENO tr INNER \
  JOIN VALORES_FISCALES.SECTOR se ON tr.sector_id = se.id INNER JOIN PARROQUIA pa ON se.parroquia_id \
  = pa.id WHERE se.descripcion = $1 AND pa.nombre =$2 ORDER BY tr.sector_id',
  GET_CONSTRUCTION_TYPE_BY_MODEL:
    'SELECT DISTINCT cr.valor_fiscal AS "valorFiscal", cr.id, cr.tipo_construccion_id AS \
  "idTipoConstruccion", tc.descripcion AS "tipoConstruccion" FROM valores_fiscales.construccion cr INNER \
  JOIN valores_fiscales.tipo_construccion tc ON tc.id = cr.tipo_construccion_id WHERE tc.descripcion = $1 \
  ORDER BY cr.tipo_construccion_id',
  UPDATE_GROUND_VALUES_BY_SECTOR: 'UPDATE valores_fiscales.terreno tr SET valor_fiscal = $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) AND sector_id = $3 RETURNING *',
  UPDATE_GROUND_VALUES_BY_FACTOR: 'UPDATE valores_fiscales.terreno tr SET valor_fiscal = valor_fiscal * $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) RETURNING *',
  UPDATE_CONSTRUCTION_VALUES_BY_MODEL: 'UPDATE valores_fiscales.construccion tr SET valor_fiscal = $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) AND \
    tipo_construccion_id = $3 RETURNING *',
  UPDATE_CONSTRUCTION_VALUES_BY_FACTOR: 'UPDATE valores_fiscales.construccion tr SET valor_fiscal = valor_fiscal * $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) RETURNING *',

  //Inmuebles
  CREATE_PROPERTY:
    "INSERT INTO inmueble_urbano (cod_catastral, direccion, id_parroquia, \
  metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, tipo_inmueble) \
  VALUES ($1, $2, (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), $4, $5, (NOW() - interval '4 hours'), (NOW() - interval '4 hours'), $6)\
  ON CONFLICT (cod_catastral) DO UPDATE SET metros_construccion = $4, metros_terreno = $5, \
  id_parroquia = (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), fecha_actualizacion = (NOW() - interval '4 hours') \
  RETURNING id_inmueble",
  CREATE_PROPERTY_WITH_SIGNED_OWNER: 'INSERT INTO propietario_inmueble (id_propietario, id_inmueble) VALUES ($1, $2)',
  CREATE_PROPERTY_OWNER: 'INSERT INTO propietario (razon_social, cedula, rif, email) VALUES ($1,$2,$3,$4) ON CONFLICT (cedula, rif) DO UPDATE SET razon_social = EXCLUDED.razon_social RETURNING *',
  GET_ALL_PROPERTIES:
    'SELECT i.id_inmueble AS "idInmueble", i.cod_catastral AS "codCatastral", i.direccion,\
  i.metros_construccion AS "metrosConstruccion", i.metros_terreno AS "metrosTerreno", i.fecha_creacion AS "fechaCreacion", \
  i.fecha_actualizacion AS "fechaActualizacion",  \
  i.fecha_ultimo_avaluo AS "fechaUltimoAvaluo" , p.nombre AS parroquia FROM inmueble_urbano i INNER JOIN parroquia p ON i.id_parroquia = p.id;',
  GET_ONE_PROPERTY_BY_COD:
    'SELECT i.id_inmueble AS "idInmueble", i.cod_catastral AS "codCatastral", i.direccion,\
  i.metros_construccion AS "metrosConstruccion", i.metros_terreno AS "metrosTerreno", i.fecha_creacion AS "fechaCreacion", \
  i.fecha_actualizacion AS "fechaActualizacion",  \
  i.fecha_ultimo_avaluo AS "fechaUltimoAvaluo" , p.nombre AS parroquia, dir_doc, AS "dirDoc", clasificacion FROM inmueble_urbano i \
  INNER JOIN parroquia p ON i.id_parroquia = p.id WHERE i.cod_catastral = $1;',
  GET_PROPERTY_OWNERS: 'SELECT p.id_propietario AS "idpropietario", razon_social AS "razonSocial", cedula, rif, email, pi.id_inmueble \
    FROM propietario p INNER JOIN propietario_inmueble pi ON p.id_propietario = pi.id_propietario;',
  GET_PROPERTY_BY_ID: 'SELECT * FROM inmueble_urbano_view WHERE id=$1',
  GET_RRI_CERTIFICATES_BY_IDS: `SELECT id_tramite AS "idTramite", url_certificado AS "urlCertificado" FROM inmueble_rri WHERE id_tramite = ANY ($1::int[])`,
  GET_RRI_BY_ID_TRAMITE: 'SELECT codigo_rri FROM inmueble_rri WHERE id_tramite = $1 ORDER BY fecha_creacion DESC LIMIT 1',
  INSERT_RRI: `INSERT INTO inmueble_rri (codigo_rri, id_tramite, url_certificado, fecha_creacion) VALUES ($1, $2, $3,(NOW() - interval '4 hours'))`,
  //ordenanza
  CREATE_ORDINANCE:
    'WITH ordenanzaTmp AS (INSERT INTO ordenanza (descripcion, tarifa, id_valor) \
    VALUES ($1, $2, (SELECT id_valor FROM valor WHERE descripcion = \'PETRO\')) RETURNING *) \
    , tarifaTmp AS (INSERT INTO tarifa_inspeccion (id_ordenanza, id_tipo_tramite, utiliza_codcat, id_variable) VALUES ((SELECT id_ordenanza FROM ordenanzaTmp), \
    $3, $4, $5) RETURNING *) \
    SELECT o.id_ordenanza AS "id", o.descripcion AS "nombreOrdenanza", o.tarifa AS "precioPetro", t.id_tipo_tramite AS "idTipoTramite", \
    t.utiliza_codcat AS "utilizaCodcat", t.id_variable IS NOT NULL AS "utilizaVariable", t.id_variable AS "idVariable", v.nombre AS "nombreVariable" \
    FROM ordenanzaTmp o INNER JOIN tarifaTmp t ON o.id_ordenanza = t.id_ordenanza \
    LEFT JOIN variable_ordenanza v ON t.id_variable = v.id_variable',
  CREATE_ORDINANCE_FOR_PROCEDURE:
    'INSERT INTO ordenanza_tramite (id_tramite, id_tarifa, petro, valor_calc, factor, factor_value, costo_ordenanza) \
    VALUES ($1, (SELECT id_tarifa FROM tarifa_inspeccion trf INNER JOIN ordenanza ord ON \
      trf.id_ordenanza=ord.id_ordenanza WHERE trf.id_tipo_tramite=$2 AND ord.descripcion = $3 LIMIT 1), \
      $4,$5,$6,$7, $8) RETURNING *;',
  ORDINANCES_BY_INSTITUTION:
    'SELECT o.id_ordenanza AS id, o.descripcion AS "nombreOrdenanza", o.tarifa AS "precioPetro", ti.id_tipo_tramite AS "idTipoTramite", \
    ti.utiliza_codcat AS "utilizaCodcat", (ti.id_variable IS NOT NULL) AS "utilizaVariable", ti.id_variable AS "idVariable", vo.nombre AS "nombreVariable" \
    FROM ordenanza o \
    INNER JOIN tarifa_inspeccion ti ON o.id_ordenanza = ti.id_ordenanza \
    LEFT JOIN variable_ordenanza vo ON ti.id_variable = vo.id_variable \
    INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = ti.id_tipo_tramite \
    INNER JOIN institucion i ON i.id_institucion = tt.id_institucion \
    WHERE i.id_institucion = $1 AND o.habilitado = true',
  ORDINANCES_WITHOUT_CODCAT_PROCEDURE:
    'SELECT v.descripcion AS "valorDescripcion", v.valor_en_bs AS "valorEnBs", \
  o.id_ordenanza as id ,o.descripcion AS "descripcionOrdenanza", o.tarifa AS "tarifaOrdenanza", \
  t.id_tarifa AS "idTarifa", t.id_tipo_tramite AS "tipoTramite", t.formula, \
  tt.costo_base AS "costoBase", t.utiliza_codcat AS "utilizaCodcat", vo.id_variable AS "idVariable", vo.nombre as "nombreVariable", \
  vo.nombre_plural AS "nombreVariablePlural" \
  FROM valor v INNER JOIN ordenanza o ON v.id_valor = o.id_valor \
  INNER JOIN tarifa_inspeccion t ON t.id_ordenanza = o.id_ordenanza \
  INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
  LEFT JOIN variable_ordenanza vo ON vo.id_variable = t.id_variable \
  WHERE t.id_tipo_tramite = $1 AND t.utiliza_codcat = false AND o.habilitado = true;',
  ORDINANCES_WITH_CODCAT_PROCEDURE:
    'SELECT v.descripcion AS "valorDescripcion", v.valor_en_bs AS "valorEnBs", \
  o.id_ordenanza as id, o.descripcion AS "descripcionOrdenanza", o.tarifa AS "tarifaOrdenanza",t.id_tarifa AS "idTarifa" , \
  t.id_tipo_tramite AS "tipoTramite",t.formula, \
  tt.costo_base AS "costoBase", t.utiliza_codcat AS "utilizaCodcat", vo.id_variable AS "idVariable", \
  vo.nombre as "nombreVariable", vo.nombre_plural AS "nombreVariablePlural" \
  FROM valor v INNER JOIN ordenanza o ON v.id_valor = o.id_valor \
  INNER JOIN tarifa_inspeccion t ON t.id_ordenanza = o.id_ordenanza \
  INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
  LEFT JOIN variable_ordenanza vo ON vo.id_variable = t.id_variable \
  WHERE t.id_tipo_tramite = $1 AND t.utiliza_codcat = true AND o.habilitado = true;',
  ORDINANCES_PROCEDURE_INSTANCES: 'SELECT * FROM ordenanzas_instancias_tramites WHERE "idTramite" = $1;',
  ORDINANCES_PROCEDURE_INSTANCES_BY_IDS: `SELECT * FROM ordenanzas_instancias_tramites WHERE "idTramite" = ANY ($1::int[])`,
  GET_ORDINANCE_VARIABLES: 'SELECT id_variable as id, nombre, nombre_plural as "nombrePlural" FROM variable_ordenanza;',
  UPDATE_ORDINANCE:
    'WITH updateTmp AS (UPDATE ordenanza SET tarifa = $2 WHERE id_ordenanza = $1 RETURNING id_ordenanza as id, descripcion AS "nombreOrdenanza", \
    tarifa AS "precioPetro") \
      SELECT o.id, "nombreOrdenanza", "precioPetro", t.id_tipo_tramite AS "idTipoTramite", \
      t.utiliza_codcat AS "utilizaCodcat", t.id_variable IS NOT NULL AS "utilizaVariable", t.id_variable AS "idVariable", v.nombre AS "nombreVariable" \
      FROM updateTmp o INNER JOIN tarifa_inspeccion t ON o.id = t.id_ordenanza \
      LEFT JOIN variable_ordenanza v ON t.id_variable = v.id_variable',
  DISABLE_ORDINANCE: 'UPDATE ordenanza SET habilitado = false WHERE id_ordenanza = $1 RETURNING *;',

  //valor
  GET_PETRO_VALUE: "SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'",
  GET_PESO_VALUE: `SELECT valor_en_bs FROM valor WHERE descripcion = 'PESO'`,
  GET_USD_VALUE: "SELECT valor_en_bs FROM valor WHERE descripcion = 'Dolar'",
  GET_PETRO_VALUE_FORMAT: "SELECT valor_en_bs AS valor FROM valor WHERE descripcion = 'PETRO'",
  GET_EURO_VALUE: `SELECT valor_en_bs FROM valor WHERE descripcion = 'EURO'`,
  UPDATE_PETRO_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'PETRO' RETURNING valor_en_bs;",
  UPDATE_PESO_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'PESO' RETURNING valor_en_bs;",
  UPDATE_USD_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'Dolar' RETURNING valor_en_bs;",
  UPDATE_EURO_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'EURO' RETURNING valor_en_bs;",

  //Estadisticas
  // OFFICIAL STATS
  GET_PROC_TOTAL_COUNT: 'SELECT COUNT (*) FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1;',
  GET_PROC_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND EXTRACT(MONTH FROM t.fecha_creacion) = $2;',
  GET_PROC_TOTAL_BY_STATUS: 'SELECT COUNT (*) FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND t.state = $2',
  GET_PROC_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_PROC_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND EXTRACT(MONTH FROM t.fechacreacion) = $2 AND t.state = $3;',
  GET_PROC_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 GROUP BY state;',
  GET_PROC_COUNT_LAST_20_DAYS:
    "SELECT COUNT (*), fechacreacion::date FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_PROC_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_PROC_COUNT_LAST_5_YEARS:
    "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM tramites_state_with_resources t \
    INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  // OFFICIAL FINING STATS
  GET_FINE_TOTAL_COUNT: 'SELECT COUNT (*) FROM multa t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1;',
  GET_FINE_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM multa t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND EXTRACT(MONTH FROM t.fecha_creacion) = $2;',
  GET_FINE_TOTAL_BY_STATUS: 'SELECT COUNT (*) FROM multa_state t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND t.state = $2',
  GET_FINE_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM multa t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_FINE_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM multa_state t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND EXTRACT(MONTH FROM t.fechacreacion) = $2 AND t.state = $3;',
  GET_FINE_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM multa_state t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 GROUP BY state;',
  GET_FINE_COUNT_LAST_20_DAYS:
    "SELECT COUNT (*), fechacreacion::date FROM multa_state t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_FINE_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM multa_state t INNER JOIN tipo_tramite tt \
    ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_FINE_COUNT_LAST_5_YEARS:
    "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM multa_state t \
    INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = t.tipotramite WHERE tt.id_institucion = $1 \
    AND fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  // SUPER USER STATS
  GET_SUPER_PROC_TOTAL_COUNT: 'SELECT COUNT (*) FROM tramite;',
  GET_SUPER_PROC_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM tramite WHERE EXTRACT(MONTH FROM fecha_creacion) = $1;',
  GET_SUPER_PROC_TOTAL_BY_STATUS: 'SELECT COUNT (*) FROM tramites_state_with_resources WHERE state = $1',
  GET_SUPER_PROC_BY_DATE: "SELECT COUNT (*), fecha_creacion::date FROM tramite WHERE fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_SUPER_PROC_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM tramites_state_with_resources WHERE EXTRACT(MONTH FROM fechacreacion) = $1 AND state = $2;',
  GET_SUPER_PROC_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM tramites_state_with_resources GROUP BY state;',
  GET_SUPER_PROC_COUNT_LAST_20_DAYS: "SELECT COUNT (*), fechacreacion::date FROM tramites_state_with_resources WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_SUPER_PROC_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM tramites_state_with_resources WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_SUPER_PROC_COUNT_LAST_5_YEARS: "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM tramites_state_with_resources \
    WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  // SOCIAL AFFAIRS STATS
  GET_AFFAIR_TOTAL_COUNT: 'SELECT COUNT (*) FROM caso_social;',
  GET_AFFAIR_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM caso_social WHERE EXTRACT(MONTH FROM fecha_creacion) = $1;',
  GET_AFFAIR_TOTAL_BY_STATUS: 'SELECT COUNT (*) FROM casos_sociales_state WHERE state = $1',
  GET_AFFAIR_BY_DATE: "SELECT COUNT (*), fecha_creacion::date FROM caso_social WHERE fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_AFFAIR_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM casos_sociales_state WHERE EXTRACT(MONTH FROM fechacreacion) = $1 AND state = $2;',
  GET_AFFAIR_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM casos_sociales_state GROUP BY state;',
  GET_AFFAIR_COUNT_LAST_20_DAYS: "SELECT COUNT (*), fechacreacion::date FROM casos_sociales_state WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_AFFAIR_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM casos_sociales_state WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_AFFAIR_COUNT_LAST_5_YEARS: "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM casos_sociales_state \
    WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  GET_APPLICATION_TOTAL_COUNT: 'SELECT COUNT (*) FROM impuesto.solicitud;',
  GET_APPLICATION_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM impuesto.solicitud WHERE EXTRACT(MONTH FROM fecha) = $1',
  GET_PENDING_SETTLEMENT_TOTAL: 'SELECT COUNT (*) FROM impuesto.solicitud sl INNER JOIN impuesto.liquidacion li ON sl.id_solicitud = li.id_solicitud WHERE sl.aprobado = false',
  GET_COMPLETED_APPLICATION_TOTAL: 'SELECT COUNT (*) FROM impuesto.solicitud WHERE aprobado = true',
  GET_MONTHLY_COMPLETED_APPLICATION_TOTAL: 'SELECT COUNT (*) FROM impuesto.solicitud WHERE EXTRACT(MONTH FROM fecha) = $1 AND aprobado = true',
  GET_RAISED_MONEY_BY_BRANCH: 'SELECT SUM("montoLiquidacion"), "descripcionRamo" FROM impuesto.solicitud_view WHERE "fechaCreacion"::date = CURRENT_DATE::date GROUP BY "descripcionRamo" ORDER BY sum DESC',
  GET_SETTLEMENTS_BY_DAY:
    "SELECT COUNT (*), sl.fecha::date AS fecha_creacion FROM impuesto.solicitud sl INNER JOIN impuesto.liquidacion li ON sl.id_solicitud = li.id_solicitud AND sl.fecha::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY sl.fecha::date;",
  GET_APPLICATION_COUNT_LAST_20_DAYS:
    "SELECT COUNT (*), sl.fecha::date AS fechacreacion FROM impuesto.solicitud sl INNER JOIN impuesto.liquidacion li ON sl.id_solicitud = li.id_solicitud \
  WHERE sl.fecha::date > CURRENT_DATE - INTERVAL '20 days' \
  GROUP BY sl.fecha::date ORDER BY fecha DESC;",
  GET_APPLICATION_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM sl.fecha::date) AS month, EXTRACT(YEAR FROM sl.fecha::date) \
  AS year FROM impuesto.solicitud sl INNER JOIN impuesto.liquidacion li ON sl.id_solicitud = li.id_solicitud WHERE fecha::date > CURRENT_DATE - INTERVAL '12 months' \
  GROUP BY month, year;",
  GET_APPLICATION_COUNT_LAST_5_YEARS:
    "SELECT COUNT (*), EXTRACT(YEAR FROM sl.fecha::date) AS year FROM impuesto.solicitud sl INNER JOIN impuesto.liquidacion li ON sl.id_solicitud = li.id_solicitud \
  WHERE sl.fecha::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",

  // EXTERNAL USER STATS
  GET_EXTERNAL_TOTAL_COUNT: 'SELECT COUNT(*) FROM tramite WHERE id_usuario = $1;',
  //GET_EXTERNAL_APPROVED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = TRUE;",
  GET_EXTERNAL_APPROVED_COUNT: `SELECT COUNT(*)
    FROM (
        SELECT t.id_tramite AS id,
        t.datos,
        t.id_tipo_tramite AS tipotramite,
        t.costo,
        t.fecha_creacion AS fechacreacion,
        t.codigo_tramite AS codigotramite,
        t.id_usuario AS usuario,
        t.url_planilla AS planilla,
        t.url_certificado AS certificado,
        i.nombre_completo AS nombrelargo,
        i.nombre_corto AS nombrecorto,
        tt.nombre_tramite AS nombretramitelargo,
        tt.nombre_corto AS nombretramitecorto,
        ev.state,
        t.aprobado,
        tt.pago_previo AS "pagoPrevio",
        t.fecha_culminacion AS fechaculminacion
      FROM tramite t
        JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
        JOIN institucion i ON i.id_institucion = tt.id_institucion
        JOIN ( SELECT evento_tramite.id_tramite,
                tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
              FROM evento_tramite
              WHERE id_tramite IN (SELECT Id_tramite FROM tramite WHERE id_usuario = $1)
              GROUP BY evento_tramite.id_tramite) ev ON t.id_tramite = ev.id_tramite

    ) t
    WHERE t.usuario = $1
            AND t.state = 'finalizado'
            AND t.aprobado = true;

  `,
  //GET_EXTERNAL_REJECTED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = FALSE;",
  GET_EXTERNAL_REJECTED_COUNT: `SELECT COUNT(*)
    FROM (
        SELECT t.id_tramite AS id,
        t.datos,
        t.id_tipo_tramite AS tipotramite,
        t.costo,
        t.fecha_creacion AS fechacreacion,
        t.codigo_tramite AS codigotramite,
        t.id_usuario AS usuario,
        t.url_planilla AS planilla,
        t.url_certificado AS certificado,
        i.nombre_completo AS nombrelargo,
        i.nombre_corto AS nombrecorto,
        tt.nombre_tramite AS nombretramitelargo,
        tt.nombre_corto AS nombretramitecorto,
        ev.state,
        t.aprobado,
        tt.pago_previo AS "pagoPrevio",
        t.fecha_culminacion AS fechaculminacion
      FROM tramite t
        JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
        JOIN institucion i ON i.id_institucion = tt.id_institucion
        JOIN ( SELECT evento_tramite.id_tramite,
                tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
              FROM evento_tramite
              WHERE id_tramite IN (SELECT Id_tramite FROM tramite WHERE id_usuario = $1)
              GROUP BY evento_tramite.id_tramite) ev ON t.id_tramite = ev.id_tramite

    ) t
    WHERE t.usuario = $1
            AND t.state = 'finalizado'
            AND t.aprobado = false;

  `,
  //Notificaciones

  GET_NON_NORMAL_OFFICIALS:
    'SELECT * FROM USUARIO  usr INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario \
    INNER JOIN cargo c ON cf.id_cargo = c.id_cargo INNER JOIN institucion ins ON c.id_institucion = ins.id_institucion WHERE \
    ins.nombre_corto = $1 AND usr.id_tipo_usuario != 3',
  GET_OFFICIALS_FOR_PROCEDURE:
    'SELECT * FROM permiso_de_acceso pda INNER JOIN usuario usr ON pda.id_usuario=usr.id_usuario \
    INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario INNER JOIN cargo c ON cf.id_cargo = c.id_cargo INNER JOIN institucion ins \
    ON c.id_institucion = ins.id_institucion WHERE ins.nombre_corto =$1 AND id_tipo_tramite = $2',
  GET_SUPER_USER: 'SELECT * FROM USUARIO WHERE id_tipo_usuario = 1',
  GET_PROCEDURE_CREATOR: 'SELECT * FROM USUARIO WHERE id_usuario = $1',
  GET_FINING_TARGET: 'SELECT cedula, nacionalidad FROM multa_state WHERE id=$1',
  GET_APPLICATION_CREATOR: 'SELECT usr.cedula, usr.nacionalidad FROM USUARIO usr INNER JOIN impuesto.solicitud_view sv ON usr.id_usuario = sv.usuario WHERE usr.id_usuario = $1',
  GET_APPLICATION_CREATOR_BY_MOVEMENT: `SELECT nombre_completo FROM usuario WHERE id_usuario = (SELECT id_usuario FROM movimientos WHERE id_procedimiento = $1 AND concepto = 'IMPUESTO' AND tipo_movimiento LIKE 'creando%')`,
  CREATE_NOTIFICATION: "INSERT INTO notificacion (id_procedimiento, emisor, receptor, descripcion, status, \
    fecha, estado, concepto) VALUES ($1, $2, $3, $4, false, (NOW() - interval '4 hours'), $5, $6) RETURNING id_notificacion",
  GET_PROCEDURE_NOTIFICATION_BY_ID: `SELECT * FROM (SELECT n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    t.id AS "idTramite",
    t.datos,
    t.tipotramite AS "tipoTramite",
    t.costo,
    t.fechacreacion AS "fechaCreacionTramite",
    t.codigotramite AS "codigoTramite",
    t.usuario,
    t.planilla,
    t.certificado,
    t.nombrecorto AS "nombreCorto",
    t.nombrelargo AS "nombreLargo",
    t.nombretramitecorto AS "nombreTramiteCorto",
    t.nombretramitelargo AS "nombreTramiteLargo",
    t.state AS estado,
    t.aprobado,
    t."pagoPrevio"
   FROM notificacion n
     JOIN (SELECT t.id_tramite AS id,
    t.datos,
    t.id_tipo_tramite AS tipotramite,
    t.costo,
    t.fecha_creacion AS fechacreacion,
    t.codigo_tramite AS codigotramite,
    t.id_usuario AS usuario,
    t.url_planilla AS planilla,
    t.url_certificado AS certificado,
    i.nombre_completo AS nombrelargo,
    i.nombre_corto AS nombrecorto,
    tt.nombre_tramite AS nombretramitelargo,
    tt.nombre_corto AS nombretramitecorto,
    ev.state,
    t.aprobado,
    tt.pago_previo AS "pagoPrevio",
    t.fecha_culminacion AS fechaculminacion
   FROM (SELECT * FROM tramite t WHERE t.id_tramite = (SELECT id_tramite FROM tramite t INNER JOIN notificacion n ON n.id_procedimiento = t.id_tramite WHERE n.concepto = 'TRAMITE' AND  n.id_notificacion = $1  ) ) t
     JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
     JOIN institucion i ON i.id_institucion = tt.id_institucion
     JOIN ( SELECT evento_tramite.id_tramite,
            tramite_evento_fsm(evento_tramite.event ORDER BY evento_tramite.id_evento_tramite) AS state
           FROM evento_tramite
          GROUP BY evento_tramite.id_tramite) ev ON t.id_tramite = ev.id_tramite
) t ON n.id_procedimiento = t.id
) nn WHERE id = $1;`,
  GET_FINING_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_multa_view WHERE id = $1',
  GET_SETTLEMENT_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_impuesto_view WHERE id = $1',
  GET_PROCEDURE_NOTIFICATIONS_FOR_USER: `
  WITH notificacion_cte AS (
    SELECT * FROM notificacion WHERE receptor = $1 AND fecha > (NOW() - interval '1 month') AND concepto = 'TRAMITE' ORDER BY fecha DESC LIMIT 50
  ), tramite_cte AS (
    SELECT * FROM tramite WHERE id_tramite IN (select id_procedimiento FROM notificacion_cte)
  )
  
  SELECT 
    n.id_notificacion AS id,
    n.descripcion,
    n.status,
    n.fecha AS "fechaCreacion",
    n.emisor,
    n.receptor,
    n.estado AS "estadoNotificacion",
    n.concepto,
    t.id_tramite AS id,
    t.datos,
    t.id_tipo_tramite AS tipotramite,
    t.costo,
    t.fecha_creacion AS fechacreacion,
    t.codigo_tramite AS codigotramite,
    t.id_usuario AS usuario,
    t.url_planilla AS planilla,
    t.url_certificado AS certificado,
    i.nombre_completo AS nombrelargo,
    i.nombre_corto AS nombrecorto,
    tt.nombre_tramite AS nombretramitelargo,
    tt.nombre_corto AS nombretramitecorto,
    ev.state,
    t.aprobado,
    tt.pago_previo AS "pagoPrevio",
    t.fecha_culminacion AS fechaculminacion
    FROM (select * from notificacion_cte) n
  
    JOIN (SELECT * FROM tramite_cte) t ON n.id_procedimiento = t.id_tramite
      JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
      JOIN institucion i ON i.id_institucion = tt.id_institucion
      JOIN ( SELECT e.id_tramite,
            tramite_evento_fsm(e.event ORDER BY e.id_evento_tramite) AS state
            FROM evento_tramite e
            WHERE id_tramite IN (select id_tramite from tramite_cte)
          GROUP BY e.id_tramite) ev ON t.id_tramite = ev.id_tramite
    WHERE receptor = $1 ORDER BY "fechaCreacion" LIMIT 40
  
  `,
  GET_FINING_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_multa_view WHERE receptor = $1 ORDER BY "fechaCreacion" LIMIT 10',
  GET_SETTLEMENT_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_impuesto_view WHERE receptor = $1 ORDER BY "fechaCreacion" LIMIT 50',
  GET_USER_HAS_NOTIFICATIONS: 'SELECT (COUNT(*) > 0) as "hasNotifications" FROM notificacion WHERE receptor = $1 ::varchar AND status = false',
  CHECK_IF_USER_EXISTS: 'SELECT * FROM usuario WHERE cedula = $1 AND nacionalidad = $2',
  MARK_ALL_AS_READ: 'UPDATE notificacion SET status = true WHERE receptor = $1',

  //Terminal
  CREATE_TERMINAL_DESTINATION: 'INSERT INTO operatividad_terminal (destino, tipo, monto, tasa) VALUES ($1, $2, $3, $4) \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, monto_calculado AS "montoCalculado"',
  TERMINAL_DESTINATIONS: 'SELECT id_operatividad_terminal AS id, destino, tipo, monto, tasa, monto_calculado AS "montoCalculado", habilitado FROM operatividad_terminal;',
  UPDATE_TERMINAL_DESTINATION:
    'UPDATE operatividad_terminal SET destino = $1, tipo = $2, monto = $3, tasa = $4, habilitado = $5 WHERE id_operatividad_terminal = $6 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado";',
  INCREASE_TERMINAL_DESTINATION_COSTS: 'UPDATE operatividad_terminal SET monto = monto * $1 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado"',
  DISABLE_TERMINAL_DESTINATION: 'UPDATE operatividad_terminal SET habilitado = false WHERE id_operatividad_terminal = $1 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado"',

  //Multa
  FINING_INIT: 'SELECT * FROM insert_multa($1, $2, $3, $4, $5);',
  GET_ALL_FINES: 'SELECT * FROM multa_state ORDER BY fechacreacion DESC;',
  GET_FINES_DIRECTOR_OR_ADMIN: 'SELECT * FROM multa_state WHERE nombrelargo = $1 ORDER BY fechacreacion DESC;',
  GET_FINES_OFFICIAL: "SELECT * FROM multa_state WHERE nombrelargo = $1 AND state != 'validando' ORDER BY fechacreacion DESC;",
  GET_FINES_EXTERNAL_USER: 'SELECT * FROM multa_state WHERE cedula = $1 AND nacionalidad = $2 ORDER BY fechacreacion DESC;',
  GET_RESOURCES_FOR_FINING: 'SELECT DISTINCT tt.sufijo, tt.costo_base,\
  ml.costo FROM tipo_tramite tt INNER JOIN multa ml ON\
  tt.id_tipo_tramite=ml.id_tipo_tramite WHERE ml.id_multa = $1',
  GET_FINING_BY_ID: 'SELECT * FROM multa_state WHERE id=$1',
  GET_FINING_ID_FROM_FINING_STATE_BY_CODE: 'SELECT id FROM multa_state WHERE codigomulta=$1',
  GET_FINING_STATE: 'SELECT id_multa AS id, multa_fsm(event ORDER BY id_evento_multa) AS state \
  FROM evento_multa \
  WHERE id_multa = $1 \
  GROUP BY id_multa;',
  GET_FINING_STATE_AND_TYPE_INFORMATION: 'SELECT mls.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado \
  FROM multa_state mls INNER JOIN tipo_tramite ttr ON mls.tipotramite=ttr.id_tipo_tramite WHERE mls.id=$1',
  UPDATE_FINING: 'SELECT update_multa_state($1, $2, $3, $4, $5) as state;',
  UPDATE_FINING_BALLOT: 'UPDATE multa SET url_boleta =$1 WHERE id_multa = $2',
  COMPLETE_FINING: 'SELECT complete_multa_state ($1,$2,$3,$4, $5) as state',

  //IMPUESTOS SEDEMAT
  TAX_PAYER_EXISTS: 'SELECT * FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2',
  TAX_PAYER_EXISTS_AMBIGUOUS: `SELECT * FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento LIKE $2`,
  UPDATE_TAXPAYER: `UPDATE impuesto.contribuyente SET tipo_documento = $2, documento = $3, razon_social = $4, 
      denominacion_comercial = $5, siglas = $6, id_parroquia = $7, sector = $8, direccion = $9, punto_referencia = $10, tipo_contribuyente = $11 WHERE id_contribuyente = $1;`,
  UPDATE_RIM:
    'UPDATE impuesto.registro_municipal SET telefono_celular = $2, email = $3, denominacion_comercial = $4, nombre_representante = $5, capital_suscrito = $6, tipo_sociedad = $7, telefono_habitacion = $8, id_parroquia = $9, direccion = $10, es_monotributo = $11 WHERE id_registro_municipal = $1',
  GET_APPLICATION_BY_ID: 'SELECT * FROM impuesto.solicitud WHERE id_solicitud = $1',
  // GET_APPLICATION_BY_SETTLEMENT_ID: 'SELECT impuesto.solicitud.* FROM impuesto.solicitud JOIN impuesto.liquidacion USING(id_solicitud) WHERE id_liquidacion = $1 LIMIT 1;',
  GET_APPLICATION_BY_SETTLEMENT_ID: 'SELECT * FROM impuesto.solicitud WHERE id_solicitud = (SELECT id_solicitud FROM impuesto.liquidacion WHERE id_liquidacion = $1)',
  GET_APPLICATION_INSTANCES_BY_USER: 'SELECT * FROM impuesto.solicitud WHERE id_usuario = $1 ORDER BY fecha DESC',
  GET_APPLICATION_DEBTS_BY_MUNICIPAL_REGISTRY: `SELECT rm.id_ramo, rm.descripcion, ROUND(SUM(l.monto_petro),8) AS monto 
    FROM impuesto.ramo rm 
    INNER JOIN impuesto.subramo sr ON rm.id_ramo = sr.id_ramo
    INNER JOIN impuesto.liquidacion l ON sr.id_subramo = l.id_subramo 
    INNER JOIN impuesto.registro_municipal r ON l.id_registro_municipal = r.id_registro_municipal
    INNER JOIN impuesto.contribuyente c ON r.id_contribuyente = c.id_contribuyente 
    INNER JOIN impuesto.solicitud s ON c.id_contribuyente = s.id_contribuyente
    INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state 
                FROM impuesto.evento_solicitud es 
                INNER JOIN impuesto.solicitud USING (id_solicitud) WHERE id_contribuyente = $2 GROUP BY es.id_solicitud
                ) ev ON s.id_solicitud = ev.id_solicitud AND ev.id_solicitud = l.id_solicitud
    WHERE ev.state = 'ingresardatos' 
    AND sr.descripcion != 'Convenio de Pago' 
    AND R.referencia_municipal= $1 
    AND r.id_contribuyente = $2 
    GROUP BY rm.id_ramo, rm.descripcion HAVING SUM (l.monto_petro) > 0`, //A??O DE LA LIQUIDACI??N MODIFICADO PARA QUE NO SE TRAIGA LAS DE 2022, CAMBIO HECHO EL 09/03/2022
  GET_APPLICATION_DEBTS_FOR_NATURAL_CONTRIBUTOR:
    "SELECT DISTINCT m.id_ramo, rm.descripcion, ROUND(SUM(l.monto_petro),8) as monto FROM impuesto.ramo rm INNER JOIN impuesto.subramo sr ON rm.id_ramo = sr.id_ramo INNER JOIN\
    impuesto.liquidacion l ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.solicitud s ON l.id_solicitud = s.id_solicitud INNER JOIN\
     (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state FROM impuesto.evento_solicitud es GROUP\
      BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE\
       ev.state = 'ingresardatos' AND c.id_contribuyente = $1 AND fecha_liquidacion <> '2022' GROUP BY rm.descripcion, rm.id_ramo HAVING SUM(l.monto_petro) > 0", //A??O DE LA LIQUIDACI??N MODIFICADO PARA QUE NO SE TRAIGA LAS DE 2022, CAMBIO HECHO EL 09/03/2022
  GET_APPLICATION_INSTANCES_BY_CONTRIBUTOR:
    'SELECT DISTINCT ON (s.id_solicitud, s.fecha) * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud WHERE s.id_contribuyente = $1\
     AND l.id_registro_municipal = (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 AND id_contribuyente = $1 LIMIT 1) ORDER BY s.fecha DESC',
  GET_APPLICATION_INSTANCES_FOR_NATURAL_CONTRIBUTOR:
    'SELECT DISTINCT ON (s.id_solicitud, s.fecha) * FROM impuesto.solicitud s INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE c.id_contribuyente = $1 ORDER BY s.fecha DESC',
  GET_SETTLEMENTS_BY_APPLICATION_INSTANCE:
    'SELECT l.*, r.descripcion AS "tipoProcedimiento", r.descripcion_corta AS ramo FROM impuesto.liquidacion l LEFT JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo LEFT JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE id_solicitud = $1 ORDER BY r.descripcion, l.fecha_vencimiento DESC',
  GET_SETTLEMENT_INSTANCES:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sr.id_ramo INNER JOIN impuesto.solicitud_state sst ON sst.id = s.id_solicitud',
  GET_SETTLEMENT_INSTANCES_BY_ID: `
    SELECT l.monto AS "montoLiquidacion", * FROM impuesto.solicitud s 
    INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud 
    INNER JOIN impuesto.subramo sr ON sr.id_subramo = l.id_subramo 
    INNER JOIN impuesto.ramo r ON r.id_ramo = sr.id_ramo 
    INNER JOIN (
        SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
       FROM impuesto.solicitud s
         JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
               FROM impuesto.evento_solicitud es
               WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_usuario = $1)
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    )sst ON sst.id = s.id_solicitud 
    WHERE s.id_usuario = $1 ORDER BY s.fecha DESC;
    `,
  GET_SETTLEMENT_INSTANCES_BY_APPLICATION_ID: `SELECT r.descripcion AS "descripcionRamo", sr.descripcion AS "descripcionSubramo", l.monto, l.datos,l.fecha_liquidacion AS "fechaLiquidacion" FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sr.id_ramo INNER JOIN impuesto.solicitud_state sst ON sst.id = s.id_solicitud WHERE s.id_solicitud = $1;`,
  GET_SOLVENCY_B_RIM_CANDIDATES_BY_RIF: `SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2) AND id_registro_municipal NOT IN (SELECT id_registro_municipal FROM impuesto.liquidacion WHERE monto IS NULL AND id_solicitud IS NOT NULL AND id_registro_municipal IS NOT NULL)`,
  GET_SOLVENCY_A_RIM_CANDIDATES_BY_RIF: `SELECT EXISTS(SELECT * FROM impuesto.liquidacion JOIN impuesto.solicitud USING(id_solicitud) WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.contribuyente WHERE documento = $1 AND tipo_documento = $2) AND id_subramo = 824 AND aprobado = true AND id_registro_municipal IS NULL AND fecha_vencimiento > $3)`,
  GET_SOLVENCY_B_RIF_CANDIDATES_BY_RIF: `WITH b AS (
    SELECT DISTINCT(impuesto.contribuyente.*) 
    FROM usuario 
    LEFT JOIN impuesto.solicitud USING(id_contribuyente) 
    JOIN impuesto.contribuyente ON usuario.id_contribuyente = impuesto.contribuyente.id_contribuyente 
    WHERE impuesto.solicitud.id_contribuyente NOT IN (SELECT id_contribuyente FROM (SELECT DISTINCT(impuesto.solicitud.*) FROM impuesto.solicitud JOIN impuesto.liquidacion USING (id_solicitud) WHERE id_registro_municipal IS NULL) s WHERE aprobado <> true AND id_contribuyente IS NOT NULL) OR id_solicitud IS NULL)
  SELECT * FROM b WHERE tipo_documento = $1 AND documento = $2`,
  GET_APPLICATION_VIEW_BY_SETTLEMENT: `
  SELECT s.id_solicitud AS "id", s.id_usuario AS "usuario", s.aprobado, s.fecha AS "fechaCreacion", l.id_liquidacion AS "idLiquidacion",
  l.monto AS "montoLiquidacion", l.recibo, l.certificado, l.certificado AS "solvencia", sr.id_subramo AS "idSubramo", l.datos, sr.subindice, sr.descripcion AS "descripcionSubramo",
  r.codigo AS "codigoRamo", r.descripcion AS "descripcionRamo", r.descripcion_corta AS "descripcionCortaRamo", c.id_contribuyente AS "contribuyente", c.tipo_documento AS "tipoDocumento",
  c.documento, c.razon_social AS "razonSocial", c.denominacion_comercial AS "denominacionComercial", c.siglas, c.sector, c.direccion, 
  c.punto_referencia AS "puntoReferencia", c.verificado, c.tipo_contribuyente AS "tipoContribyente" 
  FROM impuesto.solicitud s 
  INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud
  INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo
  INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo
  INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente
  WHERE l.id_solicitud = $1
  `,
  GET_REGISTRO_MUNICIPAL_BY_ID: `SELECT * FROM impuesto.registro_municipal WHERE id_registro_municipal = $1`,
  GET_APPLICATION_VIEW_BY_ID: 'SELECT * FROM impuesto.solicitud_view WHERE id = $1',
  GET_RIM_DIR_BY_SOL_ID:`SELECT rm.direccion FROM impuesto.registro_municipal rm
  INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal
  WHERE l.id_solicitud = $1`,
  GET_RIM_DIR_BY_FRA_ID:`SELECT rm.direccion FROM impuesto.registro_municipal rm
  INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal
  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud
  INNER JOIN impuesto.convenio conv ON conv.id_solicitud = s.id_solicitud
  INNER JOIN impuesto.fraccion f ON f.id_convenio = conv.id_convenio
  WHERE f.id_fraccion = $1`,
  GET_AGREEMENT_VIEW_BY_FRACTION_ID: `SELECT *,f.monto AS "montoFraccion", f.fecha_aprobado AS "fechaAprobacionFraccion" 
  FROM impuesto.solicitud_view sv INNER JOIN impuesto.convenio c ON sv.id=c.id_solicitud 
  INNER JOIN impuesto.fraccion f USING (id_convenio) WHERE f.id_fraccion = $1;`,
  GET_LAST_FINE_FOR_LATE_APPLICATION:
    "SELECT * FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud s \
    ON l.id_solicitud = s.id_solicitud INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE \
    l.id_subramo = (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' \
    AND sr.descripcion = 'Multa por Declaracion Tardia (Actividad Economica)') AND l.id_registro_municipal = $1 ORDER BY s.fecha DESC",
  GET_LAST_FINE_FOR_LATE_RETENTION:
    "SELECT * FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud s \
    ON l.id_solicitud = s.id_solicitud INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE \
    l.id_subramo = (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' \
    AND sr.descripcion = 'Multa por Declaracion Tardia (Agente de Retenci??n)') AND l.id_registro_municipal = $1 ORDER BY s.fecha DESC",
  GET_FIRST_MONTH_OF_SETTLEMENT_PAYMENT: 'SELECT * FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2 ORDER BY id_liquidacion LIMIT 1;',
  GET_LAST_MONTH_OF_SETTLEMENT_PAYMENT: 'SELECT * FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2 ORDER BY id_liquidacion DESC LIMIT 1;',
  GET_TOTAL_PAYMENT_OF_PROCESS_SETTLEMENT: 'SELECT SUM(monto) AS "totalLiquidaciones" FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2',
  GET_AE_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'AE\'',
  GET_SM_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'SM\'',
  GET_IU_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'IU\'',
  GET_PP_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'PP\'',

  SET_AMOUNT_IN_BS_BASED_ON_PETRO: "UPDATE impuesto.liquidacion SET monto = (monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) WHERE id_solicitud = $1 RETURNING *;",
  SET_AMOUNT_IN_BS_BASED_ON_PETRO_ROUNDED: "UPDATE impuesto.liquidacion SET monto = ROUND(monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'), 2) WHERE id_solicitud = $1 RETURNING *;",
  FINISH_ROUNDING: 'UPDATE impuesto.liquidacion SET monto = ROUND(monto, 2) WHERE id_solicitud = $1',
  SET_AMOUNT_IN_BS_BASED_ON_PETRO_SETTLEMENT: "UPDATE impuesto.liquidacion SET monto = ROUND((monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'))) WHERE id_liquidacion = $1 RETURNING *;",
  FINISH_ROUNDING_SETTLEMENT: 'UPDATE impuesto.liquidacion SET monto = ROUND(monto, 2) WHERE id_liquidacion = $1',
  SET_AMOUNT_IN_BS_BASED_ON_PETRO_AGREEMENT: "UPDATE impuesto.fraccion SET monto = ROUND((monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'))) WHERE id_fraccion = $1 RETURNING *;",
  FINISH_ROUNDING_AGREEMENT: 'UPDATE impuesto.fraccion SET monto = ROUND(monto, 2) WHERE id_fraccion = $1',

  GET_FINES_BY_APPLICATION: 'SELECT * FROM impuesto.multa WHERE id_solicitud = $1',
  GET_LITTLEST_TAXABLE_MINIMUM_FOR_CONTRIBUTOR: `SELECT ae.*
  FROM impuesto.actividad_economica ae
  INNER JOIN (SELECT * FROM impuesto.actividad_economica_sucursal WHERE id_registro_municipal = $1) aes ON aes.numero_referencia = ae.numero_referencia
  ORDER BY minimo_tributable ASC 
  LIMIT 1;`,
  GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID: `SELECT datos, monto, fecha_liquidacion, fecha_vencimiento FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud WHERE l.id_solicitud = $1 AND l.id_subramo = $2`,
  CREATE_TAX_PAYMENT_APPLICATION: "SELECT * FROM impuesto.insert_solicitud($1, (SELECT id_tipo_tramite FROM tipo_tramite WHERE nombre_tramite = 'Pago de Impuestos'), $2)",
  UPDATE_TAX_APPLICATION_PAYMENT: 'SELECT * FROM impuesto.update_solicitud_state ($1, $2)',
  COMPLETE_TAX_APPLICATION_PAYMENT: 'SELECT * FROM impuesto.complete_solicitud_state($1, $2, null, true)',
  CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION: 'SELECT * FROM insert_liquidacion($1,$2,$3,$4,$5, $6, $7)',
  CREATE_RETENTION_DETAIL: 'SELECT * FROM impuesto.insert_retencion($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
  GET_RETENTION_FISCAL_CREDIT_FOR_CONTRIBUTOR: 'SELECT sum(monto) AS credito FROM impuesto.retencion WHERE rif = $1 AND rim = $2',
  GET_RETENTION_CHARGINGS_FOR_CONTRIBUTOR: `SELECT dr.id_detalle_retencion AS id, dr.fecha_retencion AS fecha, dr.monto_retenido AS monto, dr.numero_factura AS "numeroFactura", dr.tipo_retencion AS "tipoRetencion", CONCAT(c.tipo_documento, '-', c.documento) AS rif, rm.referencia_municipal AS rim, c.razon_social AS "razonSocial", s.aprobado AS pagado FROM impuesto.detalle_retencion dr 
  INNER JOIN impuesto.liquidacion l USING (id_liquidacion) 
  INNER JOIN impuesto.registro_municipal rm USING (id_registro_municipal) 
  INNER JOIN impuesto.contribuyente c USING (id_contribuyente) 
  INNER JOIN impuesto.solicitud s USING (id_solicitud)
  WHERE dr.rif = $1 AND dr.numero_referencia = $2
  ORDER BY dr.fecha_retencion DESC;`,
  GET_RETENTION_DETAIL_BY_APPLICATION_ID: 'SELECT dr.* FROM impuesto.detalle_retencion dr INNER JOIN impuesto.liquidacion l USING (id_liquidacion) INNER JOIN impuesto.solicitud USING (id_solicitud) WHERE l.id_solicitud = $1',
  CREATE_RETENTION_FISCAL_CREDIT: 'INSERT INTO impuesto.retencion (rif, rim, monto, activo, id_solicitud) VALUES ($1,$2,$3,$4, $5) RETURNING *;',
  SET_RETENTION_AGENT_STATE: 'UPDATE impuesto.contribuyente SET es_agente_retencion = $1 WHERE id_contribuyente = $2',
  GET_RETENTION_AGENTS: "SELECT * FROM impuesto.contribuyente c INNER JOIN impuesto.registro_municipal r USING (id_contribuyente) WHERE c.es_agente_retencion = true AND r.referencia_municipal ILIKE 'AR%'",
  CREATE_NEW_RETENTION_AGENT_RIM: 'SELECT * FROM impuesto.insert_agente_retencion($1,$2)',
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM:
    "SELECT * FROM impuesto.solicitud_state s RIGHT JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
      l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
        (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) AND EXTRACT('month' FROM l.fecha_liquidacion)\
        = EXTRACT('month' FROM CURRENT_DATE) AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC",
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED: `SELECT * FROM (SELECT s.id_solicitud AS id,
    s.id_tipo_tramite AS tipotramite,
    s.aprobado,
    s.fecha,
    s.fecha_aprobado AS "fechaAprobacion",
    ev.state,
    s.tipo_solicitud AS "tipoSolicitud",
    s.id_contribuyente
   FROM impuesto.solicitud s
     JOIN ( SELECT es.id_solicitud,
            impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
           FROM impuesto.evento_solicitud es
           WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1))
          GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
) s 
RIGHT JOIN impuesto.liquidacion l on s.id = l.id_solicitud 
INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo
INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo 
WHERE rm.codigo = $1 AND l.id_registro_municipal = $2 AND EXTRACT('month' FROM l.fecha_liquidacion) = EXTRACT('month' FROM CURRENT_DATE) AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC`,
CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM_OPTIMIZED_BY_YEAR: `SELECT * FROM (SELECT s.id_solicitud AS id,
  s.id_tipo_tramite AS tipotramite,
  s.aprobado,
  s.fecha,
  s.fecha_aprobado AS "fechaAprobacion",
  ev.state,
  s.tipo_solicitud AS "tipoSolicitud",
  s.id_contribuyente
 FROM impuesto.solicitud s
   JOIN ( SELECT es.id_solicitud,
          impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
         FROM impuesto.evento_solicitud es
         WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1))
        GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
) s 
RIGHT JOIN impuesto.liquidacion l on s.id = l.id_solicitud 
INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo
INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo 
WHERE rm.codigo = $1 AND l.id_registro_municipal = $2 AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC`,
  CURRENT_SETTLEMENT_EXISTS_IN_YEAR_FOR_CODE_AND_RIM:
    "SELECT * FROM impuesto.solicitud_state s INNER JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
          l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
            (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) AND EXTRACT('year' FROM l.fecha_liquidacion)\
            = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC",
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR: `
    SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON
    l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2
    AND EXTRACT('month' FROM l.fecha_liquidacion) = EXTRACT('month' FROM CURRENT_DATE) AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC`,
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR_BY_YEAR: `
    SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON
    l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2
    AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC`,
  GET_LAST_SETTLEMENTS_FOR_INSPECTION_BY_CONTRIBUTOR: `WITH solicitudcte AS (
    SELECT id_solicitud
    FROM impuesto.solicitud 
    WHERE id_contribuyente = $1
    )

    SELECT sl.state AS estado, l.*, r.descripcion FROM (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
      FROM impuesto.solicitud s
        JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
              FROM impuesto.evento_solicitud es
              WHERE id_solicitud IN (SELECT * FROM solicitudcte)
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    ) sl INNER JOIN impuesto.liquidacion l ON sl.id = l.id_solicitud INNER JOIN impuesto.subramo sr USING (id_subramo) INNER JOIN impuesto.ramo r USING (id_ramo) WHERE id_liquidacion IN (SELECT id_liquidacion FROM
        (SELECT id_ramo, MAX(id_liquidacion) as id_liquidacion, MAX(fecha_liquidacion)
    FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l USING (id_solicitud)
    INNER JOIN impuesto.subramo sr USING (id_subramo)
    INNER JOIN impuesto.ramo r USING (id_ramo)
    WHERE id_contribuyente = $1 AND r.codigo IN ('3.01.02.07.00.000.00','3.01.02.05.00.000.00','3.01.02.09.00.000.00','3.01.03.54.00.000.00')
    GROUP BY id_ramo) x
    );`,
  ALL_YEAR_SETTLEMENTS_EXISTS_FOR_LAST_YEAR_AE_DECLARATION: `SELECT * FROM (SELECT s.id_solicitud AS id,
      s.id_tipo_tramite AS tipotramite,
      s.aprobado,
      s.fecha,
      s.fecha_aprobado AS "fechaAprobacion",
      ev.state,
      s.tipo_solicitud AS "tipoSolicitud",
      s.id_contribuyente
     FROM impuesto.solicitud s
       JOIN ( SELECT es.id_solicitud,
              impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
             FROM impuesto.evento_solicitud es
             WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1))
            GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
  ) s 
  RIGHT JOIN impuesto.liquidacion l on s.id = l.id_solicitud 
  INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo
  INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo 
  WHERE rm.codigo = $1 AND l.id_registro_municipal = $2 AND
  datos#>>'{fecha,year}' = $3
  ORDER BY fecha_liquidacion DESC`,
  GET_LAST_SETTLEMENTS_FOR_INSPECTION_BY_RIM: `WITH solicitudcte AS (
    SELECT id_solicitud
    FROM impuesto.solicitud 
    WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1)
    )

    SELECT sl.state AS estado, l.*, r.descripcion FROM (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
      FROM impuesto.solicitud s
        JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
              FROM impuesto.evento_solicitud es
              WHERE id_solicitud IN (SELECT * FROM solicitudcte)
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    ) sl INNER JOIN impuesto.liquidacion l ON sl.id = l.id_solicitud INNER JOIN impuesto.subramo sr USING (id_subramo) INNER JOIN impuesto.ramo r USING (id_ramo) WHERE id_liquidacion IN (SELECT id_liquidacion FROM
        (SELECT id_ramo, MAX(id_liquidacion) as id_liquidacion, MAX(fecha_liquidacion)
    FROM impuesto.liquidacion l
    INNER JOIN impuesto.subramo sr USING (id_subramo)
    INNER JOIN impuesto.ramo r USING (id_ramo)
    WHERE id_registro_municipal = $1 AND r.codigo IN ('3.01.02.07.00.000.00','3.01.02.05.00.000.00','3.01.02.09.00.000.00','3.01.03.54.00.000.00')
    GROUP BY id_ramo) x
    );`,
  GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM:
    'SELECT * FROM impuesto.solicitud_state s RIGHT JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
   (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) ORDER BY fecha_liquidacion DESC LIMIT 1',
  GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM_OPTIMIZED: `WITH solicitudcte AS (
    SELECT id_solicitud
    FROM impuesto.solicitud 
    WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1)
    )

    SELECT *
    FROM (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
      FROM impuesto.solicitud s
        JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
              FROM impuesto.evento_solicitud es
              WHERE id_solicitud IN (SELECT * FROM solicitudcte)
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) s
    RIGHT JOIN impuesto.liquidacion l
        ON s.id = l.id_solicitud
    INNER JOIN impuesto.subramo sr
        ON l.id_subramo = sr.id_subramo
    INNER JOIN impuesto.ramo rm
        ON sr.id_ramo = rm.id_ramo
    WHERE rm.codigo = $1
            AND l.id_registro_municipal = $2
    ORDER BY  fecha_liquidacion DESC LIMIT 1;`,
    GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM_OPTIMIZED_FOR_AE: `WITH solicitudcte AS (
      SELECT id_solicitud
      FROM impuesto.solicitud 
      WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1)
      )
  
      SELECT *
      FROM (SELECT s.id_solicitud AS id,
          s.id_tipo_tramite AS tipotramite,
          s.aprobado,
          s.fecha,
          s.fecha_aprobado AS "fechaAprobacion",
          ev.state,
          s.tipo_solicitud AS "tipoSolicitud",
          s.id_contribuyente
        FROM impuesto.solicitud s
          JOIN ( SELECT es.id_solicitud,
                  impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
                FROM impuesto.evento_solicitud es
                WHERE id_solicitud IN (SELECT * FROM solicitudcte)
                GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) s
      RIGHT JOIN impuesto.liquidacion l
          ON s.id = l.id_solicitud
      INNER JOIN impuesto.subramo sr
          ON l.id_subramo = sr.id_subramo
      INNER JOIN impuesto.ramo rm
          ON sr.id_ramo = rm.id_ramo
      WHERE rm.codigo = $1
              AND l.id_registro_municipal = $2
      ORDER BY (datos#>>'{fecha, year}')::int DESC, month_to_number(datos#>>'{fecha, month}') DESC LIMIT 1;`,
  GET_FIRST_SETTLEMENT_FOR_SUBBRANCH_AND_RIM_OPTIMIZED: `WITH solicitudcte AS (
      SELECT id_solicitud
      FROM impuesto.solicitud 
      WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2)
      )
  
      SELECT rm.descripcion_corta AS ramo, l.fecha_liquidacion AS desde
      FROM (SELECT s.id_solicitud AS id,
          s.id_tipo_tramite AS tipotramite,
          s.aprobado,
          s.fecha,
          s.fecha_aprobado AS "fechaAprobacion",
          ev.state,
          s.tipo_solicitud AS "tipoSolicitud",
          s.id_contribuyente
        FROM impuesto.solicitud s
          JOIN ( SELECT es.id_solicitud,
                  impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
                FROM impuesto.evento_solicitud es
                WHERE id_solicitud IN (SELECT * FROM solicitudcte)
                GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) s
      RIGHT JOIN impuesto.liquidacion l
          ON s.id = l.id_solicitud
      INNER JOIN impuesto.subramo sr
          ON l.id_subramo = sr.id_subramo
      INNER JOIN impuesto.ramo rm
          ON sr.id_ramo = rm.id_ramo
      WHERE sr.id_subramo IN (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE descripcion_corta = $1))
              AND l.id_registro_municipal = 
          (SELECT id_registro_municipal
          FROM impuesto.registro_municipal
          WHERE id_registro_municipal = $2 LIMIT 1)
      ORDER BY fecha_liquidacion LIMIT 1;`,
  GET_SM_INFO_BY_BRANCHID: `SELECT * FROM impuesto.tarifa_aseo JOIN impuesto.tarifa_aseo_sucursal USING(id_tarifa_aseo) WHERE id_registro_municipal = $1`,
  GET_LAST_SETTLEMENT_FOR_CODE_AND_CONTRIBUTOR:
    `SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2\
  ORDER BY fecha_liquidacion DESC LIMIT 1`,
  GET_LAST_SETTLEMENT_FOR_CODE_AND_CONTRIBUTOR_FOR_AE:
    `SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2\
  ORDER BY (datos#>>'{fecha, year}')::int DESC, month_to_number(datos#>>'{fecha, month}') DESC LIMIT 1`,
  GET_SETTLEMENTS_FOR_CODE_AND_RIM:
    'SELECT * FROM impuesto.solicitud_state s INNER JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON \
l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
 (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) ORDER BY fecha_liquidacion DESC',
  GET_SETTLEMENTS_FOR_CODE_AND_RIM_OPTIMIZED: `WITH solicitudcte AS (
  SELECT id_solicitud
  FROM impuesto.solicitud 
  WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE referencia_municipal = $2))

  SELECT *
  FROM ( SELECT s.id_solicitud AS id,
    s.id_tipo_tramite AS tipotramite,
    s.aprobado,
    s.fecha,
    s.fecha_aprobado AS "fechaAprobacion",
    ev.state,
    s.tipo_solicitud AS "tipoSolicitud",
    s.id_contribuyente
  FROM impuesto.solicitud s
    JOIN ( SELECT es.id_solicitud,
            impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
          FROM impuesto.evento_solicitud es
          WHERE id_solicitud IN (SELECT * FROM solicitudcte)
          GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
  ) s
  INNER JOIN impuesto.liquidacion l
    ON s.id = l.id_solicitud
  INNER JOIN impuesto.subramo sr
    ON l.id_subramo = sr.id_subramo
  INNER JOIN impuesto.ramo rm
    ON sr.id_ramo = rm.id_ramo
  WHERE rm.codigo = $1
        AND l.id_registro_municipal = 
    (SELECT id_registro_municipal
    FROM impuesto.registro_municipal
    WHERE referencia_municipal = $2 LIMIT 1)
  ORDER BY  fecha_liquidacion DESC;`,
  GET_ALL_SETTLEMENTS_FOR_RIM: `WITH solicitudcte AS (
    SELECT id_solicitud
    FROM impuesto.solicitud 
    WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.liquidacion WHERE id_registro_municipal = (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $1 LIMIT 1)))
  
    SELECT s.*, l.*, sr.id_subramo, sr.id_ramo, sr.subindice, sr.descripcion, rm.id_ramo, rm.codigo, rm.descripcion, rm.descripcion_corta, rm.liquidacion_especial
    FROM ( SELECT s.id_solicitud AS id,
      s.id_tipo_tramite AS tipotramite,
      s.aprobado,
      s.fecha,
      s.fecha_aprobado AS "fechaAprobacion",
      ev.state,
      s.tipo_solicitud AS "tipoSolicitud",
      s.id_contribuyente
    FROM impuesto.solicitud s
      JOIN ( SELECT es.id_solicitud,
              impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
            FROM impuesto.evento_solicitud es
            WHERE id_solicitud IN (SELECT * FROM solicitudcte)
            GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    ) s
    INNER JOIN impuesto.liquidacion l
      ON s.id = l.id_solicitud
    INNER JOIN impuesto.subramo sr
      ON l.id_subramo = sr.id_subramo
    INNER JOIN impuesto.ramo rm
      ON sr.id_ramo = rm.id_ramo
    ORDER BY  fecha_liquidacion;`,
  GET_ALL_SETTLEMENTS_FOR_CONTRIBUTOR: `SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON \
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE s.id_contribuyente = $1\
  AND l.id_registro_municipal IS NULL ORDER BY fecha_liquidacion`,
  GET_SETTLEMENTS_FOR_CODE_AND_CONTRIBUTOR:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON \
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2\
  AND l.id_registro_municipal IS NULL ORDER BY fecha_liquidacion DESC',
  CREATE_AE_BREAKDOWN_FOR_SETTLEMENT: 'INSERT INTO impuesto.ae_desglose (id_liquidacion, id_aforo, monto_declarado) VALUES ($1, $2, $3) RETURNING *',
  CREATE_SM_BREAKDOWN_FOR_SETTLEMENT: 'INSERT INTO impuesto.sm_desglose (id_liquidacion, id_inmueble, monto_aseo, monto_gas) VALUES ($1, $2, $3, $4) RETURNING *',
  CREATE_IU_BREAKDOWN_FOR_SETTLEMENT: 'INSERT INTO impuesto.iu_desglose (id_liquidacion, id_inmueble, monto) VALUES ($1, $2, $3) RETURNING *',
  CREATE_PP_BREAKDOWN_FOR_SETTLEMENT: 'INSERT INTO impuesto.pp_desglose (id_liquidacion, id_subarticulo, monto, cantidad) VALUES ($1, $2, $3, $4) RETURNING *',
  CREATE_FINING_FOR_LATE_APPLICATION:
    "INSERT INTO impuesto.liquidacion (id_solicitud, monto, id_subramo, datos, fecha_vencimiento, id_registro_municipal) VALUES ($1, $2, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' AND sr.descripcion = 'Multa por Declaracion Tardia (Actividad Economica)'), $3, $4, $5) RETURNING *",
  CREATE_FINING_FOR_LATE_RETENTION:
    "INSERT INTO impuesto.liquidacion (id_solicitud, monto, id_subramo, datos, fecha_vencimiento, id_registro_municipal) VALUES ($1, $2, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' AND sr.descripcion = 'Multa por Declaracion Tardia (Agente de Retenci??n)'), $3, $4, $5) RETURNING *",
  CREATE_FINING_FOR_LATE_APPLICATION_PETRO:
    "INSERT INTO impuesto.liquidacion (id_solicitud, monto_petro, id_subramo, datos, fecha_vencimiento, id_registro_municipal) VALUES ($1, $2, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' AND sr.descripcion = 'Multa por Declaracion Tardia (Actividad Economica)'), $3, $4, $5) RETURNING *",
  CREATE_FINING_FOR_LATE_RETENTION_PETRO:
    "INSERT INTO impuesto.liquidacion (id_solicitud, monto_petro, id_subramo, datos, fecha_vencimiento, id_registro_municipal) VALUES ($1, $2, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' AND sr.descripcion = 'Multa por Declaracion Tardia (Agente de Retenci??n)'), $3, $4, $5) RETURNING *",
  UPDATE_PAID_STATE_FOR_TAX_PAYMENT_APPLICATION: 'UPDATE impuesto.solicitud SET pagado = true WHERE id_solicitud = $1',
  UPDATE_RECEIPT_FOR_SETTLEMENTS: 'UPDATE impuesto.liquidacion SET recibo = $1 WHERE id_procedimiento = $2 AND id_solicitud = $3',
  UPDATE_CERTIFICATE_SETTLEMENT: 'UPDATE impuesto.liquidacion SET certificado = $1 WHERE id_liquidacion = $2;',
  CREATE_CONTRIBUTOR_FOR_LINKING:
    'INSERT INTO IMPUESTO.CONTRIBUYENTE (tipo_documento, documento, razon_social, denominacion_comercial, siglas, id_parroquia, sector, direccion,\
       punto_referencia, verificado, tipo_contribuyente) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *;',
  CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR:
    "INSERT INTO impuesto.registro_municipal (id_contribuyente, referencia_municipal, nombre_representante, telefono_celular,\
     email, denominacion_comercial, fecha_aprobacion, actualizado, direccion) VALUES ($1, $2, $3, $4, $5, $6, (NOW() - interval '4 hours'), $7, $8) RETURNING *;",
  CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR: 'INSERT INTO inmueble_urbano (id_registro_municipal, direccion, tipo_inmueble) VALUES ($1, $2, $3) RETURNING *;',
  GET_CONTRIBUTOR_BY_DOCUMENT_AND_DOC_TYPE: 'SELECT * FROM impuesto.contribuyente c WHERE c.documento = $1 AND c.tipo_documento = $2',
  CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR: 'INSERT INTO impuesto.actividad_economica_sucursal (id_registro_municipal, numero_referencia, aplicable_desde) VALUES ($1, $2, $3)',
  GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR: 'SELECT * FROM impuesto.registro_municipal WHERE referencia_municipal = $1 AND id_contribuyente = $2 LIMIT 1',
  GET_ECONOMIC_ACTIVITIES_BY_CONTRIBUTOR:
    'SELECT ae.* FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_sucursal aec ON ae.numero_referencia = aec.numero_referencia INNER JOIN impuesto.registro_municipal rm ON aec.id_registro_municipal = rm.id_registro_municipal WHERE rm.id_registro_municipal = $1',
  GET_ECONOMIC_ACTIVITY_BY_ID: 'SELECT ae.* FROM impuesto.actividad_economica ae WHERE id_actividad_economica = $1',
  GET_CONTRIBUTOR_HAS_BRANCH: 'SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = $1',
  REGISTRY_BY_SETTLEMENT_ID: 'SELECT * FROM impuesto.registro_municipal rm INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal WHERE l.id_liquidacion = $1;',
  GET_PAYMENT_FROM_REQ_ID: 'SELECT * FROM pago p LEFT JOIN banco b ON b.id_banco = p.id_banco WHERE id_procedimiento = $1 AND concepto = $2',
  GET_PAYMENT_FROM_REQ_ID_DEST: 'SELECT * FROM pago p LEFT JOIN banco b ON b.id_banco = p.id_banco_destino WHERE id_procedimiento = $1 AND concepto = $2',
  GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE: `SELECT p.metodo_pago AS tipo, SUM(p.monto) AS monto, COUNT(*) AS transacciones
      FROM pago p
      WHERE p.concepto IN ('IMPUESTO', 'RETENCION') AND p.id_procedimiento = $1
      GROUP BY p.metodo_pago;`,
  GET_PAYMENT_FROM_REQ_ID_GROUP_BY_PAYMENT_TYPE_AGREEMENT: `SELECT p.metodo_pago AS tipo, SUM(p.monto) AS monto, COUNT(*) AS transacciones
  FROM pago p
  WHERE p.concepto = 'CONVENIO' AND p.id_procedimiento = $1
  GROUP BY p.metodo_pago;`,
  GET_PAYMENT_FROM_REQ_ID_GROUP_BY_AGREEMENT: `SELECT p.metodo_pago AS tipo, SUM(p.monto) AS monto, COUNT(*) AS transacciones
      FROM pago p
      WHERE p.concepto = 'CONVENIO' AND p.id_procedimiento = $1
      GROUP BY p.metodo_pago;`,

  GET_RECEIPT_RECORDS_BY_USER: 'SELECT id_registro_recibo AS id, fecha, recibo, razon_social AS "razonSocial", rim, concepto FROM impuesto.registro_recibo WHERE id_usuario = $1 and recibo != \'\' ORDER BY fecha DESC;',
  INSERT_RECEIPT_RECORD: `INSERT INTO impuesto.registro_recibo (id_usuario, recibo, razon_social, rim, concepto, id_solicitud) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (id_usuario, recibo, id_solicitud) DO NOTHING RETURNING *;`,
  UPDATE_RECEIPT_RECORD: 'UPDATE impuesto.registro_recibo SET recibo = $2 WHERE id_registro_recibo = $1;',
  INSERT_AGREEMENT_RECEIPT_RECORD: `INSERT INTO impuesto.registro_recibo_convenio (id_usuario, recibo, razon_social, rim, concepto, id_fraccion) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (id_usuario, recibo, id_fraccion) DO NOTHING RETURNING *;`,
  UPDATE_AGREEMENT_RECEIPT_RECORD: 'UPDATE impuesto.registro_recibo_convenio SET recibo = $2 WHERE id_registro_recibo_convenio = $1;',
  //Dias feriados
  GET_HOLIDAYS_BASED_ON_PAYMENT_DATE: "SELECT * FROM impuesto.dias_feriados WHERE dia BETWEEN $1::date AND ($1::date + interval '7 days');",
  GET_HOLIDAYS: 'SELECT id_dia_feriado as id, dia, descripcion \
  FROM impuesto.dias_feriados \
  WHERE EXTRACT(year from dia) IN (EXTRACT(year from CURRENT_TIMESTAMP), EXTRACT(year from CURRENT_TIMESTAMP) + 1 );',
  CREATE_HOLIDAY: 'INSERT INTO impuesto.dias_feriados (dia, descripcion) VALUES ($1, $2) RETURNING id_dia_feriado AS id, dia, descripcion;',
  DELETE_HOLIDAY: 'DELETE FROM impuesto.dias_feriados WHERE id_dia_feriado = $1 RETURNING id_dia_feriado as id, dia, descripcion;',

  //VERIFICACION DE DATOS DE RIM
  CHECK_VERIFICATION_EXISTS: "SELECT *, (CURRENT_TIMESTAMP - fecha_verificacion) AS elapsed, (CURRENT_TIMESTAMP - fecha_verificacion) > interval '10 minutes' AS late  FROM impuesto.verificacion_telefono WHERE id_usuario = $1;",
  DROP_EXISTING_VERIFICATION: 'DELETE FROM impuesto.verificacion_telefono WHERE id_usuario = $1',
  CREATE_VERIFICATION: 'INSERT INTO impuesto.verificacion_telefono (codigo_verificacion, id_usuario, telefono) VALUES ($1, $2, $3) RETURNING *;',
  ADD_PHONE_TO_VERIFICATION: 'INSERT INTO impuesto.registro_municipal_verificacion (id_registro_municipal, id_verificacion_telefono) VALUES ($1, $2);',
  GET_VERIFICATION: "SELECT *, (CURRENT_TIMESTAMP - fecha_verificacion) AS elapsed, (CURRENT_TIMESTAMP - fecha_verificacion) > interval '10 minutes' AS late FROM impuesto.verificacion_telefono WHERE id_usuario = $1",
  VALIDATE_CODE: 'UPDATE impuesto.verificacion_telefono SET verificado = true WHERE id_usuario = $1',
  UPDATE_CODE: 'UPDATE impuesto.verificacion_telefono SET codigo_verificacion = $1, fecha_verificacion = CURRENT_TIMESTAMP WHERE id_usuario = $2',

  //REPORTES
  GET_IDR_DATA: `WITH liquidaciones_vigentes AS (
    SELECT CASE WHEN r.codigo = '3.01.02.07.00.000.00' THEN '3.01.02.07.00' WHEN r.codigo = '111' THEN '3.01.02.05.00' WHEN r.codigo = '122' THEN '3.01.03.54.00' WHEN r.codigo = '5000' THEN '3.01.02.08.00' WHEN r.codigo = '114' THEN '3.01.02.09.00' ELSE r.codigo END AS codigo, ROUND((monto_petro * (CASE WHEN id_subramo = 10 THEN (l.datos#>>'{valorPetro}')::DECIMAL ELSE (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO') END)), 2) AS monto_en_bs, CASE WHEN (id_subramo BETWEEN 793 AND 798 OR id_subramo = 10) THEN 'ACTIVIDADES ECONOMICAS' WHEN id_subramo IN (823, 824) THEN 'SOLVENCIAS' ELSE r.descripcion END AS descripcion 
    FROM impuesto.solicitud AS s 
    JOIN impuesto.liquidacion AS l USING (id_solicitud) 
    JOIN impuesto.subramo AS sub USING(id_subramo) 
    JOIN impuesto.ramo AS r USING(id_ramo) 
    WHERE s.fecha BETWEEN $1 AND $2 AND (s.aprobado = false OR s.fecha_aprobado > $2) AND s.tipo_solicitud <> 'CONVENIO'
  ),
  convenios_vigentes AS (
    SELECT DISTINCT ON(fr.id_fraccion) CASE WHEN r.codigo = '112' THEN '3.01.02.07.00' WHEN r.codigo = '111' THEN '3.01.02.05.00' WHEN r.codigo = '122' THEN '3.01.03.54.00' WHEN r.codigo = '5000' THEN '3.01.02.08.00' WHEN r.codigo = '114' THEN '3.01.02.09.00' ELSE r.codigo END AS codigo, fr.monto_petro * (CASE WHEN id_subramo = 99 THEN (l.datos#>>'{valorPetro}')::DECIMAL ELSE (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO') END) AS monto_en_bs, CASE WHEN (id_subramo BETWEEN 1085 AND 1090 OR id_subramo = 99) THEN 'ACTIVIDADES ECONOMICAS' ELSE r.descripcion END AS descripcion 
    FROM impuesto.fraccion AS fr 
    JOIN impuesto.convenio AS c USING(id_convenio) 
    JOIN impuesto.solicitud AS s USING(id_solicitud) 
    JOIN impuesto.liquidacion AS l USING(id_solicitud) 
    LEFT JOIN impuesto.subramo AS sub USING(id_subramo) 
    JOIN impuesto.ramo AS r USING(id_ramo) 
    WHERE (s.aprobado = false OR s.fecha_aprobado > $2) AND s.fecha BETWEEN $1 AND $2
  ),
  b AS (
    SELECT codigo, SUM(monto_total) AS monto_total, SUM(cantidad_total) AS cantidad_total, descripcion FROM (
      SELECT codigo, SUM(monto_en_bs) AS monto_total, COUNT(monto_en_bs) AS cantidad_total, descripcion 
      FROM liquidaciones_vigentes 
      GROUP BY codigo, descripcion
      UNION ALL
      SELECT codigo, SUM(monto_en_bs) AS monto_total, COUNT(monto_en_bs) AS cantidad_total, descripcion 
      FROM convenios_vigentes 
      GROUP BY codigo, descripcion
    ) c
    GROUP BY codigo, descripcion
  ),
  liquidaciones_solventes AS (
    SELECT CASE WHEN r.codigo = '112' THEN '3.01.02.07.00' WHEN r.codigo = '111' THEN '3.01.02.05.00' WHEN r.codigo = '122' THEN '3.01.03.54.00' WHEN r.codigo = '5000' THEN '3.01.02.08.00' WHEN r.codigo = '114' THEN '3.01.02.09.00' ELSE r.codigo END AS codigo, l.monto, CASE WHEN (id_subramo BETWEEN 793 AND 798 OR id_subramo = 10) THEN 'ACTIVIDADES ECONOMICAS' WHEN id_subramo IN (823, 824) THEN 'SOLVENCIAS' ELSE r.descripcion END AS descripcion 
    FROM impuesto.solicitud AS s 
    JOIN impuesto.liquidacion AS l USING(id_solicitud) 
    JOIN impuesto.subramo AS sub USING(id_subramo) 
    JOIN impuesto.ramo AS r USING(id_ramo) 
    WHERE s.aprobado = true AND s.fecha BETWEEN $1 AND $2 AND id_solicitud IN (
      SELECT id_procedimiento 
      FROM pago 
      WHERE fecha_de_aprobacion BETWEEN $1 AND $2
    )
  ),
  convenios_solventes AS (
    SELECT DISTINCT ON(fr.id_fraccion) CASE WHEN r.codigo = '112' THEN '3.01.02.07.00' WHEN r.codigo = '111' THEN '3.01.02.05.00' WHEN r.codigo = '122' THEN '3.01.03.54.00' WHEN r.codigo = '5000' THEN '3.01.02.08.00' WHEN r.codigo = '114' THEN '3.01.02.09.00' ELSE r.codigo END AS codigo, fr.monto, CASE WHEN (id_subramo BETWEEN 1085 AND 1090 OR id_subramo = 99) THEN 'ACTIVIDADES ECONOMICAS' ELSE r.descripcion END AS descripcion 
    FROM impuesto.fraccion AS fr 
    JOIN impuesto.convenio AS c USING(id_convenio) 
    JOIN impuesto.solicitud AS s USING(id_solicitud) 
    JOIN impuesto.liquidacion AS l USING(id_solicitud) 
    LEFT JOIN impuesto.subramo AS sub USING(id_subramo) 
    JOIN impuesto.ramo AS r USING(id_ramo)
    JOIN pago AS p ON p.id_procedimiento = fr.id_fraccion 
    WHERE s.aprobado = true AND s.fecha BETWEEN $1 AND $2 AND p.fecha_de_aprobacion BETWEEN $1 AND $2
  ),
  a AS (
    SELECT codigo, SUM(monto_total) AS monto_total, SUM(cantidad_total) AS cantidad_total, descripcion FROM (
      SELECT codigo, SUM(monto) AS monto_total, COUNT(monto) AS cantidad_total, descripcion 
      FROM liquidaciones_solventes 
      GROUP BY codigo, descripcion
      UNION ALL
      SELECT codigo, SUM(monto) AS monto_total, COUNT(monto) AS cantidad_total, descripcion
      FROM convenios_solventes
      GROUP BY codigo, descripcion
    ) d
    GROUP BY codigo, descripcion
  )
  SELECT a.codigo, descripcion, b.monto_total + a.monto_total AS "totalLiquidado", b.cantidad_total + a.cantidad_total AS "cantidadLiquidado", a.monto_total AS "totalIngresado", a.cantidad_total AS "cantidadIngresado" FROM a JOIN b USING(descripcion);`,
  GET_INGRESS: `SELECT ramo, descripcion, codigo, SUM("cantidadIng") as "cantidadIng", SUM(ingresado) as ingresado FROM ( 
    (SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadIng", SUM(CASE WHEN l.id_subramo = 107 OR l.id_subramo = 108 THEN (CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN (l.monto / 1.16 ) WHEN (l.datos->>'IVA')::numeric = 4 THEN (l.monto / 1.04 ) ELSE (l.monto / 1.16 ) END ) ELSE l.monto END ) as ingresado 
        FROM ((SELECT DISTINCT ON (l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto) l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos 
                FROM impuesto.liquidacion l 
                WHERE id_solicitud IS NOT NULL 
                AND id_solicitud IN (SELECT id_solicitud 
                                        FROM impuesto.solicitud 
                                        WHERE fecha_aprobado BETWEEN $1 AND $2
                                        AND tipo_solicitud != 'CONVENIO') 
                UNION ALL
                SELECT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos
                FROM impuesto.liquidacion l 
                WHERE id_solicitud IS NULL
                 AND fecha_liquidacion BETWEEN $1 AND $2 order by id_solicitud)) l 
        LEFT JOIN (SELECT *, s.id_solicitud AS id_solicitud_q 
                        FROM impuesto.solicitud s 
                        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $1 AND $2 ) 
        se ON l.id_solicitud = se.id_solicitud_q
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
        ORDER BY ramo)
    UNION
    (SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadIng", SUM(CASE WHEN l.id_subramo = 102 THEN (CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN (f.monto / 1.16 ) WHEN (l.datos->>'IVA')::numeric = 4 THEN (f.monto / 1.04 ) ELSE (f.monto / 1.16 ) END ) ELSE  f.monto END) as ingresado 
      FROM (SELECT * FROM impuesto.fraccion WHERE fecha_aprobado BETWEEN $1 AND $2) f
      INNER JOIN impuesto.convenio USING (id_convenio)
      INNER JOIN impuesto.solicitud USING (id_solicitud)
      INNER JOIN (SELECT DISTINCT ON (id_solicitud) id_solicitud, id_subramo, id_liquidacion, datos FROM impuesto.liquidacion ) l USING (id_solicitud)
      FULL OUTER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
      LEFT JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
      GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
      ORDER BY ramo)) x
        WHERE codigo != '915'
        GROUP BY ramo, descripcion, codigo;`,
  GET_LIQUIDATED: `SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadLiq", SUM(CASE WHEN l.monto IS NOT NULL THEN l.monto ELSE (monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END) as liquidado 
        FROM (SELECT *  FROM impuesto.liquidacion WHERE fecha_liquidacion BETWEEN $1 AND $2) l 
        INNER JOIN (SELECT *, s.id_solicitud AS id_solicitud_q FROM impuesto.solicitud s 
                        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) 
        se ON l.id_solicitud = se.id_solicitud_q
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
        ORDER BY ramo;`,
        GET_PAID_LIQUIDATED: `SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadIng", SUM(l.monto) as ingresado
        FROM (SELECT *  FROM impuesto.liquidacion WHERE fecha_liquidacion BETWEEN $1 AND $2) l 
        INNER JOIN (SELECT *, s.id_solicitud AS id_solicitud_q FROM impuesto.solicitud s 
                        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $1 AND $2) 
        se ON l.id_solicitud = se.id_solicitud_q
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
        ORDER BY ramo;`,
  GET_TRANSFERS_BY_BANK: `WITH liquidaciones AS (SELECT DISTINCT l.id_solicitud
    FROM ((SELECT DISTINCT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto  FROM impuesto.liquidacion l WHERE id_solicitud IS NOT NULL AND id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE fecha_aprobado BETWEEN $1 AND $2 AND tipo_solicitud != 'CONVENIO') UNION SELECT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto FROM impuesto.liquidacion l WHERE id_solicitud IS NULL AND fecha_liquidacion BETWEEN $3 AND $4 order by id_solicitud)) l 
    LEFT JOIN (SELECT *, s.id_solicitud AS id_solicitud_q 
                    FROM impuesto.solicitud s 
                    INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
        AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $5 AND $6) 
    se ON l.id_solicitud = se.id_solicitud_q
    )
    
    SELECT id_banco, banco, SUM(monto) AS monto FROM (SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, SUM(p.monto) as monto
            FROM pago p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            WHERE p.concepto IN ('IMPUESTO', 'RETENCION') AND p.aprobado = true AND p.metodo_pago = 'TRANSFERENCIA' AND p.id_procedimiento IN (SELECT * FROM liquidaciones)
            GROUP BY p.id_banco_destino, b.nombre
            UNION
            SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, SUM(ROUND(p.monto)) as monto
            FROM (SELECT * FROM pago p 
                    INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                    INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                    WHERE p.concepto = 'TRAMITE' AND p.aprobado = true AND tt.id_institucion = 9 AND p.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_aprobacion BETWEEN $7 AND $8) p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            GROUP BY p.id_banco_destino, b.nombre
            UNION
            SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, SUM(p.monto) as monto
            FROM pago p 
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            INNER JOIN impuesto.fraccion f ON f.id_fraccion = p.id_procedimiento
            WHERE p.concepto = 'CONVENIO' AND P.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_aprobacion BETWEEN $9 AND $10
            GROUP BY p.id_banco_destino, b.nombre
            ) x GROUP BY id_banco, banco;`,
  // GET_TRANSFERS_BY_BANK_BY_APPROVAL_NEW: `WITH myconstants (rDay,rMes,rYear,idBanco) as (
  //             values (EXTRACT(day FROM $1),EXTRACT(month FROM $1) + 1,EXTRACT(year FROM $1),19)
  //          )
  //          select pago.referencia,pago.monto,pago.fecha_de_pago,pago.fecha_de_aprobacion,banco.nombre
  //          from pago,banco,myconstants where
  //          pago.id_banco_destino=banco.id_banco and
  //          pago.aprobado=true and
  //          pago.metodo_pago='TRANSFERENCIA' and
  //          EXTRACT(DAY FROM pago.fecha_de_pago)=rDay and
  //          EXTRACT(MONTH FROM pago.fecha_de_pago)=rMes and
  //          EXTRACT(YEAR FROM pago.fecha_de_pago)=rYear and
  //          pago.id_banco_destino=idBanco and
  //          EXTRACT(DAY FROM pago.fecha_de_aprobacion)=rDay and
  //          EXTRACT(MONTH FROM pago.fecha_de_aprobacion)=rMes and
  //          EXTRACT(YEAR FROM pago.fecha_de_aprobacion)=rYear;`,
  GET_TRANSFERS_BY_BANK_BY_APPROVAL_NEW: `SELECT referencia, monto, fecha_de_pago AS "fecha de pago", fecha_de_aprobacion AS "fecha de aprobaci??n", banco.nombre
  FROM pago JOIN banco USING (id_banco) WHERE fecha_de_aprobacion BETWEEN $1 AND $2 AND id_banco = $3 AND metodo_pago = 'TRANSFERENCIA';`,
  GET_EXTERNAL_TRANSFERS: `SELECT CONCAT(usuario.nacionalidad, '-', usuario.cedula) AS documento, usuario.nombre_completo, pago.referencia, banco.nombre, pago.monto, pago.fecha_de_pago, CASE WHEN aprobado = true THEN 'VALIDADA' ELSE 'POR VALIDAR' END AS estatus FROM pago JOIN usuario USING (id_usuario) JOIN banco USING (id_banco) WHERE fecha_de_pago BETWEEN $1 AND $2 AND id_tipo_usuario = 4 AND metodo_pago = 'TRANSFERENCIA' ORDER BY fecha_de_pago DESC;`,
  GET_UNFINISHED_SUPPORT_TICKETS: `WITH et AS (SELECT id_tramite, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state FROM evento_tramite GROUP BY id_tramite)
  SELECT CONCAT(datos#>>'{usuario, tipoDocumento}', '-',datos#>>'{usuario, documento}') AS documento, CASE WHEN datos#>>'{usuario, rim}' IS NULL THEN '' ELSE datos#>>'{usuario, rim}' END AS rim, datos#>>'{usuario, observacion}' AS observacion, CASE WHEN datos#>>'{funcionario, respuesta}' IS NULL THEN '' ELSE datos#>>'{funcionario, respuesta}' END AS respuesta, CASE WHEN datos#>>'{funcionario, nombre}' IS NULL THEN '' ELSE datos#>>'{funcionario, nombre}' END AS funcionario, state FROM tramite JOIN et USING(id_tramite) WHERE (state = 'enproceso' OR state = 'enrevision') AND id_tipo_tramite = 37 AND fecha_creacion BETWEEN $1 AND $2`,
  GET_FINISHED_SUPPORT_TICKETS: `WITH et AS (SELECT id_tramite, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state FROM evento_tramite GROUP BY id_tramite)
  SELECT CONCAT(datos#>>'{usuario, tipoDocumento}', '-',datos#>>'{usuario, documento}') AS documento, CASE WHEN datos#>>'{usuario, rim}' IS NULL THEN '' ELSE datos#>>'{usuario, rim}' END AS rim, datos#>>'{usuario, observacion}' AS observacion, CASE WHEN datos#>>'{funcionario, respuesta}' IS NULL THEN '' ELSE datos#>>'{funcionario, respuesta}' END AS respuesta, CASE WHEN datos#>>'{funcionario, nombre}' IS NULL THEN '' ELSE datos#>>'{funcionario, nombre}' END AS funcionario, fecha_culminacion - fecha_creacion AS fecha_atendido FROM tramite JOIN et USING(id_tramite) WHERE state = 'finalizado' AND id_tipo_tramite = 37 AND fecha_creacion BETWEEN $1 AND $2`,
  GET_TRANSFERS_BY_BANK_BY_APPROVAL: `
  WITH liquidaciones AS (SELECT DISTINCT l.id_solicitud
    FROM ((SELECT DISTINCT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto  FROM impuesto.liquidacion l WHERE id_solicitud IS NOT NULL AND id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE fecha_aprobado BETWEEN $1 AND $2 AND tipo_solicitud != 'CONVENIO') UNION SELECT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto FROM impuesto.liquidacion l WHERE id_solicitud IS NULL AND fecha_liquidacion BETWEEN  $3 AND $4 order by id_solicitud)) l 
    LEFT JOIN (SELECT *, s.id_solicitud AS id_solicitud_q 
                    FROM impuesto.solicitud s 
                    INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
        AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $5 AND $6) 
    se ON l.id_solicitud = se.id_solicitud_q
    )
    
    SELECT id_banco, banco, SUM(monto) AS monto, tipo_transf AS "tipoAprobacion" FROM (
            SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, CASE u.id_tipo_usuario WHEN 4 THEN 'WEB' ELSE 'CAJERO' END as tipo_transf, SUM(p.monto) as monto
            FROM pago p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            INNER JOIN usuario u ON u.id_usuario = p.id_usuario
            WHERE p.concepto IN ('IMPUESTO', 'RETENCION') AND p.aprobado = true AND p.metodo_pago = 'TRANSFERENCIA' AND p.id_procedimiento IN (SELECT * FROM liquidaciones)
            GROUP BY p.id_banco_destino, b.nombre, tipo_transf
            UNION
            SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, CASE u.id_tipo_usuario WHEN 4 THEN 'WEB' ELSE 'CAJERO' END as tipo_transf, SUM(ROUND(p.monto)) as monto
            FROM (SELECT *, p.id_usuario as id_usuario_pago FROM pago p 
                    INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                    INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                    WHERE p.concepto = 'TRAMITE' AND p.aprobado = true AND tt.id_institucion = 9 AND p.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_aprobacion BETWEEN $7 AND $8) p
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            INNER JOIN usuario u ON u.id_usuario = p.id_usuario_pago
            GROUP BY p.id_banco_destino, b.nombre, tipo_transf
            UNION
            SELECT p.id_banco_destino AS "id_banco", b.nombre AS banco, CASE u.id_tipo_usuario WHEN 4 THEN 'WEB' ELSE 'CAJERO' END as tipo_transf, SUM(p.monto) as monto
            FROM pago p 
            INNER JOIN banco b ON b.id_banco = p.id_banco_destino
            INNER JOIN impuesto.fraccion f ON f.id_fraccion = p.id_procedimiento
            INNER JOIN usuario u ON u.id_usuario = p.id_usuario
            WHERE p.concepto = 'CONVENIO' AND P.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_aprobacion BETWEEN $9 AND $10
            GROUP BY p.id_banco_destino, b.nombre, tipo_transf
            ) x GROUP BY id_banco, banco, tipo_transf;
  `,
  GET_CASH_REPORT: `SELECT 'BS' as moneda, SUM(x.monto) AS monto FROM (
    SELECT SUM(p.monto) AS monto
    FROM pago p
    WHERE p.concepto IN ('IMPUESTO', 'CONVENIO', 'RETENCION') AND p.metodo_pago = 'EFECTIVO' AND p.fecha_de_pago BETWEEN $1 AND $2
    UNION
    SELECT SUM(p.monto) AS monto
    FROM (SELECT * FROM pago p 
            INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
            INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
            WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'EFECTIVO' AND p.fecha_de_aprobacion BETWEEN $1 AND $2) p
  ) x GROUP BY moneda;`,
  GET_CREDIT_REPORT: `SELECT sum(monto) as total FROM pago WHERE metodo_pago = 'CREDITO_FISCAL' AND fecha_de_pago BETWEEN $1 AND $2`,
  GET_CREDIT_INGRESS_BY_INTERVAL: `SELECT COALESCE(SUM(credito), 0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng" FROM impuesto.credito_fiscal WHERE credito > 0 AND importado != true AND fecha_creacion BETWEEN $1 AND $2;`,
  GET_RETENTION_CREDIT_INGRESS_BY_INTERVAL: `SELECT COALESCE(SUM(monto),0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng" FROM impuesto.retencion WHERE monto > 0 AND fecha BETWEEN $1 AND $2;`,
  GET_SM_IVA_SAGAS: `SELECT SUM(ingresado) AS ingresado, SUM("cantidadIng") as "cantidadIng"
  FROM (
  SELECT COALESCE(SUM(CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN ((monto * (0.16)) / 1.16 ) WHEN (l.datos->>'IVA')::numeric = 16 THEN ((monto * (0.04)) / 1.04 ) ELSE ((monto * (0.16)) / 1.16 ) END ),0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng"
  FROM (SELECT DISTINCT ON (l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto) l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos 
                  FROM impuesto.liquidacion l 
                  WHERE id_solicitud IS NOT NULL 
                  AND id_subramo = 107
                  AND id_solicitud IN (SELECT id_solicitud 
                                          FROM impuesto.solicitud 
                                          WHERE fecha_aprobado BETWEEN $1 AND $2
                                          AND tipo_solicitud != 'CONVENIO') ) l
  UNION ALL
  SELECT COALESCE(SUM(CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN ((f.monto * (0.16)) / 1.16 ) * 0.3 WHEN (l.datos->>'IVA')::numeric = 4 THEN ((f.monto * (0.04)) / 1.04 ) * 0.3 ELSE ((f.monto * (0.16)) / 1.16 ) * 0.3 END ),0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng"
  FROM (SELECT * FROM impuesto.fraccion WHERE fecha_aprobado BETWEEN $1 AND $2) f
        INNER JOIN impuesto.convenio USING (id_convenio)
        INNER JOIN impuesto.solicitud USING (id_solicitud)
        INNER JOIN (SELECT DISTINCT ON (id_solicitud) id_solicitud, id_subramo, id_liquidacion, monto, datos FROM impuesto.liquidacion WHERE id_subramo = 102 ) l USING (id_solicitud)
  ) X;`,
  GET_SM_BY_CODE: `SELECT * FROM impuesto.tarifa_aseo WHERE codigo = $1`,
  GET_SM_IVA_IMAU: `SELECT SUM(ingresado) AS ingresado, SUM("cantidadIng") as "cantidadIng"
      FROM (
      SELECT COALESCE(SUM(CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN ((monto * (0.16)) / 1.16 ) WHEN (l.datos->>'IVA')::numeric = 4 THEN ((monto * (0.04)) / 1.04 ) ELSE ((monto * (0.16)) / 1.16 ) END ),0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng"
        FROM (SELECT DISTINCT ON (l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto) l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos 
                        FROM impuesto.liquidacion l 
                        WHERE id_solicitud IS NOT NULL 
                        AND id_subramo = 108
                        AND id_solicitud IN (SELECT id_solicitud 
                                                FROM impuesto.solicitud 
                                                WHERE fecha_aprobado BETWEEN $1 AND $2
                                                AND tipo_solicitud != 'CONVENIO') ) l
      UNION ALL
      SELECT COALESCE(SUM(CASE WHEN (l.datos->>'IVA')::numeric = 16 THEN ((f.monto * (0.16)) / 1.16 ) * 0.7 WHEN (l.datos->>'IVA')::numeric = 4 THEN ((f.monto * (0.04)) / 1.04 ) * 0.7 ELSE ((f.monto * (0.16)) / 1.16 ) * 0.7 END ),0) AS ingresado, COALESCE(COUNT(*), 0) AS "cantidadIng"
      FROM (SELECT * FROM impuesto.fraccion WHERE fecha_aprobado BETWEEN $1 AND $2 ) f
            INNER JOIN impuesto.convenio USING (id_convenio)
            INNER JOIN impuesto.solicitud USING (id_solicitud)
            INNER JOIN (SELECT DISTINCT ON (id_solicitud) id_solicitud, id_subramo, id_liquidacion, monto, datos FROM impuesto.liquidacion  WHERE id_subramo = 102 ) l USING (id_solicitud)
      ) X;`,
  GET_POS: `SELECT SUM(monto) as total FROM (SELECT SUM(p.monto) as monto
        FROM pago p
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO', 'RETENCION') AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_aprobacion BETWEEN $1 AND $2
        UNION
        SELECT SUM(p.monto) as monto
        FROM (SELECT * FROM pago p 
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_aprobacion BETWEEN $3 AND $4) p) x;`,
  GET_CHECKS: `SELECT SUM(monto) AS total FROM (SELECT SUM(p.monto) as monto
        FROM pago p
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO', 'RETENCION') AND p.metodo_pago = 'CHEQUE' AND p.fecha_de_pago BETWEEN $1 AND $2
        UNION
        SELECT SUM(p.monto) as monto
        FROM (SELECT * FROM pago p 
        INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
        INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
        WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'CHEQUE' AND p.fecha_de_pago BETWEEN $1 AND $2) p) x;`,
  GET_SETTLEMENTS_REPORT: `WITH liqs AS (
          SELECT * FROM impuesto.liquidacion l WHERE l.fecha_liquidacion BETWEEN $1 AND $2
        )
        SELECT (c.tipo_documento || '-' || c.documento) AS "Documento", rm.referencia_municipal AS "RIM", c.razon_social AS "Razon Social", ae.descripcion AS "Actividad Economica",
        r.descripcion AS "Ramo", s.id AS "Planilla", l.fecha_liquidacion AS "Fecha Liquidacion", s.fecha AS "Fecha Recaudacion", 
        (CASE WHEN s.state = 'finalizado' THEN 'PAGADO' ELSE 'VIGENTE' END) AS "Estatus", COALESCE(l.monto, (l.monto_petro * (Select valor_en_bs from valor where descripcion = 'PETRO')), 0) as "Monto"
        FROM impuesto.contribuyente c 
        INNER JOIN impuesto.registro_municipal rm ON rm.id_contribuyente = c.id_contribuyente
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) * FROM impuesto.actividad_economica_sucursal aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia) ae ON ae.id_registro_municipal = rm.id_registro_municipal 
        INNER JOIN (SELECT * FROM liqs) l ON l.id_registro_municipal = rm.id_registro_municipal 
        INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        INNER JOIN impuesto.solicitud_state s ON s.id = l.id_solicitud 
        ORDER BY l.fecha_liquidacion, c.razon_social ASC`,
  GET_SETTLEMENT_REPORT_BY_BRANCH: `SELECT (c.tipo_documento || '-' || c.documento) AS "Documento", rm.referencia_municipal AS "RIM", c.razon_social AS "Razon Social", ae.descripcion AS "Actividad Economica",
  r.descripcion AS "Ramo", s.id AS "Planilla", l.fecha_liquidacion AS "Fecha Liquidacion", s.fecha AS "Fecha Recaudacion", 
  (CASE WHEN s.state = 'finalizado' THEN 'PAGADO' ELSE 'VIGENTE' END) AS "Estatus", COALESCE(l.monto, (l.monto_petro * (Select valor_en_bs from valor where descripcion = 'PETRO')), 0) as "Monto" 
  FROM impuesto.contribuyente c 
  INNER JOIN impuesto.registro_municipal rm ON rm.id_contribuyente = c.id_contribuyente 
  LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) * FROM impuesto.actividad_economica_sucursal aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia) ae ON ae.id_registro_municipal = rm.id_registro_municipal 
  INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal 
  INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo 
  INNER JOIN ( SELECT s.id_solicitud AS id,
      s.id_tipo_tramite AS tipotramite,
      s.aprobado,
      s.fecha,
      s.fecha_aprobado AS "fechaAprobacion",
      ev.state,
      s.tipo_solicitud AS "tipoSolicitud",
      s.id_contribuyente
  FROM impuesto.solicitud s
      JOIN ( SELECT es.id_solicitud,
              impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
          FROM impuesto.evento_solicitud es
          INNER JOIN (SELECT DISTINCT s.id_solicitud FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l USING (id_solicitud) WHERE l.fecha_liquidacion BETWEEN $1 AND $2) x ON x.id_solicitud = es.id_solicitud
          GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
  ) s ON s.id = l.id_solicitud WHERE l.fecha_liquidacion BETWEEN $1 AND $2 AND r.id_ramo = $3
  ORDER BY l.fecha_liquidacion ASC`,
  GET_IVA_REPORT: `WITH base AS (
    SELECT DISTINCT ON (l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto) l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos, l.fecha_liquidacion, 
                  (((l.datos#>'{desglose}')->0)->>'montoGas')::numeric AS base_impobible_gas, 
                  (((l.datos#>'{desglose}')->0)->>'montoGas')::numeric * (0.16) AS iva_gas,
                  CASE 
                    WHEN l.datos->>'esAgenteRetencion' = 'true' OR l.datos->>'esAgenteSENIAT' = 'true' THEN
                     (((l.datos#>'{desglose}')->0)->>'montoGas')::numeric * (0.12)
                    ELSE 0
                  END AS retencion_gas,
                  
                  
                   
                  (((l.datos#>'{desglose}')->0)->>'montoAseo')::numeric AS base_impobible_aseo,
                  (((l.datos#>'{desglose}')->0)->>'montoAseo')::numeric * (0.16) AS iva_aseo,
                  CASE 
                    WHEN l.datos->>'esAgenteRetencion' = 'true' OR l.datos->>'esAgenteSENIAT' = 'true' THEN
                     (((l.datos#>'{desglose}')->0)->>'montoAseo')::numeric * (0.12)
                    ELSE 0
                  END AS retencion_ASEO
                  
                  
                
                  FROM impuesto.liquidacion l 
                  WHERE id_solicitud IS NOT NULL 
                  AND id_subramo = 107
                  AND id_solicitud IN (SELECT id_solicitud 
                                          FROM impuesto.solicitud 
                                          WHERE fecha_aprobado BETWEEN $1::date AND $2::date
                                          AND tipo_solicitud != 'CONVENIO')
), x AS (
    SELECT id_liquidacion, id_solicitud, id_subramo, monto, datos, fecha_liquidacion,
        base_impobible_gas, iva_gas, retencion_gas, iva_gas - retencion_gas AS iva_gas_liquidado, base_impobible_gas + (iva_gas - retencion_gas) AS total_gas_liquidado,
        base_impobible_aseo, iva_aseo, retencion_aseo, iva_aseo - retencion_aseo AS iva_aseo_liquidado, base_impobible_aseo + (iva_aseo - retencion_aseo) AS total_aseo_liquidado
    FROM base
)
SELECT x.id_solicitud "Nro. Solicitud", x.fecha_liquidacion AS "Fecha", s.fecha_aprobado AS "Fecha Aprobaci??n", cont.razon_social AS "Raz??n social", base_impobible_gas "Base imponible gas", iva_gas "IVA gas", retencion_gas "Retencion gas", iva_gas_liquidado "IVA gas liquidado", total_gas_liquidado "Total gas liquidado",
        base_impobible_aseo "Base imponible aseo", iva_aseo "IVA Aseo", retencion_aseo "Retencion aseo", iva_aseo_liquidado "IVA Aseo liquidado", total_aseo_liquidado "Total aseo liquidado"
FROM x
INNER JOIN impuesto.solicitud s ON s.id_solicitud = x.id_solicitud
INNER JOIN impuesto.contribuyente cont ON cont.id_contribuyente = s.id_contribuyente
ORDER BY razon_social;`,
  GET_INGRESS_CONDO: `SELECT ramo, descripcion, codigo, SUM("cantidadIng") as "cantidadIng", SUM(ingresado) as ingresado FROM ( 
    (SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadIng", SUM(l.monto) as ingresado 
        FROM ((SELECT DISTINCT ON (l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto) l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto, l.datos, s.id_contribuyente
                FROM impuesto.liquidacion l 
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud
                WHERE l.id_solicitud IS NOT NULL 
                AND s.id_contribuyente IN (SELECT id_contribuyente FROM impuesto.condominio)
                AND l.id_solicitud IN (SELECT id_solicitud 
                                        FROM impuesto.solicitud 
                                        WHERE fecha_aprobado BETWEEN $1 AND $2
                                        AND tipo_solicitud != 'CONVENIO') )) l 
        LEFT JOIN (SELECT *, s.id_solicitud AS id_solicitud_q 
                        FROM impuesto.solicitud s 
                        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $1 AND $2) 
        se ON l.id_solicitud = se.id_solicitud_q
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
        ORDER BY ramo)
    UNION
    (SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadIng", SUM(f.monto) as ingresado 
      FROM (SELECT * FROM impuesto.fraccion WHERE fecha_aprobado BETWEEN $1 AND $2) f
      INNER JOIN impuesto.convenio USING (id_convenio)
      INNER JOIN impuesto.solicitud USING (id_solicitud)
      INNER JOIN (SELECT DISTINCT ON (id_solicitud) id_solicitud, id_subramo, id_liquidacion, datos FROM impuesto.liquidacion ) l USING (id_solicitud)
      FULL OUTER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
      LEFT JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
      WHERE solicitud.id_contribuyente IN (SELECT id_contribuyente FROM impuesto.condominio)
      GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
      ORDER BY ramo)) x
        WHERE codigo != '915' AND codigo IN ('3.01.03.54.00.000.00', '3.01.02.05.00.000.00')
        GROUP BY ramo, descripcion, codigo;`,
  GET_LIQUIDATED_CONDO: `SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, r.codigo, COUNT(l.id_liquidacion) as "cantidadLiq", SUM(CASE WHEN monto IS NOT NULL THEN monto ELSE (monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END) as liquidado 
  FROM (SELECT *, s.id_solicitud as idsoli  FROM impuesto.liquidacion l
          INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud 
          WHERE fecha_liquidacion BETWEEN $1 AND $2
          AND s.id_contribuyente IN (SELECT id_contribuyente FROM impuesto.condominio)) l 
  INNER JOIN (SELECT *, s.id_solicitud AS id_solicitud_q FROM impuesto.solicitud s 
                  INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
      AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) 
  se ON l.idsoli = se.id_solicitud_q
  RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
  INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo 
  WHERE codigo != '915' AND codigo IN ('3.01.03.54.00.000.00', '3.01.02.05.00.000.00')
  GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion
  ORDER BY ramo;`,
  GET_LIQUIDATED_CONDO_DISCLOSED: `SELECT CONCAT (data.tipo_documento,data.documento) AS Documento, data.razon_social AS RazonSocial, 
	(CASE WHEN data.aprobado = true THEN 'Solvente' ELSE 'Vigente' END) AS Estado,
	data.ramo AS Ramo, data.subRamo AS SubRamo, SUM (CASE WHEN data.monto IS NOT NULL THEN data.monto ELSE (data.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END) AS monto
    FROM (SELECT c.tipo_documento, c.documento, c.razon_social, r.descripcion as ramo, sub.descripcion as subramo,
	s.aprobado, l.monto, l.monto_petro FROM impuesto.condominio d INNER JOIN impuesto.contribuyente c 
		  ON d.id_contribuyente = c.id_contribuyente INNER JOIN impuesto.solicitud s 
		  ON d.id_contribuyente = s.id_contribuyente INNER JOIN impuesto.liquidacion l
		  ON s.id_solicitud = l.id_solicitud RIGHT JOIN impuesto.subramo sub 
		  ON sub.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo 
		  WHERE l.fecha_liquidacion BETWEEN $1 AND $2
       	GROUP BY c.tipo_documento, c.documento, c.razon_social, s.aprobado, l.monto, l.monto_petro, r.descripcion, sub.descripcion) as data 
       	GROUP BY data.tipo_documento, data.documento, data.razon_social, data.aprobado, data.ramo, data.subramo ORDER BY razon_social;
  `,
  GET_CPU_TIME_FUNCTIONARY: `SELECT t.codigo_tramite
  ,DATE_PART('day', t.fecha_culminacion - t.fecha_creacion) AS dia
  ,TO_CHAR(t.fecha_creacion, 'DD-MM-YYYY HH24:MI') AS tramite_fecha_creacion
  ,TO_CHAR(t.fecha_culminacion, 'DD-MM-YYYY HH24:MI') AS tramite_fecha_culminacion
  ,TO_CHAR(m.fecha_movimiento, 'DD-MM-YYYY HH24:MI') AS fecha_movimiento
  ,u.nombre_completo AS nombre_de_funcionario ,ca.descripcion AS cargo 
  ,m.tipo_movimiento
  FROM movimientos m
  INNER JOIN cuenta_funcionario cf ON m.id_usuario = cf.id_usuario
  INNER JOIN cargo ca ON ca.id_cargo = cf.id_cargo
  INNER JOIN tramite t ON t.id_tramite = m.id_procedimiento
  INNER JOIN usuario u ON u.id_usuario = m.id_usuario
  WHERE t.codigo_tramite LIKE '%CPU%' 
  AND t.fecha_creacion >= $1
  AND t.fecha_culminacion <= $2
  ORDER BY t.codigo_tramite, m.fecha_movimiento;`,
  GET_ALL_CASH_TOTAL: `SELECT metodo_pago, SUM(monto) AS total FROM pago 
    WHERE metodo_pago LIKE 'EFECTIVO%' AND TO_CHAR(fecha_de_aprobacion, 'YYYY/MM/DD') = $1
    GROUP BY metodo_pago;`,
  GET_ALL_TRANSFERS_DIFF_NOW_TOTAL: `SELECT b.nombre AS nombre_banco, p.referencia, TO_CHAR(p.fecha_de_pago,'YYYY/MM/DD') AS fecha, p.monto AS total,
    u.nombre_completo AS nombre_usuario
    FROM pago p
    JOIN banco b ON b.id_banco = p.id_banco_destino 
    JOIN usuario u ON u.id_usuario = p.id_usuario
    WHERE metodo_pago = 'TRANSFERENCIA' AND TO_CHAR(fecha_de_aprobacion, 'YYYY/MM/DD') = $1 AND TO_CHAR(fecha_de_pago, 'YYYY/MM/DD') <> $1
    AND u.id_tipo_usuario = 3
    ORDER BY p.id_banco_destino, fecha`,
  TOTAL_PAY_DIFF_CASH:`SELECT p.metodo_pago, 
    SUM(p.monto) AS total
    FROM pago p
    JOIN banco b ON b.id_banco = p.id_banco_destino 
    JOIN usuario u ON u.id_usuario = p.id_usuario
    WHERE metodo_pago NOT LIKE 'EFECTIVO%' AND metodo_pago <> 'CREDITO_FISCAL' AND TO_CHAR(fecha_de_aprobacion, 'YYYY/MM/DD') = $1
    AND u.id_tipo_usuario = 3
    GROUP BY  p.metodo_pago`,
  GET_ALL_PAY_DIFF_CASH_TOTAL: `SELECT p.id_banco_destino, b.nombre AS nombre_banco, p.metodo_pago, 
    SUM(p.monto) AS total
    FROM pago p
    JOIN banco b ON b.id_banco = p.id_banco_destino 
    JOIN usuario u ON u.id_usuario = p.id_usuario
    WHERE metodo_pago NOT LIKE 'EFECTIVO%' AND metodo_pago <> 'CREDITO_FISCAL' AND TO_CHAR(fecha_de_aprobacion, 'YYYY/MM/DD') = $1
    AND u.id_tipo_usuario = 3
    GROUP BY b.nombre, p.id_banco_destino, p.metodo_pago
    ORDER BY p.metodo_pago, p.id_banco_destino`,
  GET_ENTERED_DETAILED: `SELECT id_procedimiento, referencia, pago.monto AS monto_pagado, concepto, metodo_pago, impuesto.liquidacion.monto AS monto_liquidacion, banco.nombre AS banco, impuesto.ramo.descripcion AS ramo, usuario.nombre_completo AS usuario, (CASE WHEN usuario.id_tipo_usuario = 4 THEN 'Externo' ELSE 'Cajero' END) AS tipo_usuario 
    FROM pago JOIN impuesto.solicitud ON id_procedimiento = id_solicitud 
    JOIN impuesto.liquidacion USING(id_solicitud) 
    JOIN banco ON id_banco_destino = banco.id_banco 
    JOIN impuesto.subramo USING(id_subramo) 
    JOIN impuesto.ramo USING(id_ramo) 
    JOIN usuario ON pago.id_usuario = usuario.id_usuario 
    WHERE TO_CHAR(fecha_de_aprobacion,'YYYY/MM/DD') = $1 AND concepto = 'IMPUESTO'
    UNION ALL
    SELECT id_procedimiento, referencia, pago.monto AS monto_pagado, concepto, metodo_pago, impuesto.liquidacion.monto AS monto_liquidacion, banco.nombre AS banco, impuesto.ramo.descripcion AS ramo, usuario.nombre_completo AS usuario, (CASE WHEN usuario.id_tipo_usuario = 4 THEN 'Externo' ELSE 'Cajero' END) AS tipo_usuario
    FROM pago JOIN impuesto.solicitud ON id_procedimiento = id_solicitud 
    JOIN impuesto.liquidacion USING(id_solicitud) 
    JOIN banco ON id_banco_destino = banco.id_banco 
    JOIN impuesto.subramo USING(id_subramo) 
    JOIN impuesto.ramo USING(id_ramo) 
    JOIN usuario ON pago.id_usuario = usuario.id_usuario 
    WHERE TO_CHAR(fecha_de_aprobacion,'YYYY/MM/DD') = $1 AND concepto = 'TRAMITE';`,
  GET_TOTAL_ENTERED_DETAILED_BY_BRANCH:`WITH a AS (SELECT id_procedimiento, referencia, pago.monto AS monto_pagado, concepto, metodo_pago, impuesto.liquidacion.monto AS monto_liquidacion, banco.nombre AS banco, impuesto.ramo.descripcion AS ramo, usuario.nombre_completo AS usuario, (CASE WHEN usuario.id_tipo_usuario = 4 THEN 'Externo' ELSE 'Cajero' END) AS tipo_usuario 
    FROM pago JOIN impuesto.solicitud ON id_procedimiento = id_solicitud 
    JOIN impuesto.liquidacion USING(id_solicitud) 
    JOIN banco ON id_banco_destino = banco.id_banco 
    JOIN impuesto.subramo USING(id_subramo) 
    JOIN impuesto.ramo USING(id_ramo) 
    JOIN usuario ON pago.id_usuario = usuario.id_usuario 
    WHERE TO_CHAR(fecha_de_aprobacion,'YYYY/MM/DD') = $1 AND concepto = 'IMPUESTO'
    UNION ALL
    SELECT id_procedimiento, referencia, pago.monto AS monto_pagado, concepto, metodo_pago, impuesto.liquidacion.monto AS monto_liquidacion, banco.nombre AS banco, impuesto.ramo.descripcion AS ramo, usuario.nombre_completo AS usuario, (CASE WHEN usuario.id_tipo_usuario = 4 THEN 'Externo' ELSE 'Cajero' END) AS tipo_usuario
    FROM pago JOIN impuesto.solicitud ON id_procedimiento = id_solicitud 
    JOIN impuesto.liquidacion USING(id_solicitud) 
    JOIN banco ON id_banco_destino = banco.id_banco 
    JOIN impuesto.subramo USING(id_subramo) 
    JOIN impuesto.ramo USING(id_ramo) 
    JOIN usuario ON pago.id_usuario = usuario.id_usuario 
    WHERE TO_CHAR(fecha_de_aprobacion,'YYYY/MM/DD') = $1 AND concepto = 'TRAMITE')

    SELECT a.ramo, SUM(a.monto_pagado) AS monto_pagado, SUM(monto_liquidacion) AS monto_liquidacion FROM a GROUP BY ramo;`,
  //CIERRE DE CAJA
  GET_CASHIER_POS: `SELECT b.nombre as banco, SUM(p.monto) as monto, COUNT(*) as transacciones
        FROM pago p 
        INNER JOIN banco b ON b.id_banco = p.id_banco
        WHERE p.fecha_de_aprobacion::date = $1 AND p.metodo_pago = 'PUNTO DE VENTA' AND id_usuario = $2
        GROUP BY b.nombre;`,
  GET_CASHIER_CASH: `SELECT SUM(p.monto) as total, COUNT(*) as transacciones, p.metodo_pago
        FROM pago p 
        LEFT JOIN banco b ON b.id_banco = p.id_banco
        WHERE p.fecha_de_pago = $1 AND p.metodo_pago LIKE 'EFECTIVO%' AND id_usuario = $2;`,
GET_CASHIER_CASH_BROKEN_DOWN_BY_METHOD: `SELECT SUM(p.monto) as total, COUNT(*) AS transacciones, metodo_pago
FROM pago p 
LEFT JOIN banco b ON b.id_banco = p.id_banco
WHERE p.fecha_de_aprobacion BETWEEN $1 AND $3 AND p.metodo_pago LIKE 'EFECTIVO%' AND id_usuario = $2 GROUP BY metodo_pago;`,
  GET_CASHIER_CHECKS: `SELECT SUM(p.monto) as total, COUNT(*) as transacciones
        FROM pago p 
        INNER JOIN banco b ON b.id_banco = p.id_banco
        WHERE p.fecha_de_pago = $1 AND p.metodo_pago = 'CHEQUE' AND id_usuario = $2;`,
  GET_CASHIER_CREDIT: `SELECT SUM(p.monto) as total, COUNT(*) as transacciones
        FROM pago p 
        LEFT JOIN banco b ON b.id_banco = p.id_banco
        WHERE p.fecha_de_pago = $1 AND p.metodo_pago = 'CREDITO_FISCAL' AND id_usuario = $2;`,
  GET_CASHIER_TRANSFERS: `SELECT b.id_banco as id, b.nombre as banco, SUM(p.monto) as monto, COUNT(*) as transacciones
        FROM pago p 
        INNER JOIN banco b ON b.id_banco = p.id_banco_destino
        WHERE p.fecha_de_aprobacion::date = $1 AND p.metodo_pago = 'TRANSFERENCIA' AND id_usuario = $2
        GROUP BY b.id_banco, b.nombre;`,
  GET_ALL_CASHIERS_TOTAL: `SELECT u.nombre_completo, SUM(p.monto) AS monto
    FROM pago p INNER JOIN usuario u USING (id_usuario)
    WHERE p.fecha_de_pago = $1 AND u.id_tipo_usuario != 4
    GROUP BY u.nombre_completo;`,
  GET_ALL_CASHIERS_TOTAL_INT: `SELECT u.nombre_completo, SUM(p.monto) AS monto
  FROM pago p INNER JOIN usuario u USING (id_usuario)
  WHERE p.fecha_de_pago BETWEEN $1 AND $2 AND u.id_tipo_usuario != 4 AND u.id_usuario != 6915
  GROUP BY u.nombre_completo;`,
  GET_ALL_CASHIERS_METHODS_TOTAL: `SELECT p.metodo_pago AS tipo, SUM(p.monto) AS monto, COUNT(*) AS transacciones
    FROM pago p 
    WHERE p.fecha_de_pago = $1 AND p.id_usuario IS (SELECT id_usuario FROM usuario WHERE tipo_usuario != 4)
    GROUP BY p.metodo_pago;`,
  GET_ALL_CASHIERS_METHODS_TOTAL_NEW: `SELECT u.nombre_completo,
  p.fecha_de_pago,
  P.monto,
  p.referencia,
  p.metodo_pago,
  CASE concepto WHEN 'TRAMITE' THEN CONCAT('Pago de tramite - ', tt.nombre_tramite) WHEN 'IMPUESTO' THEN 'Pago de impuestos'  WHEN 'CONVENIO' THEN 'Pago de convenio'  ELSE 'Otro' END as concepto, 
  SUM(p.monto) OVER (PARTITION BY u.nombre_completo) AS sumcajero,
  SUM(p.monto) OVER (PARTITION BY u.nombre_completo, p.metodo_pago) AS summetodopagocajero
      FROM pago p 
      INNER JOIN usuario u USING (id_usuario)
      LEFT JOIN impuesto.solicitud s ON s.id_solicitud = p.id_procedimiento AND p.concepto = 'IMPUESTO'
      LEFT JOIN tramite t ON t.id_tramite = p.id_procedimiento AND p.concepto = 'TRAMITE'
      LEFT JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
      WHERE p.fecha_de_pago = $1 AND u.id_tipo_usuario != 4;`,
  GET_ALL_CASHIERS_METHODS_TOTAL_NEW_INT: `SELECT u.nombre_completo,
  p.fecha_de_pago,
  P.monto,
  p.referencia,
  p.metodo_pago,
  b.nombre as banco_destino,
  b2.nombre as banco_origen,
  CASE concepto WHEN 'TRAMITE' THEN CONCAT('Pago de tramite - ', tt.nombre_tramite) WHEN 'IMPUESTO' THEN 'Pago de impuestos'  WHEN 'CONVENIO' THEN 'Pago de convenio'  ELSE 'Otro' END as concepto, 
  SUM(p.monto) OVER (PARTITION BY u.nombre_completo) AS sumcajero,
  SUM(p.monto) OVER (PARTITION BY u.nombre_completo, p.metodo_pago) AS summetodopagocajero
      FROM pago p 
      INNER JOIN usuario u USING (id_usuario)
      LEFT JOIN banco b ON b.id_banco = p.id_banco_destino
      LEFT JOIN banco b2 ON b2.id_banco = p.id_banco
      LEFT JOIN impuesto.solicitud s ON s.id_solicitud = p.id_procedimiento AND p.concepto = 'IMPUESTO'
      LEFT JOIN tramite t ON t.id_tramite = p.id_procedimiento AND p.concepto = 'TRAMITE'
      LEFT JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite
      WHERE p.fecha_de_aprobacion::date BETWEEN $1::date AND $2::date AND u.id_tipo_usuario != 4 AND u.id_usuario != 6915`,
  //EXONERACIONES
  GET_CONTRIBUTOR:
    'SELECT c.id_contribuyente as id, razon_social AS "razonSocial", rm.denominacion_comercial AS "denominacionComercial", c.tipo_documento AS "tipoDocumento", c.documento, rm.id_registro_municipal AS "idRegistroMunicipal", rm.referencia_municipal AS "referenciaMunicipal" FROM impuesto.contribuyente c INNER JOIN impuesto.registro_municipal rm ON rm.id_contribuyente = c.id_contribuyente WHERE c.tipo_documento = $1 AND c.documento = $2 AND rm.referencia_municipal = $3;',
  GET_NATURAL_CONTRIBUTOR: 'SELECT c.id_contribuyente as id, razon_social AS "razonSocial", c.tipo_documento AS "tipoDocumento", c.documento FROM impuesto.contribuyente c WHERE c.tipo_documento = $1 AND c.documento = $2;',
  CREATE_EXONERATION: 'INSERT INTO impuesto.plazo_exoneracion (id_plazo_exoneracion, fecha_inicio) VALUES (default, $1) RETURNING *;',
  INSERT_CONTRIBUTOR_EXONERATED_ACTIVITY: `INSERT INTO impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_registro_municipal, id_actividad_economica)
                VALUES (default, $1, $2, $3);`,
  INSERT_EXONERATION_CONTRIBUTOR: 'INSERT INTO impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_registro_municipal) VALUES (default, $1, $2);',
  INSERT_EXONERATION_ACTIVITY: 'INSERT INTO impuesto.actividad_economica_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_actividad_economica) VALUES (default, $1, $2);',
  INSERT_EXONERATION_BRANCH: 'INSERT INTO impuesto.ramo_exoneracion (id_ramo_exoneracion, id_plazo_exoneracion, id_ramo) VALUES (default, $1, $2);',

  GET_EXONERATED_ACTIVITY_BY_CONTRIBUTOR:
    'SELECT * FROM impuesto.plazo_exoneracion pe \
    INNER JOIN impuesto.contribuyente_exoneracion ce ON ce.id_plazo_exoneracion = pe.id_plazo_exoneracion \
    WHERE id_registro_municipal = $1 AND id_actividad_economica = $2 AND fecha_inicio <= NOW() AND fecha_fin IS NULL',
  GET_EXONERATED_CONTRIBUTOR_STATUS:
    'SELECT * FROM impuesto.contribuyente_exoneracion ce INNER JOIN impuesto.plazo_exoneracion pe ON pe.id_plazo_exoneracion = ce.id_plazo_exoneracion \
    WHERE id_registro_municipal = $1 AND id_actividad_economica IS NULL AND fecha_fin IS NULL',
  GET_CONTRIBUTOR_HAS_ACTIVITY: 'SELECT * FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_sucursal aec ON aec.numero_referencia = ae.numero_referencia WHERE id_registro_municipal = $1 AND id_actividad_economica = $2',
  GET_CONTRIBUTOR_EXONERATIONS: `SELECT pe.*, ce.*, ae.*, c.*, rm.*, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND pe.fecha_fin)) AS active \
        FROM impuesto.plazo_exoneracion pe \
        INNER JOIN impuesto.contribuyente_exoneracion ce ON ce.id_plazo_exoneracion = pe.id_plazo_exoneracion \
        INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = ce.id_registro_municipal
        INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = rm.id_contribuyente \
        LEFT JOIN impuesto.actividad_economica ae ON ae.id_actividad_economica = ce.id_actividad_economica \
        WHERE c.tipo_documento = $1 AND c.documento = $2 AND rm.referencia_municipal = $3 ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_ACTIVITY_EXONERATIONS: `SELECT pe.*, ae.*, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.actividad_economica_exoneracion aee ON aee.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_ACTIVITY_IS_EXONERATED: `SELECT pe.id_plazo_exoneracion AS id, ae.descripcion, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active 
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.actividad_economica_exoneracion aee ON aee.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
        WHERE ae.id_actividad_economica = $1 AND (pe.fecha_fin IS NULL OR pe.fecha_fin > NOW()::DATE)
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_BRANCH_EXONERATIONS: `SELECT pe.*, r.*, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.ramo_exoneracion re ON re.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.ramo r ON r.id_ramo = re.id_ramo
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_BRANCH_IS_EXONERATED: `SELECT pe.id_plazo_exoneracion AS id, r.descripcion, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.ramo_exoneracion re ON re.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.ramo r ON re.id_ramo = r.id_ramo
        WHERE re.id_ramo = $1 AND ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin)))
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  UPDATE_EXONERATION_END_TIME: `UPDATE impuesto.plazo_exoneracion SET fecha_fin = $1 WHERE id_plazo_exoneracion = $2`,
  GET_SM_ACTIVITIES: `SELECT * FROM impuesto.tarifa_aseo`,
  GET_ALL_ACTIVITIES: 'SELECT id_actividad_economica AS id, numero_referencia AS codigo, descripcion, alicuota, minimo_tributable AS "minimoTributable" FROM impuesto.actividad_economica ORDER BY id_actividad_economica;',
  UPDATE_ALIQUOT_FOR_ACTIVITY: 'UPDATE impuesto.actividad_economica SET numero_referencia = $1, descripcion = $2, alicuota = $3, minimo_tributable = $4 WHERE id_actividad_economica = $5 RETURNING *',
  GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT: 'SELECT SUM(credito) as credito FROM impuesto.credito_fiscal WHERE id_persona = $1 AND concepto = $2',
  GET_ESTATES_FOR_JURIDICAL_CONTRIBUTOR:
    `SELECT DISTINCT ON(ai.id_inmueble) * FROM impuesto.avaluo_inmueble ai INNER JOIN inmueble_urbano iu ON ai.id_inmueble = iu.id_inmueble
     LEFT JOIN impuesto.contribuyente c ON c.id_contribuyente = iu.ocupado WHERE id_registro_municipal = $1 AND anio = EXTRACT("year" FROM CURRENT_DATE)`,
  GET_ESTATE_APPRAISAL_BY_ID_AND_YEAR: 'SELECT DISTINCT ON(ai.id_inmueble) * FROM impuesto.avaluo_inmueble ai WHERE id_inmueble = $1 AND anio = $2',
  GET_ESTATES_DATA_FOR_CONTRIBUTOR: 'SELECT * FROM inmueble_urbano WHERE id_registro_municipal = $1',
  ECONOMIC_ACTIVITY_IS_EXONERATED:
    'SELECT * FROM impuesto.actividad_economica_exoneracion INNER JOIN impuesto.plazo_exoneracion USING (id_plazo_exoneracion) WHERE id_actividad_economica = $1 AND fecha_inicio <= $2 AND (fecha_fin IS NULL OR fecha_fin >= now()::date)',
  BRANCH_IS_EXONERATED:
    'SELECT * FROM impuesto.ramo_exoneracion INNER JOIN impuesto.plazo_exoneracion USING (id_plazo_exoneracion) WHERE id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1) AND fecha_inicio <= $2 AND (fecha_fin IS NULL OR fecha_fin >= now()::date)',
  CONTRIBUTOR_IS_EXONERATED:
    'SELECT * FROM impuesto.contribuyente_exoneracion INNER JOIN impuesto.plazo_exoneracion USING (id_plazo_exoneracion) WHERE id_registro_municipal = $1 AND id_actividad_economica IS NULL AND fecha_inicio <= $2 AND (fecha_fin IS NULL OR fecha_fin >= $2)',
  CONTRIBUTOR_ECONOMIC_ACTIVIES_IS_EXONERATED:
    'SELECT * FROM impuesto.contribuyente_exoneracion INNER JOIN impuesto.plazo_exoneracion USING (id_plazo_exoneracion) WHERE id_registro_municipal = $1 AND id_actividad_economica = $2 AND fecha_inicio <= $3 AND (fecha_fin IS NULL OR fecha_fin >= now()::date)',
  MUNICIPAL_SERVICE_BY_ACTIVITIES_IS_EXONERATED: `WITH actividades AS (
  SELECT COUNT(*) FROM impuesto.registro_municipal rm 
  INNER JOIN impuesto.actividad_economica_sucursal aec ON aec.id_registro_municipal = rm.id_registro_municipal 
  INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia WHERE 
  rm.id_registro_municipal = $1) 
  
  SELECT COUNT(*) = (SELECT * FROM actividades) AS exonerado FROM (SELECT aee.id_plazo_exoneracion FROM impuesto.registro_municipal rm 
  INNER JOIN impuesto.actividad_economica_sucursal aec ON aec.id_registro_municipal = rm.id_registro_municipal 
  INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia 
  LEFT JOIN impuesto.actividad_economica_exoneracion aee ON aee.id_actividad_economica = ae.id_actividad_economica 
  LEFT JOIN impuesto.plazo_exoneracion pe ON pe.id_plazo_exoneracion = aee.id_plazo_exoneracion 
  WHERE rm.id_registro_municipal = $1 AND pe.fecha_inicio <= $2 AND (fecha_fin IS NULL OR fecha_fin >= now()::date OR fecha_fin >= $3)) t
  WHERE (t IS NOT NULL);`,
  UPDATE_SETTLEMENT_CORRECTION: 'UPDATE impuesto.liquidacion SET fecha_liquidacion = $1, fecha_vencimiento = $2, datos = $3, id_subramo = $4, id_solicitud = $5 WHERE id_liquidacion = $6 RETURNING *',
  DELETE_SETTLEMENT: 'DELETE FROM impuesto.liquidacion WHERE id_liquidacion = $1',
  RECORD_NULLIFIED_SETTLEMENT: `INSERT INTO impuesto.liquidacion_anulado (SELECT *, $2 AS observaciones, NOW() - interval '4 hours' AS fecha_anulado FROM impuesto.liquidacion WHERE id_liquidacion = $1)`,
  RECORD_NULLIFIED_PAYMENT: `INSERT INTO pago_anulado (SELECT *, $2 AS observaciones, NOW() - interval '4 hours' AS fecha_anulado FROM pago WHERE id_procedimiento = $1 AND concepto = $3)`,
  // RECORD_NULLIFIED_APPLICATION_PAYMENT: `INSERT INTO pago_anulado (SELECT *, $2 AS observaciones, NOW() - interval '4 hours' AS fecha_anulado FROM pago WHERE id_procedimiento = $1 AND concepto = 'IMPUESTO')`,
  ADD_ORIGINAL_APPLICATION_ID_IN_PATCH_APPLICATION: 'UPDATE impuesto.solicitud SET id_solicitud_original = $1 WHERE id_solicitud = $2',
  GET_LAST_AE_SETTLEMENT_BY_AE_ID: 'SELECT * FROM impuesto.get_last_settlement_by_ae($1, $2)',
  GET_LAST_AE_SETTLEMENT_BY_AE_ID_2: 'SELECT * FROM impuesto.get_last_settlement_by_ae_2($1, $2)',
  GET_SETTLEMENT_BY_ID: 'SELECT * FROM impuesto.liquidacion WHERE id_liquidacion = $1',
  GET_PATCH_APPLICATION_BY_ORIGINAL_ID_AND_STATE: `
      
    WITH solicitud_cte AS (
      SELECT * FROM impuesto.solicitud WHERE id_solicitud_original = $1
    )
    SELECT s.*, ss.state FROM impuesto.solicitud s 
    INNER JOIN (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
      FROM solicitud_cte s
        JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
              FROM impuesto.evento_solicitud es
              WHERE id_solicitud IN (SELECT id_solicitud FROM solicitud_cte)
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) ss ON s.id_solicitud = ss.id 
    WHERE s.id_solicitud_original = $1 AND ss.state = $2
`,
  GET_LAST_IU_SETTLEMENT_BY_ESTATE_ID: 'SELECT * FROM impuesto.get_last_settlement_by_estate_2($1, $2)',
  GET_LAST_IU_SETTLEMENT_BY_ESTATE_ID_NATURAL: 'SELECT * FROM impuesto.get_last_settlement_by_estate_natural_2($1, $2)',
  GET_ESTATE_BY_ID: 'SELECT * FROM inmueble_urbano INNER JOIN parroquia ON parroquia.id = inmueble_urbano.id_parroquia WHERE id_inmueble = $1',
  GET_BRANCHES_BY_CONTRIBUTOR_ID: 'SELECT * FROM impuesto.registro_municipal WHERE id_contribuyente = $1',
  GET_ECONOMIC_ACTIVITY_BY_RIM:
    'SELECT ae.id_actividad_economica as id, ae.numero_referencia as codigo, ae.descripcion, ae.alicuota, ae.minimo_tributable as "minimoTributable", aes.aplicable_desde as desde FROM impuesto.actividad_economica_sucursal aes INNER JOIN impuesto.actividad_economica ae USING (numero_referencia) WHERE id_registro_municipal = $1',
  GET_ESTATES_FOR_NATURAL_CONTRIBUTOR:
    `SELECT DISTINCT ON (ai.id_inmueble) ai.*,iu.*,c.* FROM impuesto.avaluo_inmueble ai INNER JOIN inmueble_urbano iu ON ai.id_inmueble = iu.id_inmueble INNER JOIN impuesto.inmueble_contribuyente icn ON iu.id_inmueble = icn.id_inmueble
    LEFT JOIN impuesto.contribuyente c ON c.id_contribuyente = iu.ocupado WHERE icn.id_contribuyente = $1 AND anio = EXTRACT("year" FROM CURRENT_DATE)`,
  // GET_AE_CLEANING_TARIFF: 'SELECT get_aseo AS monto FROM impuesto.get_aseo($1)',
  GET_AE_CLEANING_TARIFF: `SELECT tarifa FROM impuesto.tarifa_aseo JOIN impuesto.tarifa_aseo_sucursal USING(id_tarifa_aseo) WHERE id_registro_municipal = $1`,
  DELETE_SETTLEMENTS_BY_BRANCH_CODE_AND_RIM: 'DELETE FROM impuesto.liquidacion WHERE id_subramo IN (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1)) AND id_registro_municipal = $2',
  NULLIFY_SETTLEMENT_CONSTRAINT_BY_BRANCH_AND_RIM: `UPDATE impuesto.liquidacion SET id_registro_municipal = null WHERE id_liquidacion IN (SELECT id_liquidacion FROM impuesto.liquidacion WHERE id_subramo IN (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1)) AND id_registro_municipal = $2)`,
  NULLIFY_APPLICATION_CONSTRAINT_BY_BRANCH_AND_RIM: `UPDATE impuesto.solicitud SET id_usuario = null, id_contribuyente = null WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.liquidacion WHERE id_subramo IN (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE codigo = $1)) AND id_registro_municipal = $2)`,
  GET_RESIDENTIAL_CLEANING_TARIFF: 'SELECT * FROM impuesto.tabulador_aseo_residencial WHERE fecha_hasta IS NULL;',
  GET_AE_GAS_TARIFF: 'SELECT get_gas AS monto FROM impuesto.get_gas($1)',
  GET_RESIDENTIAL_GAS_TARIFF: 'SELECT * FROM impuesto.tabulador_gas_residencial WHERE fecha_hasta IS NULL;',
  GET_PUBLICITY_CATEGORIES: 'SELECT * FROM impuesto.categoria_propaganda',
  GET_PUBLICITY_SUBCATEGORIES: 'SELECT * FROM impuesto.tipo_aviso_propaganda',
  GET_PUBLICITY: "SELECT id_tipo_aviso_propaganda, concat(cp.descripcion, ' - ', tap.descripcion) AS descripcion FROM impuesto.categoria_propaganda cp INNER JOIN impuesto.tipo_aviso_propaganda tap USING (id_categoria_propaganda);",
  INSERT_ESTATE_VALUE: `INSERT INTO impuesto.avaluo_inmueble (id_inmueble, avaluo_terreno, avaluo_construccion, anio) VALUES ($1,$2, $3, EXTRACT(year FROM NOW() - interval'4 hours'))`,
  CHECK_IF_HAS_COMMERCIAL_ESTATES: `SELECT COUNT(*) as commercials FROM inmueble_urbano WHERE id_registro_municipal = $1 AND tipo_inmueble = 'COMERCIAL';`,
  COUNT_ESTATES: `SELECT COUNT(*) as allestates FROM inmueble_urbano WHERE id_registro_municipal = $1;`,
  SET_DATE_FOR_LINKED_APPROVED_APPLICATION: 'UPDATE impuesto.solicitud SET fecha = $1, fecha_aprobado = $1 WHERE id_solicitud = $2',
  SET_DATE_FOR_LINKED_ACTIVE_APPLICATION: 'UPDATE impuesto.solicitud SET fecha = $1 WHERE id_solicitud = $2',
  LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR: 'INSERT INTO impuesto.inmueble_contribuyente (id_inmueble, id_contribuyente) VALUES ($1, $2) RETURNING *',
  LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR_EX: 'INSERT INTO impuesto.inmueble_contribuyente (id_inmueble, id_contribuyente, relacion) VALUES ($1, $2, $3) RETURNING *',
  UNLINK_ESTATE_WITH_NATURAL_CONTRIBUTOR: 'DELETE FROM impuesto.inmueble_contribuyente WHERE id_inmueble = $1 AND id_contribuyente = $2',
  GET_AGREEMENT_FRACTION_BY_ID: 'SELECT * FROM impuesto.fraccion WHERE id_fraccion = $1',
  GET_AGREEMENT_FRACTION_STATE: 'SELECT state FROM impuesto.fraccion_state WHERE id = $1',
  GET_AGREEMENTS_BY_USER: 'SELECT * FROM impuesto.convenio c INNER JOIN impuesto.solicitud s ON c.id_solicitud = s.id_solicitud WHERE s.id_usuario = $1 ORDER BY s.fecha DESC',
  GET_AGREEMENTS_BY_RIM:
    "SELECT DISTINCT ON (id_solicitud, s.fecha) * FROM impuesto.convenio INNER JOIN impuesto.solicitud s USING (id_solicitud) INNER JOIN impuesto.liquidacion USING (id_solicitud) WHERE id_registro_municipal = $1 AND tipo_solicitud = 'CONVENIO' ORDER BY s.fecha DESC",
  GET_FRACTIONS_BY_AGREEMENT_ID: 'SELECT * FROM impuesto.fraccion f WHERE f.id_convenio = $1',
  APPLICATION_TOTAL_AMOUNT_BY_ID: 'SELECT SUM(monto) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1',
  APPLICATION_TOTAL_PETRO_AMOUNT_BY_ID: 'SELECT SUM(monto_petro) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1',
  GET_SETTLEMENTS_BY_MONTH_IN_GROUPED_BRANCH: `WITH liqsServ AS (
    SELECT *, r.descripcion AS "descripcionRamo", sr.descripcion AS "descripcionSubramo" FROM impuesto.liquidacion l 
INNER JOIN impuesto.subramo sr USING (id_subramo) 
INNER JOIN impuesto.ramo r USING (id_ramo) 

WHERE id_subramo IN 
  (select unnest($1::int[])) 
  AND l.monto > 0 
  AND EXTRACT('month' FROM l.fecha_liquidacion) = EXTRACT('month' FROM $2::date) 
  AND EXTRACT('year' FROM l.fecha_liquidacion) = EXTRACT('year' FROM $2::date) 
ORDER BY l.fecha_liquidacion DESC
)

SELECT * FROM liqsServ l INNER JOIN (SELECT s.id_solicitud AS id,
  s.id_contribuyente,
  ev.state
 FROM impuesto.solicitud s
   JOIN ( SELECT es.id_solicitud,
          impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
         FROM impuesto.evento_solicitud es
         WHERE id_solicitud IN ((SELECT id_solicitud FROM liqsServ))
        GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud) s ON l.id_solicitud = s.id`,
  GET_APPLICATION_STATE: `SELECT s.id_solicitud AS id,
  ev.state
 FROM impuesto.solicitud s
   JOIN ( SELECT es.id_solicitud,
          impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
         FROM impuesto.evento_solicitud es
         WHERE id_solicitud = $1
        GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud;`,
  GET_CONTRIBUTOR_BY_ID: 'SELECT * FROM impuesto.contribuyente WHERE id_contribuyente = $1',
  GET_SETTLEMENTS_FOR_CONTRIBUTOR_SEARCH: `WITH solicitudcte AS (
    SELECT id_solicitud
    FROM impuesto.solicitud 
    WHERE id_contribuyente = $1

)

SELECT *,
        s.descripcion AS "descripcionSubramo",
         r.descripcion AS "descripcionRamo"
FROM (SELECT s.id_solicitud AS id,
    s.id_tipo_tramite AS tipotramite,
    s.aprobado,
    s.fecha,
    s.fecha_aprobado AS "fechaAprobacion",
    ev.state,
    s.tipo_solicitud AS "tipoSolicitud",
    s.id_contribuyente
   FROM impuesto.solicitud s
     JOIN ( SELECT es.id_solicitud,
            impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
           FROM impuesto.evento_solicitud es
           WHERE id_solicitud IN (SELECT * FROM solicitudcte)
          GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
) sl
INNER JOIN impuesto.liquidacion l
    ON sl.id = l.id_solicitud
LEFT JOIN impuesto.subramo s
USING (id_subramo)
LEFT JOIN impuesto.ramo r
USING (id_ramo)
WHERE sl.id_contribuyente= $1
ORDER BY fecha_liquidacion DESC;
`,
  GET_SETTLEMENTS_FOR_BRANCH_SEARCH: `WITH solicitudcte AS (
  SELECT id_solicitud
  FROM impuesto.solicitud 
  WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1)
  
  )
  
  SELECT id_ramo, id_subramo, id, "tipotramite", aprobado, fecha, "fechaAprobacion", state, "tipoSolicitud", id_contribuyente, id_liquidacion, id_solicitud, l.monto, certificado, recibo, fecha_liquidacion, datos, fecha_vencimiento, id_registro_municipal, remitido, monto_petro, subindice, r.descripcion, codigo, s.descripcion, descripcion_corta, liquidacion_especial,
  s.descripcion AS "descripcionSubramo",
  r.descripcion AS "descripcionRamo"
  FROM (SELECT s.id_solicitud AS id,
    s.id_tipo_tramite AS tipotramite,
    s.aprobado,
    s.fecha,
    s.fecha_aprobado AS "fechaAprobacion",
    ev.state,
    s.tipo_solicitud AS "tipoSolicitud",
    s.id_contribuyente
    FROM impuesto.solicitud s
    JOIN ( SELECT es.id_solicitud,
      impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
      FROM impuesto.evento_solicitud es
      WHERE id_solicitud IN (SELECT * FROM solicitudcte)
      GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
      ) sl
      INNER JOIN impuesto.liquidacion l
      ON sl.id = l.id_solicitud
      LEFT JOIN impuesto.subramo s
      USING (id_subramo)
      LEFT JOIN impuesto.ramo r
      USING (id_ramo)
      WHERE l.id_registro_municipal= $1
      ORDER BY fecha_liquidacion DESC;
      `,
  SET_DATE_FOR_LINKED_SETTLEMENT: 'UPDATE impuesto.liquidacion SET fecha_liquidacion = $1 WHERE id_liquidacion = $2',
  ASSIGN_CONTRIBUTOR_TO_USER: 'UPDATE USUARIO SET id_contribuyente = $1 WHERE id_usuario = $2',
  GET_CONTRIBUTOR_BY_USER: 'SELECT c.* FROM USUARIO u INNER JOIN impuesto.contribuyente c ON u.id_contribuyente = c.id_contribuyente WHERE u.id_usuario = $1',
  GET_FRACTION_BY_AGREEMENT_AND_FRACTION_ID: 'SELECT * FROM impuesto.fraccion WHERE id_convenio = $1 AND id_fraccion = $2',
  UPDATE_FRACTION_STATE: 'SELECT * FROM impuesto.update_fraccion_state ($1, $2)',
  COMPLETE_FRACTION_STATE: 'SELECT * FROM impuesto.complete_fraccion_state ($1, $2, true)',
  SEARCH_CONTRIBUTOR_BY_NAME: 'SELECT * FROM impuesto.contribuyente WHERE razon_social ILIKE $1',
  GET_CONTRIBUTOR_WITH_BRANCH: 'SELECT * FROM impuesto.registro_municipal r INNER JOIN impuesto.contribuyente c ON r.id_contribuyente = c.id_contribuyente WHERE r.referencia_municipal = $1',
  CHANGE_SETTLEMENT_TO_NEW_APPLICATION: `UPDATE impuesto.liquidacion SET id_solicitud = $1 
    WHERE id_registro_municipal = $2 AND id_subramo 
    IN (SELECT id_subramo FROM impuesto.subramo WHERE descripcion != 'Convenio de Pago' AND id_ramo = $3) 
    AND id_liquidacion 
    IN (SELECT id_liquidacion FROM impuesto.liquidacion l 
      INNER JOIN (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
       FROM impuesto.solicitud s
         JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
               FROM impuesto.evento_solicitud es
               WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1))
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    ) ss  
      ON ss.id = l.id_solicitud  
      WHERE ss.state = 'ingresardatos');`,
  GET_SETTLEMENT_IDS_BY_RIM_AND_BRANCH: `
  SELECT l.* FROM impuesto.liquidacion l INNER JOIN 
  (SELECT s.id_solicitud AS id,
          s.id_tipo_tramite AS tipotramite,
          s.aprobado,
          s.fecha,
          s.fecha_aprobado AS "fechaAprobacion",
          ev.state,
          s.tipo_solicitud AS "tipoSolicitud",
          s.id_contribuyente
         FROM impuesto.solicitud s
           JOIN ( SELECT es.id_solicitud,
                  impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
                 FROM impuesto.evento_solicitud es
                 WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1 LIMIT 1))
                GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
      ) ss  ON ss.id = l.id_solicitud 
  WHERE ss.state = 'ingresardatos' AND id_registro_municipal = $1 AND
   id_subramo IN (SELECT id_subramo FROM impuesto.subramo WHERE descripcion !='Convenio de Pago' AND id_ramo = $2);`, //A??O DE LA LIQUIDACI??N MODIFICADO PARA QUE NO MODIFIQUE LAS DE 2022, CAMBIO HECHO EL 09/03/2022
  INSERT_DISCOUNT_FOR_SETTLEMENT: 'INSERT INTO impuesto.liquidacion_descuento (id_liquidacion, porcentaje_descuento) VALUES ($1, $2)',
  CREATE_AGREEMENT: 'INSERT INTO impuesto.convenio (id_solicitud, cantidad) VALUES ($1, $2) RETURNING *',
  CREATE_AGREEMENT_FRACTION: 'SELECT * FROM impuesto.insert_fraccion($1, $2, $3, $4)',
  UPDATE_SETTLEMENT_AMOUNT_AND_DATA: `UPDATE impuesto.liquidacion SET datos = $1, monto_petro = $2 WHERE id_liquidacion = $3 RETURNING *`,
  GET_ACTIVE_AE_SETTLEMENTS_FOR_COMPLEMENTATION: `SELECT l.*, s.state as estado FROM impuesto.liquidacion l 
  INNER JOIN (SELECT s.id_solicitud AS id,
  s.id_tipo_tramite AS tipotramite,
  s.aprobado,
  s.fecha,
  s.fecha_aprobado AS "fechaAprobacion",
  ev.state,
  s.tipo_solicitud AS "tipoSolicitud",
  s.id_contribuyente
 FROM impuesto.solicitud s
   JOIN ( SELECT es.id_solicitud,
          impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
         FROM impuesto.evento_solicitud es
         WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1 LIMIT 1))
        GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
) s ON l.id_solicitud = s.id
  WHERE l.id_registro_municipal = $1 AND id_subramo = 10 AND (state ='ingresardatos' OR state='finalizado')`,
  GET_ACTIVE_AE_SETTLEMENTS_FOR_SUSTITUTION: `SELECT l.*, s.state as estado FROM impuesto.liquidacion l 
  INNER JOIN (SELECT s.id_solicitud AS id,
  s.id_tipo_tramite AS tipotramite,
  s.aprobado,
  s.fecha,
  s.fecha_aprobado AS "fechaAprobacion",
  ev.state,
  s.tipo_solicitud AS "tipoSolicitud",
  s.id_contribuyente
 FROM impuesto.solicitud s
   JOIN ( SELECT es.id_solicitud,
          impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
         FROM impuesto.evento_solicitud es
         WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $1 LIMIT 1))
        GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
) s ON l.id_solicitud = s.id
  WHERE l.id_registro_municipal = $1 AND id_subramo = 10 AND state ='ingresardatos'`,
  CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT: "UPDATE impuesto.liquidacion SET id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = $1 AND descripcion = 'Convenio de Pago') WHERE id_solicitud = $2 RETURNING *",
  CONTRIBUTOR_HAS_ACTIVE_AGREEMENT_PROCEDURE: `SELECT * FROM tramites_state_with_resources WHERE tipotramite = 26 
  AND datos #>> '{funcionario, contribuyente,tipoDocumento}' = $1 
  AND datos #>> '{funcionario, contribuyente,documento}' = $2 
  AND datos #>> '{funcionario, contribuyente,registroMunicipal}' = $3
  AND state = 'enrevision';`,
  SET_SETTLEMENTS_AS_FORWARDED_BY_RIM: `UPDATE impuesto.liquidacion SET remitido = true WHERE id_registro_municipal = $1 AND id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE subindice = '1' AND id_ramo = $2) AND id_liquidacion IN (SELECT id_liquidacion FROM impuesto.liquidacion l 
      INNER JOIN (SELECT s.id_solicitud AS id,
        s.id_tipo_tramite AS tipotramite,
        s.aprobado,
        s.fecha,
        s.fecha_aprobado AS "fechaAprobacion",
        ev.state,
        s.tipo_solicitud AS "tipoSolicitud",
        s.id_contribuyente
       FROM impuesto.solicitud s
         JOIN ( SELECT es.id_solicitud,
                impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state
               FROM impuesto.evento_solicitud es
               WHERE id_solicitud IN (SELECT id_solicitud FROM impuesto.solicitud WHERE id_contribuyente = (SELECT id_contribuyente FROM impuesto.registro_municipal WHERE id_registro_municipal = $2 LIMIT 1))
              GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud
    ) ss ON ss.id_liquidacion = l.id_liquidacion)`,
  GET_USER_BY_APPLICATION_AND_RIM: 'SELECT id_usuario FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud WHERE l.id_registro_municipal = $1',
  ADD_VERIFIED_CONTRIBUTOR: "INSERT INTO impuesto.verificacion_telefono (fecha_verificacion, verificado, id_usuario) VALUES ((NOW() - interval '4 hours'), true, $1) RETURNING *",
  GET_USER_IN_CHARGE_OF_BRANCH:
    'SELECT vt.id_usuario as id FROM impuesto.verificacion_telefono vt INNER JOIN impuesto.registro_municipal_verificacion rmv USING (id_verificacion_telefono)\
     INNER JOIN impuesto.registro_municipal rm USING (id_registro_municipal) INNER JOIN impuesto.contribuyente c USING (id_contribuyente) WHERE\
      rm.referencia_municipal = $1 AND c.tipo_documento = $2 AND c.documento = $3',
  GET_USER_IN_CHARGE_OF_BRANCH_BY_ID:
    'SELECT vt.id_usuario as id FROM impuesto.verificacion_telefono vt INNER JOIN impuesto.registro_municipal_verificacion rmv USING (id_verificacion_telefono)\
       INNER JOIN impuesto.registro_municipal rm USING (id_registro_municipal) INNER JOIN impuesto.contribuyente c USING (id_contribuyente) WHERE\
        rm.id_registro_municipal = $1',
  CREATE_OR_UPDATE_FISCAL_CREDIT: 'SELECT * FROM impuesto.insert_credito($1, $2, $3, $4, $5)',
  BRANCH_IS_ONE_BEST_PAYERS: `SELECT * FROM impuesto.liquidacion WHERE id_registro_municipal = $1 AND id_registro_municipal IN (
    SELECT id_registro_municipal FROM (SELECT id_registro_municipal, SUM(monto) AS monto 
    FROM Impuesto.liquidacion
    WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $2 AND datos#>>'{fecha,year}' = $3
    GROUP BY id_registro_municipal 
    ORDER BY monto DESC
    LIMIT 1000) s)`,
  ADD_BRANCH_FOR_CONTRIBUTOR:
    "INSERT INTO impuesto.registro_municipal (id_contribuyente, fecha_aprobacion, telefono_celular, email, denominacion_comercial, nombre_representante, actualizado, capital_suscrito, tipo_sociedad, estado_licencia, direccion, id_parroquia, es_monotributo, objeto, monto_timbre, fecha_timbre, banco_timbre) VALUES ($1, (NOW() - interval '4 hours'), $2, $3, $4, $5, true, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) RETURNING *",
  UPDATE_BRANCH_INFO: 'UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4, actualizado = $5, direccion = $6 WHERE referencia_municipal = $7 RETURNING *',
  UPDATE_LICENSE_STATUS: 'UPDATE impuesto.registro_municipal SET estado_licencia = $1 WHERE id_registro_municipal = $2',
  UPDATE_ECONOMIC_ACTIVITIES_FOR_BRANCH:
    'INSERT INTO impuesto.actividad_economica_sucursal AS aes (id_registro_municipal, numero_referencia, aplicable_desde) VALUES ($1, $2, $3) ON CONFLICT (id_registro_municipal, numero_referencia) DO UPDATE SET aplicable_desde = EXCLUDED.aplicable_desde returning *, xmax::text::int > 0 AS updated;',
  UPDATE_MUNICIPAL_SERVICES_FOR_BRANCH:
    'INSERT INTO impuesto.tarifa_aseo_sucursal AS sm (id_tarifa_aseo, id_registro_municipal, aplicable_desde) VALUES ($1, $2, $3) ON CONFLICT (id_registro_municipal, id_tarifa_aseo) DO UPDATE SET aplicable_desde = EXCLUDED.aplicable_desde returning *, xmax::text::int > 0 AS updated;',
  GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR:
    'SELECT ae.id_actividad_economica AS id, ae.numero_referencia as "numeroReferencia", ae.descripcion, ae.alicuota, ae.minimo_tributable AS "minimoTributable" \
    FROM impuesto.actividad_economica_sucursal aec \
    INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia WHERE id_registro_municipal = $1;',
  MODIFY_BRANCH_REFERENCE: `UPDATE impuesto.registro_municipal SET referencia_municipal = $1 WHERE id_registro_municipal = $2`,
  BRANCH_EXISTS: `SELECT * FROM impuesto.registro_municipal WHERE referencia_municipal = $1`,
  GET_BRANCHES: `SELECT id_ramo AS id, codigo, descripcion, descripcion_corta, liquidacion_especial AS "liquidacionEspecial", ROUND(monto * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'), 2) AS "monto" FROM impuesto.ramo;`,
  GET_BRANCHES_BY_ROL: `SELECT id_ramo AS id, codigo, descripcion, descripcion_corta, liquidacion_especial AS "liquidacionEspecial", ROUND(monto * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'), 2) AS "monto" FROM impuesto.ramo JOIN ramo_cargo USING(id_ramo) WHERE id_cargo = $1;`,
  GET_SUBRANCHES_BY_ID: `SELECT id_subramo AS id, descripcion, subindice, (monto * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) AS "monto" FROM impuesto.subramo WHERE id_ramo = $1`,
  GET_BRANCHES_FOR_REPORT: 'SELECT id_ramo AS id, codigo AS "ramo", descripcion, descripcion_corta FROM impuesto.ramo;',
  GET_SUT_ESTATE_BY_ID: 'SELECT * FROM inmueble_urbano WHERE id_inmueble = $1',
  IS_SPECIAL_SETTLEMENT: 'SELECT * FROM impuesto.ramo WHERE codigo = (SELECT codigo FROM impuesto.ramo WHERE id_ramo=$1) AND codigo IN (SELECT codigo FROM impuesto.ramo WHERE liquidacion_especial = true);',
  GET_RIM_DATA: `SELECT id_registro_municipal AS id, referencia_municipal as "rim", telefono_celular AS "telefonoCelular", 
    telefono_habitacion AS "telefonoHabitacion", email, denominacion_comercial AS "denominacionComercial", nombre_representante AS "nombreRepresentante"
    FROM impuesto.registro_municipal WHERE referencia_municipal = $1`,
  GET_ESTATES_BY_RIM: `SELECT id_inmueble AS id, id_liquidacion_fecha_inicio, dir_doc AS "dirDoc", cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", relacion_contribuyente AS relacion, clasificacion FROM inmueble_urbano WHERE id_registro_municipal = (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $1 ORDER BY id_registro_municipal DESC LIMIT 1);`,
  GET_ESTATES_BY_NATURAL_CONTRIBUTOR: `SELECT id_inmueble AS id, id_liquidacion_fecha_inicio as id_liquidacion, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", icn.relacion AS relacion, dir_doc AS "dirDoc", clasificacion 
    FROM inmueble_urbano iu INNER JOIN impuesto.inmueble_contribuyente icn USING (id_inmueble)
    WHERE id_contribuyente = $1`,
  GET_ESTATES_BY_USER_INFO: `SELECT id_inmueble AS id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", dir_doc AS "dirDoc"
    FROM inmueble_urbaano iu 
    INNER JOIN impuesto.inmueble_contribuyente icn ON iu.id_inmueble = icn.id_inmueble
    INNER JOIN impuesto.contribuyente c ON icn.id_contribuyente = c.id_contribuyente
    WHERE tipo_documento = $1 AND documento = $2;`,
  UPDATE_LAST_UPDATE_DATE: "UPDATE impuesto.contribuyente SET fecha_ultima_actualizacion = (NOW() - interval '4 hours') WHERE id_contribuyente = $1",
  GET_PARISH_ESTATES: `SELECT id_inmueble AS id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", id_registro_municipal AS "idRim"
    FROM inmueble_urbaano iu
    WHERE id_parroquia = $1`,
  GET_APPRAISALS_BY_ID: 'SELECT anio, avaluo_terreno AS "avaluoTerreno", avaluo_construccion AS "avaluoConstruccion" FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1',
  GET_CURRENT_APPRAISALS_BY_ID: "SELECT anio, avaluo FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1 and anio = EXTRACT('year' FROM CURRENT_DATE);",
  INSERT_COMMON_LAND: `INSERT INTO inmueble_ejidos(id_inmueble, uso, clase, tenencia, contrato, fecha_vencimiento) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id_inmueble AS id, uso, clase, tenencia, contrato, fecha_vencimiento AS "fechaVencimiento";`,
  INSERT_GRAVEYARD: `INSERT INTO inmueble_cementerios(id_inmueble, area_servicios, tenencia, sector, area_servicios_indicador) VALUES ($1, $2, $3, $4, $5) RETURNING id_inmueble AS id, area_servicios AS "areaServicios", tenencia, sector, area_servicios_indicador AS "areaServiciosIndicador";`,
  INSERT_QUIOSCO: `INSERT INTO inmueble_quioscos(id_inmueble, objeto, tipo, zona, id_canon) VALUES ($1, $2, $3, $4, $5) RETURNING id_inmueble AS id, objeto AS "objetoQuiosco", tipo AS "tipoQuiosco", zona AS "zonaQuiosco", id_canon AS "canonArrendamientoQuiosco";`,
  INSERT_MARKET_ESTATE: `INSERT INTO inmueble_mercados(id_inmueble, mercados, tipo_local, tipo_aeconomica, canon_arrendamiento) VALUES ($1, $2, $3, $4, $5) RETURNING id_inmueble AS id, mercados, tipo_local AS "tipoLocal", tipo_aeconomica AS "tipoAE", canon_arrendamiento AS "canonArrendamientoMercado";`,
  UPDATE_COMMON_LAND: `UPDATE inmueble_ejidos SET uso = $2, clase = $3, tenencia = $4, contrato = $5, fecha_vencimiento = $6 WHERE id_inmueble = $1;`,
  UPDATE_GRAVEYARD: `UPDATE inmueble_cementerios SET area_servicios = $2, tenencia = $3, sector = $4 WHERE id_inmueble = $1;`,
  UPDATE_QUIOSCO: `UPDATE inmueble_quioscos SET objeto = $2, tipo = $3, zona = $4 WHERE id_inmueble = $1;`,
  UPDATE_MARKET_ESTATE: `UPDATE inmueble_mercados SET mercados = $2, tipo_local = $3, tipo_aeconomica = $4 WHERE id_inmueble = $1;`,
  GET_COMMON_LAND: `SELECT id_inmueble AS id, uso, clase, tenencia, fecha_vencimiento AS "fechaVencimiento", contrato FROM inmueble_ejidos WHERE id_inmueble = $1;`,
  GET_GRAVEYARD: `SELECT id_inmueble AS id, sector, area_servicios AS "areaServicios", tenencia, area_servicios_indicador AS "areaServiciosIndicador" FROM inmueble_cementerios WHERE id_inmueble = $1;`,
  GET_MARKET_ESTATE: `SELECT id_inmueble AS id, mercados, tipo_local AS "tipoLocal", tipo_aeconomica AS "tipoAE", canon_arrendamiento AS "canonArrendamientoMercado" FROM inmueble_mercados WHERE id_inmueble = $1;`,
  GET_QUIOSCO: `SELECT id_inmueble AS id, objeto AS "objetoQuiosco", tipo AS "tipoQuiosco", zona AS "zonaQuiosco", i.monto AS "canonArrendamientoQuiosco" FROM inmueble_quioscos JOIN inmueble.canon_arrendamiento_quiosco AS i USING(id_canon) WHERE id_inmueble = $1;`,
  CREATE_BARE_ESTATE: `INSERT INTO inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, tipo_inmueble, dir_doc, clasificacion, relativos)
    VALUES (default, $1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", dir_doc AS "dirDoc", clasificacion`,
  CREATE_BARE_ESTATE_NATURAL: `INSERT INTO inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, tipo_inmueble)
    VALUES (default, $1, $2, $3, $4, $5, 'RESIDENCIAL') RETURNING id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble"`,
  CREATE_BARE_ESTATE_COMMERCIAL: `INSERT INTO inmueble_urbano (id_inmueble, cod_catastral, direccion, id_parroquia, metros_construccion, metros_terreno, tipo_inmueble, id_registro_municipal)
    VALUES (default, $1, $2, $3, $4, $5, 'COMERCIAL', (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $6)) RETURNING id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
    metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble"`,
  UPDATE_ESTATE: `UPDATE inmueble_urbano SET direccion = $1, id_parroquia = $2, metros_construccion = $3, metros_terreno = $4, tipo_inmueble = $5, cod_catastral = $6, dir_doc = $8, clasificacion = $9, relativos = $10 WHERE id_inmueble = $7 RETURNING id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
  metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", dir_doc AS "dirDoc", clasificacion;`,
  GET_ESTATE_BY_CODCAT: `SELECT id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", id_parroquia AS "idParroquia",
   metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", relacion_contribuyente as relacion ,id_registro_municipal, id_registro_municipal IS NOT NULL as enlazado, dir_doc AS "dirDoc", clasificacion, relativos AS relativo FROM inmueble_urbano WHERE cod_catastral = $1;`,
  GET_ESTATE_BY_CODCAT_NAT: `SELECT id_inmueble as id, cod_catastral AS "codigoCatastral", direccion, metros_construccion AS "metrosConstruccion", 
   id_parroquia AS "idParroquia", metros_terreno AS "metrosTerreno", tipo_inmueble AS "tipoInmueble", relacion as relacion, dir_doc AS "dirDoc", clasificacion 
   FROM inmueble_urbano iu LEFT JOIN impuesto.inmueble_contribuyente icn USING (id_inmueble) 
   WHERE cod_catastral = $1;`,

  LINK_ESTATE_WITH_RIM: `UPDATE inmueble_urbano SET id_registro_municipal = $1, relacion_contribuyente = $3 WHERE cod_catastral = $2;`,
  UNLINK_ESTATE_WITH_RIM: 'UPDATE inmueble_urbano SET id_registro_municipal = null, relacion_contribuyente = null WHERE cod_catastral = $2 AND id_registro_municipal = $1;',

  //ESTADISTICAS DASHBOARD SEDEMAT
  // Totales
  // 1. Total de usuarios registrados en SUT
  TOTAL_REGISTERED_USERS: `SELECT COUNT(*) AS total FROM usuario;`,
  //  2. Total de contribuyentes
  TOTAL_REGISTERED_CONTRIBUTORS: `SELECT COUNT(*) AS total FROM impuesto.contribuyente;`,
  //  3. Total de RIMs /
  TOTAL_REGISTERED_RIMS: `SELECT COUNT(*) AS total FROM impuesto.registro_municipal;`,
  //  Total de RIMs que declararon en el mes (AE) /
  //  Sin fecha proporcionada
  TOTAL_AE_DECLARATIONS_IN_MONTH: `SELECT COUNT(*) FROM impuesto.registro_municipal r 
    INNER JOIN (SELECT DISTINCT ON (id_registro_municipal) * FROM 
    (SELECT * FROM impuesto.liquidacion WHERE EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours'))
    AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) AND id_subramo = 10) x) l USING (id_registro_municipal)`,
  // Con fecha proporcionada
  TOTAL_AE_DECLARATIONS_IN_MONTH_WITH_DATE: `SELECT COUNT(*) FROM impuesto.registro_municipal r 
    INNER JOIN (SELECT DISTINCT ON (id_registro_municipal) * FROM 
    (SELECT * FROM impuesto.liquidacion WHERE EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date)
    AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) AND id_subramo = 10) x) l USING (id_registro_municipal)`,
  // Total de RIMs que pagaron en el mes (AE)
  //  Sin fecha proporcionada
  TOTAL_AE_APPLICATION_PAYMENTS_IN_MONTH: `SELECT COUNT(*) FROM impuesto.registro_municipal r 
    INNER JOIN 
            (SELECT DISTINCT ON (id_registro_municipal) * FROM 
                    (SELECT * FROM impuesto.liquidacion 
                        WHERE EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours'))
                        AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) AND id_subramo = 10) x
            ) l USING (id_registro_municipal) 
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado = true;`,

  // Con fecha proporcionada
  TOTAL_AE_APPLICATION_PAYMENTS_IN_MONTH_WITH_DATE: `SELECT COUNT(*) FROM impuesto.registro_municipal r 
    INNER JOIN 
            (SELECT DISTINCT ON (id_registro_municipal) * FROM 
                    (SELECT * FROM impuesto.liquidacion 
                        WHERE EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::Date)
                        AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) AND id_subramo = 10) x
            ) l USING (id_registro_municipal) 
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado = true;`,

  //  Graficas mensuales
  //  1. Tasas de AE liquidadas/pagadas (por d??a reflejado en gr??fico de barras)
  //  Sin fecha proporcionada
  TOTAL_SOLVENCY_RATES_IN_MONTH: `SELECT COALESCE(x.liquidado, 0) AS liquidado, COALESCE(x.pagado,0) AS pagado, z.fecha FROM (SELECT COALESCE(l.fecha, p.fecha)::date as fecha, coalesce(liquidado, 0) as liquidado, coalesce(pagado, 0) as pagado
  FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) AS liquidado
    FROM impuesto.liquidacion l
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE id_subramo = 100 AND s.aprobado = false
    GROUP BY fecha_liquidacion) l
  FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) AS pagado
    FROM impuesto.liquidacion l
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE id_subramo = 100 AND s.aprobado = true
    
    GROUP BY fecha_aprobado) p ON p.fecha = l.fecha 
  ) x RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
    z ON x.fecha::date = z.fecha::date WHERE EXTRACT('month' FROM z.fecha) = EXTRACT('month' FROM (NOW() - interval '4 hours'))
    AND EXTRACT('year' FROM z.fecha) = EXTRACT('year' FROM (NOW() - interval '4 hours'))
    ORDER BY z.fecha;`,
  //  Con fecha proporcionada
  TOTAL_SOLVENCY_RATES_IN_MONTH_WITH_DATE: `SELECT COALESCE(x.liquidado, 0) AS liquidado, COALESCE(x.pagado,0) AS pagado, z.fecha FROM (SELECT COALESCE(l.fecha, p.fecha)::date as fecha, coalesce(liquidado, 0) as liquidado, coalesce(pagado, 0) as pagado
  FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) AS liquidado
    FROM impuesto.liquidacion l
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE id_subramo = 100 AND s.aprobado = false
    GROUP BY fecha_liquidacion) l
  FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) AS pagado
    FROM impuesto.liquidacion l
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE id_subramo = 100 AND s.aprobado = true
    
    GROUP BY fecha_aprobado) p ON p.fecha = l.fecha 
  ) x RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
    z ON x.fecha::date = z.fecha::date WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from $3::date)
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from $3::date)
    ORDER BY z.fecha;`,

  //  2. Bs por ramo por d??a liquidado/ingresado (4 ramos principales reflejado en gr??fico de torta)
  //  Sin fecha proporcionada
  TOTAL_BS_BY_BRANCH_IN_MONTH: `WITH solicitud_view AS (
    SELECT *, l.monto AS montos FROM impuesto.solicitud S
    RIGHT JOIN impuesto.liquidacion l USING (id_solicitud)
    LEFT JOIN impuesto.subramo USING (id_subramo)
    LEFT JOIN impuesto.ramo USING (id_ramo)
  )

  SELECT z.fecha, COALESCE(SUM(montos),0) AS valor, z.ramo FROM solicitud_view v
  RIGHT JOIN (SELECT generate_series::date AS fecha, c.column1 as ramo FROM generate_series($1, $2, interval '1 day') CROSS JOIN (SELECT * FROM (VALUES ('AE'), ('SM'), ('IU'), ('PP')) XX) c )
  z ON v.fecha_aprobado = z.fecha AND v.descripcion_corta = z.ramo
  WHERE descripcion_corta IN ('AE','SM','IU','PP') or descripcion_corta is null
   AND EXTRACT('month' FROM z.fecha) = EXTRACT('month' FROM (NOW() - interval '4 hours'))
   AND EXTRACT('year' FROM z.fecha) = EXTRACT('year' FROM (NOW() - interval '4 hours'))
  GROUP BY z.fecha, z.ramo ORDER BY z.fecha`,

  //  Con fecha proporcionada
  TOTAL_BS_BY_BRANCH_IN_MONTH_WITH_DATE: `WITH solicitud_view AS (
    SELECT *, l.monto AS montos FROM impuesto.solicitud S
    RIGHT JOIN impuesto.liquidacion l USING (id_solicitud)
    LEFT JOIN impuesto.subramo USING (id_subramo)
    LEFT JOIN impuesto.ramo USING (id_ramo)
  )

  SELECT z.fecha, COALESCE(SUM(montos),0) AS valor, z.ramo FROM solicitud_view v
RIGHT JOIN (SELECT generate_series::date AS fecha, c.column1 as ramo FROM generate_series($1, $2, interval '1 day') CROSS JOIN (SELECT * FROM (VALUES ('AE'), ('SM'), ('IU'), ('PP')) XX) c )
  z ON v.fecha_aprobado = z.fecha AND v.descripcion_corta = z.ramo
WHERE descripcion_corta IN ('AE','SM','IU','PP') or descripcion_corta is null
   AND EXTRACT('month' FROM z.fecha) = EXTRACT('month' FROM $3::date)
   AND EXTRACT('year' FROM z.fecha) = EXTRACT('year' FROM $3::date)
  GROUP BY z.fecha, z.ramo ORDER BY z.fecha`,

  //  Con intervalo proporcionado
  TOTAL_BS_BY_BRANCH_IN_MONTH_WITH_INTERVAL: `WITH 
  solicitud_range_q AS (
    select * from impuesto.solicitud WHERE fecha_aprobado BETWEEN $1 AND $2
  ), fraccion_q AS (
    SELECT * FROM impuesto.fraccion WHERE fecha_aprobado BETWEEN $1 AND $2
  ), liq_q AS (
    SELECT DISTINCT l.id_solicitud, l.id_liquidacion, l.id_subramo, l.monto  
    FROM impuesto.liquidacion l 
    WHERE id_solicitud IS NOT NULL 
    AND id_solicitud IN (SELECT id_solicitud 
                          FROM solicitud_range_q
                          WHERE tipo_solicitud != 'CONVENIO') 
    UNION SELECT l.id_liquidacion, l.id_solicitud, l.id_subramo, l.monto 
    FROM impuesto.liquidacion l 
    WHERE id_solicitud IS NULL 
    AND fecha_liquidacion 
    BETWEEN $1 AND $2
    
  ), distinct_liq_q AS (
    SELECT DISTINCT ON (id_solicitud) id_solicitud, id_subramo, id_liquidacion FROM impuesto.liquidacion WHERE fecha_liquidacion BETWEEN $1 AND $2
  ),
  
  solicitud_q as (
    SELECT *, s.id_solicitud AS id_solicitud_q
                          FROM impuesto.solicitud s
                          INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud)
              AS state FROM impuesto.evento_solicitud es WHERE id_solicitud IN (SELECT id_solicitud FROM solicitud_range_q)  GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE fecha_aprobado BETWEEN $1 AND $2
  )
  
  SELECT ramo, COALESCE(SUM(monto),0) AS valor FROM (
      (SELECT r.descripcion_corta AS ramo, SUM(l.monto) AS monto
          FROM liq_q l
          LEFT JOIN  solicitud_q
          se ON l.id_solicitud = se.id_solicitud_q
          RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
          INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo
          WHERE r.descripcion_corta IN ('AE','SM','IU','PP')
          GROUP BY ramo
          ORDER BY ramo)
      UNION
      (SELECT r.descripcion_corta AS ramo, SUM(f.monto) AS monto
        FROM fraccion_q f
        INNER JOIN impuesto.convenio USING (id_convenio)
        INNER JOIN impuesto.solicitud USING (id_solicitud)
        INNER JOIN distinct_liq_q l USING (id_solicitud)
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo
        WHERE r.descripcion_corta IN ('AE','SM','IU','PP')
        GROUP BY ramo
        ORDER BY ramo)
        UNION
         (SELECT 'OTROS' AS ramo, SUM(l.monto) AS monto
          FROM liq_q l
          LEFT JOIN solicitud_q
          se ON l.id_solicitud = se.id_solicitud_q
          RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
          INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo
          WHERE r.codigo NOT IN ('3.01.02.07.00.000.00','3.01.02.05.00.000.00','3.01.03.54.00.000.00','3.01.02.09.00.000.00')
          GROUP BY ramo
          ORDER BY ramo)
      UNION
      (SELECT 'OTROS' AS ramo, SUM(f.monto) AS monto
        FROM fraccion_q f
        INNER JOIN impuesto.convenio USING (id_convenio)
        INNER JOIN impuesto.solicitud USING (id_solicitud)
        INNER JOIN distinct_liq_q l USING (id_solicitud)
        RIGHT JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_ramo
        WHERE r.codigo NOT IN ('3.01.02.07.00.000.00','3.01.02.05.00.000.00','3.01.03.54.00.000.00','3.01.02.09.00.000.00')
        GROUP BY ramo
        ORDER BY ramo)) x 
          GROUP BY ramo;`,

  //  3. Total recaudado por mes (gr??fico de linea con anotaciones)
  //  Sin fecha proporcionada
  TOTAL_GAININGS_IN_MONTH: `SELECT z.fecha, COALESCE(SUM(monto),0) AS valor
  FROM (
  SELECT fecha_de_aprobacion, SUM(p.monto) AS monto
  FROM pago p
  INNER JOIN (
      SELECT id_solicitud, ARRAY_AGG(id_subramo)
      FROM impuesto.liquidacion l 
      GROUP BY id_solicitud
      HAVING NOT (85 = ANY(ARRAY_AGG(l.id_subramo)) OR 236 = ANY(ARRAY_AGG(l.id_subramo)))
  ) sub ON sub.id_solicitud = p.id_procedimiento
  WHERE p.aprobado = true AND concepto = 'IMPUESTO'
  GROUP BY p.fecha_de_aprobacion
  
  UNION ALL
  SELECT fecha_de_aprobacion, SUM(monto) AS monto
  FROM pago p
  WHERE aprobado = true AND concepto = 'CONVENIO'
  GROUP BY fecha_de_aprobacion
  UNION ALL
  SELECT fecha_de_aprobacion, SUM(monto) AS monto
  FROM (SELECT * FROM pago WHERE concepto = 'TRAMITE') p
  INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento
  INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = t.id_tipo_tramite
  WHERE tt.id_institucion = 9
  GROUP BY fecha_de_aprobacion) x RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON x.fecha_de_aprobacion::date = z.fecha::date
  WHERE EXTRACT('month' from fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
  AND EXTRACT('year' from fecha) = EXTRACT('year' from (NOW() - interval '4 hours'))
  GROUP BY fecha
  ORDER BY fecha
  `,

  //  Con fecha proporcionada
  TOTAL_GAININGS_IN_MONTH_WITH_DATE: `SELECT z.fecha, COALESCE(SUM(monto),0) AS valor
  FROM (SELECT fecha_de_aprobacion, SUM(monto) AS monto
  FROM pago p
  WHERE aprobado = true AND concepto IN ('IMPUESTO', 'CONVENIO')
  GROUP BY fecha_de_aprobacion
  UNION ALL
  SELECT fecha_de_aprobacion, SUM(monto) AS monto
  FROM (SELECT * FROM pago WHERE concepto = 'TRAMITE') p
  INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento
  INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = t.id_tipo_tramite
  WHERE tt.id_institucion = 9
  GROUP BY fecha_de_aprobacion) x RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON x.fecha_de_aprobacion::date = z.fecha::date
  WHERE EXTRACT('month' from fecha) = EXTRACT('month' from $3::date)
  AND EXTRACT('year' from fecha) = EXTRACT('year' from $3::date)
  GROUP BY fecha
  ORDER BY fecha;`,

  //  4. Total de liquidaciones pagadas/vigentes (%)
  //  Sin fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_AE: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (10,99)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (10,99)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from (NOW() - interval '4 hours')) ORDER BY z.fecha;`,
  //  Con fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_AE_WITH_DATE: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (10,99)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (10,99)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from $3::date)
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from $3::date) ORDER BY z.fecha;`,
  //  Sin fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_SM: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (107,108,102)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (107,108,102)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from (NOW() - interval '4 hours')) ORDER BY z.fecha;`,
  //  Con fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_SM_WITH_DATE: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (107,108,102)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (107,108,102)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from $3::date)
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from $3::date) ORDER BY z.fecha;`,
  //  Sin fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_IU: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (9,103)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (9,103)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from (NOW() - interval '4 hours')) ORDER BY z.fecha;`,
  //  Con fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_IU_WITH_DATE: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (9,103)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (9,103)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from $3::date)
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from $3::date) ORDER BY z.fecha;`,
  //  Sin fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_PP: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (12,104)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (12,104)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from (NOW() - interval '4 hours')) ORDER BY z.fecha;`,
  //  Con fecha proporcionada
  TOTAL_SETTLEMENTS_IN_MONTH_PP_WITH_DATE: `SELECT z.fecha, COALESCE(l.liq,0) AS liquidado, COALESCE(p.pag,0) AS pagado FROM (
    SELECT fecha_liquidacion AS fecha, COUNT(*) as liq
    FROM impuesto.liquidacion l
    WHERE id_subramo IN (12,104)
    GROUP BY fecha_liquidacion) l
    FULL OUTER JOIN (
    SELECT fecha_aprobado AS fecha, COUNT(*) as pag
    FROM impuesto.liquidacion l
    LEFT JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE s.aprobado IS NULL OR s.aprobado = true
    AND id_subramo IN (12,104)
    GROUP BY fecha_aprobado
    ) p ON p.fecha = l.fecha RIGHT JOIN (SELECT generate_series::date AS fecha FROM generate_series($1, $2, interval '1 day'))
  z ON p.fecha::date = z.fecha::date AND l.fecha::date = z.fecha::date
    WHERE EXTRACT('month' from z.fecha) = EXTRACT('month' from $3::date)
    AND EXTRACT('year' from z.fecha) = EXTRACT('year' from $3::date) ORDER BY z.fecha;`,
  //Extras para el 4
  ECONOMIC_ACTIVITIES_EXONERATION_INTERVALS: `SELECT fecha_inicio as "fechaInicio", fecha_fin AS "fechaFin", COUNT(*) as cantidad 
      FROM impuesto.actividad_economica_exoneracion aee INNER JOIN
       impuesto.plazo_exoneracion p ON p.id_plazo_exoneracion = aee.id_plazo_exoneracion 
       GROUP BY fecha_inicio, fecha_fin;`,

  //  Top contribuyentes
  //  1. Agentes de retenci??n que han declarado/pagado por mes
  //  Sin fecha
  TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH: `WITH rimsAR AS (
    SELECT id_registro_municipal FROM impuesto.contribuyente 
    INNER JOIN impuesto.registro_municipal USING (id_contribuyente) 
    WHERE es_agente_retencion = true AND NOT referencia_municipal ILIKE 'AR%'
  ),
  pagados AS (
    SELECT COUNT(DISTINCT id_registro_municipal) AS pagado FROM impuesto.registro_municipal rm 
    INNER JOIN (SELECT id_registro_municipal, id_solicitud
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l USING (id_registro_municipal)
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE l.id_registro_municipal IN 
            (SELECT id_registro_municipal FROM 
              (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l ) AND s.aprobado = true
  ),
  liquidado AS (
    SELECT COUNT(DISTINCT id_registro_municipal) AS liquidado FROM impuesto.registro_municipal rm 
    INNER JOIN (SELECT id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l USING (id_registro_municipal)
    WHERE l.id_registro_municipal IN 
            (SELECT id_registro_municipal FROM 
              (SELECT id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l )
  )

  SELECT (SELECT * FROM liquidado), (SELECT * FROM pagados), (SELECT count(*) AS total FROM rimsAR)`,

  //  Con fecha
  TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH_WITH_DATE: `WITH rimsAR AS (
    SELECT id_registro_municipal FROM impuesto.contribuyente 
    INNER JOIN impuesto.registro_municipal USING (id_contribuyente) 
    WHERE es_agente_retencion = true AND NOT referencia_municipal ILIKE 'AR%'
  ),
  pagados AS (
    SELECT COUNT(DISTINCT id_registro_municipal) AS pagado FROM impuesto.registro_municipal rm 
    INNER JOIN (SELECT id_registro_municipal, id_solicitud
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l USING (id_registro_municipal)
    INNER JOIN impuesto.solicitud s USING (id_solicitud)
    WHERE l.id_registro_municipal IN 
            (SELECT id_registro_municipal FROM 
              (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l ) AND s.aprobado = true
  ),
  liquidado AS (
    SELECT COUNT(DISTINCT id_registro_municipal) AS liquidado FROM impuesto.registro_municipal rm 
    INNER JOIN (SELECT id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l USING (id_registro_municipal)
    WHERE l.id_registro_municipal IN 
            (SELECT id_registro_municipal FROM 
              (SELECT id_registro_municipal
              FROM impuesto.liquidacion 
              WHERE id_subramo = 10 AND 
              EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date) 
              AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) 
              AND id_registro_municipal IN (SELECT id_registro_municipal FROM rimsAR)) l )
  )

  SELECT (SELECT * FROM liquidado), (SELECT * FROM pagados), (SELECT count(*) AS total FROM rimsAR)`,

  //  2. Top 1000 contribuyentes que han declarado/pagado por mes
  //  Sin fecha
  TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH: `WITH topContr AS (
    SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal FROM impuesto.liquidacion WHERE id_registro_municipal IN (
      SELECT id_registro_municipal FROM (SELECT DISTINCT ON(id_registro_municipal) id_registro_municipal, SUM(monto) as monto 
      FROM Impuesto.liquidacion
      WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2
      AND id_registro_municipal IS NOT NULL
      GROUP BY id_registro_municipal 
      ORDER BY id_registro_municipal DESC
      LIMIT 1000) s)
    ),
    pagados AS (
      SELECT COUNT(id_registro_municipal) AS pagado FROM impuesto.registro_municipal rm 
      INNER JOIN (SELECT id_registro_municipal, id_solicitud FROM 
                (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, id_solicitud
                FROM impuesto.liquidacion 
                WHERE id_subramo = 10 AND 
                EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
                AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
                AND id_registro_municipal IN (SELECT id_registro_municipal FROM topContr)) l ) l USING (id_registro_municipal)
      INNER JOIN impuesto.solicitud s USING (id_solicitud)
      WHERE s.aprobado = true
    ),
    liquidados AS (
      SELECT COUNT(id_registro_municipal) AS liquidado FROM impuesto.registro_municipal rm 
      INNER JOIN (SELECT id_registro_municipal, id_solicitud FROM 
                (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, id_solicitud
                FROM impuesto.liquidacion 
                WHERE id_subramo = 10 AND 
                EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM (NOW() - interval '4 hours')) 
                AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM (NOW() - interval '4 hours')) 
                AND id_registro_municipal IN (SELECT id_registro_municipal FROM topContr)) l ) l USING (id_registro_municipal)
    )

    SELECT (SELECT * FROM liquidados), (SELECT * FROM pagados), (SELECT COUNT(*) FROM topContr) AS total`,

  //  Con fecha
  TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH_WITH_DATE: `WITH topContr AS (
    SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal FROM impuesto.liquidacion WHERE id_registro_municipal IN (
        SELECT id_registro_municipal FROM (SELECT DISTINCT ON(id_registro_municipal) id_registro_municipal, SUM(monto) as monto 
        FROM Impuesto.liquidacion
        WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2
        AND id_registro_municipal IS NOT NULL
        GROUP BY id_registro_municipal 
        ORDER BY id_registro_municipal DESC
        LIMIT 1000) s)
    ),
    pagados AS (
      SELECT COUNT(id_registro_municipal) AS pagado FROM impuesto.registro_municipal rm 
      INNER JOIN (SELECT id_registro_municipal, id_solicitud FROM 
                (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, id_solicitud
                FROM impuesto.liquidacion 
                WHERE id_subramo = 10 AND 
                EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $3::date) 
                AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $3::date) 
                AND id_registro_municipal IN (SELECT id_registro_municipal FROM topContr)) l ) l USING (id_registro_municipal)
      INNER JOIN impuesto.solicitud s USING (id_solicitud)
      WHERE s.aprobado = true
    ),
    liquidados AS (
      SELECT COUNT(id_registro_municipal) AS liquidado FROM impuesto.registro_municipal rm 
      INNER JOIN (SELECT id_registro_municipal, id_solicitud FROM 
                (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, id_solicitud
                FROM impuesto.liquidacion 
                WHERE id_subramo = 10 AND 
                EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $3::date) 
                AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $3::date) 
                AND id_registro_municipal IN (SELECT id_registro_municipal FROM topContr)) l ) l USING (id_registro_municipal)
    )

    SELECT (SELECT * FROM liquidados), (SELECT * FROM pagados), (SELECT COUNT(*) FROM topContr) AS total`,

  //  Coeficientes
  //  1. Tasa de Default Intermensual (TDI)
  //  TDI = Cantidad de Contribuyentes que pagaron mes anterior pero no mes actual (gr??fico de barra o linea por mes, incluyendo coeficiente y cantidad de contribuyentes)
  TOTAL_CONTRIBUTOR_DEFAULT_RATE: `WITH solicitudesae AS (
    SELECT id_registro_municipal 
    FROM impuesto.liquidacion l
    WHERE Id_subramo = 10 
    AND datos#>>'{fecha, month}' = $1 AND datos#>>'{fecha, year}' = $2
    AND id_registro_municipal IS NOT NULL
    GROUP BY id_registro_municipal
    ),
    solicitudespasado AS (
        SELECT id_registro_municipal
        FROM impuesto.liquidacion l
        WHERE Id_subramo = 10 
        AND datos#>>'{fecha, month}' = $3 AND datos#>>'{fecha, year}' = $4
    AND id_registro_municipal IS NOT NULL
    GROUP BY id_registro_municipal
    )	
    SELECT COUNT(*) AS valor
    FROM impuesto.registro_municipal
    WHERE id_registro_municipal 
    NOT IN (
          SELECT id_registro_municipal FROM solicitudesae
      )
    AND id_registro_municipal
    IN (
        SELECT id_registro_municipal FROM solicitudespasado
    );
`,

  //  2. Promedio D??as para Pago (PDP)
  //  PDP = Promedio de d??as que demoran los contribuyentes en realizar pagos vencidos medidos por mes (gr??fico de linea o de barra)
  //  Sin fecha proporcionada
  TOTAL_PAYMENT_DAYS_AVERAGE_IN_MONTH: `SELECT AVG(fecha_de_pago - s.fecha), MAX(fecha_de_pago - s.fecha)
    FROM (SELECT * FROM impuesto.solicitud WHERE id_solicitud IN (SELECT id_solicitud 
                                  FROM impuesto.liquidacion
                                  where EXTRACT('month' from fecha_liquidacion) = EXTRACT('month' from (NOW() - interval '4 hours'))
                                  AND EXTRACT('year' from fecha_liquidacion) = EXTRACT('year' from (NOW() - interval '4 hours')))  
                                  AND EXTRACT('month' from fecha) = EXTRACT('month' from (NOW() - interval '4 hours'))
                                  AND EXTRACT('year' from fecha) = EXTRACT('year' from (NOW() - interval '4 hours'))) s
    INNER JOIN (SELECT * 
            FROM pago 
            WHERE concepto = 'IMPUESTO' 
            AND EXTRACT('month' FROM fecha_de_pago) = EXTRACT('month' from (NOW() - interval '4 hours')) 
            AND EXTRACT('year' FROM fecha_de_pago) = EXTRACT('year' from (NOW() - interval '4 hours')) ) 
          p ON p.id_procedimiento = s.id_solicitud;`,
  //  Con fecha proporcionada
  TOTAL_PAYMENT_DAYS_AVERAGE_IN_MONTH_WITH_DATE: `SELECT AVG(fecha_de_pago - s.fecha) AS promedio, MAX(fecha_de_pago - s.fecha) AS "limiteSuperior"
    FROM (SELECT * FROM impuesto.solicitud WHERE id_solicitud IN (SELECT id_solicitud 
                                  FROM impuesto.liquidacion
                                  where EXTRACT('month' from fecha_liquidacion) = EXTRACT('month' from $1::date)
                                  AND EXTRACT('year' from fecha_liquidacion) = EXTRACT('year' from $1::date))  
                                  AND EXTRACT('month' from fecha) = EXTRACT('month' from $1::date)
                                  AND EXTRACT('year' from fecha) = EXTRACT('year' from $1::date)) s
    INNER JOIN (SELECT * 
            FROM pago 
            WHERE concepto = 'IMPUESTO' 
            AND EXTRACT('month' FROM fecha_de_pago) = EXTRACT('month' from $1::date) 
            AND EXTRACT('year' FROM fecha_de_pago) = EXTRACT('year' from $1::date) ) 
          p ON p.id_procedimiento = s.id_solicitud;`,

  //  3. Tasa Nuevas Licencias (TNL)
  //  TNL = Cantidad de Licencias Nuevas mes actual/Cantidad de Licencias Nuevas mes anterior (por mes en grafico de barra o linea, incluyendo el coeficiente y la cantidad de nuevas licencias)
  //  Sin fecha proporcionada
  TOTAL_NEW_LICENSES_IN_MONTH: `WITH anterior AS (
    SELECT COUNT(*)
    FROM tramite 
    WHERE id_tipo_tramite IN (28, 36)
    AND EXTRACT('month' from fecha_culminacion) = EXTRACT('month' from (NOW() - interval '1 month'))
    AND EXTRACT('year' from fecha_culminacion) = EXTRACT('year' from (NOW() - interval '1 month'))
    )
    SELECT COUNT(*) AS valor,  COALESCE(COUNT(*)::numeric / NULLIF((SELECT * FROM anterior),0),0) AS coeficiente
    FROM tramite 
    WHERE id_tipo_tramite IN (28, 36)
    AND EXTRACT('month' from fecha_culminacion) = EXTRACT('month' from (NOW() - interval '4 hours'))
    AND EXTRACT('year' from fecha_culminacion) = EXTRACT('year' from (NOW() - interval '4 hours'))`,
  //  Con fecha proporcionada
  TOTAL_NEW_LICENSES_IN_MONTH_WITH_DATE: `WITH anterior AS (
    SELECT COUNT(*)
    FROM tramite 
    WHERE id_tipo_tramite IN (28, 36)
    AND EXTRACT('month' from fecha_culminacion) = EXTRACT('month' from ($1::date - interval '1 month'))
    AND EXTRACT('year' from fecha_culminacion) = EXTRACT('year' from ($1::date - interval '1 month'))
    )
    SELECT COUNT(*) AS valor, COALESCE(COUNT(*)::numeric / NULLIF((SELECT * FROM anterior),0),0) AS coeficiente
    FROM tramite 
    WHERE id_tipo_tramite IN (28, 36)
    AND EXTRACT('month' from fecha_culminacion) = EXTRACT('month' from $1::date)
    AND EXTRACT('year' from fecha_culminacion) = EXTRACT('year' from $1::date)`,

  SET_NON_APPROVED_STATE_FOR_APPLICATION: 'UPDATE impuesto.solicitud SET aprobado = false, fecha_aprobado = null WHERE id_solicitud = $1;',
  SET_NON_APPROVED_STATE_FOR_AGREEMENT_FRACTION: 'UPDATE impuesto.fraccion SET aprobado = false, fecha_aprobado = null WHERE id_fraccion = $1;',
  SET_NON_APPROVED_STATE_FOR_PROCEDURE: 'UPDATE tramite SET aprobado = false, fecha_culminacion = null WHERE id_tramite = $1;',
  DELETE_PAYMENT_REFERENCES_BY_PROCESS_AND_CONCEPT: 'DELETE FROM pago WHERE id_procedimiento = $1 AND concepto = $2;',
  DELETE_FISCAL_CREDIT_BY_APPLICATION_ID: 'DELETE FROM impuesto.credito_fiscal WHERE id_solicitud = $1;',
  NULLIFY_AMOUNT_IN_REVERSED_FRACTION: `UPDATE impuesto.fraccion SET monto = null WHERE id_fraccion = $1`,
  NULLIFY_AMOUNT_IN_REVERSED_APPLICATION: `UPDATE impuesto.liquidacion SET monto = null WHERE id_solicitud = $1`,

  //Validacion de pagos individual
  APPROVE_PAYMENT: `UPDATE pago SET aprobado = true, fecha_de_aprobacion = (NOW() - interval '4 hours') WHERE id_pago = $1 RETURNING *`,
  PAYMENT_PROCEDURE_INFO: `select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, 
    pago.id_procedimiento AS idProcedimiento, pago.referencia, pago.fecha_de_pago AS fechaDePago, 
    pago.fecha_de_aprobacion AS fechaDeAprobacion, tramite.codigo_tramite AS "codigoTramite", 
    tipo_tramite.sufijo AS sufijo, tipo_tramite.id_tipo_tramite AS tipotramite, pago.concepto  from pago
    INNER JOIN tramite ON pago.id_procedimiento = tramite.id_tramite
    INNER JOIN tipo_tramite ON tipo_tramite.id_tipo_tramite = tramite.id_tipo_tramite where pago.id_pago = $1`,
  PAYMENT_FINE_INFO: `SELECT codigo_multa, id_tipo_tramite  FROM pago p 
    INNER JOIN multa m ON m.id_multa = p.id_procedimiento 
    INNER JOIN tipo_tramite tt ON tt.id_tipo_tramite = m.id_tipo_tramite WHERE p.id_pago = $1`,
  PAYMENTS_ALL_APPROVED: `SELECT true = ALL(SELECT aprobado FROM pago WHERE id_procedimiento = (SELECT id_procedimiento FROM pago WHERE id_pago = $1)) as alltrue`,
  UPDATE_PAYMENT_SETTLEMENT: `UPDATE impuesto.solicitud SET aprobado = true, fecha_aprobado = (NOW() - interval '4 hours') WHERE id_solicitud = (SELECT id_procedimiento FROM pago WHERE id_pago = $1);`,
  PAYMENT_SETTLEMENT_INFO: `select pago.id_pago AS id, pago.monto, pago.aprobado, pago.id_banco AS idBanco, pago.id_procedimiento AS idProcedimiento, 
    pago.referencia, pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, 
    solicitud.aprobado as "solicitudAprobada", pago.concepto, contribuyente.tipo_documento AS nacionalidad, 
    contribuyente.documento from pago
    INNER JOIN impuesto.solicitud ON pago.id_procedimiento = solicitud.id_solicitud
    INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
    where pago.id_pago = $1`,
  PAYMENT_CONV_UPDATE: `UPDATE impuesto.fraccion SET aprobado = true, fecha_aprobado = (NOW() - interval '4 hours') WHERE id_fraccion = (SELECT id_procedimiento FROM pago WHERE id_pago = $1);`,
  PAYMENT_CONV_INFO: `select pago.id_pago AS id, pago.monto, pago.aprobado, 
    pago.id_banco AS idBanco, (SELECT id_procedimiento FROM pago WHERE id_pago = $1) AS idProcedimiento, pago.referencia, 
    pago.fecha_de_pago AS fechaDePago, pago.fecha_de_aprobacion AS fechaDeAprobacion, pago.concepto, 
    contribuyente.tipo_documento AS nacionalidad, contribuyente.documento,
    (SELECT true = ALL(SELECT aprobado FROM impuesto.fraccion WHERE id_convenio = (SELECT id_convenio FROM impuesto.fraccion WHERE id_fraccion = (SELECT id_procedimiento FROM pago WHERE id_pago = $1) ))) AS "solicitudAprobada"
    from pago
    INNER JOIN impuesto.fraccion ON fraccion.id_fraccion = pago.id_procedimiento
    INNER JOIN impuesto.convenio ON fraccion.id_convenio = convenio.id_convenio
    INNER JOIN impuesto.solicitud ON solicitud.id_solicitud = convenio.id_solicitud
    INNER JOIN impuesto.contribuyente ON solicitud.id_contribuyente = contribuyente.id_contribuyente
                where pago.id_pago = $1`,

  // ! DESCUENTOS
  GET_ACTIVITY_DISCOUNTS: `SELECT DISTINCT ON (aee.id_plazo_descuento, aee.id_actividad_economica) pe.*, ae.*, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active
  FROM impuesto.plazo_descuento pe
  INNER JOIN impuesto.actividad_economica_descuento aee ON aee.id_plazo_descuento = pe.id_plazo_descuento
  INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
  ORDER BY aee.id_plazo_descuento DESC;`,
  GET_BRANCH_INFO_FOR_DISCOUNT_BY_ACTIVITY: `SELECT rm.id_ramo AS id, rm.descripcion AS ramo, aed.porcentaje_descuento AS porcentaje FROM impuesto.ramo rm 
  INNER JOIN impuesto.actividad_economica_descuento aed USING (id_ramo) 
  WHERE aed.id_plazo_descuento = $1 AND aed.id_actividad_economica = $2;`,
  GET_BRANCH_INFO_FOR_DISCOUNT_BY_BRANCH: `SELECT rm.id_ramo AS id, rm.descripcion AS ramo, aed.porcentaje_descuento AS porcentaje FROM impuesto.ramo rm 
  INNER JOIN impuesto.contribuyente_descuento aed USING (id_ramo) 
  WHERE aed.id_plazo_descuento = $1 AND aed.id_registro_municipal = $2;`,
  CREATE_DISCOUNT: `INSERT INTO impuesto.plazo_descuento (id_plazo_descuento, fecha_inicio) VALUES (default, $1) RETURNING *;`,
  GET_ACTIVITY_IS_DISCOUNTED: `SELECT pe.id_plazo_descuento AS id, ae.id_actividad_economica AS aforo, ae.descripcion, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active 
  FROM impuesto.plazo_descuento pe
  INNER JOIN impuesto.actividad_economica_descuento aee ON aee.id_plazo_descuento = pe.id_plazo_descuento
  INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
  WHERE ae.id_actividad_economica = $1 AND aee.id_ramo = $2 AND (pe.fecha_fin IS NULL OR pe.fecha_fin > NOW()::DATE)
  ORDER BY pe.id_plazo_descuento DESC;`,
  INSERT_DISCOUNT_ACTIVITY: `INSERT INTO impuesto.actividad_economica_descuento (id_actividad_economica_descuento, id_plazo_descuento, id_actividad_economica, id_ramo, porcentaje_descuento) VALUES (default, $1, $2, $3, $4) RETURNING *;`,
  UPDATE_DISCOUNT_END_TIME: `UPDATE impuesto.plazo_descuento SET fecha_fin = $1 WHERE id_plazo_descuento = $2`,
  GET_CONTRIBUTOR_DISCOUNTS: `SELECT DISTINCT ON (ce.id_ramo) pe.*, ce.*, ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND pe.fecha_fin)) AS active 
  FROM impuesto.plazo_descuento pe 
  INNER JOIN impuesto.contribuyente_descuento ce ON ce.id_plazo_descuento = pe.id_plazo_descuento 
  INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = ce.id_registro_municipal
  INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = rm.id_contribuyente
  WHERE c.tipo_documento = $1 AND c.documento = $2 AND rm.referencia_municipal = $3 ORDER BY ce.id_ramo DESC;`,
  GET_DISCOUNTED_BRANCH_BY_CONTRIBUTOR: `
  SELECT * FROM impuesto.plazo_descuento pe 
      INNER JOIN impuesto.contribuyente_descuento ce ON ce.id_plazo_descuento = pe.id_plazo_descuento
      INNER JOIN impuesto.ramo rm USING (id_ramo)
      WHERE ce.id_registro_municipal = $1 AND ce.id_ramo = $2`,
  GET_BRANCH_IS_DISCOUNTED_FOR_CONTRIBUTOR: `
  SELECT * FROM impuesto.plazo_descuento pe 
      INNER JOIN impuesto.contribuyente_descuento ce ON ce.id_plazo_descuento = pe.id_plazo_descuento
      INNER JOIN impuesto.ramo rm USING (id_ramo)
      WHERE ce.id_registro_municipal = $1 AND ce.id_ramo = $2 AND (pe.fecha_fin >= $3::date OR pe.fecha_fin IS NULL)`,
  INSERT_CONTRIBUTOR_DISCOUNT_FOR_BRANCH: `
  INSERT INTO impuesto.contribuyente_descuento (id_contribuyente_descuento, id_plazo_descuento, id_registro_municipal, id_ramo, porcentaje_descuento)
                  VALUES (default, $1, $2, $3, $4) RETURNING *;`,
  GET_ACTIVITY_DISCOUNT_BY_ID: `SELECT pe.id_plazo_descuento AS id, ae.id_actividad_economica AS aforo, ae.descripcion, ae.numero_referencia AS "numeroReferencia", ((pe.fecha_fin IS NULL) OR (NOW() BETWEEN pe.fecha_inicio AND (pe.fecha_fin))) AS active 
  FROM impuesto.plazo_descuento pe
  INNER JOIN impuesto.actividad_economica_descuento aee ON aee.id_plazo_descuento = pe.id_plazo_descuento
  INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
  WHERE pe.id_plazo_descuento = $1 AND ae.id_actividad_economica = $2
  ORDER BY pe.id_plazo_descuento DESC;`,
  ECONOMIC_ACTIVITY_HAS_DISCOUNT_IN_BRANCH: `SELECT * FROM impuesto.actividad_economica_descuento INNER JOIN
   impuesto.plazo_descuento USING (id_plazo_descuento) 
   WHERE id_actividad_economica = $1 AND id_ramo = (SELECT id_ramo FROM impuesto.ramo WHERE codigo = $2 LIMIT 1) AND fecha_inicio <= $3 AND (fecha_fin IS NULL OR $3 <= fecha_fin)`,
  CONTRIBUTOR_HAS_DISCOUNT_IN_BRANCH: `SELECT * FROM impuesto.contribuyente_descuento INNER JOIN
   impuesto.plazo_descuento USING (id_plazo_descuento) 
   WHERE id_registro_municipal = $1 AND id_ramo=(SELECT id_ramo FROM impuesto.ramo WHERE codigo = $2 LIMIT 1) AND fecha_inicio <= $3 AND (fecha_fin IS NULL OR $3 <= fecha_fin)`,
  GET_CHARGINGS: `WITH cobranz AS (
    SELECT id_registro_municipal, id_cobranza AS "idCobranza", cob.id_cartera AS "idCartera", cob.contactado, estatus_telefonico as "estatusTelefonico",
    observaciones ,
    posee_convenio "poseeConvenio",
    fiscalizar,
    estimacion_pago "estimacionPago", u.nombre_completo AS "nombreCompleto"
        FROM impuesto.cobranza cob 
        LEFT JOIN impuesto.cartera cart ON cart.id_cartera = cob.id_cartera 
        LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario)
    , pagosramos AS (
    SELECT 
    rm.id_registro_municipal,
    CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, 
    rm.referencia_municipal AS rim,
    cont.razon_social as "razonSocial",
    contactado,
    estatus_telefonico as "estatusTelefonico",
    observaciones ,
    posee_convenio "poseeConvenio",
    fiscalizar,
    estimacion_pago "estimacionPago",
    rm.telefono_celular AS telefono,
    COALESCE(lae.apr, 0) AS "pagoAE", 
    COALESCE(lsm.apr, 0) AS "pagoSM",
    COALESCE(liu.apr, 0) AS "pagoIU",
    COALESCE(lpp.apr, 0) AS "pagoPP",
    COALESCE(lmul.apr, 0) AS "pagoMUL",
    (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lmul.apr, 0)) / 10.0 AS PROGRESO
    
    
    FROM impuesto.cobranza c
    INNER JOIN Impuesto.registro_municipal rm ON rm.id_registro_municipal = c.id_registro_municipal
    INNER JOIN Impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr 
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = 'agosto' OR datos#>>'{fecha, month}' = 'septiembre') 
                AND datos#>>'{fecha, year}' = '2020' 
                AND id_subramo IN (10, 99)) lae ON lae.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr 
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = 'agosto') 
                AND datos#>>'{fecha, year}' = '2020' 
                AND id_subramo IN (66, 102, 107, 108)) lsm ON lsm.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS  apr 
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = 'agosto') 
                AND datos#>>'{fecha, year}' = '2020' 
                AND id_subramo IN (9, 103)) liu ON liu.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr 
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = 'agosto') 
                AND datos#>>'{fecha, year}' = '2020' 
                AND id_subramo IN (12, 104)) lpp ON lpp.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr 
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = 'agosto') 
                AND datos#>>'{fecha, year}' = '2020' 
                AND id_subramo IN (101, 105, 30)) lmul ON lmul.id_registro_municipal = rm.id_registro_municipal
    )
    SELECT pr.rif, pr.rim, pr."razonSocial", pr.telefono, c.*, pr."pagoAE", pr."pagoSM", pr."pagoIU", pr."pagoPP", pr."pagoMUL", pr.progreso
    FROM cobranz c INNER JOIN pagosramos pr ON c.id_registro_municipal = pr.id_registro_municipal
    ORDER BY c."idCobranza";`,
  GET_CHARGINGS_BY_WALLET: `WITH cobranz AS (
    SELECT id_registro_municipal, id_cobranza AS "idCobranza", cob.id_cartera AS "idCartera", cob.contactado, estatus_telefonico as "estatusTelefonico",
    observaciones ,
    posee_convenio "poseeConvenio",
    fiscalizar, rating,
    estimacion_pago "estimacionPago", u.nombre_completo AS "nombreCompleto"
        FROM impuesto.cobranza cob 
        LEFT JOIN impuesto.cartera cart ON cart.id_cartera = cob.id_cartera 
        LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario
        WHERE cob.id_cartera = $1)
    , pagosramos AS (
    SELECT 
    rm.id_registro_municipal,
    CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, 
    rm.referencia_municipal AS rim,
    cont.razon_social as "razonSocial",
    contactado,
    estatus_telefonico as "estatusTelefonico",
    observaciones ,
    posee_convenio "poseeConvenio",
    fiscalizar,
    estimacion_pago "estimacionPago",
    rm.telefono_celular AS telefono,
    COALESCE(lae.apr, 0) AS "pagoAE", 
    COALESCE(lsm.apr, 0) AS "pagoSM",
    COALESCE(liu.apr, 0) AS "pagoIU",
    COALESCE(lpp.apr, 0) AS "pagoPP",
    COALESCE(lmul.apr, 0) AS "pagoMUL",
    COALESCE(lae.monto, 0) AS "montoAE", 
    COALESCE(lsm.monto, 0) AS "montoSM",
    COALESCE(liu.monto, 0) AS "montoIU",
    COALESCE(lpp.monto, 0) AS "montoPP",
    COALESCE(lmul.monto, 0) AS "montoMUL",
    (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lmul.apr, 0)) / 10.0 AS PROGRESO
    
    
    FROM impuesto.cobranza c
    INNER JOIN Impuesto.registro_municipal rm ON rm.id_registro_municipal = c.id_registro_municipal
    INNER JOIN Impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = $2) 
                AND datos#>>'{fecha, year}' = $3 
                AND id_subramo IN (10, 99) GROUP BY id_registro_municipal, s.aprobado) lae ON lae.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = $4) 
                AND datos#>>'{fecha, year}' = $5 
                AND id_subramo IN (66, 102, 107, 108) GROUP BY id_registro_municipal, s.aprobado) lsm ON lsm.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS  apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = $4) 
                AND datos#>>'{fecha, year}' = $5 
                AND id_subramo IN (9, 103) GROUP BY id_registro_municipal, s.aprobado) liu ON liu.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = $4) 
                AND datos#>>'{fecha, year}' = $5 
                AND id_subramo IN (12, 104) GROUP BY id_registro_municipal, s.aprobado) lpp ON lpp.id_registro_municipal = rm.id_registro_municipal
    LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                FROM impuesto.liquidacion l
                INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                WHERE (datos#>>'{fecha, month}' = $4) 
                AND datos#>>'{fecha, year}' = $5 
                AND id_subramo IN (101, 105, 30) GROUP BY id_registro_municipal, s.aprobado) lmul ON lmul.id_registro_municipal = rm.id_registro_municipal
    )
    SELECT pr.rif, pr.rim, pr."razonSocial", pr.telefono, c.*, pr."pagoAE", pr."montoAE", pr."pagoSM", pr."montoSM", pr."pagoIU", pr."montoIU", pr."pagoPP",pr."montoPP", pr."pagoMUL", pr."montoMUL", pr.progreso
    FROM cobranz c INNER JOIN pagosramos pr ON c.id_registro_municipal = pr.id_registro_municipal
    ORDER BY c."idCobranza";`,
  GET_CHARGINGS_BY_WALLET_EXCEL: `WITH cobranz AS (
      SELECT id_registro_municipal, CASE cob.contactado WHEN true THEN 'Si' ELSE 'No' END AS contactado, estatus_telefonico as "estatusTelefonico",
        observaciones ,
        CASE posee_convenio WHEN true THEN 'Si' ELSE 'No' END AS "poseeConvenio",
        CASE fiscalizar WHEN true THEN 'Si' ELSE 'No' END as fiscalizar, rating,
        estimacion_pago "estimacionPago", u.nombre_completo AS "nombreCompleto"
          FROM impuesto.cobranza cob 
          LEFT JOIN impuesto.cartera cart ON cart.id_cartera = cob.id_cartera 
          LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario
          WHERE cob.id_cartera = $1)
      , pagosramos AS (
      SELECT 
      rm.id_registro_municipal,
      CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, 
      rm.referencia_municipal AS rim,
      cont.razon_social as "razonSocial",
      contactado,
      estatus_telefonico as "estatusTelefonico",
      observaciones ,
      posee_convenio "poseeConvenio",
      fiscalizar,
      estimacion_pago "estimacionPago",
      rm.telefono_celular AS telefono,
      COALESCE(lae.apr, 0) AS "pagoAE", 
      COALESCE(lsm.apr, 0) AS "pagoSM",
      COALESCE(liu.apr, 0) AS "pagoIU",
      COALESCE(lpp.apr, 0) AS "pagoPP",
      COALESCE(lmul.apr, 0) AS "pagoMUL",
      COALESCE(lae.monto, 0) AS "montoAE", 
      COALESCE(lsm.monto, 0) AS "montoSM",
      COALESCE(liu.monto, 0) AS "montoIU",
      COALESCE(lpp.monto, 0) AS "montoPP",
      COALESCE(lmul.monto, 0) AS "montoMUL",
      CASE WHEN 
      lmul.apr != 0 THEN
        (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lmul.apr, 0)) / 15.0 
      ELSE
      (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0)) / 12.0 
      END AS PROGRESO
      
      
      FROM impuesto.cobranza c
      INNER JOIN Impuesto.registro_municipal rm ON rm.id_registro_municipal = c.id_registro_municipal
      INNER JOIN Impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $2) 
                  AND datos#>>'{fecha, year}' = $3 
                  AND id_subramo IN (10, 99) GROUP BY id_registro_municipal, s.aprobado) lae ON lae.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (66, 102, 107, 108) GROUP BY id_registro_municipal, s.aprobado) lsm ON lsm.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS  apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (9, 103) GROUP BY id_registro_municipal, s.aprobado) liu ON liu.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (12, 104) GROUP BY id_registro_municipal, s.aprobado) lpp ON lpp.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (101, 105, 30) GROUP BY id_registro_municipal, s.aprobado) lmul ON lmul.id_registro_municipal = rm.id_registro_municipal
      )
      SELECT pr.rif, pr.rim, pr."razonSocial", c.*, pr.telefono,
      CASE pr."pagoAE" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoAE", pr."montoAE", 
      CASE pr."pagoSM" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoSM", pr."montoSM", 
      CASE pr."pagoIU" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoIU", pr."montoIU", 
      CASE pr."pagoPP" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoPP", pr."montoPP", 
      CASE pr."pagoAE" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoMUL", pr."montoMUL", 
      pr.progreso
      FROM cobranz c INNER JOIN pagosramos pr ON c.id_registro_municipal = pr.id_registro_municipal;`,
  GET_CHARGINGS_BY_WALLET_AR: `WITH cobranz AS (
      SELECT id_registro_municipal, id_cobranza AS "idCobranza", cob.id_cartera AS "idCartera", cob.contactado, estatus_telefonico as "estatusTelefonico",
      observaciones ,
      posee_convenio "poseeConvenio",
      fiscalizar, rating,
      estimacion_pago "estimacionPago", u.nombre_completo AS "nombreCompleto"
          FROM impuesto.cobranza cob 
          LEFT JOIN impuesto.cartera cart ON cart.id_cartera = cob.id_cartera 
          LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario
          WHERE cob.id_cartera = $1)
      , pagosramos AS (
      SELECT 
      rm.id_registro_municipal,
      CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, 
      rm.referencia_municipal AS rim,
      cont.razon_social as "razonSocial",
      contactado,
      estatus_telefonico as "estatusTelefonico",
      observaciones ,
      posee_convenio "poseeConvenio",
      fiscalizar,
      rm.telefono_celular AS telefono,
      estimacion_pago "estimacionPago",
      COALESCE(lae.apr, 0) AS "pagoAE", 
      COALESCE(lsm.apr, 0) AS "pagoSM",
      COALESCE(liu.apr, 0) AS "pagoIU",
      COALESCE(lpp.apr, 0) AS "pagoPP",
      COALESCE(lmul.apr, 0) AS "pagoMUL",
      COALESCE(lret.apr, 0) AS pago_ret,
      COALESCE(lae.monto, 0) AS "montoAE", 
      COALESCE(lsm.monto, 0) AS "montoSM",
      COALESCE(liu.monto, 0) AS "montoIU",
      COALESCE(lpp.monto, 0) AS "montoPP",
      COALESCE(lmul.monto, 0) AS "montoMUL",
      COALESCE(lret.monto, 0) AS monto_ret,
      CASE WHEN 
      lmul.apr != 0 THEN
        (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lret.apr, 0) + COALESCE(lmul.apr, 0)) / 15.0 
      ELSE
      (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lret.apr, 0)) / 12.0 
      END AS PROGRESO
      
      
      FROM impuesto.cobranza c
      INNER JOIN Impuesto.registro_municipal rm ON rm.id_registro_municipal = c.id_registro_municipal
      INNER JOIN Impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $2) 
                  AND datos#>>'{fecha, year}' = $3 
                  AND id_subramo IN (10, 99) GROUP BY id_registro_municipal, s.aprobado) lae ON lae.id_registro_municipal = rm.id_registro_municipal 
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (66, 102, 107, 108)  GROUP BY id_registro_municipal, s.aprobado) lsm ON lsm.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS  apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (9, 103)  GROUP BY id_registro_municipal, s.aprobado) liu ON liu.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (12, 104)  GROUP BY id_registro_municipal, s.aprobado) lpp ON lpp.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                  FROM impuesto.liquidacion l
                  INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                  WHERE (datos#>>'{fecha, month}' = $4) 
                  AND datos#>>'{fecha, year}' = $5 
                  AND id_subramo IN (101, 105, 30)  GROUP BY id_registro_municipal, s.aprobado) lmul ON lmul.id_registro_municipal = rm.id_registro_municipal
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
      FROM impuesto.liquidacion l
      INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
      WHERE (datos#>>'{fecha, month}' = $4) 
      AND datos#>>'{fecha, year}' = $5 
      AND id_subramo IN (52)  GROUP BY id_registro_municipal, s.aprobado) lret ON lret.id_registro_municipal = rm.id_registro_municipal
      )
      SELECT pr.rif, pr.rim, pr."razonSocial", pr.telefono, c.*, pr."pagoAE", pr."montoAE", pr."pagoSM", pr."montoSM", pr."pagoIU", pr."montoIU", pr."pagoPP",pr."montoPP", pr."pagoMUL", pr."montoMUL", pr."pago_ret", pr."monto_ret", pr.progreso
      FROM cobranz c INNER JOIN pagosramos pr ON c.id_registro_municipal = pr.id_registro_municipal
      ORDER BY c."idCobranza";`,
  GET_CHARGINGS_BY_WALLET_AR_EXCEL: `WITH cobranz AS (
        SELECT id_registro_municipal, CASE cob.contactado WHEN true THEN 'Si' ELSE 'No' END AS contactado, estatus_telefonico as "estatusTelefonico",
        observaciones ,
        CASE posee_convenio WHEN true THEN 'Si' ELSE 'No' END AS "poseeConvenio",
        CASE fiscalizar WHEN true THEN 'Si' ELSE 'No' END as fiscalizar, rating,
        estimacion_pago "estimacionPago", u.nombre_completo AS "nombreCompleto"
            FROM impuesto.cobranza cob 
            LEFT JOIN impuesto.cartera cart ON cart.id_cartera = cob.id_cartera 
            LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario
            WHERE cob.id_cartera = $1)
        , pagosramos AS (
        SELECT 
        rm.id_registro_municipal,
        CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, 
        rm.referencia_municipal AS rim,
        cont.razon_social as "razonSocial",
        contactado,
        estatus_telefonico as "estatusTelefonico",
        observaciones ,
        posee_convenio "poseeConvenio",
        fiscalizar,
        rm.telefono_celular AS telefono,
        estimacion_pago "estimacionPago",
        COALESCE(lae.apr, 0) AS "pagoAE", 
        COALESCE(lsm.apr, 0) AS "pagoSM",
        COALESCE(liu.apr, 0) AS "pagoIU",
        COALESCE(lpp.apr, 0) AS "pagoPP",
        COALESCE(lmul.apr, 0) AS "pagoMUL",
        COALESCE(lret.apr, 0) AS pago_ret,
        COALESCE(lae.monto, 0) AS "montoAE", 
        COALESCE(lsm.monto, 0) AS "montoSM",
        COALESCE(liu.monto, 0) AS "montoIU",
        COALESCE(lpp.monto, 0) AS "montoPP",
        COALESCE(lmul.monto, 0) AS "montoMUL",
        COALESCE(lret.monto, 0) AS monto_ret,
        CASE WHEN 
        lmul.apr != 0 THEN
          (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lret.apr, 0) + COALESCE(lmul.apr, 0)) / 15.0 
        ELSE
          (COALESCE(lae.apr, 0) + COALESCE(lsm.apr, 0) + COALESCE(liu.apr, 0) + COALESCE(lpp.apr, 0) + COALESCE(lret.apr, 0)) / 12.0 
        END AS PROGRESO
        
        
        FROM impuesto.cobranza c
        INNER JOIN Impuesto.registro_municipal rm ON rm.id_registro_municipal = c.id_registro_municipal
        INNER JOIN Impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                    FROM impuesto.liquidacion l
                    INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                    WHERE (datos#>>'{fecha, month}' = $2) 
                    AND datos#>>'{fecha, year}' = $3 
                    AND id_subramo IN (10, 99) GROUP BY id_registro_municipal, s.aprobado) lae ON lae.id_registro_municipal = rm.id_registro_municipal
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                    FROM impuesto.liquidacion l
                    INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                    WHERE (datos#>>'{fecha, month}' = $4) 
                    AND datos#>>'{fecha, year}' = $5 
                    AND id_subramo IN (66, 102, 107, 108)  GROUP BY id_registro_municipal, s.aprobado) lsm ON lsm.id_registro_municipal = rm.id_registro_municipal
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS  apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                    FROM impuesto.liquidacion l
                    INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                    WHERE (datos#>>'{fecha, month}' = $4) 
                    AND datos#>>'{fecha, year}' = $5 
                    AND id_subramo IN (9, 103)  GROUP BY id_registro_municipal, s.aprobado) liu ON liu.id_registro_municipal = rm.id_registro_municipal
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                    FROM impuesto.liquidacion l
                    INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                    WHERE (datos#>>'{fecha, month}' = $4) 
                    AND datos#>>'{fecha, year}' = $5 
                    AND id_subramo IN (12, 104)  GROUP BY id_registro_municipal, s.aprobado) lpp ON lpp.id_registro_municipal = rm.id_registro_municipal
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                    FROM impuesto.liquidacion l
                    INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                    WHERE (datos#>>'{fecha, month}' = $4) 
                    AND datos#>>'{fecha, year}' = $5 
                    AND id_subramo IN (101, 105, 30)  GROUP BY id_registro_municipal, s.aprobado) lmul ON lmul.id_registro_municipal = rm.id_registro_municipal
        LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END as apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
        FROM impuesto.liquidacion l
        INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
        WHERE (datos#>>'{fecha, month}' = $4) 
        AND datos#>>'{fecha, year}' = $5 
        AND id_subramo IN (52)  GROUP BY id_registro_municipal, s.aprobado) lret ON lret.id_registro_municipal = rm.id_registro_municipal
        )
        SELECT pr.rif, pr.rim, pr."razonSocial", pr.telefono, c.*, 
        CASE pr."pagoAE" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoAE", pr."montoAE", 
        CASE pr."pagoSM" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoSM", pr."montoSM", 
        CASE pr."pagoIU" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoIU", pr."montoIU", 
        CASE pr."pagoPP" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoPP", pr."montoPP", 
        CASE pr."pagoAE" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pagoMUL", pr."montoMUL", 
        CASE pr."pago_ret" WHEN 0 THEN 'No declarado' WHEN 1 THEN 'Declarado' WHEN 2 THEN 'Pagado' END AS "pago_ret", pr."monto_ret", 
        pr.progreso
        FROM cobranz c INNER JOIN pagosramos pr ON c.id_registro_municipal = pr.id_registro_municipal;`,
  GET_WALLETS: `SELECT cart.id_cartera AS "idCartera", cart.id_usuario as "idUsuario", u.nombre_completo AS "nombreCompleto", 
  es_ar AS "esAr", SUM(CASE WHEN contactado = true THEN 1 ELSE 0 END)::numeric / count(*) AS "porcentajeContactado", 
  SUM(CASE WHEN lae.apr = 2 THEN 1 ELSE 0 END)::numeric / count(*) AS "porcentajePagado"
      FROM impuesto.cartera cart 
      INNER JOIN impuesto.cobranza cob ON cob.id_cartera = cart.id_cartera
      LEFT JOIN usuario u ON u.id_usuario = cart.id_usuario 
      LEFT JOIN (SELECT DISTINCT ON (id_registro_municipal) id_registro_municipal, CASE WHEN s.aprobado IS NULL THEN 0 WHEN s.aprobado = false THEN 1 WHEN s.aprobado = true THEN 2 END AS apr, CASE WHEN s.aprobado = true THEN SUM(l.monto) ELSE SUM(l.monto_petro * (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO')) END AS monto
                      FROM impuesto.liquidacion l
                      INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud  
                      WHERE (datos#>>'{fecha, month}' = $1) 
                      AND datos#>>'{fecha, year}' = $2
                      AND id_subramo IN (10, 99) GROUP BY id_registro_municipal, s.aprobado) lae ON lae.id_registro_municipal = cob.id_registro_municipal
      GROUP BY cart.id_usuario, cart.id_cartera, u.nombre_completo, es_ar
      ORDER BY cart.id_cartera;`,
  LINK_WALLET_TO_USER: `UPDATE impuesto.cartera SET id_usuario = $2 WHERE id_cartera = $1 RETURNING id_cartera AS "idCartera", id_usuario AS "idUsuario";`,
  CREATE_CHARGINGS: `INSERT INTO impuesto.cobranza (id_registro_municipal, rating)
  SELECT DISTINCT ON (l.id_registro_municipal) l.id_registro_municipal,
  CASE 
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '0 days' AND interval '10 days' THEN '5'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '11 days' AND interval '15 days' THEN '4'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '16 days' AND interval '20 days' THEN '3'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '21 days' AND interval '25 days' THEN '2'
      ELSE '1'
  END AS rating
  FROM (
        SELECT l.monto, id_solicitud, l.id_registro_municipal
        FROM (SELECT *, datos#>>'{fecha,month}' AS mes, datos#>>'{fecha,year}' AS anyo FROM impuesto.liquidacion WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2) l
        INNER JOIN (
                      SELECT MAX(monto) as monto, id_registro_municipal,  datos#>>'{fecha,month}' as mes, datos#>>'{fecha, year}' as anyo 
                      FROM impuesto.liquidacion WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2
                      GROUP BY id_registro_municipal, mes, anyo
                      ) sub ON sub.monto = l.monto AND sub.mes = l.mes AND sub.anyo = l.anyo AND sub.id_registro_municipal = l.id_registro_municipal       
        ) l
  INNER JOIN impuesto.solicitud s USING (id_solicitud)
  WHERE s.aprobado = true AND id_registro_municipal IN (
    SELECT * FROM (
        SELECT id_registro_municipal FROM (SELECT DISTINCT ON (l.id_registro_municipal) l.id_registro_municipal, SUM(monto) as montoTotal 
        FROM Impuesto.liquidacion l
        INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud
        INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = l.id_registro_municipal
        INNER JOIN impuesto.contribuyente cont ON s.id_contribuyente = cont.id_contribuyente AND rm.id_contribuyente = cont.id_contribuyente
        WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2 AND s.aprobado = true AND cont.es_agente_retencion = false
        GROUP BY l.id_registro_municipal 
        ) x  ORDER BY montoTotal DESC LIMIT $4 ) X   ) 
      LIMIT $4 RETURNING *;
`,
  CREATE_CHARGINGS_AR: `INSERT INTO impuesto.cobranza (id_registro_municipal, rating)
  SELECT DISTINCT ON (l.id_registro_municipal) l.id_registro_municipal, 
  CASE 
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '0 days' AND interval '10 days' THEN '5'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '11 days' AND interval '15 days' THEN '4'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '16 days' AND interval '20 days' THEN '3'
      WHEN (s.fecha_aprobado::timestamptz - cast(date_trunc('month', $3::date) as timestamptz) ) BETWEEN interval '21 days' AND interval '25 days' THEN '2'
      ELSE '1'  
  END AS rating
  FROM (
    SELECT l.monto, id_solicitud, rmar.id_registro_municipal
    FROM (SELECT rm.* FROM impuesto.registro_municipal rm INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = rm.id_contribuyente WHERE c.es_agente_retencion = true AND rm.referencia_municipal NOT LIKE 'AR%') rmar
    LEFT JOIN (SELECT *, datos#>>'{fecha,month}' AS mes, datos#>>'{fecha,year}' AS anyo FROM impuesto.liquidacion WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2) l ON l.id_registro_municipal = rmar.id_registro_municipal
    LEFT JOIN (
                  SELECT MAX(monto) as monto, id_registro_municipal,  datos#>>'{fecha,month}' as mes, datos#>>'{fecha, year}' as anyo 
                  FROM impuesto.liquidacion WHERE id_subramo = 10 AND datos#>>'{fecha,month}' = $1 AND datos#>>'{fecha,year}' = $2
                  GROUP BY id_registro_municipal, mes, anyo
                  ) sub ON sub.monto = l.monto AND sub.mes = l.mes AND sub.anyo = l.anyo AND sub.id_registro_municipal = l.id_registro_municipal        
    ) l
  LEFT JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud
  RETURNING *;
`,
  UPDATE_CHARGING: `UPDATE impuesto.cobranza SET contactado = $2, 
    estatus_telefonico = $3, 
    observaciones = $4, 
    posee_convenio = $5, 
    fiscalizar = $6, 
    estimacion_pago = $7 WHERE id_cobranza = $1 RETURNING id_cobranza AS "idCobranza", id_registro_municipal, contactado, estatus_telefonico AS "estatusTelefonico", observaciones, posee_convenio AS "poseeConvenio",
    fiscalizar, estimacion_pago AS "estimacionPago";`,
  CREATE_WALLET: `INSERT INTO impuesto.cartera (id_cartera, id_usuario, es_ar) VALUES (default, null, $1) RETURNING *`,
  SET_WALLET: `UPDATE impuesto.cobranza SET id_cartera = $1 WHERE id_cobranza = $2`,

  CHARGINGS_GROUPED: `SELECT rating, COUNT(*) FROM impuesto.cobranza GROUP BY rating;`,

  //FISCALIZACION
  INSERT_FISCALIZATION: `INSERT INTO impuesto.fiscalizacion (id_registro_municipal, tipo) VALUES ($1, $2) RETURNING id_fiscalizacion AS "idFiscalizacion", id_registro_municipal AS "idRegistroMunicipal",
              id_usuario AS "idUsuario", tipo, fecha, medida, estado, auditoria, comparecio`,
  GET_FISCALIZATIONS: `SELECT id_fiscalizacion AS "idFiscalizacion", rm.id_registro_municipal AS "idRegistroMunicipal", id_usuario AS "idUsuario", tipo, 
        fecha, medida, estado, auditoria, comparecio, CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, rm.referencia_municipal as rim, cont.razon_social as "razonSocial",
        rm.telefono_celular AS telefono, rm.direccion 
    FROM impuesto.fiscalizacion f
    INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = f.id_registro_municipal
    INNER JOIN impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente`,
  GET_FISCALIZATIONS_ID: `SELECT id_fiscalizacion AS "idFiscalizacion", rm.id_registro_municipal AS "idRegistroMunicipal", id_usuario AS "idUsuario", tipo, 
    fecha, medida, estado, auditoria, comparecio, CONCAT(cont.tipo_documento, '-', cont.documento) AS rif, rm.referencia_municipal as rim, cont.razon_social as "razonSocial",
    rm.telefono_celular AS telefono, rm.direccion 
    FROM impuesto.fiscalizacion f
    INNER JOIN impuesto.registro_municipal rm ON rm.id_registro_municipal = f.id_registro_municipal
    INNER JOIN impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
    WHERE id_fiscalizacion = $1`,
  UPDATE_FISCALIZATION: `UPDATE impuesto.fiscalizacion SET id_usuario = $2, medida = $3, estado = $4, auditoria = $5, comparecio = $6 WHERE id_fiscalizacion = $1 RETURNING id_fiscalizacion AS "idFiscalizacion", medida, estado, auditoria, comparecio, id_usuario AS "idUsuario"`,

  // ? BAREMO

  GET_SCALE_FOR_COMMERCIAL_ESTATE_MTS_COST: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 1`,
  GET_SCALE_FOR_COMMERCIAL_ESTATE_PETRO_LIMIT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 2`,

  GET_SCALE_FOR_PERMANENT_AE_SOLVENCY: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 3`,
  GET_SCALE_FOR_PROVISIONAL_AE_SOLVENCY: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 4`,

  GET_SCALE_FOR_INDUSTRIAL_ESTATE_MTS_COST: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 5`,
  GET_SCALE_FOR_INDUSTRIAL_ESTATE_PETRO_LIMIT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 6`,

  GET_SCALE_FOR_AE_FINING_LIMIT_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 7`,
  GET_SCALE_FOR_AE_FINING_STARTING_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 8`,
  GET_SCALE_FOR_AE_FINING_AUGMENT_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 9`,

  GET_SCALE_FOR_RETENTION_FINING_LIMIT_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 10`,
  GET_SCALE_FOR_RETENTION_FINING_STARTING_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 11`,
  GET_SCALE_FOR_RETENTION_FINING_AUGMENT_AMOUNT: `SELECT indicador FROM impuesto.baremo WHERE id_baremo = 12`,

  // VEHICULOS
  GET_VEHICLE_BRANDS: `SELECT id_marca_vehiculo AS id, nombre FROM impuesto.marca_vehiculo ORDER BY nombre;`,
  GET_VEHICLE_TYPES: `SELECT id_tipo_vehiculo AS id, descripcion FROM impuesto.tipo_vehiculo ORDER BY id_tipo_vehiculo`,
  GET_VEHICLE_CATEGORIES: `SELECT id_categoria_vehiculo AS id, descripcion FROM impuesto.categoria_vehiculo ORDER BY id_categoria_vehiculo`,
  GET_VEHICLE_CATEGORIES_BY_TYPE: `SELECT id_categoria_vehiculo AS id, descripcion FROM impuesto.categoria_vehiculo WHERE id_tipo_vehiculo = $1 ORDER BY id_categoria_vehiculo`,
  GET_VEHICLE_SUBCATEGORIES_BY_CATEGORY: `SELECT sv.id_subcategoria_vehiculo AS id, sv.descripcion, ROUND(((SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO') * sv.tarifa)) AS costo FROM impuesto.subcategoria_vehiculo sv WHERE id_categoria_vehiculo = $1 ORDER BY id_subcategoria_vehiculo`,
  GET_VEHICLE_BY_ID: `SELECT v.id_vehiculo AS id, mv.nombre AS marca, sv.id_subcategoria_vehiculo AS idSubcategoria, sv.descripcion AS subcategoria, v.modelo_vehiculo AS modelo,
  v.placa_vehiculo AS placa, v.anio_vehiculo AS anio, v.color_vehiculo AS color, v.fecha_ultima_actualizacion AS "fechaUltimaActualizacion",
  v.serial_carroceria_vehiculo AS "serialCarroceria", v.tipo_carroceria_vehiculo AS "tipoCarroceria",
  v.tipo_combustible_vehiculo AS "tipoCombustible", v.peso_vehiculo AS peso, v.cilindraje_vehiculo AS cilindraje, v.serial_motor_vehiculo AS "serialMotor", cv.id_categoria_vehiculo AS idCategoria, cv.descripcion AS categoria, cedula_propietario AS "cedulaPropietario", nombre_propietario AS "nombrePropietario"
  FROM impuesto.marca_vehiculo mv 
  INNER JOIN impuesto.vehiculo v USING (id_marca_vehiculo) 
  INNER JOIN impuesto.subcategoria_vehiculo sv USING (id_subcategoria_vehiculo)
  INNER JOIN impuesto.categoria_vehiculo cv USING (id_categoria_vehiculo)
  WHERE id_vehiculo = $1
  ORDER BY v.id_vehiculo`,
  CREATE_VEHICLE: `INSERT INTO impuesto.vehiculo (id_marca_vehiculo, id_registro_municipal, id_subcategoria_vehiculo, modelo_vehiculo, placa_vehiculo, anio_vehiculo, color_vehiculo, fecha_ultima_actualizacion, serial_carroceria_vehiculo, tipo_carroceria_vehiculo, tipo_combustible_vehiculo, peso_vehiculo, cilindraje_vehiculo, serial_motor_vehiculo, cedula_propietario, nombre_propietario) VALUES ($1, $2, $3, $4, $5, $6, $7, null, $8, $9, $10, $11, $12, $13, $14, $15) RETURNING *`,
  UPDATE_VEHICLE: `UPDATE impuesto.vehiculo SET id_marca_vehiculo = $1, id_subcategoria_vehiculo = $2, modelo_vehiculo = $3, placa_vehiculo = $4, anio_vehiculo = $5, color_vehiculo = $6, serial_carroceria_vehiculo = $7, peso_vehiculo = $8, cilindraje_vehiculo = $9, serial_motor_vehiculo = $10, cedula_propietario = $12, nombre_propietario = $13 WHERE id_vehiculo = $11 RETURNING *`,
  DELETE_VEHICLE: `DELETE FROM impuesto.vehiculo WHERE id_vehiculo = $1`,
  UPDATE_VEHICLE_SUBCATEGORY: `UPDATE impuesto.subcategoria_vehiculo SET id_valor = $1, tarifa = $2, descripcion = $3, id_categoria_vehiculo = $4 WHERE id_subcategoria_vehiculo = $5 RETURNING *`,
  GET_VEHICLES_BY_CONTRIBUTOR: `SELECT v.id_vehiculo AS id, mv.nombre AS marca, sv.id_subcategoria_vehiculo AS idSubcategoria, sv.descripcion AS subcategoria, v.modelo_vehiculo AS modelo,
  v.placa_vehiculo AS placa, v.anio_vehiculo AS anio, v.color_vehiculo AS color, v.fecha_ultima_actualizacion AS "fechaUltimaActualizacion",
  v.serial_carroceria_vehiculo AS "serialCarroceria", v.tipo_carroceria_vehiculo AS "tipoCarroceria",
  v.tipo_combustible_vehiculo AS "tipoCombustible", v.peso_vehiculo AS peso, v.cilindraje_vehiculo AS cilindraje, v.serial_motor_vehiculo AS "serialMotor", cv.id_categoria_vehiculo AS idCategoria, cv.descripcion AS categoria, l.datos#>>'{fecha, year}' AS "fechaInicio", cedula_propietario AS "cedulaPropietario", nombre_propietario AS "nombrePropietario"
  FROM impuesto.marca_vehiculo mv
  INNER JOIN impuesto.vehiculo v USING (id_marca_vehiculo) 
  INNER JOIN impuesto.subcategoria_vehiculo sv USING (id_subcategoria_vehiculo)
  INNER JOIN impuesto.categoria_vehiculo cv USING (id_categoria_vehiculo)
  JOIN impuesto.vehiculo_contribuyente USING(id_vehiculo)
  LEFT JOIN impuesto.liquidacion l ON v.id_liquidacion_fecha_inicio = l.id_liquidacion
  WHERE id_contribuyente = $1
  ORDER BY v.id_vehiculo`,
  GET_VEHICLES_BY_PLATE: `SELECT v.id_vehiculo AS id, mv.nombre AS marca, sv.id_subcategoria_vehiculo AS idSubcategoria, sv.descripcion AS subcategoria, v.modelo_vehiculo AS modelo,
  v.placa_vehiculo AS placa, v.anio_vehiculo AS anio, v.color_vehiculo AS color, v.fecha_ultima_actualizacion AS "fechaUltimaActualizacion",
  v.serial_carroceria_vehiculo AS "serialCarroceria", v.tipo_carroceria_vehiculo AS "tipoCarroceria",
  v.tipo_combustible_vehiculo AS "tipoCombustible", v.peso_vehiculo AS peso, v.cilindraje_vehiculo AS cilindraje, v.serial_motor_vehiculo AS "serialMotor", cv.id_categoria_vehiculo AS idCategoria, cv.descripcion AS categoria, l.datos#>>'{fecha, year}' AS "fechaInicio", cedula_propietario AS "cedulaPropietario", nombre_propietario AS "nombrePropietario"
  FROM impuesto.marca_vehiculo mv
  INNER JOIN impuesto.vehiculo v USING (id_marca_vehiculo) 
  INNER JOIN impuesto.subcategoria_vehiculo sv USING (id_subcategoria_vehiculo)
  INNER JOIN impuesto.categoria_vehiculo cv USING (id_categoria_vehiculo)
  JOIN impuesto.vehiculo_contribuyente USING(id_vehiculo)
  LEFT JOIN impuesto.liquidacion l ON v.id_liquidacion_fecha_inicio = l.id_liquidacion
  WHERE placa_vehiculo = $1
  ORDER BY v.id_vehiculo`,
  GET_VEHICLES_BY_MUNICIPAL_REFERENCE: `SELECT v.id_vehiculo AS id, mv.nombre AS marca, sv.id_subcategoria_vehiculo AS idSubcategoria, sv.descripcion AS subcategoria, v.modelo_vehiculo AS modelo,
  v.placa_vehiculo AS placa, v.anio_vehiculo AS anio, v.color_vehiculo AS color, v.fecha_ultima_actualizacion AS "fechaUltimaActualizacion",
  v.serial_carroceria_vehiculo AS "serialCarroceria", v.tipo_carroceria_vehiculo AS "tipoCarroceria",
  v.tipo_combustible_vehiculo AS "tipoCombustible", v.peso_vehiculo AS peso, v.cilindraje_vehiculo AS cilindraje, v.serial_motor_vehiculo AS "serialMotor", cv.id_categoria_vehiculo AS idCategoria, cv.descripcion AS categoria, l.datos#>>'{fecha, year}' AS "fechaInicio", cedula_propietario AS "cedulaPropietario", nombre_propietario AS "nombrePropietario"
  FROM impuesto.marca_vehiculo mv 
  INNER JOIN impuesto.vehiculo v USING (id_marca_vehiculo) 
  INNER JOIN impuesto.subcategoria_vehiculo sv USING (id_subcategoria_vehiculo)
  INNER JOIN impuesto.categoria_vehiculo cv USING (id_categoria_vehiculo)
  LEFT JOIN impuesto.liquidacion l ON v.id_liquidacion_fecha_inicio = l.id_liquidacion
  WHERE v.id_registro_municipal = $1
  ORDER BY v.id_vehiculo`,
  CHECK_VEHICLE_EXISTS_FOR_USER: `SELECT 1 FROM impuesto.vehiculo WHERE id_contribuyente = $1 AND placa_vehiculo = $2`,
  CHECK_VEHICLE_EXISTS: `SELECT 1 FROM impuesto.vehiculo WHERE LOWER(placa_vehiculo) = LOWER($1)`,

  UPDATE_VEHICLE_PAYMENT_DATE: `UPDATE impuesto.vehiculo SET fecha_ultima_actualizacion = DEFAULT WHERE id_vehiculo = $1`,
  GET_VEHICLE_SUBCATEGORY_BY_ID: `SELECT descripcion FROM impuesto.subcategoria_vehiculo WHERE id_subcategoria_vehiculo = $1`,
  GET_VEHICLE_BRAND_BY_ID: `SELECT nombre AS descripcion FROM impuesto.marca_vehiculo WHERE id_marca_vehiculo = $1`,
  GET_ASSETS_FOR_VEHICLE_DATA: `SELECT mv.id_marca_vehiculo AS "idMarca", mv.nombre as "nombreMarca", sv.id_subcategoria_vehiculo AS "idSubcategoria", 
  sv.descripcion AS "descripcionSubcategoria", cv.id_categoria_vehiculo AS "idCategoria", 
  cv.descripcion AS "descripcionCategoria", tv.id_tipo_vehiculo AS "idTipo", tv.descripcion AS "descripcionTipo" 
  FROM impuesto.marca_vehiculo mv 
      INNER JOIN impuesto.vehiculo v USING (id_marca_vehiculo)
      INNER JOIN impuesto.subcategoria_vehiculo sv USING (id_subcategoria_vehiculo)
      INNER JOIN impuesto.categoria_vehiculo cv USING (id_categoria_vehiculo)
      INNER JOIN impuesto.tipo_vehiculo tv USING (id_tipo_vehiculo)
      WHERE v.id_vehiculo = $1`,
  // CONDOMINIO
  GET_CONDO_PAYMENTS: `
  SELECT cp.id_contribuyente, s.fecha_aprobado, l.fecha_liquidacion, l.id_subramo, l.monto, l.monto_petro 
  FROM impuesto.condominio_propietario cp 
  INNER JOIN impuesto.contribuyente cont ON cp.id_contribuyente = cont.id_contribuyente 
  INNER JOIN impuesto.condominio cond ON cond.id_condominio = cp.id_condominio 
  INNER JOIN impuesto.solicitud s ON s.id_contribuyente = cont.id_contribuyente 
  INNER JOIN impuesto.liquidacion l ON l.id_solicitud = s.id_solicitud 
  WHERE cp.id_condominio = $1
  AND fecha_aprobado IS NOT null 
  AND l.id_subramo IN ($2)
  ORDER BY fecha_aprobado DESC 
  limit 1
  `,
  EDIT_CONDO_TYPE_BY_ID: 'UPDATE impuesto.condominio SET id_tipo_condominio = $2 WHERE id_condominio = $1 RETURNING *;',
  EDIT_CONDO_APART_BY_ID: 'UPDATE impuesto.condominio SET apartamentos = $2 WHERE id_condominio = $1 RETURNING *;',
  GET_ALL_CONDO_TYPES: 'SELECT * FROM impuesto.tipo_condominio',
  GET_CONDOMINIUM_TYPE_BY_ID: 'SELECT tipo_condominio, tarifa_gas, tarifa_aseo, tarifa_inmueble_urbano FROM impuesto.condominio JOIN impuesto.tipo_condominio USING (id_tipo_condominio) WHERE id_condominio = $1',
  GET_CONDOMINIUMS: `
      SELECT id_condominio AS "idCondominio", CONCAT(cont.tipo_documento, '-', cont.documento) AS documento, cont.razon_social AS "razonSocial", cond.apartamentos
      FROM impuesto.contribuyente cont
      INNER JOIN impuesto.condominio cond ON cond.id_contribuyente = cont.id_contribuyente;
  `,
  GET_CONDOMINIUM: `
      SELECT id_condominio AS "idCondominio", CONCAT(cont.tipo_documento, '-', cont.documento) AS documento, cont.razon_social AS "razonSocial", cond.apartamentos, p.nombre as "parroquia"
      FROM impuesto.contribuyente cont
      INNER JOIN parroquia p ON p.id = cont.id_parroquia
      INNER JOIN impuesto.condominio cond ON cond.id_contribuyente = cont.id_contribuyente
      WHERE id_condominio = $1
  `,
  GET_CONDOMINIUM_BY_DOC: `
      SELECT id_condominio AS "idCondominio", CONCAT(cont.tipo_documento, '-', cont.documento) AS documento, cont.razon_social AS "razonSocial", cond.apartamentos, p.nombre as "parroquia"
      FROM impuesto.contribuyente cont
      INNER JOIN parroquia p ON p.id = cont.id_parroquia
      INNER JOIN impuesto.condominio cond ON cond.id_contribuyente = cont.id_contribuyente
      WHERE cont.tipo_documento = $1 AND cont.documento = $2;
  `,
  GET_CONDOMINIUM_OWNERS: `
      SELECT id_condominio AS "idCondominio", cont.id_contribuyente as "idContribuyente", CONCAT(cont.tipo_documento, '-', cont.documento) AS documento, cont.razon_social AS "razonSocial", p.nombre as "parroquia", cont.direccion 
      FROM impuesto.contribuyente cont
      LEFT JOIN parroquia p ON p.id = cont.id_parroquia
      INNER JOIN impuesto.condominio_propietario cp ON cp.id_contribuyente = cont.id_contribuyente
      WHERE cp.id_condominio = $1;
  `,
  GET_CONDOMINIUM_OWNER_BY_DOC: `
      SELECT id_condominio AS "idCondominio", CONCAT(cont.tipo_documento, '-', cont.documento) AS documento, cont.razon_social AS "razonSocial", p.nombre as "parroquia", cont.direccion
      FROM impuesto.contribuyente cont
      LEFT JOIN parroquia p ON p.id = cont.id_parroquia
      INNER JOIN impuesto.condominio_propietario cp ON cont.id_contribuyente = cp.id_contribuyente
      WHERE cont.tipo_documento = $1 AND cont.documento = $2;
  `,
  CREATE_CONDOMINIUM: `
      INSERT INTO impuesto.condominio (id_contribuyente) 
      VALUES ((SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2))
      RETURNING id_condominio
  `,
  DELETE_CONDOMINIUM: `
      DELETE FROM impuesto.condominio WHERE id_condominio = $1;
  `,
  ADD_CONDO_OWNER: `
      INSERT INTO impuesto.condominio_propietario (id_contribuyente, id_condominio) 
      VALUES ((SELECT id_contribuyente FROM impuesto.contribuyente WHERE tipo_documento = $1 AND documento = $2), $3)
  `,
  DELETE_CONDO_OWNER: `
      DELETE FROM impuesto.condominio_propietario WHERE id_condominio = $1 AND id_contribuyente = $2;
  `,
  // Validatedoc
  APPROVED_FINING_BY_DOC: `SELECT * FROM multa WHERE nacionalidad = $1 AND cedula = $2 AND aprobado = false;`,
  APPROVED_FINING_BY_VEHICLE_PLATE: `SELECT * FROM multa WHERE LOWER(CASE WHEN datos#>>'{funcionario, placa}' IS NOT NULL THEN datos#>>'{funcionario, placa}' ELSE 'N/A' END) = LOWER($1)  AND aprobado = false;`,
  IS_VEHICLE_UP_TO_DATE: `SELECT CASE 
                                  WHEN cv.id_tipo_vehiculo = 1 
                                  THEN EXTRACT('year' FROM fecha_ultima_actualizacion) = EXTRACT('year' FROM current_timestamp) 
                                      AND EXTRACT('month' FROM fecha_ultima_actualizacion) = EXTRACT('month' FROM current_timestamp)
                                  WHEN cv.id_tipo_vehiculo = 2
                                  THEN EXTRACT('year' FROM fecha_ultima_actualizacion) = EXTRACT('year' FROM current_timestamp) 
                                  END
                                  AS solvente
                          FROM impuesto.vehiculo v
                          INNER JOIN impuesto.subcategoria_vehiculo scv ON scv.id_subcategoria_vehiculo = v.id_subcategoria_vehiculo
                          INNER JOIN impuesto.categoria_vehiculo cv ON cv.id_categoria_vehiculo = scv.id_categoria_vehiculo
                          WHERE LOWER(placa_vehiculo) = LOWER($1)`,
  gtic: {
    GET_NATURAL_CONTRIBUTOR:
      'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE nu_cedula = $1 AND tx_tp_doc = $2 AND (trim(nb_representante_legal) NOT IN (SELECT trim(nb_marca) FROM tb014_marca_veh) AND trim(nb_representante_legal) NOT IN (SELECT trim(tx_marca) FROM t45_vehiculo_marca) OR trim(nb_representante_legal) IS NULL) ORDER BY co_contribuyente DESC',
    GET_JURIDICAL_CONTRIBUTOR:
      'SELECT DISTINCT ON (nu_referencia) * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE tx_rif = $1 AND tx_tp_doc = $2 AND nu_referencia IS NOT NULL AND trim(nb_representante_legal) NOT IN (SELECT trim(nb_marca) FROM tb014_marca_veh) AND trim(nb_representante_legal) NOT IN (SELECT trim(tx_marca) FROM t45_vehiculo_marca)',
    GET_CONTRIBUTOR_BY_ID: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE co_contribuyente = $1',
    NATURAL_CONTRIBUTOR_EXISTS: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE nu_cedula = $1 AND tx_tp_doc = $2;',
    JURIDICAL_CONTRIBUTOR_EXISTS: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE tx_rif = $1 AND nu_referencia = $2 AND tx_tp_doc = $3',
    CONTRIBUTOR_ECONOMIC_ACTIVITIES:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT DISTINCT ON (ca.nu_ref_actividad) * FROM tb041_contrib_act ca \
    INNER JOIN tb039_ae_actividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
    INNER JOIN (SELECT MAX(co_ordenanza) as co_ordenanza, nu_anio FROM tb035_anio_ordenanza GROUP BY nu_anio order by co_ordenanza) ao ON ao.co_ordenanza = ae.co_ordenanza \
    WHERE co_contribuyente = $1 \
    AND ca.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) \
    AND ao.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza);',
    ECONOMIC_ACTIVITIES_JURIDICAL:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT DISTINCT ON (ae.nu_ref_actividad) * FROM tb041_contrib_act ca \
    INNER JOIN tb004_contribuyente c ON ca.co_contribuyente = c.co_contribuyente \
    INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo \
    INNER JOIN tb039_ae_actividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
    INNER JOIN (SELECT MAX(co_ordenanza) as co_ordenanza, nu_anio FROM tb035_anio_ordenanza GROUP BY nu_anio order by co_ordenanza) ao ON ao.co_ordenanza = ae.co_ordenanza \
    WHERE tc.tx_tp_doc = $1 AND c.tx_rif = $2 \
    AND ca.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) \
    AND ao.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza);',
    ECONOMIC_ACTIVIES_NATURAL:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT DISTINCT ON (ae.nu_ref_actividad) * FROM tb041_contrib_act ca \
    INNER JOIN tb004_contribuyente c ON ca.co_contribuyente = c.co_contribuyente \
    INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo \
    INNER JOIN tb039_ae_actividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
    INNER JOIN (SELECT MAX(co_ordenanza) as co_ordenanza, nu_anio FROM tb035_anio_ordenanza GROUP BY nu_anio order by co_ordenanza) ao ON ao.co_ordenanza = ae.co_ordenanza \
    WHERE tc.tx_tp_doc = $1 AND c.nu_cedula = $2 \
    AND ca.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) \
    AND ao.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza);',
    GET_ACTIVE_ECONOMIC_ACTIVITIES_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 87 AND co_estatus = 1 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC',
    GET_ACTIVE_MUNICIPAL_SERVICES_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 175 AND co_estatus = 1 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC',
    GET_ACTIVE_URBAN_ESTATE_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 445 AND co_estatus = 1 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC',
    GET_ACTIVE_PUBLICITY_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 97 AND co_estatus = 1 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC',
    GET_PAID_ECONOMIC_ACTIVITIES_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 87 AND co_estatus = 2 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC LIMIT 1',
    GET_PAID_MUNICIPAL_SERVICES_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 175 AND co_estatus = 2 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC LIMIT 1',
    GET_PAID_URBAN_ESTATE_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 445 AND co_estatus = 2 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC LIMIT 1',
    GET_PAID_PUBLICITY_SETTLEMENT: 'SELECT * FROM tb079_liquidacion WHERE co_tipo_solicitud = 97 AND co_estatus = 2 AND co_contribuyente = $1 ORDER BY co_liquidacion DESC LIMIT 1',
    GET_RESIDENTIAL_CLEANING_TARIFF: 'SELECT * FROM tb031_tarifa_aseo_residencial WHERE fecha_hasta IS NULL;',
    GET_RESIDENTIAL_GAS_TARIFF: 'SELECT * FROM tb032_tarifa_gas_residencial WHERE fecha_hasta IS NULL;',
    GET_MAX_GAS_TARIFF_BY_CONTRIBUTOR:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT * FROM tb041_contrib_act ca \
    INNER JOIN tb039_ae_actividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
    INNER JOIN (SELECT MAX(co_ordenanza) as co_ordenanza, nu_anio FROM tb035_anio_ordenanza GROUP BY nu_anio order by co_ordenanza) ao ON ao.co_ordenanza = ae.co_ordenanza \
    INNER JOIN tb045_gas_actividad ga ON ga.nu_ref_actividad = ae.nu_ref_actividad \
    WHERE co_contribuyente = $1 \
    AND ca.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) \
    AND ao.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) AND fecha_hasta IS NULL ORDER BY nu_tarifa DESC LIMIT 1;', //Sirve para ambos, juridico y
    GET_MAX_CLEANING_TARIFF_BY_CONTRIBUTOR:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT * FROM tb041_contrib_act ca \
    INNER JOIN tb039_ae_actividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
    INNER JOIN (SELECT MAX(co_ordenanza) as co_ordenanza, nu_anio FROM tb035_anio_ordenanza GROUP BY nu_anio order by co_ordenanza) ao ON ao.co_ordenanza = ae.co_ordenanza \
    INNER JOIN tb030_aseo_actividad ga ON ga.nu_ref_actividad = ae.nu_ref_actividad \
    WHERE co_contribuyente = $1 \
    AND ca.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) \
    AND ao.co_ordenanza = (SELECT co_ordenanza FROM ultima_ordenanza) AND fecha_hasta IS NULL ORDER BY nu_tarifa DESC LIMIT 1;',
    GET_INFO_FOR_AE_CERTIFICATE: 'SELECT * FROM tb034_motivo m INNER JOIN t09_tipo_solicitud ts ON m.co_motivo = ts.co_motivo INNER JOIN tb046_ae_ramo r ON ts.co_ramo = r.co_ramo WHERE ts.co_tipo_solicitud = 87;',
    GET_ESTATES_BY_CONTRIBUTOR:
      'SELECT *, i.tx_direccion AS direccion_inmueble  FROM (SELECT * FROM tb071_contrib_inmueble WHERE in_activo = 1) ci INNER JOIN tb070_inmueble i INNER JOIN tb067_im_tipo_inmueble ti ON i.co_tp_inmueble = ti.co_tp_inmueble ON ci.co_inmueble = i.co_inmueble INNER JOIN tb076_avaluo_inmueble ai ON ai.co_inmueble = i.co_inmueble WHERE co_contribuyente = $1 AND nu_anio = EXTRACT(year FROM CURRENT_TIMESTAMP);',
    GET_PUBLICITY_ARTICLES: 'SELECT * FROM tb104_art_propaganda;',
    GET_PUBLICITY_SUBARTICLES: 'SELECT * FROM tb102_medio_propaganda where CO_ARTICULO is not null;',
    GET_MOTIVE_BY_TYPE_ID: 'SELECT * FROM t09_tipo_solicitud ts INNER JOIN tb034_motivo m ON ts.co_motivo = m.co_motivo WHERE co_tipo_solicitud = $1;',
    GET_BRANCH_BY_TYPE_ID: 'SELECT * FROM t09_tipo_solicitud ts INNER JOIN tb046_ae_ramo r ON r.co_ramo = ts.co_ramo  WHERE co_tipo_solicitud = $1;',
    GET_REPRESENTATIVE_BY_EMAIL: 'SELECT * FROM t01_usuario WHERE da_email = $1;',
    GET_CONTRIBUTOR_BY_REPRESENTATIVE_USER: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE co_usuario_registro = $1 ',
    GET_CONTRIBUTOR_BY_REPRESENTATIVE_USER_EXTENDED: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE co_contribuyente = $1 ORDER BY c.co_contribuyente DESC',
    GET_ESTATES_BY_MUNICIPAL_REGISTRY:
      'SELECT i.*, c.nb_representante_legal FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo INNER JOIN\
       (SELECT * FROM tb071_contrib_inmueble WHERE in_activo = 1) ci ON ci.co_contribuyente = c.co_contribuyente INNER JOIN\
        tb070_inmueble i ON ci.co_inmueble = i.co_inmueble WHERE nu_referencia = $1;',
    GET_SETTLEMENTS_BY_MUNICIPAL_REGISTRY:
      'SELECT l.*, r.* FROM tb004_contribuyente c  INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo INNER JOIN\
       tb079_liquidacion l ON l.co_contribuyente = c.co_contribuyente INNER JOIN tb046_ae_ramo r ON l.co_ramo = r.co_ramo WHERE nu_referencia = $1 AND nu_monto_bolivar_fuerte IS NULL AND \
       l.anio_liquidacion = EXTRACT(year FROM CURRENT_DATE) ORDER BY fe_liquidacion DESC;',
    CHECK_OLDER_SETTLEMENT_EXISTS: `SELECT EXISTS(SELECT * FROM tb079_liquidacion l WHERE l.co_contribuyente = $1 AND l.fe_liquidacion < $2 AND l.co_ramo = $3 AND l.co_motivo != 150);`,
    GET_SETTLEMENTS_BY_CONTRIBUTOR:
      'SELECT l.*, r.* FROM tb004_contribuyente c  INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo INNER JOIN\
    tb079_liquidacion l ON l.co_contribuyente = c.co_contribuyente INNER JOIN tb046_ae_ramo r ON l.co_ramo = r.co_ramo WHERE c.co_contribuyente = $1 AND nu_monto_bolivar_fuerte IS NULL AND \
    l.anio_liquidacion = EXTRACT(year FROM CURRENT_DATE) ORDER BY fe_liquidacion DESC;',
    GET_FISCAL_CREDIT_BY_MUNICIPAL_REGISTRY:
      'SELECT cf.* FROM tb004_contribuyente c  INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo INNER JOIN\
       t67_credito_fiscal cf ON cf.co_contribuyente = c.co_contribuyente WHERE nu_referencia = $1 AND in_activo = true ORDER BY co_credito_fiscal DESC LIMIT 1;',
    GET_FISCAL_CREDIT_BY_CONTRIBUTOR: 'SELECT cf.* FROM t67_credito_fiscal cf WHERE cf.co_contribuyente = $1 AND in_activo = true ORDER BY co_credito_fiscal DESC LIMIT 1;',
    GET_FININGS_BY_MUNICIPAL_REGISTRY:
      'SELECT dm.* FROM tb004_contribuyente c  INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo INNER JOIN\
       tb051_ae_decl_multa dm ON dm.co_contribuyente = c.co_contribuyente INNER JOIN tb079_liquidacion l ON l.co_liquidacion = dm.co_liquidacion_propio \
       INNER JOIN tb046_ae_ramo r ON r.co_ramo = l.co_ramo INNER JOIN tb034_motivo m ON m.co_motivo = l.co_motivo \
       WHERE nu_referencia = $1 AND EXTRACT(YEAR FROM dm.created_at) = EXTRACT(YEAR FROM CURRENT_DATE);',
    GET_FININGS_BY_CONTRIBUTOR:
      'SELECT dm.*,l.*, r.*, m.*, dm.created_at as fecha_liquidacion FROM tb051_ae_decl_multa dm INNER JOIN tb079_liquidacion l ON l.co_liquidacion = dm.co_liquidacion_propio \
      INNER JOIN tb046_ae_ramo r ON r.co_ramo = l.co_ramo INNER JOIN tb034_motivo m ON m.co_motivo = l.co_motivo \
      WHERE dm.co_contribuyente = $1 AND EXTRACT(YEAR FROM dm.created_at) = EXTRACT(YEAR FROM CURRENT_DATE);',
  },
  ADD_MOVEMENT: "INSERT INTO movimientos (id_procedimiento, id_usuario, fecha_movimiento, tipo_movimiento, concepto) VALUES ($1, $2, (NOW() - interval '4 hours'), $3, $4);",
  GET_OBSERVATIONS: 'SELECT * FROM tramite_observaciones WHERE id_tramite = $1 ORDER BY fecha DESC LIMIT 1;',
  GET_ALL_CONTRIBUTORS_WITH_DECLARED_MUNICIPAL_SERVICES: `SELECT nombre_representante, denominacion_comercial, fecha_aprobacion, monto, id_solicitud FROM impuesto.registro_municipal r 
  INNER JOIN (SELECT DISTINCT ON (id_registro_municipal) * FROM 
  (SELECT * FROM impuesto.liquidacion WHERE EXTRACT('month' FROM fecha_liquidacion) = EXTRACT('month' FROM $1::date)
  AND EXTRACT('year' FROM fecha_liquidacion) = EXTRACT('year' FROM $1::date) AND id_subramo = 10) x) l USING (id_registro_municipal);`,
  SAVE_MAP:`INSERT INTO mapa_inmueble (id_inmueble, url) VALUES ($1, $2)`,
};

export default queries;
