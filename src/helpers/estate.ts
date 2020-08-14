import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import { Tramite, Inmueble } from '@root/interfaces/sigt';

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
    console.log('GetEstateInfoByCod')
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
  try{
    console.log('taxPayerEStateBYRIM')
    const rimData = (await client.query(queries.GET_RIM_DATA, [rim]));
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }
    const contributor = (await client.query(queries.GET_CONTRIBUTOR, [typeDoc, rif, rim]));
    if (contributor.rowCount === 0) {
      throw new Error('Contribuyente no encontrado');
    }
    const estates = (await client.query(queries.GET_ESTATES_BY_RIM, [rim])).rows;
    const estatesWithAppraisals = await Promise.all(estates.map((row) => {
      return new Promise(async (res, rej) => {
        res({
          ...row,
          avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows
        })
      })
    }));

    return {status: 200, contribuyente: contributor.rows[0], inmuebles: estatesWithAppraisals};

  } catch (e) {
    throw {
      error: e,
      message: errorMessageExtractor(e)
    };
  } finally {
    client.release();
  }
}

export const userEstates = async ({ typeDoc, doc }) => {
  const client = await pool.connect();
  try{
    const estates = (await client.query(queries.GET_ESTATES_BY_USER_INFO, [typeDoc, doc])).rows;
    const estatesWithAppraisals = await Promise.all(estates.map((row) => {
      return new Promise(async (res, rej) => {
        res({
          ...row,
          avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows
        })
      })
    }));

    return estatesWithAppraisals;

  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
}

export const getEstateByCod = async ({ codCat }) => {
  const client = await pool.connect();
  try{
    console.log('getEstateByCod')
    const estate = (await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]));

    if(estate.rowCount === 0){
      throw new Error('Inmueble no encontrado.')
    }

    return {
      status: 200,
      message: 'Inmueble encontrado',
      inmueble: {...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };

  } catch (e) {
    throw {
      error: e,
      message: e.message
    };
  } finally {
    client.release();
  }
}

export const parishEstates = async ({ idParroquia }) => {
  const client = await pool.connect();
  try{
    const estates = (await client.query(queries.GET_PARISH_ESTATES, [idParroquia])).rows;
    const estatesWithAppraisals = await Promise.all(estates.map((row) => {
      return new Promise(async (res, rej) => {
        res({
          ...row,
          avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [row.id])).rows,
          rim: (await client.query(queries.GET_RIM_DATA, [row.idRim])).rows[0],
        })
      })
    }));

    return estatesWithAppraisals;

  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
}


export const createBareEstate = async ({ codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, avaluos }) => {
  const client = await pool.connect();
  try{
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble])).rows[0];
    console.log(estate);
    const appraisals = await Promise.all(avaluos.map((row) => {
      return client.query(queries.INSERT_ESTATE_VALUE, [estate.id, row.avaluo, row.anio])
    }))
    await client.query('COMMIT');

    return {status: 200, inmueble: {...estate, avaluos}};
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

export const updateEstate = async ({ id, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, avaluos }) => {
  const client = await pool.connect();
  try{
    await client.query('BEGIN');
    await client.query(`DELETE FROM impuesto.avaluo_inmueble WHERE id_inmueble = $1`, [id])
    const appraisals = await Promise.all(avaluos.map((row) => {
      return client.query(queries.INSERT_ESTATE_VALUE, [estate.id, row.avaluo, row.anio])
    }))
    const estate = (await client.query(queries.UPDATE_ESTATE, [direccion, idParroquia, metrosConstruccion, metrosTerreno, tipoInmueble, codCat, id])).rows[0];

    await client.query('COMMIT');

    return estate;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}


export const linkCommercial = async ({ codCat, rim, relacion }) => {
  const client = await pool.connect();
  try{
    const rimData = (await client.query(queries.GET_RIM_DATA, [rim]));
    if (rimData.rowCount === 0) {
      throw new Error('RIM no encontrado');
    }

    let estate = (await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]));

    if(estate.rowCount === 0){
      throw new Error('Inmueble no encontrado.')
    }

    if(estate.rows[0].enlazado){
      throw new Error('El inmueble ya está enlazado')
    }

    (await client.query(queries.LINK_ESTATE_WITH_RIM, [rimData.rows[0].id, codCat, relacion]))

    estate = (await client.query(queries.GET_ESTATE_BY_CODCAT, [codCat]));

    return {
      status: 200,
      message: 'Inmueble enlazado',
      inmueble: {...estate.rows[0], avaluos: (await client.query(queries.GET_APPRAISALS_BY_ID, [estate.rows[0].id])).rows },
    };

  } catch (e) {
    throw {
      error: e,
      message: e.message
    };
  } finally {
    client.release();
  }
}

export const createBareEstateNatural = async ({ idContributor, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno }) => {
  const client = await pool.connect();
  try{
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE_NATURAL, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno])).rows[0];
    (await client.query(queries.LINK_ESTATE_WITH_NATURAL_CONTRIBUTOR, [estate.id, idContributor]))

    await client.query('COMMIT');

    return estate;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

export const createBareEstateCommercial = async ({ rim, codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno }) => {
  const client = await pool.connect();
  try{
    await client.query('BEGIN');
    const estate = (await client.query(queries.CREATE_BARE_ESTATE_COMMERCIAL, [codCat, direccion, idParroquia, metrosConstruccion, metrosTerreno, rim])).rows[0];

    await client.query('COMMIT')

    return estate
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}