import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import { Tramite, Inmueble } from '@root/interfaces/sigt';
import moment from 'moment';

const pool = Pool.getInstance();

export const getEstatesInfo = async () => {
  const client = await pool.connect();
  try {
    const estates = (await client.query(queries.GET_ALL_PROPERTIES)).rows;
    return await addOwners(estates, client);
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
    console.log('GetEstateInfoByCod');
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
    Promise.all(
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
  try {
    console.log('taxPayerEStateBYRIM');
    const rimData = await client.query(queries.GET_RIM_DATA, [rim]);
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }
    const contributor = await client.query(queries.GET_CONTRIBUTOR, [typeDoc, rif, rim]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }
    const estates = (await client.query(queries.GET_ESTATES_BY_RIM, [rim])).rows;

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
            avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows,
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
  try {
    const contributor = await client.query(queries.GET_NATURAL_CONTRIBUTOR, [typeDoc, doc]);
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }
    const estates = (await client.query(queries.GET_ESTATES_BY_NATURAL_CONTRIBUTOR, [contributor.rows[0].id])).rows;
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
            avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows,
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
  try {
    console.log('getEstateByCod');
    const estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);

    if (estate.rowCount === 0) {
      throw new Error('Inmueble no encontrado.');
    }

    return {
      status: 200,
      message: 'Inmueble encontrado',
      inmueble: { ...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e) {
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

export const createBareEstate = async ({ codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, avaluos }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble])).rows[0];
    console.log(estate);
    const appraisals = await Promise.all(
      avaluos.map((row) => {
        return client.query(queries.INSERT_ESTATE_VALUE, [estate.id, row.avaluo, row.anio]);
      })
    );
    await client.query('COMMIT');

    return { status: 200, inmueble: { ...estate, avaluos } };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const updateEstate = async ({ id, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, avaluos }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let estate = (await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat])).rows[0];
    if(estate.enlazado && tipoInmueble === 'RESIDENCIAL'){
      const commercialEstates = await client.query(queries.CHECK_IF_HAS_COMMERCIAL_ESTATES, [estate.id_registro_municipal]);
      const allEstates = await client.query(queries.COUNT_ESTATES, [estate.id_registro_municipal]);
      if(allEstates.rows[0].allestates === 1){
        throw new Error('El contribuyente debe tener por lo menos un inmueble COMERCIAL ya asociado.')
      }else if(allEstates.rows[0].allestates > 1 && (commercialEstates.rows[0].commercials === 1 && estate.tipoInmueble === 'COMERCIAL' )){
        throw new Error('El contribuyente debe tener por lo menos un inmueble COMERCIAL ya asociado.')
      }
    }
    await client.query(`DELETE FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1`, [id]);
    const appraisals = await Promise.all(
      avaluos.map((row) => {
        return client.query(queries.INSERT_ESTATE_VALUE, [id, row.avaluo, row.anio]);
      })
    );
    estate = await client.query(queries.UPDATE_ESTATE, [direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, codCat, id]);

    await client.query('COMMIT');
    return { status: 200, message: 'Inmueble actualizado' };
    // return {inmueble: {...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows }};
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

export const updateEstateDate = async ({ id, date, rim, taxPayer }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const fromDate = moment(date).subtract(1, 'M');
    const fromEndDate = fromDate.clone().endOf('month').format('MM-DD-YYYY');
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [null, taxPayer])).rows[0];
    const rimData = (await client.query(queries.GET_RIM_DATA, [rim])).rows[0];
    const ghostSettlement = (
      await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
        application.id_solicitud,
        0.0,
        'IU',
        'Pago ordinario',
        { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year(), desglose: [{ inmueble: id }] },
        fromEndDate,
        rimData.id || null,
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

    if(estate.rows[0].tipoInmueble === 'RESIDENCIAL'){
      const commercialEstates = await client.query(queries.CHECK_IF_HAS_COMMERCIAL_ESTATES, [rimData.rows[0].id]);
      if(commercialEstates.rows[0].commercials === 0){
        throw new Error('El contribuyente no tiene un inmueble comercial ya asociado.')
      }
    }

    await client.query(queries.LINK_ESTATE_WITH_RIM, [rimData.rows[0].id, codCat, relacion]);

    estate = await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]);

    return {
      status: 200,
      message: 'Inmueble enlazado',
      inmueble: { ...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e) {
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
  } catch (e) {
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

    return {
      status: 200,
      message: 'Inmueble enlazado',
      inmueble: { ...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };
  } catch (e) {
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
  } catch (e) {
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
