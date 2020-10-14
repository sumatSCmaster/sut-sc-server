
INSERT INTO valor VALUES (4, 'PETRO', 17937438.15);

UPDATE ordenanza SET id_valor = 4;

ALTER TABLE tipo_tramite RENAME COLUMN costo_utmm TO costo_petro; 

ALTER TABLE ordenanza_tramite RENAME COLUMN utmm TO petro;

DROP TRIGGER tipos_tramites_costo_utmm_trig ON valor;

CREATE FUNCTION public.tipos_tramites_costo_petro_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuevoCosto numeric;
    BEGIN
        nuevoCosto = NEW.valor_en_bs;
        UPDATE tipo_tramite SET costo_base = ROUND((nuevoCosto * costo_petro),2) WHERE costo_petro IS NOT NULL;
        RETURN NEW;
    END
$$;

CREATE TRIGGER tipos_tramites_costo_petro_trig AFTER UPDATE ON public.valor FOR EACH ROW WHEN (((new.descripcion)::text = 'PETRO'::text)) EXECUTE FUNCTION public.tipos_tramites_costo_petro_trigger_func();

DROP VIEW public.ordenanzas_instancias_tramites;

CREATE OR REPLACE VIEW public.ordenanzas_instancias_tramites AS
 SELECT ot.id_ordenanza_tramite AS id,
    ot.id_tramite AS "idTramite",
    o.descripcion AS ordenanza,
    ot.factor,
    ot.factor_value AS "factorValue",
    ot.petro,
    ot.valor_calc AS "valorCalc",
    ot.costo_ordenanza AS "costoOrdenanza"
   FROM ((public.ordenanza_tramite ot
     JOIN public.tarifa_inspeccion ti ON ((ot.id_tarifa = ti.id_tarifa)))
     JOIN public.ordenanza o ON ((o.id_ordenanza = ti.id_ordenanza)));

ALTER TABLE impuesto.liquidacion ADD COLUMN monto_petro NUMERIC;

DROP FUNCTION insert_liquidacion(integer, numeric, varchar, varchar, json, date, integer);
CREATE OR REPLACE FUNCTION public.insert_liquidacion(_id_solicitud integer DEFAULT NULL::integer, _monto_petro numeric DEFAULT NULL::numeric, _ramo character varying DEFAULT NULL::character varying, _descripcion_ramo character varying DEFAULT NULL::character varying, _datos json DEFAULT NULL::json, _fecha date DEFAULT NULL::date, _id_registro_municipal integer DEFAULT NULL::integer)
 RETURNS SETOF impuesto.liquidacion
 LANGUAGE plpgsql
AS $function$
DECLARE
    liquidacionRow impuesto.liquidacion%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.liquidacion (id_solicitud, monto_petro, id_subramo, datos, fecha_vencimiento) VALUES (_id_solicitud, _monto_petro, (SELECT sr.id_subramo FROM impuesto.subramo sr INNER JOIN impuesto.ramo r ON sr.id_ramo = r.id_ramo WHERE (r.descripcion = _ramo OR r.descripcion_corta = _ramo) AND (sr.descripcion = _descripcion_ramo OR sr.descripcion = 'Pago ordinario') ORDER BY id_subramo DESC LIMIT 1), _datos, _fecha) RETURNING * INTO liquidacionRow;

        IF _id_registro_municipal IS NOT NULL THEN
            UPDATE impuesto.liquidacion SET id_registro_municipal = _id_registro_municipal WHERE id_liquidacion = liquidacionRow.id_liquidacion;
        END IF;

        RETURN QUERY SELECT * FROM impuesto.liquidacion WHERE id_liquidacion=liquidacionRow.id_liquidacion;

        RETURN;
    END;
$function$;


ALTER TABLE impuesto.fraccion ADD COLUMN monto_petro NUMERIC;


UPDATE impuesto.avaluo_inmueble SET avaluo = ROUND(avaluo / (SELECT valor_en_bs FROM valor WHERE descripcion = 'PETRO'), 8);


UPDATE tipo_tramite SET costo_petro = 0.12 WHERE id_tipo_tramite = 28;

UPDATE tipo_tramite SET formato = 'SEDEMAT-001', planilla ='sedemat-solt-LAE', certificado ='sedemat-cert-LAE', id_ramo = 9 WHERE id_tipo_tramite = 36

ALTER TABLE impuesto.baremo_servicio_municipal RENAME TO baremo;

ALTER TABLE impuesto.registro_municipal ADD COLUMN es_monotributo boolean default false;



DROP FUNCTION impuesto.insert_fraccion(integer, numeric, integer, date);
CREATE OR REPLACE FUNCTION impuesto.insert_fraccion(_id_convenio integer, _monto_petro numeric, _porcion integer, _fecha date)
 RETURNS SETOF impuesto.fraccion
 LANGUAGE plpgsql
AS $function$
DECLARE
    fraccionRow impuesto.fraccion%ROWTYPE;
    BEGIN
        INSERT INTO impuesto.fraccion (id_convenio, monto_petro, porcion, fecha) VALUES (_id_convenio,  _monto_petro, _porcion, _fecha) RETURNING * into fraccionRow;
        
        INSERT INTO impuesto.evento_fraccion values (default, fraccionRow.id_fraccion, 'iniciar', now());
            
        RETURN QUERY SELECT * FROM impuesto.fraccion WHERE id_fraccion=fraccionRow.id_fraccion;
                
        RETURN;
    END;
$function$;


ALTER TABLE impuesto.fraccion ALTER COLUMN monto DROP NOT NULL;

INSERT INTO impuesto.baremo (descripcion, indicador) VALUES ('Costo de Solvencia de Actividad Economica Permanente', 0.12);
INSERT INTO impuesto.baremo (descripcion, indicador) VALUES ('Costo de Solvencia de Actividad Economica Temporal', 0.24);