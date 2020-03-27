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
  CREATE_USER: `INSERT INTO usuario (nombre_completo, nombre_de_usuario, direccion, cedula, nacionalidad, id_tipo_usuario, password, telefono) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
  ADD_PASSWORD: 'INSERT INTO cuenta_funcionario (id_usuario, password) VALUES ($1, $2);',
  ADD_OFFICIAL_DATA: 'INSERT INTO cuenta_funcionario (id_usuario, id_institucion) VALUES ($1, $2);',
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
  VALIDATE_TOKEN: "SELECT 1 FROM recuperacion WHERE token_recuperacion = $1 AND usado = false AND CURRENT_TIMESTAMP - fecha_recuperacion < '20 minutes';",
  EMAIL_EXISTS: 'SELECT 1 FROM usuario u WHERE nombre_de_usuario = $1;',
  EXTERNAL_USER_COMPLETE:
    'UPDATE usuario SET direccion = $1, cedula = $2, nacionalidad = $3, nombre_de_usuario = $4, password=$5, nombre_completo=$6, telefono=$7 WHERE id_usuario = $8 RETURNING *',
  DISABLE_TOKEN: 'UPDATE recuperacion SET usado = true WHERE token_recuperacion = $1',
  UPDATE_PASSWORD:
    'WITH usuario AS (SELECT u.id_usuario FROM usuario u INNER JOIN recuperacion r ON r.id_usuario = u.id_usuario WHERE token_recuperacion = $1) \
      UPDATE usuario SET password = $2 WHERE id_usuario = (SELECT id_usuario FROM usuario)',
  DROP_OFFICIAL_PERMISSIONS: 'DELETE FROM permiso_de_acceso WHERE id_usuario = $1;',

  //BANKS
  INSERT_PAYMENT: 'INSERT INTO pago (id_tramite, referencia, monto, id_banco, fecha_de_pago) VALUES ($1, $2, $3, $4, $5) RETURNING *;',
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
  GET_SECTIONS_BY_PROCEDURE:
    'SELECT DISTINCT sect.id_seccion as id, sect.nombre FROM\
  campo_tramite ct RIGHT JOIN seccion sect ON ct.id_seccion=sect.id_seccion WHERE ct.id_tipo_tramite=$1 ORDER BY sect.id_seccion',
  GET_PROCEDURE_BY_INSTITUTION:
    'SELECT id_tipo_tramite, nombre_tramite, costo_base, sufijo, pago_previo, utiliza_informacion_catastral FROM tipo_tramite tt WHERE id_institucion = $1 ORDER BY id_tipo_tramite',
  GET_FIELDS_BY_SECTION:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_BY_SECTION_FOR_OFFICIALS:
    "SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
    campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 AND NOT (ct.estado='iniciado' OR ct.estado = 'ingresardatos') ORDER BY ct.orden",
  GET_FIELDS_FOR_SOCIAL_CASE:
    'SELECT ct.*, camp.nombre, camp.tipo, camp.validacion, camp.col FROM campo_tramite ct INNER JOIN\
  campo camp ON ct.id_campo = camp.id_campo WHERE ct.id_seccion = $1 AND ct.id_tipo_tramite = $2 ORDER BY ct.orden',
  GET_TAKINGS_BY_PROCEDURE:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto,\
  ttr.fisico FROM recaudo rec INNER JOIN tipo_tramite_recaudo ttr ON rec.id_recaudo=ttr.id_recaudo\
  WHERE ttr.id_tipo_tramite=$1 ORDER BY rec.id_recaudo',
  GET_TAKINGS_FOR_VALIDATION:
    'SELECT rec.id_recaudo as id, rec.nombre_largo AS nombreCompleto, rec.nombre_corto AS nombreCorto, \
ttr.fisico FROM recaudo rec INNER JOIN tipo_tramite_recaudo ttr ON rec.id_recaudo=ttr.id_recaudo \
WHERE ttr.id_tipo_tramite=$1 AND ttr.fisico = false ORDER BY rec.id_recaudo',
  GET_TAKINGS_OF_INSTANCES: 'SELECT * FROM tramite_archivo_recaudo WHERE id_tramite = ANY( $1::int[] );',
  INSERT_TAKINGS_IN_PROCEDURE: 'INSERT INTO tramite_archivo_recaudo VALUES ($1,$2)',
  GET_PROCEDURES_INSTANCES_BY_INSTITUTION_ID:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
    nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, tipo_tramite.pago_previo AS "pagoPrevio" FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
    tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
    tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 ORDER BY tramites_state.fechacreacion;',
  GET_IN_PROGRESS_PROCEDURES_INSTANCES_BY_INSTITUTION:
    'SELECT tramites_state.*, institucion.nombre_completo AS nombrelargo, institucion.nombre_corto AS \
    nombrecorto, tipo_tramite.nombre_tramite AS nombretramitelargo, tipo_tramite.nombre_corto AS nombretramitecorto, tipo_tramite.pago_previo AS "pagoPrevio"  FROM tramites_state INNER JOIN tipo_tramite ON tramites_state.tipotramite = \
    tipo_tramite.id_tipo_tramite INNER JOIN institucion ON institucion.id_institucion = \
    tipo_tramite.id_institucion WHERE tipo_tramite.id_institucion = $1 AND tramites_state.state=\'enproceso\' ORDER BY tramites_state.fechacreacion;',
  GET_ONE_PROCEDURE: 'SELECT * FROM tipo_tramite WHERE id_tipo_tramite = $1',
  GET_ONE_PROCEDURE_INFO:
    'SELECT id_tipo_tramite as id, id_institucion AS "idInstitucion", nombre_tramite AS "nombre", costo_base as costo, nombre_corto as "nombreCorto"  FROM tipo_tramite WHERE id_tipo_tramite = $1;',
  UPDATE_PROCEDURE_COST: 'UPDATE tipo_tramite SET costo_base = $2 WHERE id_tipo_tramite = $1 RETURNING *',
  VALIDATE_FIELDS_FROM_PROCEDURE:
    'SELECT DISTINCT camp.validacion, camp.tipo FROM campo_tramite ct INNER JOIN campo camp ON\
     ct.id_campo=camp.id_campo WHERE ct.id_tipo_tramite=$1 AND ct.estado=$2',
  GET_RESOURCES_FOR_PROCEDURE:
    'SELECT DISTINCT tt.sufijo, tt.costo_base, usr.nombre_completo as nombrecompleto, \
    usr.nombre_de_usuario as nombreusuario, tr.costo FROM tipo_tramite tt INNER JOIN tramite tr ON\
    tt.id_tipo_tramite=tr.id_tipo_tramite INNER JOIN usuario usr ON tr.id_usuario=usr.id_usuario\
    WHERE tt.id_tipo_tramite=$1',
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
  UPDATE_STATE: 'SELECT update_tramite_state($1, $2, $3, $4, $5) as state;', //tramite, evento
  COMPLETE_STATE: 'SELECT complete_tramite_state ($1,$2,$3,$4, $5) as state',
  UPDATE_STATE_SOCIAL_CASE: 'SELECT update_caso_state($1, $2, $3) as state', //idcaso, event, datos
  UPDATE_PROCEDURE_INSTANCE_COST: 'UPDATE tramite SET costo = $1 WHERE id_tramite = $2',
  GET_PROCEDURE_BY_ID: 'SELECT * FROM tramites_state_with_resources WHERE id=$1',
  GET_SOCIAL_CASE_BY_ID: 'SELECT * FROM casos_sociales_state WHERE id=$1',
  GET_CERTIFICATE_BY_PROCEDURE_ID: 'SELECT certificado AS "urlCertificado" FROM tramites_state_with_resources WHERE id = $1',
  GET_PROCEDURE_INSTANCES_FOR_USER: 'SELECT * FROM tramites_state_with_resources WHERE usuario = $1 ORDER BY fechacreacion;',
  GET_ALL_PROCEDURE_INSTANCES: 'SELECT * FROM tramites_state_with_resources ORDER BY fechacreacion;',

  //parroquias
  GET_PARISHES: 'SELECT * FROM parroquia;',

  //Valores fiscales
  GET_SECTOR_BY_PARISH: 'SELECT id, descripcion FROM VALORES_FISCALES.SECTOR WHERE PARROQUIA_ID = (SELECT ID FROM PARROQUIA WHERE NOMBRE = $1) ORDER BY id',
  GET_YEARS: 'SELECT id, descripcion FROM VALORES_FISCALES.ANO ORDER BY DESCRIPCION DESC LIMIT 4',
  GET_CONSTRUCTION_TYPES: 'SELECT id, descripcion FROM VALORES_FISCALES.TIPO_CONSTRUCCION',
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

  //Inmuebles
  GET_ALL_PROPERTIES:
    'SELECT i.id_inmueble AS "idInmueble", i.cod_catastral AS "codCatastral", i.direccion,\
  i.metros_construccion AS "metrosConstruccion", i.metros_terreno AS "metrosTerreno", i.fecha_creacion AS "fechaCreacion",i.fecha_actualizacion AS "fechaActualizacion",  \
  i.fecha_ultimo_avaluo AS "fechaUltimoAvaluo" , p.nombre AS parroquia FROM inmueble_urbano i INNER JOIN parroquia p ON i.id_parroquia = p.id;',
  GET_ONE_PROPERTY_BY_COD:
    'SELECT i.id_inmueble AS "idInmueble", i.cod_catastral AS "codCatastral", i.direccion,\
  i.metros_construccion AS "metrosConstruccion", i.metros_terreno AS "metrosTerreno", i.fecha_creacion AS "fechaCreacion",i.fecha_actualizacion AS "fechaActualizacion",  \
  i.fecha_ultimo_avaluo AS "fechaUltimoAvaluo" , p.nombre AS parroquia FROM inmueble_urbano i INNER JOIN parroquia p ON i.id_parroquia = p.id WHERE i.cod_catastral = $1;',
  GET_PROPERTY_OWNERS:
    'SELECT p.id_propietario AS "idpropietario", razon_social AS "razonSocial", cedula, rif, email, pi.id_inmueble FROM propietario p INNER JOIN propietario_inmueble pi ON p.id_propietario = pi.id_propietario;',
  CREATE_PROPERTY:
    'INSERT INTO inmueble_urbano (cod_catastral, direccion, id_parroquia, \
    metros_construccion, metros_terreno, fecha_creacion, fecha_actualizacion, tipo_inmueble) \
    VALUES ($1, $2, (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), $4, $5, now(), now(), $6)\
    ON CONFLICT (cod_catastral) DO UPDATE SET metros_construccion = $4, metros_terreno = $5, \
    id_parroquia = (SELECT id FROM parroquia WHERE nombre = $3 LIMIT 1), fecha_actualizacion = now() \
    RETURNING id_inmueble',
  GET_PROPERTY_BY_ID: 'SELECT * FROM inmueble_urbano_view WHERE id=$1',
  CREATE_PROPERTY_OWNER:
    'INSERT INTO propietario (razon_social, cedula, rif, email) VALUES ($1,$2,$3,$4) ON CONFLICT (cedula, rif) DO UPDATE razon_social = $1 RETURNING *',
  CREATE_PROPERTY_WITH_SIGNED_OWNER: 'INSERT INTO propietario_inmueble (id_propietario, id_inmueble) VALUES ($1, $2)',
  //ordenanza
  ORDINANCES_WITHOUT_CODCAT_PROCEDURE:
    'SELECT v.descripcion AS "valorDescripcion", v.valor_en_bs AS "valorEnBs", \
  o.id_ordenanza as id ,o.descripcion AS "descripcionOrdenanza", o.tarifa AS "tarifaOrdenanza", t.id_tipo_tramite AS "tipoTramite",t.tasa, t.formula, \
  tt.costo_base AS "costoBase", t.utiliza_codcat AS "utilizaCodcat", vo.id_variable AS "idVariable", vo.nombre as "nombreVariable", vo.nombre_plural AS "nombreVariablePlural" \
  FROM valor v INNER JOIN ordenanza o ON v.id_valor = o.id_valor \
  INNER JOIN tarifa_inspeccion t ON t.id_ordenanza = o.id_ordenanza \
  INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
  LEFT JOIN variable_ordenanza vo ON vo.id_variable = t.id_variable \
  WHERE t.id_tipo_tramite = $1 AND t.utiliza_codcat = false;',
  ORDINANCES_WITH_CODCAT_PROCEDURE:
    'SELECT v.descripcion AS "valorDescripcion", v.valor_en_bs AS "valorEnBs", \
  o.id_ordenanza as id, o.descripcion AS "descripcionOrdenanza", o.tarifa AS "tarifaOrdenanza", t.id_tipo_tramite AS "tipoTramite",t.tasa, t.formula, \
  tt.costo_base AS "costoBase", t.utiliza_codcat AS "utilizaCodcat", vo.id_variable AS "idVariable", vo."nombreVariable", vo.nombre_plural AS "nombreVariablePlural" \
  FROM valor v INNER JOIN ordenanza o ON v.id_valor = o.id_valor \
  INNER JOIN tarifa_inspeccion t ON t.id_ordenanza = o.id_ordenanza \
  INNER JOIN tipo_tramite tt ON t.id_tipo_tramite = tt.id_tipo_tramite \
  LEFT JOIN variable_ordenanza vo ON vo.id_variable = t.id_variable \
  WHERE t.id_tipo_tramite = $1 AND t.utiliza_codcat = true;',
  CREATE_ORDINANCE_FOR_PROCEDURE:
    'INSERT INTO ordenanza_tramite (id_tramite, id_tarifa, utmm, valor_calc, factor, factor_value, costo_ordenanza) \
    VALUES ($1, (SELECT id_tarifa FROM tarifa_inspeccion trf INNER JOIN ordenanza ord ON \
      trf.id_ordenanza=ord.id_ordenanza WHERE trf.id_tipo_tramite=$2 AND ord.descripcion = $3 LIMIT 1), \
      $4,$5,$6,$7, $8) RETURNING *;',
  ORDINANCES_PROCEDURE_INSTANCES: 'SELECT * FROM ordenanzas_instancias_tramites WHERE "idTramite" = $1;',
  //valor
  GET_UTMM_VALUE: "SELECT valor_en_bs FROM valor WHERE descripcion = 'UTMM'",
  UPDATE_UTMM_VALUE: "UPDATE valor SET valor_en_bs = $1 WHERE descripcion = 'UTMM' RETURNING valor_en_bs;",
};

export default queries;
