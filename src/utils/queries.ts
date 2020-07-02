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
    'SELECT i.*, c.descripcion AS cargo, c.id_cargo AS "idCargo" FROM institucion i INNER JOIN cargo c ON i.id_institucion = c.id_institucion INNER JOIN cuenta_funcionario cf ON c.id_cargo = cf.id_cargo \
    WHERE cf.id_usuario = $1;',
  CHECK_IF_OFFICIAL: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Funcionario' AND u.cedula = $1",
  CHECK_IF_DIRECTOR: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Director' AND u.cedula = $1",
  CHECK_IF_ADMIN: "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Administrador' AND u.cedula = $1",
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
  INSERT_PAYMENT: 'INSERT INTO pago (id_procedimiento, referencia, monto, id_banco, fecha_de_pago, concepto) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *;',
  INSERT_PAYMENT_CASHIER: 'INSERT INTO pago (id_procedimiento, referencia, monto, id_banco, fecha_de_pago, concepto ,aprobado, fecha_de_aprobacion, metodo_pago) VALUES ($1, $2, $3, $4, $5, $6, true, now(), $7) RETURNING *;',

  GET_ALL_BANKS: 'SELECT id_banco as id, nombre, validador  FROM banco',
  VALIDATE_PAYMENTS: 'SELECT validate_payments($1);',
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
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
    from usuario usr INNER JOIN cuenta_funcionario cf ON\
    usr.id_usuario=cf.id_usuario INNER JOIN cargo c ON cf.id_cargo = c.id_cargo WHERE c.id_institucion = $1 AND usr.id_usuario != $2 AND usr.id_tipo_usuario!=1',
  GET_ALL_OFFICIALS:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
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
  INSERT_TAKINGS_IN_PROCEDURE: 'INSERT INTO tramite_archivo_recaudo VALUES ($1,$2)',
  GET_SECTIONS_BY_PROCEDURE: 'SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  campo_tramite ct RIGHT JOIN seccion sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1 ORDER BY sect.id_seccion',
  GET_PROCEDURE_BY_INSTITUTION: 'SELECT id_tipo_tramite, nombre_tramite, costo_base, sufijo, pago_previo, utiliza_informacion_catastral, costo_utmm \
    FROM tipo_tramite tt WHERE id_institucion = $1 ORDER BY id_tipo_tramite',
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND (ct.estado='iniciado' OR ct.estado = 'ingresardatos') \
    ORDER BY ct.orden",
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
  GET_PROCEDURE_DATA: 'SELECT datos FROM tramite WHERE id_tramite=$1',
  GET_SOCIAL_CASES_STATE: 'SELECT * FROM CASOS_SOCIALES_STATE WHERE tipotramite=$1',
  GET_ID_FROM_PROCEDURE_STATE_BY_CODE: 'SELECT id FROM TRAMITES_STATE_WITH_RESOURCES WHERE codigotramite=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION: 'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado \
  FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK:
    'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado as formatoCertificado, ttr.planilla_rechazo as formatoRechazo, ttr.sufijo \
  FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
  GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
    nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, \
    tipo_tramite.pago_previo AS "pagoPrevio" FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
    tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
    tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 ORDER BY tramites_state.fechacreacion;',
  GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
    nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, \
    tipo_tramite.pago_previo AS "pagoPrevio"  FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
    tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
    tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND tramites_state.state=\'enproceso\' ORDER BY tramites_state.fechacreacion;',
  GET_ALL_PROCEDURES_EXCEPT_VALIDATING_ONES:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
  nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, \
  tipo_tramite.pago_previo AS "pagoPrevio"  FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
  tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
  tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND tramites_state.state!=\'validando\' ORDER BY tramites_state.fechacreacion;',
  GET_RESOURCES_FOR_PROCEDURE:
    'SELECT DISTINCT tt.sufijo, tt.costo_base, usr.nombre_completo as nombrecompleto, \
    usr.nombre_de_usuario as nombreusuario, tr.costo, tt.planilla, tr.id_tipo_tramite AS "tipoTramite" FROM tipo_tramite tt INNER JOIN tramite tr ON\
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
  GET_PROCEDURE_INSTANCES_FOR_USER: 'SELECT * FROM tramites_state_with_resources WHERE usuario = $1 ORDER BY fechacreacion;',
  GET_ALL_PROCEDURE_INSTANCES: 'SELECT * FROM tramites_state_with_resources ORDER BY fechacreacion;',
  GET_ONE_PROCEDURE_INFO: 'SELECT id_tipo_tramite as id, id_institucion AS "idInstitucion", nombre_tramite AS "nombre", costo_base as costo, \
    nombre_corto as "nombreCorto"  FROM tipo_tramite WHERE id_tipo_tramite = $1;',
  VALIDATE_FIELDS_FROM_PROCEDURE: 'SELECT DISTINCT camp.validacion, camp.tipo FROM campo_tramite ct INNER JOIN campo camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=$2',
  UPDATE_PROCEDURE_COST: 'UPDATE tipo_tramite SET costo_utmm = $2, costo_base = $3 WHERE id_tipo_tramite = $1 RETURNING *',
  UPDATE_STATE: 'SELECT update_tramite_state($1, $2, $3, $4, $5) as state;', //tramite, evento
  COMPLETE_STATE: 'SELECT complete_tramite_state ($1,$2,$3,$4, $5) as state',
  UPDATE_STATE_SOCIAL_CASE: 'SELECT update_caso_state($1, $2, $3) as state', //idcaso, event, datos
  UPDATE_PROCEDURE_INSTANCE_COST: 'UPDATE tramite SET costo = $1 WHERE id_tramite = $2',
  UPDATE_APPROVED_STATE_FOR_PROCEDURE: 'UPDATE TRAMITE SET aprobado=$1, fecha_culminacion = now() WHERE id_tramite=$2',

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
    'INSERT INTO inmueble_urbano (cod_catastral, direccion, id_parroquia, \
  metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, tipo_inmueble) \
  VALUES ($1, $2, (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), $4, $5, now(), now(), $6)\
  ON CONFLICT (cod_catastral) DO UPDATE SET metros_construccion = $4, metros_terreno = $5, \
  id_parroquia = (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), fecha_actualizacion = now() \
  RETURNING id_inmueble',
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
  i.fecha_ultimo_avaluo AS "fechaUltimoAvaluo" , p.nombre AS parroquia FROM inmueble_urbano i \
  INNER JOIN parroquia p ON i.id_parroquia = p.id WHERE i.cod_catastral = $1;',
  GET_PROPERTY_OWNERS: 'SELECT p.id_propietario AS "idpropietario", razon_social AS "razonSocial", cedula, rif, email, pi.id_inmueble \
    FROM propietario p INNER JOIN propietario_inmueble pi ON p.id_propietario = pi.id_propietario;',
  GET_PROPERTY_BY_ID: 'SELECT * FROM inmueble_urbano_view WHERE id=$1',

  //ordenanza
  CREATE_ORDINANCE:
    'WITH ordenanzaTmp AS (INSERT INTO ordenanza (descripcion, tarifa, id_valor) \
    VALUES ($1, $2, (SELECT id_valor FROM valor WHERE descripcion = \'UTMM\')) RETURNING *) \
    , tarifaTmp AS (INSERT INTO tarifa_inspeccion (id_ordenanza, id_tipo_tramite, utiliza_codcat, id_variable) VALUES ((SELECT id_ordenanza FROM ordenanzaTmp), \
    $3, $4, $5) RETURNING *) \
    SELECT o.id_ordenanza AS "id", o.descripcion AS "nombreOrdenanza", o.tarifa AS "precioUtmm", t.id_tipo_tramite AS "idTipoTramite", \
    t.utiliza_codcat AS "utilizaCodcat", t.id_variable IS NOT NULL AS "utilizaVariable", t.id_variable AS "idVariable", v.nombre AS "nombreVariable" \
    FROM ordenanzaTmp o INNER JOIN tarifaTmp t ON o.id_ordenanza = t.id_ordenanza \
    LEFT JOIN variable_ordenanza v ON t.id_variable = v.id_variable',
  CREATE_ORDINANCE_FOR_PROCEDURE:
    'INSERT INTO ordenanza_tramite (id_tramite, id_tarifa, utmm, valor_calc, factor, factor_value, costo_ordenanza) \
    VALUES ($1, (SELECT id_tarifa FROM tarifa_inspeccion trf INNER JOIN ordenanza ord ON \
      trf.id_ordenanza=ord.id_ordenanza WHERE trf.id_tipo_tramite=$2 AND ord.descripcion = $3 LIMIT 1), \
      $4,$5,$6,$7, $8) RETURNING *;',
  ORDINANCES_BY_INSTITUTION:
    'SELECT o.id_ordenanza AS id, o.descripcion AS "nombreOrdenanza", o.tarifa AS "precioUtmm", ti.id_tipo_tramite AS "idTipoTramite", \
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
  GET_ORDINANCE_VARIABLES: 'SELECT id_variable as id, nombre, nombre_plural as "nombrePlural" FROM variable_ordenanza;',
  UPDATE_ORDINANCE:
    'WITH updateTmp AS (UPDATE ordenanza SET tarifa = $2 WHERE id_ordenanza = $1 RETURNING id_ordenanza as id, descripcion AS "nombreOrdenanza", \
    tarifa AS "precioUtmm") \
      SELECT o.id, "nombreOrdenanza", "precioUtmm", t.id_tipo_tramite AS "idTipoTramite", \
      t.utiliza_codcat AS "utilizaCodcat", t.id_variable IS NOT NULL AS "utilizaVariable", t.id_variable AS "idVariable", v.nombre AS "nombreVariable" \
      FROM updateTmp o INNER JOIN tarifa_inspeccion t ON o.id = t.id_ordenanza \
      LEFT JOIN variable_ordenanza v ON t.id_variable = v.id_variable',
  DISABLE_ORDINANCE: 'UPDATE ordenanza SET habilitado = false WHERE id_ordenanza = $1 RETURNING *;',

  //valor
  GET_UTMM_VALUE: "SELECT valor_en_bs FROM valor WHERE descripcion = 'UTMM'",
  GET_UTMM_VALUE_FORMAT: "SELECT valor_en_bs AS valor FROM valor WHERE descripcion = 'UTMM'",
  UPDATE_UTMM_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'UTMM' RETURNING valor_en_bs;",

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
  GET_EXTERNAL_APPROVED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = TRUE;",
  GET_EXTERNAL_REJECTED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = FALSE;",

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
  CREATE_NOTIFICATION: 'INSERT INTO notificacion (id_procedimiento, emisor, receptor, descripcion, status, \
    fecha, estado, concepto) VALUES ($1, $2, $3, $4, false, now(), $5, $6) RETURNING id_notificacion',
  GET_PROCEDURE_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_tramite_view WHERE id = $1',
  GET_FINING_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_multa_view WHERE id = $1',
  GET_SETTLEMENT_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_impuesto_view WHERE id = $1',
  GET_PROCEDURE_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_tramite_view WHERE receptor = $1 ORDER BY "fechaCreacion"',
  GET_FINING_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_multa_view WHERE receptor = $1 ORDER BY "fechaCreacion"',
  GET_SETTLEMENT_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_impuesto_view WHERE receptor = $1 ORDER BY "fechaCreacion"',
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
  GET_ALL_FINES: 'SELECT * FROM multa_state ORDER BY fechacreacion;',
  GET_FINES_DIRECTOR_OR_ADMIN: 'SELECT * FROM multa_state WHERE nombrelargo = $1 ORDER BY fechacreacion;',
  GET_FINES_OFFICIAL: "SELECT * FROM multa_state WHERE nombrelargo = $1 AND state != 'validando' ORDER BY fechacreacion;",
  GET_FINES_EXTERNAL_USER: 'SELECT * FROM multa_state WHERE cedula = $1 AND nacionalidad = $2;',
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
  GET_APPLICATION_BY_ID: 'SELECT * FROM impuesto.solicitud WHERE id_solicitud = $1',
  GET_APPLICATION_INSTANCES_BY_USER: 'SELECT * FROM impuesto.solicitud WHERE id_usuario = $1',
  GET_APPLICATION_DEBTS_BY_MUNICIPAL_REGISTRY:
    "SELECT rm.id_ramo, rm.descripcion, SUM(l.monto) AS monto FROM impuesto.ramo rm INNER JOIN impuesto.subramo sr ON rm.id_ramo = sr.id_ramo\
    INNER JOIN impuesto.liquidacion l ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.registro_municipal r ON l.id_registro_municipal\
    = r.id_registro_municipal INNER JOIN impuesto.contribuyente c ON r.id_contribuyente = c.id_contribuyente INNER JOIN impuesto.solicitud s ON\
    c.id_contribuyente = s.id_contribuyente INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud)\
    AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud WHERE ev.state = 'ingresardatos' AND\
    r.referencia_municipal = $1 AND r.id_contribuyente = $2 GROUP BY rm.id_ramo, rm.descripcion HAVING SUM (l.monto) > 0",
  GET_APPLICATION_DEBTS_FOR_NATURAL_CONTRIBUTOR:
    "SELECT rm.id_ramo, rm.descripcion, SUM(l.monto) as monto FROM impuesto.ramo rm INNER JOIN impuesto.subramo sr ON rm.id_ramo = sr.id_ramo INNER JOIN\
    impuesto.liquidacion l ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.solicitud s ON l.id_solicitud = s.id_solicitud INNER JOIN\
     (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) AS state FROM impuesto.evento_solicitud es GROUP\
      BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE\
       ev.state = 'ingresardatos' AND c.id_contribuyente = $1 GROUP BY rm.descripcion, rm.id_ramo HAVING SUM(l.monto) > 0",
  GET_APPLICATION_INSTANCES_BY_CONTRIBUTOR:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente INNER JOIN\
     impuesto.registro_municipal r ON c.id_contribuyente = r.id_contribuyente WHERE r.referencia_municipal = $1 AND c.documento = $2 AND c.tipo_documento = $3;',
  GET_APPLICATION_INSTANCES_FOR_NATURAL_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE c.documento = $1 AND c.tipo_documento = $2;',
  GET_SETTLEMENTS_BY_APPLICATION_INSTANCE:
    'SELECT l.*, r.descripcion AS "tipoProcedimiento" FROM impuesto.liquidacion l INNER JOIN impuesto.subramo sr ON l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE id_solicitud = $1',
  GET_SETTLEMENT_INSTANCES:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sr.id_ramo INNER JOIN impuesto.solicitud_state sst ON sst.id = s.id_solicitud',
  GET_SETTLEMENT_INSTANCES_BY_ID:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON sr.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sr.id_ramo INNER JOIN impuesto.solicitud_state sst ON sst.id = s.id_solicitud WHERE s.id_usuario = $1;',
  GET_APPLICATION_VIEW_BY_SETTLEMENT: 'SELECT * FROM impuesto.solicitud_view WHERE "idLiquidacion" = $1',
  GET_LAST_FINE_FOR_LATE_APPLICATION:
    "SELECT EXTRACT(month FROM s.fecha::date) AS mes, EXTRACT(year FROM s.fecha::date) AS anio FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud s \
    ON l.id_solicitud = s.id_solicitud INNER JOIN impuesto.contribuyente c ON s.id_contribuyente = c.id_contribuyente WHERE \
    l.id_subramo = (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE r.codigo = '501' \
    AND sr.descripcion = 'Multa por Declaracion Tardia (Actividad Economica)') AND l.id_registro_municipal = $1 ORDER BY s.fecha DESC",
  GET_FIRST_MONTH_OF_SETTLEMENT_PAYMENT: 'SELECT * FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2 ORDER BY id_liquidacion LIMIT 1;',
  GET_LAST_MONTH_OF_SETTLEMENT_PAYMENT: 'SELECT * FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2 ORDER BY id_liquidacion DESC LIMIT 1;',
  GET_TOTAL_PAYMENT_OF_PROCESS_SETTLEMENT: 'SELECT SUM(monto) AS "totalLiquidaciones" FROM impuesto.liquidacion WHERE id_procedimiento = $1 AND id_solicitud = $2',
  GET_AE_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'AE\'',
  GET_SM_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'SM\'',
  GET_IU_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'IU\'',
  GET_PP_SETTLEMENTS_FOR_CONTRIBUTOR: 'SELECT * FROM impuesto.solicitud_view sv WHERE contribuyente = $1 AND "descripcionRamo" = \'PP\'',

  GET_FINES_BY_APPLICATION: 'SELECT * FROM impuesto.multa WHERE id_solicitud = $1',
  GET_BREAKDOWN_AND_SETTLEMENT_INFO_BY_ID: `SELECT datos FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud s ON s.id_solicitud = l.id_solicitud WHERE l.id_solicitud = $1 AND l.id_subramo = $2;`,
  CREATE_TAX_PAYMENT_APPLICATION: "SELECT * FROM impuesto.insert_solicitud($1, (SELECT id_tipo_tramite FROM tipo_tramite WHERE nombre_tramite = 'Pago de Impuestos'), $2)",
  UPDATE_TAX_APPLICATION_PAYMENT: 'SELECT * FROM impuesto.update_solicitud_state ($1, $2)',
  COMPLETE_TAX_APPLICATION_PAYMENT: 'SELECT * FROM impuesto.complete_solicitud_state($1, $2, null, true)',
  CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION: 'SELECT * FROM insert_liquidacion($1,$2,$3,$4,$5, $6)',
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_RIM:
    "SELECT * FROM impuesto.solicitud_state s INNER JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
     l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
      (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) AND EXTRACT('month' FROM l.fecha_liquidacion)\
       = EXTRACT('month' FROM CURRENT_DATE) ORDER BY fecha_liquidacion DESC",
  CURRENT_SETTLEMENT_EXISTS_FOR_CODE_AND_CONTRIBUTOR:
    "SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2 \
  AND EXTRACT('month' FROM l.fecha_liquidacion) = EXTRACT('month' FROM CURRENT_DATE) AND l.id_registro_municipal IS NULL ORDER BY fecha_liquidacion DESC",
  GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM:
    'SELECT * FROM impuesto.solicitud_state s INNER JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
   (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) ORDER BY fecha_liquidacion DESC LIMIT 1',
  GET_LAST_SETTLEMENT_FOR_CODE_AND_CONTRIBUTOR:
    'SELECT * FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l on s.id_solicitud = l.id_solicitud INNER JOIN impuesto.subramo sr ON\
  l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND s.id_contribuyente = $2\
  AND l.id_registro_municipal IS NULL ORDER BY fecha_liquidacion DESC LIMIT 1',
  GET_SETTLEMENTS_FOR_CODE_AND_RIM:
    'SELECT * FROM impuesto.solicitud_state s INNER JOIN impuesto.liquidacion l on s.id = l.id_solicitud INNER JOIN impuesto.subramo sr ON \
l.id_subramo = sr.id_subramo INNER JOIN impuesto.ramo rm ON sr.id_ramo = rm.id_ramo WHERE rm.codigo = $1 AND l.id_registro_municipal =\
 (SELECT id_registro_municipal FROM impuesto.registro_municipal WHERE referencia_municipal = $2 LIMIT 1) ORDER BY fecha_liquidacion DESC',
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
  UPDATE_PAID_STATE_FOR_TAX_PAYMENT_APPLICATION: 'UPDATE impuesto.solicitud SET pagado = true WHERE id_solicitud = $1',
  UPDATE_RECEIPT_FOR_SETTLEMENTS: 'UPDATE impuesto.liquidacion SET recibo = $1 WHERE id_procedimiento = $2 AND id_solicitud = $3',
  UPDATE_CERTIFICATE_SETTLEMENT: 'UPDATE impuesto.liquidacion SET certificado = $1 WHERE id_liquidacion = $2;',
  CREATE_CONTRIBUTOR_FOR_LINKING:
    'INSERT INTO IMPUESTO.CONTRIBUYENTE (tipo_documento, documento, razon_social, denominacion_comercial, siglas, id_parroquia, sector, direccion,\
       punto_referencia, verificado, tipo_contribuyente) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *;',
  CREATE_MUNICIPAL_REGISTRY_FOR_LINKING_CONTRIBUTOR:
    'INSERT INTO impuesto.registro_municipal (id_contribuyente, referencia_municipal, nombre_representante, telefono_celular,\
     email, denominacion_comercial, fecha_aprobacion, actualizado) VALUES ($1, $2, $3, $4, $5, $6, now(), $7) RETURNING *;',
  CREATE_ESTATE_FOR_LINKING_CONTRIBUTOR: 'INSERT INTO inmueble_urbano (id_registro_municipal, direccion, tipo_inmueble) VALUES ($1, $2, $3) RETURNING *;',
  GET_CONTRIBUTOR_BY_DOCUMENT_AND_DOC_TYPE: 'SELECT * FROM impuesto.contribuyente c WHERE c.documento = $1 AND c.tipo_documento = $2',
  CREATE_ECONOMIC_ACTIVITY_FOR_CONTRIBUTOR: 'INSERT INTO impuesto.actividad_economica_contribuyente (id_contribuyente, numero_referencia) VALUES ($1, $2)',
  GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR: 'SELECT * FROM impuesto.registro_municipal WHERE referencia_municipal = $1 AND id_contribuyente = $2 LIMIT 1',
  GET_ECONOMIC_ACTIVITIES_BY_CONTRIBUTOR:
    'SELECT ae.* FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_contribuyente aec ON ae.numero_referencia = aec.numero_referencia INNER JOIN impuesto.contribuyente c ON aec.id_contribuyente = c.id_contribuyente WHERE c.id_contribuyente = $1',
  REGISTRY_BY_SETTLEMENT_ID: 'SELECT * FROM impuesto.registro_municipal rm INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal WHERE l.id_liquidacion = $1;',
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
  GET_INGRESS: `SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, COUNT(*) as "cantidadIng", SUM(monto) as ingresado 
        FROM impuesto.liquidacion l 
        INNER JOIN impuesto.solicitud s ON l.id_solicitud = s.id_solicitud 
        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) 
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud 
        INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo 
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_subramo 
        WHERE state = 'finalizado' AND fecha_liquidacion BETWEEN $1 AND $2 
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion;`,
  GET_LIQUIDATED: `SELECT CONCAT(r.codigo, '.', sub.subindice) AS ramo, CONCAT(r.descripcion, ' - ', sub.descripcion) AS descripcion, COUNT(*) as "cantidadLiq", SUM(monto) as liquidado \
        FROM impuesto.liquidacion l  \
        INNER JOIN impuesto.solicitud s ON l.id_solicitud = s.id_solicitud \
        INNER JOIN (SELECT es.id_solicitud, impuesto.solicitud_fsm(es.event::text ORDER BY es.id_evento_solicitud) \
            AS state FROM impuesto.evento_solicitud es GROUP BY es.id_solicitud) ev ON s.id_solicitud = ev.id_solicitud \
        INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo \
        INNER JOIN Impuesto.ramo r ON r.id_ramo = sub.id_subramo \
        WHERE state != 'finalizado' AND fecha_liquidacion BETWEEN $1 AND $2 \
        GROUP BY r.codigo, sub.subindice, r.descripcion, sub.descripcion;`,
  GET_TRANSFERS_BY_BANK: `SELECT b.id_banco, b.nombre AS banco, SUM(p.monto) as monto
        FROM pago p
        INNER JOIN banco b ON b.id_banco = p.id_banco
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO') AND p.aprobado = true AND p.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_pago BETWEEN $1 AND $2
        GROUP BY b.id_banco, b.nombre
        UNION
        SELECT b.id_banco, b.nombre AS banco, SUM(ROUND(p.monto)) as monto
        FROM (SELECT * FROM pago p 
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                WHERE p.concepto = 'TRAMITE' AND p.aprobado = true AND tt.id_institucion = 9 AND p.metodo_pago = 'TRANSFERENCIA' AND p.fecha_de_pago BETWEEN $1 AND $2) p
        INNER JOIN banco b ON b.id_banco = p.id_banco
        GROUP BY b.id_banco, b.nombre;`,
  GET_CASH_REPORT: `SELECT 'BS' as moneda, x.monto FROM(
        SELECT SUM(p.monto) AS monto
        FROM pago p
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO') AND p.metodo_pago = 'EFECTIVO' AND p.fecha_de_pago BETWEEN $1 AND $2
        UNION
        SELECT SUM(p.monto) AS monto
        FROM (SELECT * FROM pago p 
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'EFECTIVO' AND p.fecha_de_pago BETWEEN $1 AND $2) p
      ) x;`,
  GET_POS: `SELECT SUM(monto) as total FROM (SELECT SUM(p.monto) as monto
        FROM pago p
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO') AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_pago BETWEEN $1 AND $2
        UNION
        SELECT SUM(p.monto) as monto
        FROM (SELECT * FROM pago p 
                INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
                INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
                WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'PUNTO DE VENTA' AND p.fecha_de_pago BETWEEN $1 AND $2) p) x;`,
  GET_CHECKS: `SELECT SUM(monto) AS total FROM (SELECT SUM(p.monto) as monto
        FROM pago p
        WHERE p.concepto IN ('IMPUESTO', 'CONVENIO') AND p.metodo_pago = 'CHEQUE' AND p.fecha_de_pago BETWEEN $1 AND $2
        UNION
        SELECT SUM(p.monto) as monto
        FROM (SELECT * FROM pago p 
        INNER JOIN tramite t ON t.id_tramite = p.id_procedimiento 
        INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite 
        WHERE p.concepto = 'TRAMITE' AND tt.id_institucion = 9 AND p.metodo_pago = 'CHEQUE' AND p.fecha_de_pago BETWEEN $1 AND $2) p) x;`,
  GET_SETTLEMENTS_REPORT: `SELECT (c.tipo_documento || '-' || c.documento) AS "Documento", rm.referencia_municipal AS "RIM", c.razon_social AS "Razon Social", 
        r.descripcion AS "Ramo", s.id AS "Planilla", l.fecha_liquidacion AS "Fecha Liquidacion", s.fecha AS "Fecha Recaudacion", 
        (CASE WHEN s.state = 'finalizado' THEN 'PAGADO' ELSE 'VIGENTE' END) AS "Estatus", l.monto as "Monto" 
        FROM impuesto.contribuyente c 
        INNER JOIN impuesto.registro_municipal rm ON rm.id_contribuyente = c.id_contribuyente 
        INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal 
        INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        INNER JOIN impuesto.solicitud_state s ON s.id = l.id_solicitud WHERE l.fecha_liquidacion BETWEEN $1 AND $2;`,
  GET_SETTLEMENT_REPORT_BY_BRANCH: `SELECT (c.tipo_documento || '-' || c.documento) AS "Documento", rm.referencia_municipal AS "RIM", c.razon_social AS "Razon Social", 
        r.descripcion AS "Ramo", s.id AS "Planilla", l.fecha_liquidacion AS "Fecha Liquidacion", s.fecha AS "Fecha Recaudacion", 
        (CASE WHEN s.state = 'finalizado' THEN 'PAGADO' ELSE 'VIGENTE' END) AS "Estatus", l.monto as "Monto" 
        FROM impuesto.contribuyente c 
        INNER JOIN impuesto.registro_municipal rm ON rm.id_contribuyente = c.id_contribuyente 
        INNER JOIN impuesto.liquidacion l ON l.id_registro_municipal = rm.id_registro_municipal 
        INNER JOIN impuesto.subramo sub ON sub.id_subramo = l.id_subramo INNER JOIN impuesto.ramo r ON r.id_ramo = sub.id_ramo 
        INNER JOIN impuesto.solicitud_state s ON s.id = l.id_solicitud WHERE l.fecha_liquidacion BETWEEN $1 AND $2 AND r.id_ramo = $3;`,

  //EXONERACIONES
  GET_CONTRIBUTOR: 'SELECT id_contribuyente as id, razon_social AS "razonSocial", denominacion_comercial AS "denominacionComercial" FROM impuesto.contribuyente c WHERE c.tipo_documento = $1 AND c.documento = $2;',
  CREATE_EXONERATION: 'INSERT INTO impuesto.plazo_exoneracion (id_plazo_exoneracion, fecha_inicio) VALUES (default, $1) RETURNING *;',
  INSERT_CONTRIBUTOR_EXONERATED_ACTIVITY: `INSERT INTO impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_contribuyente, id_actividad_economica)
                VALUES (default, $1, $2, $3);`,
  INSERT_EXONERATION_CONTRIBUTOR: 'INSERT INTO impuesto.contribuyente_exoneracion (id_contribuyente_exoneracion, id_plazo_exoneracion, id_contribuyente) VALUES (default, $1, $2);',
  INSERT_EXONERATION_ACTIVITY: 'INSERT INTO impuesto.actividad_economica_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_actividad_economica) VALUES (default, $1, $2);',
  INSERT_EXONERATION_BRANCH: 'INSERT INTO impuesto.ramo_exoneracion (id_actividad_economica_exoneracion, id_plazo_exoneracion, id_ramo) VALUES (default, $1, $2);',

  GET_EXONERATED_ACTIVITY_BY_CONTRIBUTOR:
    'SELECT * FROM impuesto.plazo_exoneracion pe INNER JOIN impuesto.contribuyente_exoneracion ce ON ce.id_plazo_exoneracion = pe.id_plazo_exoneracion WHERE id_contribuyente = $1 AND id_actividad_economica = $2 AND fecha_inicio <= NOW() AND fecha_fin IS NULL',
  GET_EXONERATED_CONTRIBUTOR_STATUS:
    'SELECT * FROM impuesto.contribuyente_exoneracion ce INNER JOIN impuesto.plazo_exoneracion pe ON pe.id_plazo_exoneracion = ce.id_plazo_exoneracion WHERE id_contribuyente = $1 AND id_actividad_economica IS NULL AND fecha_fin IS NULL',
  GET_CONTRIBUTOR_HAS_ACTIVITY: 'SELECT * FROM impuesto.actividad_economica ae INNER JOIN impuesto.actividad_economica_contribuyente aec ON aec.numero_referencia = ae.numero_referencia WHERE id_contribuyente = $1 AND id_actividad_economica = $2',
  GET_CONTRIBUTOR_EXONERATIONS: `SELECT pe.*, ce.*, ae.*, c.*, (pe.fecha_fin IS NULL ) AS active \
        FROM impuesto.plazo_exoneracion pe \
        INNER JOIN impuesto.contribuyente_exoneracion ce ON ce.id_plazo_exoneracion = pe.id_plazo_exoneracion \
        INNER JOIN impuesto.contribuyente c ON c.id_contribuyente = ce.id_contribuyente \
        LEFT JOIN impuesto.actividad_economica ae ON ae.id_actividad_economica = ce.id_actividad_economica \
        WHERE c.tipo_documento = $1 AND c.documento = $2 ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_ACTIVITY_EXONERATIONS: `SELECT pe.*, ae.*, (pe.fecha_fin IS NULL ) AS active 
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.actividad_economica_exoneracion aee ON aee.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_ACTIVITY_IS_EXONERATED: `SELECT pe.id_plazo_exoneracion AS id, ae.descripcion, (pe.fecha_fin IS NULL ) AS active 
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.actividad_economica_exoneracion aee ON aee.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.actividad_economica ae ON aee.id_actividad_economica = ae.id_actividad_economica
        WHERE ae.id_actividad_economica = $1 AND (pe.fecha_fin IS NULL)
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_BRANCH_EXONERATIONS: `SELECT pe.*, r.*, (pe.fecha_fin IS NULL) AS active 
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.ramo_exoneracion re ON re.id_plazo_exoneracion = pe.id_plazo_exoneracion
        INNER JOIN impuesto.ramo r ON r.id_ramo = re.id_ramo
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  GET_BRANCH_IS_EXONERATED: `SELECT pe.*, ae.*, (pe.fecha_fin IS NULL ) AS active 
        FROM impuesto.plazo_exoneracion pe
        INNER JOIN impuesto.ramo_exoneracion re ON re.id_plazo_exoneracion = pe.id_plazo_exoneracion
        WHERE id_ramo = $1 AND ( pe.fecha_fin IS NULL)
        ORDER BY pe.id_plazo_exoneracion DESC;`,
  UPDATE_EXONERATION_END_TIME: `UPDATE impuesto.plazo_exoneracion SET fecha_fin = $1 WHERE id_plazo_exoneracion = $2`,
  GET_ALL_ACTIVITIES: 'SELECT id_actividad_economica AS id, numero_referencia AS codigo, descripcion FROM impuesto.actividad_economica;',
  GET_ESTATES_FOR_JURIDICAL_CONTRIBUTOR: 'SELECT * FROM impuesto.avaluo_inmueble ai INNER JOIN inmueble_urbano iu ON ai.id_inmueble = iu.id_inmueble WHERE id_registro_municipal = $1 ORDER BY ai.anio DESC',
  GET_ESTATES_FOR_NATURAL_CONTRIBUTOR:
    'SELECT ai.*,iu.* FROM impuesto.avaluo_inmueble ai INNER JOIN inmueble_urbano iu ON ai.id_inmueble = iu.id_inmueble INNER JOIN impuesto.inmueble_contribuyente_natural icn ON iu.id_inmueble = icn.id_inmueble WHERE icn.id_contribuyente = $1 ORDER BY ai.anio DESC',
  GET_AE_CLEANING_TARIFF:
    'SELECT * FROM impuesto.actividad_economica_contribuyente aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia INNER JOIN impuesto.tabulador_aseo_actividad_economica ta ON ta.numero_referencia = ae.numero_referencia WHERE id_contribuyente = $1 ORDER BY monto DESC LIMIT 1;',
  GET_RESIDENTIAL_CLEANING_TARIFF: 'SELECT * FROM impuesto.tabulador_aseo_residencial WHERE fecha_hasta IS NULL;',
  GET_AE_GAS_TARIFF:
    'SELECT * FROM impuesto.actividad_economica_contribuyente aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia INNER JOIN impuesto.tabulador_gas_actividad_economica tg ON tg.numero_referencia = ae.numero_referencia WHERE id_contribuyente = $1 ORDER BY monto DESC LIMIT 1;',
  GET_RESIDENTIAL_GAS_TARIFF: 'SELECT * FROM impuesto.tabulador_gas_residencial WHERE fecha_hasta IS NULL;',
  GET_PUBLICITY_CATEGORIES: 'SELECT * FROM impuesto.categoria_propaganda',
  GET_PUBLICITY_SUBCATEGORIES: 'SELECT * FROM impuesto.tipo_aviso_propaganda',
  INSERT_ESTATE_VALUE: 'INSERT INTO impuesto.avaluo_inmueble (id_inmueble, avaluo, anio) VALUES ($1,$2,$3)',
  SET_DATE_FOR_LINKED_APPROVED_APPLICATION: 'UPDATE impuesto.solicitud SET fecha = $1, fecha_aprobado = $1 WHERE id_solicitud = $2',
  SET_DATE_FOR_LINKED_ACTIVE_APPLICATION: 'UPDATE impuesto.solicitud SET fecha = $1 WHERE id_solicitud = $2',
  LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR: 'INSERT INTO impuesto.inmueble_contribuyente_natural (id_inmueble, id_contribuyente) VALUES ($1, $2) RETURNING *',
  GET_AGREEMENT_FRACTION_BY_ID: 'SELECT * FROM impuesto.fraccion WHERE id_fraccion = $1',
  GET_AGREEMENT_FRACTION_STATE: 'SELECT state FROM impuesto.fraccion_state WHERE id = $1',
  GET_AGREEMENTS_BY_USER: 'SELECT * FROM impuesto.convenio c INNER JOIN impuesto.solicitud s ON c.id_solicitud = s.id_solicitud WHERE s.id_usuario = $1',
  GET_FRACTIONS_BY_AGREEMENT_ID: 'SELECT * FROM impuesto.fraccion f WHERE f.id_convenio = $1',
  APPLICATION_TOTAL_AMOUNT_BY_ID: 'SELECT SUM(monto) AS monto_total FROM impuesto.liquidacion WHERE id_solicitud = $1',
  GET_APPLICATION_STATE: 'SELECT state FROM impuesto.solicitud_state WHERE id = $1',
  GET_CONTRIBUTOR_BY_ID: 'SELECT * FROM impuesto.contribuyente WHERE id_contribuyente = $1',
  SET_DATE_FOR_LINKED_SETTLEMENT: 'UPDATE impuesto.liquidacion SET fecha_liquidacion = $1 WHERE id_liquidacion = $2',
  ASSIGN_CONTRIBUTOR_TO_USER: 'UPDATE USUARIO SET id_contribuyente = $1 WHERE id_usuario = $2',
  GET_CONTRIBUTOR_BY_USER: 'SELECT c.* FROM USUARIO u INNER JOIN impuesto.contribuyente c ON u.id_contribuyente = c.id_contribuyente WHERE u.id_usuario = $1',
  GET_FRACTION_BY_AGREEMENT_AND_FRACTION_ID: 'SELECT * FROM impuesto.fraccion WHERE id_convenio = $1 AND id_fraccion = $2',
  UPDATE_FRACTION_STATE: 'SELECT * FROM impuesto.update_fraccion_state ($1, $2)',
  COMPLETE_FRACTION_STATE: 'SELECT * FROM impuesto.complete_fraccion_state ($1, $2, true)',
  SEARCH_CONTRIBUTOR_BY_NAME: 'SELECT * FROM impuesto.contribuyente WHERE razon_social ILIKE = $1',
  GET_CONTRIBUTOR_WITH_BRANCH: 'SELECT * FROM impuesto.registro_municipal r INNER JOIN impuesto.contribuyente c ON r.id_contribuyente = c.id_contribuyente WHERE r.referencia_municipal = $1',
  CHANGE_SETTLEMENT_TO_NEW_APPLICATION:
    "UPDATE impuesto.liquidacion SET id_solicitud = $1 WHERE id_registro_municipal = $2 AND id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE subindice = '1' AND id_ramo = $3) AND id_liquidacion IN (SELECT id_liquidacion  FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud_state ss ON ss.id = l.id_solicitud  WHERE ss.state = 'ingresardatos');",
  GET_SETTLEMENT_IDS_BY_RIM_AND_BRANCH:
    "SELECT id_liquidacion FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud_state ss ON ss.id = l.id_solicitud  WHERE ss.state = 'ingresardatos' AND id_registro_municipal = $1 AND id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE subindice = '1' AND id_ramo = $2);",
  INSERT_DISCOUNT_FOR_SETTLEMENT: 'INSERT INTO impuesto.liquidacion_descuento (id_liquidacion, porcentaje_descuento) VALUES ($1, $2)',
  CREATE_AGREEMENT: 'INSERT INTO impuesto.convenio (id_solicitud, cantidad) VALUES ($1, $2) RETURNING *',
  CREATE_AGREEMENT_FRACTION: 'SELECT * FROM impuesto.insert_fraccion($1, $2, $3, $4)',
  CHANGE_SETTLEMENT_BRANCH_TO_AGREEMENT: "UPDATE impuesto.liquidacion SET id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE id_ramo = $1 AND descripcion = 'Convenio de Pago') WHERE id_solicitud = $2",
  SET_SETTLEMENTS_AS_FORWARDED_BY_RIM:
    "UPDATE impuesto.liquidacion SET remitido = true WHERE id_registro_municipal = $1 AND id_subramo = (SELECT id_subramo FROM impuesto.subramo WHERE subindice = '1' AND id_ramo = $2) AND id_liquidacion IN (SELECT id_liquidacion  FROM impuesto.liquidacion l INNER JOIN impuesto.solicitud_state ss ON ss.id = l.id_solicitud  WHERE ss.state = 'ingresardatos');",
  GET_USER_BY_APPLICATION_AND_RIM: 'SELECT id_usuario FROM impuesto.solicitud s INNER JOIN impuesto.liquidacion l ON s.id_solicitud = l.id_solicitud WHERE l.id_registro_municipal = $1',
  ADD_VERIFIED_CONTRIBUTOR: 'INSERT INTO impuesto.verificacion_telefono (fecha_verificacion, verificado, id_usuario) VALUES (now(), true, $1)',
  ADD_BRANCH_FOR_CONTRIBUTOR: 'INSERT INTO impuesto.registro_municipal (id_contribuyente, fecha_aprobacion, telefono_celular, email, denominacion_comercial, nombre_representante, actualizado) VALUES ($1, now(), $2, $3, $4, $5, true) RETURNING *',
  UPDATE_BRANCH_INFO: 'UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4, actualizado = $5 WHERE referencia_municipal = $6 RETURNING *',
  GET_ECONOMIC_ACTIVITIES_CONTRIBUTOR:
    'SELECT ae.id_actividad_economica AS id, ae.numero_referencia as "numeroReferencia", ae.descripcion, ae.alicuota, ae.minimo_tributable AS "minimoTributable" FROM impuesto.actividad_economica_contribuyente aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia WHERE id_contribuyente = $1;',
  GET_BRANCHES: 'SELECT id_ramo AS id, codigo, descripcion, descripcion_corta FROM impuesto.ramo;',
  GET_SUT_ESTATE_BY_ID: 'SELECT * FROM inmueble_urbano WHERE id_inmueble = $1',
  gtic: {
    GET_NATURAL_CONTRIBUTOR: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE nu_cedula = $1 AND tx_tp_doc = $2 ORDER BY co_contribuyente DESC',
    GET_JURIDICAL_CONTRIBUTOR: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE tx_rif = $1 AND tx_tp_doc = $2 AND nu_referencia IS NOT NULL ORDER BY co_contribuyente DESC',
    GET_CONTRIBUTOR_BY_ID: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE co_contribuyente = $1',
    NATURAL_CONTRIBUTOR_EXISTS: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE nu_cedula = $1 AND tx_tp_doc = $2;',
    JURIDICAL_CONTRIBUTOR_EXISTS: 'SELECT * FROM tb004_contribuyente c INNER JOIN tb002_tipo_contribuyente tc ON tc.co_tipo = c.co_tipo WHERE tx_rif = $1 AND nu_referencia = $2 AND tx_tp_doc = $3',
    CONTRIBUTOR_ECONOMIC_ACTIVITIES:
      'WITH ultima_ordenanza AS (SELECT co_ordenanza FROM tb035_anio_ordenanza WHERE nu_anio = EXTRACT(year from CURRENT_timestamp) ORDER BY co_ordenanza DESC LIMIT 1) \
    SELECT * FROM tb041_contrib_act ca \
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
    INNER JOIN tb039_ae_act ividad ae ON ca.nu_ref_actividad = ae.nu_ref_actividad \
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
      'SELECT dm.*,l.*, r.*, m.* FROM tb051_ae_decl_multa dm INNER JOIN tb079_liquidacion l ON l.co_liquidacion = dm.co_liquidacion_propio \
      INNER JOIN tb046_ae_ramo r ON r.co_ramo = l.co_ramo INNER JOIN tb034_motivo m ON m.co_motivo = l.co_motivo \
      WHERE dm.co_contribuyente = $1 AND EXTRACT(YEAR FROM dm.created_at) = EXTRACT(YEAR FROM CURRENT_DATE);',
  },
};

export default queries;
