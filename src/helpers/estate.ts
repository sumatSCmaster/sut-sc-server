import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import { Tramite, Inmueble } from '@root/interfaces/sigt';
import moment from 'moment';
import { mainLogger } from '@utils/logger';

const pool = Pool.getInstance();

export const getEstatesInfo = async () => {
  const client = await pool.connect();
  try {
    const entities = (await client.query('SELECT * FROM inmueble.entidad')).rows;
    const parishes = (await client.query('SELECT * FROM inmueble.parroquia WHERE id_parroquia <> 5')).rows;
    const ambits = (await client.query('SELECT * FROM inmueble.ambito')).rows;
    const sectors = (await client.query('SELECT * FROM inmueble.sector')).rows;
    const blocks = (await client.query('SELECT * FROM inmueble.manzana')).rows;
    const urbanLandTypes = (await client.query('SELECT * FROM inmueble.tipo_tierra_urbana')).rows;
    const buildingTypes = (await client.query('SELECT * FROM inmueble.tipo_edificacion')).rows;
    const buildingClassifications = (await client.query('SELECT * FROM inmueble.clase_edificacion')).rows;
    const constructionTypes = (await client.query('SELECT * FROM inmueble.tipo_construccion')).rows;
    const dwellingTypes = (await client.query('SELECT * FROM inmueble.tipo_vivienda')).rows;
    const constructionValues = (await client.query('SELECT * FROM inmueble.valor_construccion')).rows;
    const landClasses = (await client.query('SELECT * FROM inmueble.clase_terreno')).rows;
    const subsectors = (await client.query('SELECT * FROM inmueble.subsector')).rows;
    // return await addOwners(estates, client);
    return {data: {entities, parishes, ambits, sectors, blocks, urbanLandTypes, buildingTypes, buildingClassifications, constructionTypes, dwellingTypes, constructionValues, landClasses, subsectors}, status: 200}
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || errorMessageExtractor(e) || 'Error al obtener los inmuebles',
    };
  } finally {
    client.release();
  }
};

export const getEstateInfoByCod = async (cod: string) => {
  const client = await pool.connect();
  try {
    mainLogger.info('GetEstateInfoByCod');
    const estate = (await client.query(queries.GET_ONE_PROPERTY_BY_COD, [cod])).rows;
    const res = await addOwners(estate, client);
    return { data: res[0] };
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || errorMessageExtractor(e) || 'Error al obtener los inmuebles',
    };
  } finally {
    client.release();
  }
};

export const addOwners = async (properties, client: PoolClient) => {
  try {
    let localProperties = [...properties];
    const owners = (await client.query(queries.GET_PROPERTY_OWNERS)).rows;
    const ownersSplit = owners.reduce((prev, next) => {
      if (prev[next.id_inmueble] === undefined) {
        let arr: any[] = [];
        arr.push(next);
        prev[next.id_inmueble] = arr;
      } else {
        prev[next.id_inmueble].push(next);
      }
      return prev;
    }, {});
    return localProperties.map((prop) => {
      prop.propietarios = ownersSplit[prop.idInmueble];
      return prop;
    });
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || errorMessageExtractor(e) || 'Error al obtener propietarios',
    };
  }
};

export const createPersonalEstate = async (procedure) => {
  const client = await pool.connect();
  const { codCat, direccion, parroquia, areaTerreno, areaConstruccion, tipoInmueble } = procedure.datos.funcionario;
  const { propietarios } = procedure.datos.funcionario;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.CREATE_PROPERTY, [codCat, direccion, parroquia, areaConstruccion, areaTerreno, tipoInmueble])).rows[0];
    const inmueble = (await client.query(queries.GET_PROPERTY_BY_ID, [response.id_inmueble])).rows[0];
    await Promise.all(
      propietarios.map(async (el) => {
        const owner = (await client.query(queries.CREATE_PROPERTY_OWNER, [el.razonSocial, el.cedula, el.rif, el.email])).rows[0];
        await client.query(queries.CREATE_PROPERTY_WITH_SIGNED_OWNER, [owner.id_propietario, inmueble.id]);
      })
    );
    client.query('COMMIT');
    return { status: 200, message: 'Código catastral creado satisfactoriamente', inmueble };
  } catch (error) {
    client.query('ROLLBACK');
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};

// SEDEMAT

export const taxPayerEstatesByRIM = async ({ typeDoc, rif, rim }) => {
  const client = await pool.connect();
  let estates;
  try {
    mainLogger.info('taxPayerEStateBYRIM');
    const rimData = await client.query(queries.GET_RIM_DATA, [rim]);
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }
    const contributor = await client.query(queries.GET_CONTRIBUTOR, [typeDoc, rif, rim]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }
    estates = (await client.query(queries.GET_ESTATES_BY_RIM, [rim])).rows;
    estates = await Promise.all(estates.map(async estate => {
      let extraInfo;
      switch(estate.clasificacion) {
        case 'EJIDO':
          extraInfo = (await client.query(queries.GET_COMMON_LAND, [estate.id])).rows[0];
          break;
        case 'CEMENTERIO':
          extraInfo = (await client.query(queries.GET_GRAVEYARD, [estate.id])).rows[0];
          break;
        case 'MERCADO':
          extraInfo = (await client.query(queries.GET_MARKET_ESTATE, [estate.id])).rows[0];
          break;
        case 'QUIOSCO':
          extraInfo = (await client.query(queries.GET_QUIOSCO, [estate.id])).rows[0];
          break;
        default: break;
        }
      return {...estate, ...extraInfo};
    }));
    const estatesWithAppraisals = await Promise.all(
      estates.map((row) => {
        return new Promise(async (res, rej) => {
          const liq = (await client.query('SELECT fecha_liquidacion FROM impuesto.liquidacion WHERE id_liquidacion = $1', [row.id_liquidacion_fecha_inicio])).rows[0];
          let fecha;
          if (liq) {
            fecha = moment(liq.fecha_liquidacion).add(1, 'M');
          }
          res({
            ...row,
            avaluos: (await client.query('SELECT avaluo_terreno AS "avaluoTerreno", avaluo_construccion AS "avaluoConstruccion" FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1 ORDER BY anio DESC LIMIT 1', [row.id])).rows,
            fechaInicio: fecha || null,
          });
        });
      })
    );

    return { status: 200, contribuyente: contributor.rows[0], inmuebles: estatesWithAppraisals };
  } catch (e) {
    throw {
      error: e,
      message: errorMessageExtractor(e),
    };
  } finally {
    client.release();
  }
};

export const taxPayerEstatesByNaturalCont = async ({ typeDoc, doc }) => {
  const client = await pool.connect();
  let estates, extraInfo;
  try {
    const contributor = await client.query(queries.GET_NATURAL_CONTRIBUTOR, [typeDoc, doc]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }
    estates = (await client.query(queries.GET_ESTATES_BY_NATURAL_CONTRIBUTOR, [contributor.rows[0].id])).rows;
    estates = await Promise.all(estates.map(async estate => {
      let extraInfo;
      switch(estate.clasificacion) {
        case 'EJIDO':
          extraInfo = (await client.query(queries.GET_COMMON_LAND, [estate.id])).rows[0];
          break;
        case 'CEMENTERIO':
          extraInfo = (await client.query(queries.GET_GRAVEYARD, [estate.id])).rows[0];
          break;
        case 'MERCADO':
          extraInfo = (await client.query(queries.GET_MARKET_ESTATE, [estate.id])).rows[0];
          break;
        case 'QUIOSCO':
          extraInfo = (await client.query(queries.GET_QUIOSCO, [estate.id])).rows[0];
          break;
        default: break;
        }
      return {...estate, ...extraInfo};
    }));
    const estatesWithAppraisals = await Promise.all(
      estates.map((row) => {
        return new Promise(async (res, rej) => {
          const liq = (await client.query('SELECT fecha_liquidacion FROM impuesto.liquidacion WHERE id_liquidacion = $1', [row.id_liquidacion])).rows[0];
          let fecha;
          if (liq) {
            fecha = moment(liq.fecha_liquidacion).add(1, 'M');
          }
          const actualizable = (await client.query(`SELECT * FROM impuesto.liquidacion WHERE id_subramo = 9 AND (datos#>>'{desglose, 0, inmueble}')::INT = $1`, [row.id])).rowCount <= 1;
          console.log(liq, fecha, row, 'MASTER INMUEBLE')
          res({
            ...row,
            avaluos: (await client.query('SELECT avaluo_terreno AS "avaluoTerreno", avaluo_construccion AS "avaluoConstruccion" FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1 ORDER BY anio DESC LIMIT 1', [row.id])).rows,
            fechaInicio: fecha || null,
            actualizable
          });
        });
      })
    );

    return { status: 200, contribuyente: contributor.rows[0], inmuebles: estatesWithAppraisals };
  } catch (e) {
    throw {
      error: e,
      message: errorMessageExtractor(e),
    };
  } finally {
    client.release();
  }
};

export const userEstates = async ({ typeDoc, doc }) => {
  const client = await pool.connect();
  try {
    const estates = (await client.query(queries.GET_ESTATES_BY_USER_INFO, [typeDoc, doc])).rows;
    const estatesWithAppraisals = await Promise.all(
      estates.map((row) => {
        return new Promise(async (res, rej) => {
          res({
            ...row,
            avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows,
          });
        });
      })
    );

    return estatesWithAppraisals;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getEstateByCod = async ({ codCat }) => {
  const client = await pool.connect();
  let extraInfo;
  try {
    mainLogger.info('getEstateByCod');
    const estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    const propietorRim = (
      await client.query(
        `SELECT CONCAT(cont.tipo_documento, '-', cont.documento) as rif, 
                                                            rm.referencia_municipal as rim, razon_social as "razonSocial", 
                                                            rm.denominacion_comercial as "denominacionComercial", telefono_celular as telefono, 
                                                            email, rm.direccion
    FROM impuesto.registro_municipal rm
    INNER JOIN impuesto.contribuyente cont ON cont.id_contribuyente = rm.id_contribuyente
    WHERE id_registro_municipal = $1`,
        [estate.rows[0].id_registro_municipal]
      )
    ).rows[0];

    const propietors = (
      await client.query(
        `SELECT CONCAT(cont.tipo_documento, '-', cont.documento) as rif, razon_social as "razonSocial", relacion
                                              FROM inmueble_urbano iu
                                              INNER JOIN impuesto.inmueble_contribuyente ic ON ic.id_inmueble = iu.id_inmueble
                                              INNER JOIN impuesto.contribuyente cont ON cont.id_contribuyente = ic.id_contribuyente
                                              WHERE iu.id_inmueble = $1`,
        [estate.rows[0].id]
      )
    ).rows;
    const inmueble = {...estate.rows[0]}
    inmueble.tipoTierraUrbana = (await client.query('SELECT * FROM inmueble.tipo_tierra_urbana WHERE id_tipo_tierra_urbana = (SELECT id_tipo_tierra_urbana FROM inmueble.detalle_codigo WHERE id_inmueble = $1)', [inmueble.id])).rows[0];
    inmueble.tipoConstruccion = (await client.query('SELECT * FROM inmueble.tipo_construccion WHERE id_tipo_construccion = (SELECT id_tipo_construccion FROM inmueble.detalle_codigo WHERE id_inmueble = $1)', [inmueble.id])).rows[0];
    inmueble.claseTerreno = (await client.query('SELECT * FROM inmueble.clase_terreno WHERE id_clase_terreno = (SELECT id_clase_terreno FROM impuesto.inmueble_tributo WHERE id_inmueble = $1)', [inmueble.id])).rows[0];
    inmueble.valorConstruccion = (await client.query('SELECT * FROM inmueble.valor_construccion WHERE id_valor_construccion = (SELECT id_valor_construccion FROM impuesto.inmueble_tributo WHERE id_inmueble = $1)', [inmueble.id])).rows[0];
    inmueble.manzana = (await client.query('SELECT * FROM inmueble.manzana WHERE id_manzana = (SELECT id_manzana FROM inmueble.detalle_codigo WHERE id_inmueble = $1)', [inmueble.id])).rows[0];
    const cod = inmueble.codigoCatastral.split('').findIndex(elem => /[a-zA-Z]/.test(elem));
    inmueble.ambito = (await client.query('SELECT * FROM inmueble.ambito WHERE cod_ambito = $1', [inmueble.codigoCatastral.slice(cod, cod + 3)])).rows[0];
    delete inmueble.idTipoConstruccion;
    delete inmueble.idTipoTierraUrbana;
    switch(inmueble.clasificacion) {
      case 'EJIDO':
        extraInfo = (await client.query(queries.GET_COMMON_LAND, [inmueble.id])).rows[0];
        break;
      case 'CEMENTERIO':
        extraInfo = (await client.query(queries.GET_GRAVEYARD, [inmueble.id])).rows[0];
        break;
      case 'MERCADO':
        extraInfo = (await client.query(queries.GET_MARKET_ESTATE, [inmueble.id])).rows[0];
        break;
      case 'QUIOSCO':
        extraInfo = (await client.query(queries.GET_QUIOSCO, [inmueble.id])).rows[0];
        break;
      default: break;
      }
    
    return {
      status: 200,
      message: 'Inmueble encontrado',
      inmueble: { ...inmueble, ...extraInfo, propietarioRim: propietorRim, propietarios: propietors, avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e: any) {
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const parishEstates = async ({ idParroquia }) => {
  const client = await pool.connect();
  try {
    const estates = (await client.query(queries.GET_PARISH_ESTATES, [idParroquia])).rows;
    const estatesWithAppraisals = await Promise.all(
      estates.map((row) => {
        return new Promise(async (res, rej) => {
          res({
            ...row,
            avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows,
            rim: (await client.query(queries.GET_RIM_DATA, [row.idRim])).rows[0],
          });
        });
      })
    );

    return estatesWithAppraisals;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const createBareEstate = async ({ codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, tipoTierraUrbana, tipoConstruccion, dirDoc, claseTerreno, valorConstruccion, manzana, userId, clasificacion, uso, tenencia, contrato, clase, fechaVencimiento, mercados, tipoLocal, tipoAE, objetoQuiosco, tipoQuiosco, zonaQuiosco, areaServicios, areaServiciosIndicador, sector, canonArrendamientoMercado, canonArrendamientoQuiosco }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // const codIsApproved = (await client.query(queries.GET_APPROVED_CPU_PROCEDURE, [codigoCpu])).rows[0];
    // if (!codIsApproved) throw new Error('El código ingresado no pertenece a un trámite aprobado de solvencia de inmuebles');
    const estateAlreadyExists = (await client.query('SELECT EXISTS(SELECT * FROM inmueble_urbano WHERE cod_catastral = $1)', [codCat])).rows[0]?.exists;
    if (estateAlreadyExists) throw {status: 401, message: 'El codigo catastral registrado en el sistema ya existe'};
    let estate = (await client.query(queries.CREATE_BARE_ESTATE, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, dirDoc, clasificacion])).rows[0];
    switch(estate.clasificacion) {
      case 'EJIDO':
        const ejido = (await client.query(queries.INSERT_COMMON_LAND, [estate.id, uso, clase, tenencia, contrato, fechaVencimiento])).rows[0];
        estate = {...estate, ...ejido};
        break;
      case 'MERCADO':
        const mercado = (await client.query(queries.INSERT_MARKET_ESTATE, [estate.id, mercados, tipoLocal, tipoAE, canonArrendamientoMercado])).rows[0];
        estate = {...estate, ...mercado};
        break;
      case 'QUIOSCO':
        const canonQuiosco = (await client.query(`SELECT id_canon FROM inmueble.canon_arrendamiento_quiosco WHERE nombre = $1`, [tipoQuiosco])).rows[0]?.id_canon;
        const quiosco = (await client.query(queries.INSERT_QUIOSCO , [estate.id, objetoQuiosco, tipoQuiosco, zonaQuiosco, canonQuiosco])).rows[0];
        estate = {...estate, ...quiosco};
        break;
      case 'CEMENTERIO':
        const cementerio = (await client.query(queries.INSERT_GRAVEYARD, [estate.id, areaServicios, tenencia, sector, areaServiciosIndicador])).rows[0];
        estate = {...estate, ...cementerio};
        break;
      default:
       break;
    }
    mainLogger.info(estate);
    // await client.query(queries.ADD_MOVEMENT, [estate.id, userId, 'inmueble_registrado', 'INMUEBLE']);
    await client.query(queries.INSERT_ESTATE_VALUE, [estate.id, tipoTierraUrbana.monto * metrosTerreno, tipoConstruccion.monto * metrosConstruccion ]);
    await client.query('INSERT INTO impuesto.inmueble_tributo (id_inmueble, id_clase_terreno, id_valor_construccion) VALUES ($1, $2, $3)', [estate.id, claseTerreno, valorConstruccion]);
    await client.query('INSERT INTO inmueble.detalle_codigo (id_inmueble, id_manzana, id_tipo_tierra_urbana, id_tipo_construccion) VALUES($1, $2, $3, $4)', [estate.id, manzana, tipoTierraUrbana.id_tipo_tierra_urbana, tipoConstruccion.id_tipo_construccion])
    await client.query('COMMIT');

    return { status: 200, inmueble: { ...estate, avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.id])).rows } };
  } catch (e: any) {
    mainLogger.error(e);
    await client.query('ROLLBACK');
    throw {
      status: e.status || 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || e.message || 'Error al crear el inmueble',
    };
  } finally {
    client.release();
  }
};

export const updateEstate = async ({ id, codCat, newCodCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, avaluos, areaServiciosIndicador, tipoTierraUrbana, tipoConstruccion, dirDoc, claseTerreno, valorConstruccion, manzana, userId, clasificacion, uso, clase, tenencia, contrato, fechaVencimiento, mercados, tipoLocal, tipoAE, objetoQuiosco, tipoQuiosco, zonaQuiosco, areaServicios, sector, canonArrendamientoQuiosco, canonArrendamientoMercado}) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let estate = (await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat])).rows[0];
    // const movimiento = await client.query(queries.ADD_MOVEMENT, [id, userId, 'inmueble_modificado', 'INMUEBLE']);
    if (estate.enlazado && tipoInmueble === 'RESIDENCIAL') {
      const commercialEstates = await client.query(queries.CHECK_IF_HAS_COMMERCIAL_ESTATES, [estate.id_registro_municipal]);
      const allEstates = await client.query(queries.COUNT_ESTATES, [estate.id_registro_municipal]);
      if (+allEstates.rows[0].allestates === 1) {
        throw new Error('El contribuyente debe tener por lo menos un inmueble COMERCIAL ya asociado.');
      } else if (+allEstates.rows[0].allestates > 1 && +commercialEstates.rows[0].commercials === 1 && estate.tipoInmueble === 'COMERCIAL') {
        throw new Error('El contribuyente debe tener por lo menos un inmueble COMERCIAL ya asociado.');
      }
    }
    await client.query(`DELETE FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1`, [id]);
    await client.query(queries.INSERT_ESTATE_VALUE, [id, tipoTierraUrbana.monto * metrosTerreno, tipoConstruccion.monto * metrosConstruccion]);
    estate = (await client.query(queries.UPDATE_ESTATE, [direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, newCodCat, id, dirDoc, clasificacion])).rows[0];
    await client.query('DELETE FROM inmueble_ejidos WHERE id_inmueble = $1', [estate.id]);
    await client.query('DELETE FROM inmueble_mercados WHERE id_inmueble = $1', [estate.id]);
    await client.query('DELETE FROM inmueble_cementerios WHERE id_inmueble = $1', [estate.id]);
    await client.query('DELETE FROM inmueble_quioscos WHERE id_inmueble = $1', [estate.id]);
    await client.query('DELETE FROM impuesto.inmueble_tributo WHERE id_inmueble = $1', [estate.id]);
    await client.query('DELETE FROM inmueble.detalle_codigo WHERE id_inmueble = $1', [estate.id]);
    await client.query('INSERT INTO inmueble.detalle_codigo (id_inmueble, id_manzana, id_tipo_tierra_urbana, id_tipo_construccion) VALUES($1, $2, $3, $4)', [estate.id, manzana, tipoTierraUrbana.id_tipo_tierra_urbana, tipoConstruccion.id_tipo_construccion])
    await client.query('INSERT INTO impuesto.inmueble_tributo (id_inmueble, id_clase_terreno, id_valor_construccion) VALUES ($1, $2, $3)', [estate.id, claseTerreno, valorConstruccion]);
    console.log(estate, 'MASTER ESTATE');
    switch(estate.clasificacion) {
      case 'EJIDO':
        const ejido = (await client.query(queries.INSERT_COMMON_LAND, [estate.id, uso, clase, tenencia, contrato, fechaVencimiento])).rows[0];
        estate = {...estate, ...ejido};
        break;
      case 'MERCADO':
        const mercado = (await client.query(queries.INSERT_MARKET_ESTATE, [estate.id, mercados, tipoLocal, tipoAE, canonArrendamientoMercado])).rows[0];
        estate = {...estate, ...mercado};
        break;
      case 'QUIOSCO':
        const quiosco = (await client.query(queries.INSERT_QUIOSCO , [estate.id, objetoQuiosco, tipoQuiosco, zonaQuiosco, canonArrendamientoQuiosco])).rows[0];
        estate = {...estate, ...quiosco};
        break;
      case 'CEMENTERIO':
        const cementerio = (await client.query(queries.INSERT_GRAVEYARD, [estate.id, areaServicios, tenencia, sector, areaServiciosIndicador])).rows[0];
        estate = {...estate, ...cementerio};
        break;
      default:
       break;
    }
    await client.query('COMMIT');
    return { status: 200, message: 'Inmueble actualizado', inmueble: estate };
    // return {inmueble: {...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows }};
  } catch (e: any) {
    await client.query('ROLLBACK');
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const updateEstateDate = async ({ id, date, rim, taxpayer }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const fromDate = moment(date).subtract(1, 'M');
    await client.query(`DELETE FROM impuesto.liquidacion WHERE id_subramo = 9 AND (datos#>>'{desglose, 0, inmueble}')::INT = $1`, [id])
    const IUData = (await client.query('SELECT clasificacion FROM inmueble_urbano WHERE id_inmueble = $1', [id])).rows[0]?.clasificacion;
    const fromEndDate = fromDate.clone().endOf('month').format('MM-DD-YYYY');
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [null, taxpayer])).rows[0];
    const rimData = (await client.query(queries.GET_RIM_DATA, [rim])).rows[0];
    const period = ((fromDate, classification) => {
      switch(classification) {
        case 'MERCADO' || 'QUIOSCO':
          return fromDate.toDate().toLocaleString('es-ES', { month: 'long' });
        case 'CEMENTERIO':
          return 'Anual';
        default:
          return fromDate.month() < 3 ? 'Primer Trimestre' : fromDate.month() < 6 ? 'Segundo Trimestre' : fromDate.month() < 9 ? 'Tercer Trimestre' : 'Cuarto Trimestre';  
      }
    })(fromDate, IUData);
    const ghostSettlement = (
      await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
        application.id_solicitud,
        0.0,
        'IU',
        'Pago ordinario',
        { fecha: {month: period, year: fromDate.year()}, desglose: [{ inmueble: id, clasificacion: IUData }] },
        fromEndDate,
        rimData?.id || null,
      ])
    ).rows[0];
    (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'ingresardatos_pi'])).rows[0].state;
    const state = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'aprobacioncajero_pi'])).rows[0].state;
    await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
    let updt = await client.query('UPDATE inmueble_urbano SET id_liquidacion_fecha_inicio = $1 WHERE id_inmueble = $2', [ghostSettlement.id_liquidacion, id]);
    await client.query('COMMIT');
    return { status: 200, message: updt.rowCount > 0 ? 'Fecha enlazada' : 'No se actualizo un inmueble' };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const linkCommercial = async ({ codCat, rim, relacion }) => {
  const client = await pool.connect();
  try {
    const rimData = await client.query(queries.GET_RIM_DATA, [rim]);
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }

    let estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    if (estate.rows[0].enlazado) {
      throw new Error('El inmueble ya está enlazado');
    }

    if (estate.rows[0].tipoInmueble === 'RESIDENCIAL') {
      const commercialEstates = await client.query(queries.CHECK_IF_HAS_COMMERCIAL_ESTATES, [rimData.rows[0].id]);
      if (+commercialEstates.rows[0].commercials === 0) {
        throw new Error('El contribuyente no tiene un inmueble comercial ya asociado.');
      }
    }

    await client.query(queries.LINK_ESTATE_WITH_RIM, [rimData.rows[0].id, codCat, relacion]);

    estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);
    let extraInfo;
    switch(estate.rows[0].clasificacion) {      
      case 'EJIDO':
          extraInfo = (await client.query(queries.GET_COMMON_LAND, [estate.rows[0].id])).rows[0];
          break;
        case 'CEMENTERIO':
          extraInfo = (await client.query(queries.GET_GRAVEYARD, [estate.rows[0].id])).rows[0];
          break;
        case 'MERCADO':
          extraInfo = (await client.query(queries.GET_MARKET_ESTATE, [estate.rows[0].id])).rows[0];
          break;
        case 'QUIOSCO':
          extraInfo = (await client.query(queries.GET_QUIOSCO, [estate.rows[0].id])).rows[0];
          break;
        default: break;
        }
    return {
      status: 200,
      message: 'Inmueble enlazado',
      inmueble: { ...estate.rows[0], ...extraInfo, avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e: any) {
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const unlinkCommercial = async ({ codCat, rim }) => {
  const client = await pool.connect();
  try {
    const rimData = await client.query(queries.GET_RIM_DATA, [rim]);
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }

    let estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    await client.query(queries.UNLINK_ESTATE_WITH_RIM, [rimData.rows[0].id, codCat]);

    return {
      status: 200,
      message: 'Inmueble enlazado',
    };
  } catch (e: any) {
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const linkNatural = async ({ codCat, typeDoc, doc, relacion }) => {
  const client = await pool.connect();
  try {
    const contributor = await client.query(queries.GET_NATURAL_CONTRIBUTOR, [typeDoc, doc]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }

    let estate = await client.query(queries.GET_ESTATE_BY_CODCAT_NAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR_EX, [estate.rows[0].id, contributor.rows[0].id, relacion]);

    estate = await client.query(queries.GET_ESTATE_BY_CODCAT_NAT, [codCat]);
    let extraInfo;
    switch(estate.rows[0].clasificacion) {      
      case 'EJIDO':
          extraInfo = (await client.query(queries.GET_COMMON_LAND, [estate.rows[0].id])).rows[0];
          break;
        case 'CEMENTERIO':
          extraInfo = (await client.query(queries.GET_GRAVEYARD, [estate.rows[0].id])).rows[0];
          break;
        case 'MERCADO':
          extraInfo = (await client.query(queries.GET_MARKET_ESTATE, [estate.rows[0].id])).rows[0];
          break;
        case 'QUIOSCO':
          extraInfo = (await client.query(queries.GET_QUIOSCO, [estate.rows[0].id])).rows[0];
          break;
        default: break;
        }
    return {
      status: 200,
      message: 'Inmueble enlazado',
      inmueble: { ...estate.rows[0], ...extraInfo, avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e: any) {
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const unlinkNatural = async ({ codCat, typeDoc, doc }) => {
  const client = await pool.connect();
  try {
    const contributor = await client.query(queries.GET_NATURAL_CONTRIBUTOR, [typeDoc, doc]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }

    let estate = await client.query(queries.GET_ESTATE_BY_CODCAT_NAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    await client.query(queries.UNLINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [estate.rows[0].id, contributor.rows[0].id]);

    return {
      status: 200,
      message: 'Inmueble desenlazado',
    };
  } catch (e: any) {
    throw {
      error: e,
      message: e.message,
    };
  } finally {
    client.release();
  }
};

export const createBareEstateNatural = async ({ idContributor, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE_NATURAL, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno])).rows[0];
    await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [estate.id, idContributor]);

    await client.query('COMMIT');

    return estate;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const createBareEstateCommercial = async ({ rim, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE_COMMERCIAL, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, rim])).rows[0];

    await client.query('COMMIT');

    return estate;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};
