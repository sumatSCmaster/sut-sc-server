import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import { Usuario } from '@root/interfaces/sigt';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';

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
  let types;
  try {
    mainLogger.info('getVehicleTypes - try');
    let cachedTypes = await redisClient.getAsync(REDIS_KEY);
    if (cachedTypes !== null) {
      mainLogger.info('getVehicleTypes - getting cached types');
      types = JSON.parse(cachedTypes);
    } else {
      mainLogger.info('getVehicleTypes - getting types from db');
      client = await pool.connect();
      const response = (await client.query(queries.GET_VEHICLE_TYPES)).rows.map(async (type: VehicleType) => {
        if (client) {
          type.categorias = await Promise.all(await getVehicleCategoriesByType(type.id, client));
          return type;
        }
        return;
      });
      types = await Promise.all(response);
      await redisClient.setAsync(REDIS_KEY, JSON.stringify(types));
      await redisClient.expireAsync(REDIS_KEY, 36000);
    }

    return { status: 200, message: 'Tipos de vehiculos obtenidos', tipoVehiculo: types };
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
export const getVehiclesByContributor = async (id?: number, rim?: number): Promise<Response & { vehiculos: Vehicle[] }> => {
  const client = await pool.connect();
  try {
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

/**
 *
 * @param payload
 * @param user
 */
export const createVehicle = async (payload: Vehicle, user: Usuario): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.CREATE_VEHICLE, [marca, user.id, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible])).rows[0];
    await client.query('COMMIT');
    const brand = (await client.query(queries.GET_VEHICLE_BRAND_BY_ID, [response.id_marca_vehiculo])).rows[0].descripcion;
    const subcategory = (await client.query(queries.GET_VEHICLE_SUBCATEGORY_BY_ID, [response.id_subcategoria_vehiculo])).rows[0].descripcion;

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
      subcategoria: response.id_subcategoria_vehiculo || subcategory,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
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

/**
 *
 * @param payload
 * @param id
 */
export const updateVehicle = async (payload: Vehicle, id: number): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_VEHICLE, [marca, subcategoria, modelo, placa, anio, color, serialCarroceria, tipoCarroceria, tipoCombustible, id])).rows[0];
    await client.query('COMMIT');

    const vehicle: Vehicle = {
      id: response.id_vehiculo,
      placa: response.placa_vehiculo,
      marca: response.id_marca_vehiculo,
      modelo: response.marca_vehiculo,
      color: response.color_vehiculo,
      anio: response.anio_vehiculo,
      subcategoria: response.id_subcategoria_vehiculo,
      serialCarroceria: response.serial_carroceria_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
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
  subcategoria: number | string;
  modelo: string;
  placa: string;
  serialCarroceria: string;
  tipoCombustible: string;
  tipoCarroceria: string;
  anio: number;
  color: string;
  fechaUltimaActualizacion: Date;
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
