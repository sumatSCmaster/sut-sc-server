import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator } from './errors';
import { PoolClient } from 'pg';
import { Tramite, Inmueble } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getPropertiesInfo = async () => {
  const client = await pool.connect();
  try {
    const properties = (await client.query(queries.GET_ALL_PROPERTIES)).rows;
    return await addOwners(properties, client);
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error al obtener los inmuebles',
    };
  } finally {
    client.release();
  }
};

export const getPropertyInfoByCod = async (cod: string) => {
  const client = await pool.connect();
  try {
    const property = (await client.query(queries.GET_ONE_PROPERTY_BY_COD, [cod])).rows;
    const res = await addOwners(property, client);
    console.log('one', res);
    return res;
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error al obtener los inmuebles',
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
    return localProperties.map(prop => {
      prop.propietarios = ownersSplit[prop.idInmueble];
      return prop;
    });
  } catch (e) {
    throw {
      status: 500,
      error: errorMessageGenerator(e) || 'Error al obtener propietarios',
    };
  }
};

export const createPersonalProperty = async procedure => {
  const client = await pool.connect();
  const { codCatastral, direccion, parroquia, metrosTerreno, metrosConstruccion, tipoInmueble } = procedure.datos.funcionario;
  const { propietarios } = procedure.datos.usuario;
  try {
    client.query('BEGIN');
    const response = (await client.query(queries.CREATE_PROPERTY, [codCatastral, direccion, parroquia, metrosConstruccion, metrosTerreno, tipoInmueble]))
      .rows[0];
    const inmueble = (await client.query(queries.GET_PROPERTY_BY_ID, [response.id_inmueble])).rows[0];
    Promise.all(
      propietarios.map(async el => {
        const owner = (await client.query(queries.CREATE_PROPERTY_OWNER, [el.razonSocial, el.cedula, el.rif, el.email])).rows[0];
        await client.query(queries.CREATE_PROPERTY_WITH_SIGNED_OWNER, [owner.id_propietario, inmueble.id]);
      })
    );
    client.query('COMMIT');
    return { status: 200, message: 'Código catastral creado satisfactoriamente', inmueble };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error,
      message: errorMessageGenerator(error) || 'Error al crear el codigo catastral',
    };
  } finally {
    client.release();
  }
};
