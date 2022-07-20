import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { ClientBase, PoolClient } from 'pg';
import { Usuario } from '@root/interfaces/sigt';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';
import moment from 'moment';

const pool = Pool.getInstance();

/**
 *
 */
export const checkVehicleExists = () => async (req: any, res, next) => {
  const client = await pool.connect();
  const { id: usuario } = req.user;
  const { placa } = req.body.vehiculo;
  try {
    const vehicleExists = (await client.query(queries.CHECK_VEHICLE_EXISTS_FOR_USER, [usuario, placa])).rowCount > 0;
    if (!vehicleExists) return next();
    return res.status(403).send({ status: 403, message: 'El vehiculo ya existe para el usuario que solicita' });
  } catch (error) {
    mainLogger.error(error);
    return res.send({
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al verificar existencia del vehiculo',
    });
  } finally {
    client.release();
  }
};

/**
 *
 */
export const getBrands = async (): Promise<Response & { marcas: { id: number; nombre: string }[] }> => {
  const REDIS_KEY = 'vehicleBrands';
  let client: PoolClient | undefined;
  const redisClient = Redis.getInstance();
  let brands;
  try {
    mainLogger.info('getBrands - try');
    let cachedBrands = await redisClient.getAsync(REDIS_KEY);
    if (cachedBrands !== null) {
      mainLogger.info(`getBrands - getting cached brands`);
      brands = JSON.parse(cachedBrands);
    } else {
      mainLogger.info('getBrands - getting brands from db');
      client = await pool.connect();
      const res = await client.query(queries.GET_VEHICLE_BRANDS);
      brands = res.rows;
      await redisClient.setAsync(REDIS_KEY, JSON.stringify(brands));
      await redisClient.expireAsync(REDIS_KEY, 36000);
    }
    return { marcas: brands, status: 200, message: 'Marcas de vehiculos obtenidas' };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener marcas de vehiculos',
    };
  } finally {
    if (client) client.release();
  }
};

/**
 *
 */
export const getVehicleTypes = async (): Promise<Response & { tipoVehiculo: VehicleType[] }> => {
  const REDIS_KEY = 'vehicleTypes';
  let client: PoolClient | undefined;
  const redisClient = Redis.getInstance();
  let categories;
  try {
    mainLogger.info('getVehicleCategories - try');
    let cachedCategories = await redisClient.getAsync(REDIS_KEY);
    if (cachedCategories !== null) {
      mainLogger.info('getVehicleCategories - getting cached categories');
      categories = JSON.parse(cachedCategories);
    } else {
      mainLogger.info('getVehicleCategories - getting categories from db');
      client = await pool.connect();
      // const response = (await client.query(queries.GET_VEHICLE_TYPES)).rows.map(async (type: VehicleType) => {
      //   if (client) {
      //     type.categorias = await Promise.all(await getVehicleCategoriesByType(type.id, client));
      //     return type;
      //   }
      //   return;
      // });
      const response = (await client.query(queries.GET_VEHICLE_CATEGORIES)).rows.map(async cat => {
        if (client) {
          cat.subcategoria = await Promise.all(await getVehicleSubcategoriesByCategory(cat.id, client));
          return cat;
        }
        return;
      })
      categories = await Promise.all(response);
      await redisClient.setAsync(REDIS_KEY, JSON.stringify(categories));
      await redisClient.expireAsync(REDIS_KEY, 36000);
    }

    return { status: 200, message: 'Tipos de vehiculos obtenidos', tipoVehiculo: categories };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener tipos de vehiculos',
    };
  } finally {
    if (client) client.release();
  }
};

/**
 *
 */
const getVehicleCategoriesByType = async (id: number, client: PoolClient): Promise<VehicleCategory[]> => {
  try {
    const response = (await client.query(queries.GET_VEHICLE_CATEGORIES_BY_TYPE, [id])).rows.map(async (category: VehicleCategory) => {
      category.subcategorias = await Promise.all(await getVehicleSubcategoriesByCategory(category.id, client));
      return category;
    });
    const categories: VehicleCategory[] = await Promise.all(response);
    return categories;
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener categorias de vehiculos',
    };
  }
};

/**
 *
 * @param id
 * @param client
 */
const getVehicleSubcategoriesByCategory = async (id: number, client: PoolClient): Promise<VehicleSubcategory[]> => {
  try {
    const subcategories: VehicleSubcategory[] = (await client.query(queries.GET_VEHICLE_SUBCATEGORIES_BY_CATEGORY, [id])).rows;
    return subcategories;
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener subcategorias de vehiculos',
    };
  }
};

/**
 *
 * @param id
 */
export const getVehiclesByContributorInternal = async (id?: number, rim?: number): Promise<Response & { vehiculos: Vehicle[] }> => {
  const client = await pool.connect();
  try {
    // const idContribuyente = (await client.query('SELECT id_contribuyente FROM usuario WHERE id_usuario = $1', [id])).rows[0]?.id_contribuyente;
    // if (!idContribuyente) throw {status: 401, message: 'Debes ser un contribuyente para acceder a los impuestos vehiculares'}
    const vehicles: Vehicle[] = id ? (await client.query(queries.GET_VEHICLES_BY_CONTRIBUTOR, [id])).rows : (await client.query(queries.GET_VEHICLES_BY_MUNICIPAL_REFERENCE, [rim])).rows;
    return { status: 200, message: 'Vehiculos del contribuyente obtenidos', vehiculos: vehicles };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los vehiculos del contribuyente',
    };
  } finally {
    client.release();
  }
};

export const getVehiclesByContributor = async (id?: number, rim?: number): Promise<Response & { vehiculos: Vehicle[] }> => {
  const client = await pool.connect();
  try {
    const idContribuyente = (await client.query('SELECT id_contribuyente FROM usuario WHERE id_usuario = $1', [id])).rows[0]?.id_contribuyente;
    if (!idContribuyente) throw {status: 401, message: 'Debes ser un contribuyente para acceder a los impuestos vehiculares'}
    const vehicles: Vehicle[] = id ? (await client.query(queries.GET_VEHICLES_BY_CONTRIBUTOR, [idContribuyente])).rows : (await client.query(queries.GET_VEHICLES_BY_MUNICIPAL_REFERENCE, [rim])).rows;
    return { status: 200, message: 'Vehiculos del contribuyente obtenidos', vehiculos: vehicles };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los vehiculos del contribuyente',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param payload
 * @param user
 */
export const createVehicleForRim = async (payload: Vehicle, user: Usuario): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible, peso, cilindraje, serialMotor } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.CREATE_VEHICLE, [marca, user.id, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible, peso, cilindraje, serialMotor])).rows[0];
    await client.query('COMMIT');
    const brand = (await client.query(queries.GET_VEHICLE_BRAND_BY_ID, [response.id_marca_vehiculo])).rows[0].descripcion;
    const responseVehicle = (await client.query(queries.GET_VEHICLE_BY_ID, [response.id_vehiculo])).rows[0];

    const vehicle: Vehicle = {
      id: response.id_vehiculo,
      placa: response.placa_vehiculo,
      marca: brand,
      modelo: response.modelo_vehiculo,
      color: response.color_vehiculo,
      anio: response.anio_vehiculo,
      serialCarroceria: response.serial_carroceria_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      idSubcategoria: response.id_subcategoria_vehiculo || responseVehicle.id_subcategoria_vehiculo,
      subcategoria: responseVehicle.subcategoria,
      idCategoria: responseVehicle.id_categoria_vehiculo,
      categoria: responseVehicle.categoria,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
      peso: response.peso_vehiculo, 
      cilindraje: response.cilindraje_vehiculo, 
      serialMotor: response.serial_motor_vehiculo
    };
    return { status: 201, message: 'Vehiculo creado satisfactoriamente', vehiculo: vehicle };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear vehiculo',
    };
  } finally {
    client.release();
  }
};

export const createVehicle = async (payload: Vehicle, user: Usuario): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible, peso, cilindraje, serialMotor } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.CREATE_VEHICLE, [marca, null, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible, peso, cilindraje, serialMotor])).rows[0];
    const idContribuyente = (await client.query('SELECT id_contribuyente FROM usuario WHERE id_usuario = $1', [user.id])).rows[0]?.id_contribuyente;
    if (idContribuyente) {
      await client.query(`INSERT INTO impuesto.vehiculo_contribuyente(id_vehiculo, id_contribuyente) VALUES($1, $2)`, [response.id_vehiculo, idContribuyente])
    }
    await client.query('COMMIT');
    const brand = (await client.query(queries.GET_VEHICLE_BRAND_BY_ID, [response.id_marca_vehiculo])).rows[0].descripcion;
    const responseVehicle = (await client.query(queries.GET_VEHICLE_BY_ID, [response.id_vehiculo])).rows[0];

    const vehicle: Vehicle = {
      id: response.id_vehiculo,
      placa: response.placa_vehiculo,
      marca: brand,
      modelo: response.modelo_vehiculo,
      color: response.color_vehiculo,
      anio: response.anio_vehiculo,
      serialCarroceria: response.serial_carroceria_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      idSubcategoria: response.id_subcategoria_vehiculo || responseVehicle.id_subcategoria_vehiculo,
      subcategoria: responseVehicle.subcategoria,
      idCategoria: responseVehicle.id_categoria_vehiculo,
      categoria: responseVehicle.categoria,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
      peso: response.peso_vehiculo, 
      cilindraje: response.cilindraje_vehiculo, 
      serialMotor: response.serial_motor_vehiculo
    };
    return { status: 201, message: 'Vehiculo creado satisfactoriamente', vehiculo: vehicle };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear vehiculo',
    };
  } finally {
    client.release();
  }
};

export const linkVehicle = async(placa: string, id: number, isRim: boolean) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const vehicles: Vehicle[] = isRim ? (await client.query(queries.GET_VEHICLES_BY_CONTRIBUTOR, [id])).rows : (await client.query(queries.GET_VEHICLES_BY_MUNICIPAL_REFERENCE, [id])).rows;
    const idVehiculo = (await client.query('SELECT id_vehiculo FROM impuesto.vehiculo WHERE placa_vehiculo = $1', [placa])).rows[0].id_vehiculo;
    const enlazadoARim = (await client.query('SELECT * FROM impuesto.vehiculo WHERE id_registro_municipal IS NOT NULL AND id_vehiculo = $1', [idVehiculo])).rows[0];
    const enlazadoARif = (await client.query('SELECT * FROM impuesto.vehiculo_contribuyente WHERE id_vehiculo = $1', [idVehiculo])).rows[0];
    if (enlazadoARif || enlazadoARim) throw {status: 406, message: 'El vehiculo ya esta enlazado a otro contribuyente'};
    isRim ? await client.query('UPDATE impuesto.vehiculo SET id_registro_municipal = $1 WHERE id_vehiculo = $2', [id, idVehiculo]) : await client.query('INSERT INTO impuesto.vehiculo_contribuyente(id_vehiculo, id_contribuyente) VALUES ($1, $2)', [idVehiculo, id]);
    // const response = (await client.query('SELECT * FROM impuesto.vehiculo WHERE placa_vehiculo = $1', [placa])).rows[0];
    // const brand = (await client.query(queries.GET_VEHICLE_BRAND_BY_ID, [response.id_marca_vehiculo])).rows[0].descripcion;
    // const responseVehicle = (await client.query(queries.GET_VEHICLE_BY_ID, [response.id_vehiculo])).rows[0];
    await client.query('COMMIT');

    // const vehicle: Vehicle = {
    //   id: response.id_vehiculo,
    //   placa: response.placa_vehiculo,
    //   marca: brand,
    //   modelo: response.modelo_vehiculo,
    //   color: response.color_vehiculo,
    //   anio: response.anio_vehiculo,
    //   serialCarroceria: response.serial_carroceria_vehiculo,
    //   tipoCarroceria: response.tipo_carroceria_vehiculo,
    //   tipoCombustible: response.tipo_combustible_vehiculo,
    //   idSubcategoria: response.id_subcategoria_vehiculo || responseVehicle.id_subcategoria_vehiculo,
    //   subcategoria: responseVehicle.subcategoria,
    //   idCategoria: responseVehicle.id_categoria_vehiculo,
    //   categoria: responseVehicle.categoria,
    //   fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
    //   peso: response.peso_vehiculo, 
    //   cilindraje: response.cilindraje_vehiculo, 
    //   serialMotor: response.serial_motor_vehiculo
    // };
    let vehicle = vehicles.find(v => v.placa === placa)

    console.log('PABLO',vehicle, vehicles)

    return {status: 201, message: 'vehiculo enlazado de manera exitosa', vehicle};
  } catch(e) {
    await client.query('ROLLBACK');
    throw {status: 500, message: e.message}
  }
} 

export const unlinkVehicle = async(idVehiculo: number) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE impuesto.vehiculo SET id_registro_municipal = null WHERE id_vehiculo = $1', [idVehiculo]);
    await client.query('DELETE FROM impuesto.vehiculo_contribuyente WHERE id_vehiculo = $1', [idVehiculo]);
    await client.query('COMMIT');
    return {status: 201, message: 'vehiculo desenlazado de manera exitosa'};
  } catch(e) {
    await client.query('ROLLBACK');
    throw {status: 500, message: e.message}
  }
} 
/**
 *
 * @param payload
 * @param id
 */
export const updateVehicle = async (payload: Vehicle, id: number): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { peso, cilindraje, serialMotor, marca, subcategoria, modelo, placa, anio, color, serialCarroceria } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_VEHICLE, [marca, subcategoria, modelo, placa, anio, color, serialCarroceria, peso, cilindraje, serialMotor, id])).rows[0];
    await client.query('COMMIT');
    const responseVehicle = (await client.query(queries.GET_VEHICLE_BY_ID, [response.id_vehiculo])).rows[0];

    const vehicle: Vehicle = {
      id: response.id_vehiculo,
      placa: response.placa_vehiculo,
      marca: response.id_marca_vehiculo,
      modelo: response.modelo_vehiculo,
      color: response.color_vehiculo,
      anio: response.anio_vehiculo,
      idSubcategoria: response.id_subcategoria_vehiculo || responseVehicle.id_subcategoria_vehiculo,
      subcategoria: responseVehicle.subcategoria,
      idCategoria: responseVehicle.id_categoria_vehiculo,
      categoria: responseVehicle.categoria,
      serialCarroceria: response.serial_carroceria_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
      peso: response.peso_vehiculo, 
      cilindraje: response.cilindraje_vehiculo, 
      serialMotor: response.serial_motor_vehiculo
    };

    return { status: 200, message: 'Vehiculo actualizado', vehiculo: vehicle };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar vehiculo',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 */
export const deleteVehicle = async (id: number): Promise<Response> => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(queries.DELETE_VEHICLE, [id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Vehiculo eliminado' };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al eliminar vehiculo',
    };
  } finally {
    client.release();
  }
};

export const updateVehicleDate = async ({ id, date, rim, taxpayer }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const fromDate = moment(date).subtract(1, 'years');
    const fromEndDate = fromDate.clone().endOf('month').format('MM-DD-YYYY');
    const application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [null, taxpayer])).rows[0];
    const rimData = (await client.query(queries.GET_RIM_DATA, [rim])).rows[0];
    const ghostSettlement = (
      await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
        application.id_solicitud,
        0.0,
        'VH',
        'Pago ordinario',
        { fecha: {year: fromDate.year()}, desglose: [{ vehiculo: id }] },
        fromEndDate,
        rimData?.id || null,
      ])
    ).rows[0];
    (await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'ingresardatos_pi'])).rows[0].state;
    const state = (await client.query(queries.COMPLETE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'aprobacioncajero_pi'])).rows[0].state;
    await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
    let updt = await client.query('UPDATE impuesto.vehiculo SET id_liquidacion_fecha_inicio = $1 WHERE id_vehiculo = $2', [ghostSettlement.id_liquidacion, id]);
    await client.query('COMMIT');
    return { status: 200, message: updt.rowCount > 0 ? 'Fecha enlazada' : 'No se actualizo un vehiculo' };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};

/**
 *
 * @param payload
 * @param id
 */
export const updateVehicleSubcategory = async (payload: VehicleSubcategory, id: number) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar categoria de vehiculos',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param vehicle
 * @param client
 */
export const createVehicleStructureForProcedure = async (vehicle: Vehicle, client: PoolClient) => {
  try {
    const assets = (await client.query(queries.GET_ASSETS_FOR_VEHICLE_DATA, [vehicle.id])).rows[0];
    const newVehicle = {
      ...vehicle,
      subcategoria: { id: assets.idSubcategoria, descripcion: assets.descripcionSubcategoria },
      categoria: { id: assets.idCategoria, descripcion: assets.descripcionCategoria },
      tipo: { id: assets.idTipo, descripcion: assets.descripcionTipo },
      marca: { id: assets.idMarca, descripcion: assets.nombreMarca },
    };
    return newVehicle;
  } catch (e) {
    throw e;
  }
};

interface Vehicle {
  id: number;
  marca: number | string;
  idCategoria: number;
  categoria: string;
  idSubcategoria: number;
  subcategoria: string;
  modelo: string;
  placa: string;
  serialCarroceria: string;
  tipoCombustible: string;
  tipoCarroceria: string;
  anio: number;
  color: string;
  fechaUltimaActualizacion?: Date;
  peso: string;
  cilindraje: string;
  serialMotor: string;
}
interface VehicleCategory {
  id: number;
  descripcion: string;
  subcategorias: VehicleSubcategory[];
}
interface VehicleSubcategory {
  id: number;
  descripcion: string;
  costo: number;
}
interface VehicleType {
  id: number;
  descripcion: string;
  categorias: VehicleCategory[];
}

interface Response {
  status: number;
  message: string;
}
