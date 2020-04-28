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
  ADD_OFFICIAL_DATA: 'INSERT INTO cuenta_funcionario (id_usuario, id_institucion) VALUES ($1, $2) RETURNING *;',
  ADD_OFFICIAL_PERMISSIONS: 'INSERT INTO permiso_de_acceso (id_usuario, id_tipo_tramite) VALUES ($1, $2)',
  INSERT_GOOGLE_USER: 'INSERT INTO datos_google VALUES ($1, $2)',
  INSERT_FACEBOOK_USER: 'INSERT INTO datos_facebook VALUES ($1, $2)',
  EXTERNAL_USER_INIT: 'INSERT INTO usuario (nombre_completo, id_tipo_usuario) VALUES ($1, 4) RETURNING *',
  SIGN_UP_WITH_LOCAL_STRATEGY:
    'INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula,\
  nacionalidad,id_tipo_usuario, password, telefono) VALUES ($1,$2,$3,$4,$5,4,$6, $7) RETURNING *',
  ADD_PASSWORD_RECOVERY:
    'WITH usuario AS (SELECT id_usuario FROM usuario WHERE nombre_de_usuario = $1) \
       INSERT INTO recuperacion (id_usuario, token_recuperacion, usado) VALUES ((SELECT id_usuario FROM usuario), $2, false) RETURNING token_recuperacion;',
  GET_USER_BY_USERNAME: 'SELECT * FROM usuario WHERE nombre_de_usuario = $1;',
  GET_USER_BY_ID: 'SELECT * FROM datos_usuario WHERE cedula = $1',
  GET_USER_INFO_BY_ID:
    'SELECT nombre_completo as "nombreCompleto", nombre_de_usuario AS "nombreUsuario", direccion, cedula, nacionalidad FROM usuario WHERE id_usuario = $1;',
  GET_PHONES_FROM_USERNAME:
    'SELECT numero FROM telefonos_usuario tu \
    INNER JOIN usuario u ON tu.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_USER_TYPE_FROM_USERNAME:
    'SELECT tu.* FROM tipo_usuario tu \
    INNER JOIN usuario u ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE U.nombre_de_usuario = $1;',
  GET_GOOGLE_DATA_FROM_USERNAME:
    'SELECT dg.* FROM datos_google dg \
    INNER JOIN usuario u ON dg.id_usuario = u.id_usuario \
    WHERE u.nombre_de_usuario = $1',
  GET_OFFICIAL_DATA_FROM_USERNAME:
    'SELECT cf.* FROM cuenta_funcionario cf \
    INNER JOIN usuario u ON u.id_usuario = cf.id_usuario \
    WHERE u.nombre_de_usuario = $1;',
  GET_USER_PERMISSIONS: 'SELECT pa.id_tipo_tramite FROM permiso_de_acceso pa WHERE id_usuario = $1',
  GET_ADMIN:
    "SELECT u.cedula, u.nombre_completo FROM usuario u INNER JOIN rol r ON u.id_rol = r.id WHERE u.id_rol = \
  (SELECT id FROM rol WHERE nombre = 'Administrador')",
  GET_OAUTH_USER:
    'SELECT usr.* FROM usuario usr LEFT JOIN datos_facebook df ON usr.id_usuario=df.id_usuario\
  LEFT JOIN datos_google dg ON usr.id_usuario = dg.id_usuario\
  WHERE dg.id_google = $1 OR df.id_facebook=$1',
  GET_EXTERNAL_USER: 'SELECT * FROM usuario WHERE id_usuario = $1',
  GET_ADMIN_INSTITUTE: 'SELECT i.* FROM institucion i INNER JOIN cuenta_funcionario cf ON i.id_institucion = cf.id_institucion \
    WHERE cf.id_usuario = $1;',
  CHECK_IF_OFFICIAL:
    "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Funcionario' AND u.cedula = $1",
  CHECK_IF_DIRECTOR:
    "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Director' AND u.cedula = $1",
  CHECK_IF_ADMIN:
    "SELECT 1 FROM usuario u \
    INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
    WHERE tu.descripcion = 'Administrador' AND u.cedula = $1",
  CHECK_IF_SUPERUSER:
    "SELECT 1 FROM usuario u \
  INNER JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario \
  WHERE tu.descripcion = 'Superuser' AND u.cedula = $1",
  ADMIN_EXISTS:
    'SELECT * FROM usuario usr inner join cuenta_funcionario cf ON usr.id_usuario \
  = cf.id_usuario WHERE id_tipo_usuario = 2 AND id_institucion = $1',
  VALIDATE_TOKEN: "SELECT 1 FROM recuperacion WHERE token_recuperacion = $1 AND usado = false AND CURRENT_TIMESTAMP - fecha_recuperacion < '20 minutes';",
  EMAIL_EXISTS: 'SELECT 1 FROM usuario u WHERE nombre_de_usuario = $1;',
  EXTERNAL_USER_COMPLETE:
    'UPDATE usuario SET direccion = $1, cedula = $2, nacionalidad = $3, nombre_de_usuario = $4, password=$5, nombre_completo=$6, telefono=$7 \
    WHERE id_usuario = $8 RETURNING *',
  DISABLE_TOKEN: 'UPDATE recuperacion SET usado = true WHERE token_recuperacion = $1',
  UPDATE_PASSWORD:
    'WITH usuarioTmp AS (SELECT u.id_usuario FROM usuario u INNER JOIN recuperacion r ON r.id_usuario = u.id_usuario WHERE token_recuperacion = $1) \
      UPDATE usuario SET password = $2 WHERE id_usuario = (SELECT id_usuario FROM usuarioTmp)',
  UPDATE_USER:
    'UPDATE usuario SET direccion = $1, nombre_completo = $2, telefono = $3 WHERE id_usuario = $4 RETURNING id_usuario as id, direccion, \
      nombre_completo as "nombreCompleto", telefono',
  DROP_OFFICIAL_PERMISSIONS: 'DELETE FROM permiso_de_acceso WHERE id_usuario = $1;',

  //BANKS
  INSERT_PAYMENT: 'INSERT INTO pago (id_procedimiento, referencia, monto, id_banco, fecha_de_pago, concepto) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *;',
  GET_ALL_BANKS: 'SELECT id_banco as id, nombre  FROM banco',
  VALIDATE_PAYMENTS: 'SELECT validate_payments($1);',
  GET_BANK_ACCOUNTS_FOR_INSTITUTION:
    'SELECT id_institucion_banco AS id, id_institucion AS institucion, id_banco AS banco, \
    numero_cuenta AS numerocuenta, nombre_titular AS nombretitular, documento_de_identificacion AS documento FROM institucion_banco WHERE id_institucion = $1',

  //OFFICIALS
  CREATE_OFFICIAL:
    'WITH funcionario AS (INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula,\
    nacionalidad, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $9, $6, $7) RETURNING id_usuario)\
    INSERT INTO cuenta_funcionario VALUES((SELECT id_usuario from funcionario), $8) RETURNING *',
  GET_OFFICIAL:
    'SELECT usr.* from usuario usr INNER JOIN cuenta_funcionario cf ON\
     usr.id_usuario=cf.id_usuario WHERE usr.id_usuario=$1 AND cf.id_institucion = $2',
  GET_OFFICIALS_BY_INSTITUTION:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
    from usuario usr INNER JOIN cuenta_funcionario cf ON\
    usr.id_usuario=cf.id_usuario WHERE cf.id_institucion = $1 AND usr.id_usuario != $2 AND usr.id_tipo_usuario!=1',
  GET_ALL_OFFICIALS:
    'SELECT usr.id_usuario AS id, usr.nombre_completo AS nombreCompleto, usr.nombre_de_usuario AS nombreUsuario,\
    usr.direccion, usr.cedula, usr.nacionalidad, usr.id_tipo_usuario AS tipoUsuario, usr.telefono\
    from usuario usr INNER JOIN cuenta_funcionario cf ON\
    usr.id_usuario=cf.id_usuario WHERE usr.id_tipo_usuario!=1',
  GET_ALL_INSTITUTION: 'SELECT * FROM institucion',
  GET_ONE_INSTITUTION: 'SELECT * FROM institucion WHERE id_institucion = $1',
  GET_ONE_INSTITUTION_INFO:
    'SELECT id_institucion AS id, nombre_completo AS "nombreCompleto", nombre_corto AS "nombreCorto" FROM institucion WHERE id_institucion = $1;',
  UPDATE_OFFICIAL:
    'UPDATE usuario SET nombre_completo = $1, nombre_de_usuario = $2, direccion = $3,\
    cedula = $4, nacionalidad = $5, telefono =$6, id_tipo_usuario = $8 WHERE id_usuario = $7 RETURNING *',
  DELETE_OFFICIAL:
    'DELETE FROM usuario usr USING cuenta_funcionario cf WHERE\
    usr.id_usuario = cf.id_usuario AND usr.id_usuario = $1\
    AND cf.id_institucion = $2 RETURNING *;',
  DELETE_OFFICIAL_AS_SUPERUSER: 'DELETE FROM usuario WHERE usuario.id_usuario = $1 RETURNING *;',

  //tramite
  PROCEDURE_INIT: 'SELECT * FROM insert_tramite($1, $2, $3);',
  SOCIAL_CASE_INIT: 'SELECT * FROM insert_caso(0, $1, $2);', //datos, id usuario
  CREATE_RECEIPT: 'INSERT INTO factura_tramite (id_factura, id_tramite) VALUES (default, $1) RETURNING *;',
  ADD_ITEM_TO_RECEIPT: 'INSERT INTO detalle_factura (id_detalle, id_factura, nombre, costo) VALUES (default, $1, $2, $3)',
  INSERT_TAKINGS_IN_PROCEDURE: 'INSERT INTO tramite_archivo_recaudo VALUES ($1,$2)',
  GET_SECTIONS_BY_PROCEDURE:
    'SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  campo_tramite ct RIGHT JOIN seccion sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1 ORDER BY sect.id_seccion',
  GET_PROCEDURE_BY_INSTITUTION:
    'SELECT id_tipo_tramite, nombre_tramite, costo_base, sufijo, pago_previo, utiliza_informacion_catastral, costo_utmm \
    FROM tipo_tramite tt WHERE id_institucion = $1 ORDER BY id_tipo_tramite',
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND (ct.estado='iniciado' OR ct.estado = 'ingresardatos') \
    ORDER BY ct.orden",
  GET_FIELDS_BY_SECTION_FOR_OFFICIALS:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 \
    AND NOT (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_FOR_SOCIAL_CASE:
    'SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
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
  GET_PLANILLA_AND_CERTIFICATE_TYPE_PROCEDURE: 'SELECT planilla, certificado FROM tipo_tramite WHERE id_tipo_tramite=$1',
  GET_STATE_AND_TYPE_OF_PROCEDURE: 'SELECT state, tipotramite FROM tramites_state_with_resources WHERE id=$1',
  GET_PROCEDURE_DATA: 'SELECT datos FROM tramite WHERE id_tramite=$1',
  GET_SOCIAL_CASES_STATE: 'SELECT * FROM CASOS_SOCIALES_STATE WHERE tipotramite=$1',
  GET_ID_FROM_PROCEDURE_STATE_BY_CODE: 'SELECT id FROM TRAMITES_STATE_WITH_RESOURCES WHERE codigotramite=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION: 'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado \
  FROM tramites_state_with_resources tsr INNER JOIN tipo_tramite ttr ON tsr.tipotramite=ttr.id_tipo_tramite WHERE tsr.id=$1',
  GET_PROCEDURE_STATE_AND_TYPE_INFORMATION_MOCK: 'SELECT tsr.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado as formatoCertificado \
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
    usr.nombre_de_usuario as nombreusuario, tr.costo, tt.planilla FROM tipo_tramite tt INNER JOIN tramite tr ON\
    tt.id_tipo_tramite=tr.id_tipo_tramite INNER JOIN usuario usr ON tr.id_usuario=usr.id_usuario\
    WHERE tr.id_tramite = $1',
  GET_PROCEDURE_STATES:
    'SELECT id_tramite AS id, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM evento_tramite \
  GROUP BY id_tramite;',
  GET_PROCEDURE_STATE:
    'SELECT id_tramite AS id, tramite_evento_fsm(event ORDER BY id_evento_tramite) AS state  \
  FROM evento_tramite \
  WHERE id_tramite = $1 \
  GROUP BY id_tramite;', //tramite
  GET_PROCEDURE_STATE_FOR_SOCIAL_CASE:
    'SELECT id_caso AS id, caso_social_fsm(event ORDER BY id_evento_caso) AS state  \
  FROM eventos_caso_social \
  WHERE id_caso = $1 \
  GROUP BY id_caso;',
  GET_ONE_PROCEDURE: 'SELECT * FROM tipo_tramite WHERE id_tipo_tramite = $1',
  GET_PROCEDURE_BY_ID: 'SELECT * FROM tramites_state_with_resources WHERE id=$1',
  GET_SOCIAL_CASE_BY_ID: 'SELECT * FROM casos_sociales_state WHERE id=$1',
  GET_CERTIFICATE_BY_PROCEDURE_ID: 'SELECT certificado AS "urlCertificado" FROM tramites_state_with_resources WHERE id = $1',
  GET_PROCEDURE_INSTANCES_FOR_USER: 'SELECT * FROM tramites_state_with_resources WHERE usuario = $1 ORDER BY fechacreacion;',
  GET_ALL_PROCEDURE_INSTANCES: 'SELECT * FROM tramites_state_with_resources ORDER BY fechacreacion;',
  GET_ONE_PROCEDURE_INFO:
    'SELECT id_tipo_tramite as id, id_institucion AS "idInstitucion", nombre_tramite AS "nombre", costo_base as costo, \
    nombre_corto as "nombreCorto"  FROM tipo_tramite WHERE id_tipo_tramite = $1;',
  VALIDATE_FIELDS_FROM_PROCEDURE:
    'SELECT DISTINCT camp.validacion, camp.tipo FROM campo_tramite ct INNER JOIN campo camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=$2',
  UPDATE_PROCEDURE_COST: 'UPDATE tipo_tramite SET costo_utmm = $2, costo_base = $3 WHERE id_tipo_tramite = $1 RETURNING *',
  UPDATE_STATE: 'SELECT update_tramite_state($1, $2, $3, $4, $5) as state;', //tramite, evento
  COMPLETE_STATE: 'SELECT complete_tramite_state ($1,$2,$3,$4, $5) as state',
  UPDATE_STATE_SOCIAL_CASE: 'SELECT update_caso_state($1, $2, $3) as state', //idcaso, event, datos
  UPDATE_PROCEDURE_INSTANCE_COST: 'UPDATE tramite SET costo = $1 WHERE id_tramite = $2',
 
  //parroquias
  GET_PARISHES: 'SELECT * FROM parroquia;',

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
  UPDATE_GROUND_VALUES_BY_SECTOR:
    'UPDATE valores_fiscales.terreno tr SET valor_fiscal = $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) AND sector_id = $3 RETURNING *',
  UPDATE_GROUND_VALUES_BY_FACTOR:
    'UPDATE valores_fiscales.terreno tr SET valor_fiscal = valor_fiscal * $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) RETURNING *',
  UPDATE_CONSTRUCTION_VALUES_BY_MODEL:
    'UPDATE valores_fiscales.construccion tr SET valor_fiscal = $1 WHERE \
    ano_id=(SELECT id FROM valores_fiscales.ano WHERE descripcion = $2) AND \
    tipo_construccion_id = $3 RETURNING *',
  UPDATE_CONSTRUCTION_VALUES_BY_FACTOR:
    'UPDATE valores_fiscales.construccion tr SET valor_fiscal = valor_fiscal * $1 WHERE \
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
  CREATE_PROPERTY_OWNER:
  'INSERT INTO propietario (razon_social, cedula, rif, email) VALUES ($1,$2,$3,$4) ON CONFLICT (cedula, rif) DO UPDATE razon_social = $1 RETURNING *',
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
  GET_PROPERTY_OWNERS:
    'SELECT p.id_propietario AS "idpropietario", razon_social AS "razonSocial", cedula, rif, email, pi.id_inmueble \
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
  GET_UTMM_VALUE_FORMAT: 'SELECT valor_en_bs AS valor FROM valor WHERE descripcion = \'UTMM\'',
  UPDATE_UTMM_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'UTMM' RETURNING valor_en_bs;",

  //Estadisticas
  // OFFICIAL STATS
  GET_PROC_TOTAL_COUNT: 'SELECT COUNT (*) FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1;',
  GET_PROC_TOTAL_IN_MONTH:
    'SELECT COUNT (*) FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND EXTRACT(MONTH FROM t.fecha_creacion) = $2;',
  GET_PROC_TOTAL_BY_STATUS:
    'SELECT COUNT (*) FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND t.state = $2',
  GET_PROC_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM tramite t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_PROC_BY_STATUS_MONTHLY:
    'SELECT COUNT (*) FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND EXTRACT(MONTH FROM t.fechacreacion) = $2 AND t.state = $3;',
  GET_PROC_COUNT_BY_STATE:
    'SELECT COUNT (*), state FROM tramites_state_with_resources t INNER JOIN tipo_tramite tt \
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
  GET_FINE_TOTAL_IN_MONTH:
    'SELECT COUNT (*) FROM multa t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND EXTRACT(MONTH FROM t.fecha_creacion) = $2;',
  GET_FINE_TOTAL_BY_STATUS:
    'SELECT COUNT (*) FROM multa_state t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite WHERE tt.id_institucion = $1 \
    AND t.state = $2',
  GET_FINE_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM multa t INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_FINE_BY_STATUS_MONTHLY:
    'SELECT COUNT (*) FROM multa_state t INNER JOIN tipo_tramite tt ON t.tipotramite = tt.id_tipo_tramite \
    WHERE tt.id_institucion = $1 AND EXTRACT(MONTH FROM t.fechacreacion) = $2 AND t.state = $3;',
  GET_FINE_COUNT_BY_STATE:
    'SELECT COUNT (*), state FROM multa_state t INNER JOIN tipo_tramite tt \
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
  GET_SUPER_PROC_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM tramite WHERE fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_SUPER_PROC_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM tramites_state_with_resources WHERE EXTRACT(MONTH FROM fechacreacion) = $1 AND state = $2;',
  GET_SUPER_PROC_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM tramites_state_with_resources GROUP BY state;',
  GET_SUPER_PROC_COUNT_LAST_20_DAYS:
    "SELECT COUNT (*), fechacreacion::date FROM tramites_state_with_resources WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_SUPER_PROC_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM tramites_state_with_resources WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_SUPER_PROC_COUNT_LAST_5_YEARS:
    "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM tramites_state_with_resources \
    WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  // SOCIAL AFFAIRS STATS
  GET_AFFAIR_TOTAL_COUNT: 'SELECT COUNT (*) FROM caso_social;',
  GET_AFFAIR_TOTAL_IN_MONTH: 'SELECT COUNT (*) FROM caso_social WHERE EXTRACT(MONTH FROM fecha_creacion) = $1;',
  GET_AFFAIR_TOTAL_BY_STATUS: 'SELECT COUNT (*) FROM casos_sociales_state WHERE state = $1',
  GET_AFFAIR_BY_DATE:
    "SELECT COUNT (*), fecha_creacion::date FROM caso_social WHERE fecha_creacion::date > CURRENT_DATE - INTERVAL '30 days' GROUP BY fecha_creacion::date;",
  GET_AFFAIR_BY_STATUS_MONTHLY: 'SELECT COUNT (*) FROM casos_sociales_state WHERE EXTRACT(MONTH FROM fechacreacion) = $1 AND state = $2;',
  GET_AFFAIR_COUNT_BY_STATE: 'SELECT COUNT (*), state FROM casos_sociales_state GROUP BY state;',
  GET_AFFAIR_COUNT_LAST_20_DAYS:
    "SELECT COUNT (*), fechacreacion::date FROM casos_sociales_state WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '20 days' \
    GROUP BY fechacreacion::date ORDER BY fechacreacion DESC;",
  GET_AFFAIR_COUNT_LAST_12_MONTHS:
    "SELECT COUNT (*), EXTRACT(MONTH FROM fechacreacion::date) AS month, EXTRACT(YEAR FROM fechacreacion::date) \
    AS year FROM casos_sociales_state WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '12 months' \
    GROUP BY month, year;",
  GET_AFFAIR_COUNT_LAST_5_YEARS:
    "SELECT COUNT (*), EXTRACT(YEAR FROM fechacreacion::date) AS year FROM casos_sociales_state \
    WHERE fechacreacion::date > CURRENT_DATE - INTERVAL '5 years' GROUP BY year;",
  // EXTERNAL USER STATS
  GET_EXTERNAL_TOTAL_COUNT: 'SELECT COUNT(*) FROM tramite WHERE id_usuario = $1;',
  GET_EXTERNAL_APPROVED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = TRUE;",
  GET_EXTERNAL_REJECTED_COUNT: "SELECT COUNT(*) FROM tramites_state_with_resources WHERE usuario = $1 AND state = 'finalizado' AND aprobado = FALSE;",

  //Notificaciones

  GET_NON_NORMAL_OFFICIALS:
    'SELECT * FROM USUARIO  usr INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario \
    INNER JOIN institucion ins ON cf.id_institucion = ins.id_institucion WHERE \
    ins.nombre_corto = $1 AND usr.id_tipo_usuario != 3',
  GET_OFFICIALS_FOR_PROCEDURE:
    'SELECT * FROM permiso_de_acceso pda INNER JOIN usuario usr ON pda.id_usuario=usr.id_usuario \
    INNER JOIN CUENTA_FUNCIONARIO cf ON usr.id_usuario = cf.id_usuario INNER JOIN institucion ins \
    ON cf.id_institucion = ins.id_institucion WHERE ins.nombre_corto =$1 AND id_tipo_tramite = $2',
  GET_SUPER_USER: 'SELECT * FROM USUARIO WHERE id_tipo_usuario = 1',
  GET_PROCEDURE_CREATOR: 'SELECT * FROM USUARIO WHERE id_usuario = $1',
  GET_FINING_TARGET: 'SELECT cedula, nacionalidad FROM multa_state WHERE id=$1',
  CREATE_NOTIFICATION:
    'INSERT INTO notificacion (id_procedimiento, emisor, receptor, descripcion, status, \
    fecha, estado, concepto) VALUES ($1, $2, $3, $4, false, now(), $5, $6) RETURNING id_notificacion',
  GET_PROCEDURE_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_tramite_view WHERE id = $1',
  GET_FINING_NOTIFICATION_BY_ID: 'SELECT * FROM notificacion_multa_view WHERE id = $1',
  GET_PROCEDURE_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_tramite_view WHERE receptor = $1 ORDER BY "fechaCreacion"',
  GET_FINING_NOTIFICATIONS_FOR_USER: 'SELECT * FROM notificacion_multa_view WHERE receptor = $1 ORDER BY "fechaCreacion"',
  GET_USER_HAS_NOTIFICATIONS: 'SELECT (COUNT(*) > 0) as "hasNotifications" FROM notificacion WHERE receptor = $1 ::varchar AND status = false',
  CHECK_IF_USER_EXISTS: 'SELECT * FROM usuario WHERE cedula = $1 AND nacionalidad = $2',
  MARK_ALL_AS_READ: 'UPDATE notificacion SET status = true WHERE receptor = $1',

  //Terminal
  CREATE_TERMINAL_DESTINATION:
    'INSERT INTO operatividad_terminal (destino, tipo, monto, tasa) VALUES ($1, $2, $3, $4) \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, monto_calculado AS "montoCalculado"',
  TERMINAL_DESTINATIONS:
    'SELECT id_operatividad_terminal AS id, destino, tipo, monto, tasa, monto_calculado AS "montoCalculado", habilitado FROM operatividad_terminal;',
  UPDATE_TERMINAL_DESTINATION:
    'UPDATE operatividad_terminal SET destino = $1, tipo = $2, monto = $3, tasa = $4, habilitado = $5 WHERE id_operatividad_terminal = $6 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado";',
  INCREASE_TERMINAL_DESTINATION_COSTS:
    'UPDATE operatividad_terminal SET monto = monto * $1 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado"',
  DISABLE_TERMINAL_DESTINATION:
    'UPDATE operatividad_terminal SET habilitado = false WHERE id_operatividad_terminal = $1 \
    RETURNING id_operatividad_terminal AS id, destino, tipo, monto, tasa, habilitado, monto_calculado AS "montoCalculado"',
  
  
  //Multa
  FINING_INIT: 'SELECT * FROM insert_multa($1, $2, $3, $4, $5);',
  GET_ALL_FINES: 'SELECT * FROM multa_state ORDER BY fechacreacion;',
  GET_FINES_DIRECTOR_OR_ADMIN: 'SELECT * FROM multa_state WHERE nombrelargo = $1 ORDER BY fechacreacion;',
  GET_FINES_OFFICIAL: "SELECT * FROM multa_state WHERE nombrelargo = $1 AND state != 'validando' ORDER BY fechacreacion;",
  GET_FINES_EXTERNAL_USER: 'SELECT * FROM multa_state WHERE cedula = $1 AND nacionalidad = $2;',
  GET_RESOURCES_FOR_FINING:
    'SELECT DISTINCT tt.sufijo, tt.costo_base,\
  ml.costo FROM tipo_tramite tt INNER JOIN multa ml ON\
  tt.id_tipo_tramite=ml.id_tipo_tramite WHERE ml.id_multa = $1',
  GET_FINING_BY_ID: 'SELECT * FROM multa_state WHERE id=$1',
  GET_FINING_ID_FROM_FINING_STATE_BY_CODE: 'SELECT id FROM multa_state WHERE codigomulta=$1',
  GET_FINING_STATE:
    'SELECT id_multa AS id, multa_fsm(event ORDER BY id_evento_multa) AS state \
  FROM evento_multa \
  WHERE id_multa = $1 \
  GROUP BY id_multa;',
  GET_FINING_STATE_AND_TYPE_INFORMATION: 'SELECT mls.*, ttr.formato, ttr.planilla AS solicitud, ttr.certificado \
  FROM multa_state mls INNER JOIN tipo_tramite ttr ON mls.tipotramite=ttr.id_tipo_tramite WHERE mls.id=$1',
  UPDATE_FINING: 'SELECT update_multa_state($1, $2, $3, $4, $5) as state;',
  UPDATE_FINING_BALLOT: 'UPDATE multa SET url_boleta =$1 WHERE id_multa = $2',
  COMPLETE_FINING: 'SELECT complete_multa_state ($1,$2,$3,$4, $5) as state',
};

export default queries;
