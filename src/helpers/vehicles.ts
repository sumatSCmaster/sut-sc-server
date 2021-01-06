import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import { Usuario } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const checkVehicleExists = () => async (req: any, res, next) => {
  const client = await pool.connect();
  const { id: usuario } = req.user;
  const { placa } = req.body.vehiculo;
  try {
    const vehicleExists = (await client.query(queries.CHECK_VEHICLE_EXISTS_FOR_USER, [usuario, placa])).rowCount > 0;
    if (!vehicleExists) return next();
    return res.status(403).send({ status: 403, message: 'El vehiculo ya existe para el usuario que solicita' });
  } catch (error) {
    console.log(error);
    return res.send({
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || errorMessageExtractor(error) || 'Error al verificar existencia del vehiculo',
    });
  } finally {
    client.release();
  }
};

export const getBrands = async (): Promise<Response & { marcas: { id: number; nombre: string }[] }> => {
  const client = await pool.connect();
  try {
    const res = await client.query(queries.GET_VEHICLE_BRANDS);
    return { marcas: res.rows, status: 200, message: 'Marcas de vehiculos obtenidas' };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener marcas de vehiculos',
    };
  } finally {
    client.release();
  }
};

export const getVehicleTypes = async (): Promise<Response & { tipoVehiculo: VehicleType[] }> => {
  const client = await pool.connect();
  try {
    const response = (await client.query(queries.GET_VEHICLE_TYPES)).rows.map(async (type: VehicleType) => {
      type.categorias = await Promise.all(await getVehicleCategoriesByType(type.id, client));
      return type;
    });
    const types: VehicleType[] = await Promise.all(response);
    return { status: 200, message: 'Tipos de vehiculos obtenidos', tipoVehiculo: types };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener tipos de vehiculos',
    };
  } finally {
    client.release();
  }
};

const getVehicleCategoriesByType = async (id: number, client: PoolClient): Promise<VehicleCategory[]> => {
  try {
    const response = (await client.query(queries.GET_VEHICLE_CATEGORIES_BY_TYPE, [id])).rows.map(async (category: VehicleCategory) => {
      category.subcategorias = await Promise.all(await getVehicleSubcategoriesByCategory(category.id, client));
      return category;
    });
    const categories: VehicleCategory[] = await Promise.all(response);
    return categories;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener categorias de vehiculos',
    };
  }
};

const getVehicleSubcategoriesByCategory = async (id: number, client: PoolClient): Promise<VehicleSubcategory[]> => {
  try {
    const subcategories: VehicleSubcategory[] = (await client.query(queries.GET_VEHICLE_SUBCATEGORIES_BY_CATEGORY, [id])).rows;
    return subcategories;
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener subcategorias de vehiculos',
    };
  }
};

export const getVehiclesByContributor = async (id: number): Promise<Response & { vehiculos: Vehicle[] }> => {
  const client = await pool.connect();
  try {
    const vehicles: Vehicle[] = (await client.query(queries.GET_VEHICLES_BY_CONTRIBUTOR, [id])).rows;
    return { status: 200, message: 'Vehiculos del contribuyente obtenidos', vehiculos: vehicles };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los vehiculos del contribuyente',
    };
  } finally {
    client.release();
  }
};

export const createVehicle = async (payload: Vehicle, user: Usuario): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, serialMotor, tipoCarroceria, tipoCombustible } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.CREATE_VEHICLE, [marca, user.id, subcategoria, modelo, placa, anio, color, serialCarroceria, serialMotor, tipoCarroceria, tipoCombustible])).rows[0];
    await client.query('COMMIT');

    const vehicle: Vehicle = {
      id: response.id_vehiculo,
      placa: response.placa_vehiculo,
      marca: response.id_marca_vehiculo,
      modelo: response.marca_vehiculo,
      color: response.color_vehiculo,
      anio: response.anio_vehiculo,
      serialCarroceria: response.serial_carroceria_vehiculo,
      serialMotor: response.serial_motor_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      subcategoria: response.id_subcategoria_vehiculo,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
    };
    return { status: 201, message: 'Vehiculo creado satisfactoriamente', vehiculo: vehicle };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al crear vehiculo',
    };
  } finally {
    client.release();
  }
};

export const updateVehicle = async (payload: Vehicle, id: number): Promise<Response & { vehiculo: Vehicle }> => {
  const client = await pool.connect();
  const { marca, subcategoria, modelo, placa, anio, color, serialCarroceria, serialMotor, tipoCarroceria, tipoCombustible } = payload;
  try {
    await client.query('BEGIN');
    const response = (await client.query(queries.UPDATE_VEHICLE, [marca, subcategoria, modelo, placa, anio, color, serialCarroceria, serialMotor, tipoCarroceria, tipoCombustible, id])).rows[0];
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
      serialMotor: response.serial_motor_vehiculo,
      tipoCarroceria: response.tipo_carroceria_vehiculo,
      tipoCombustible: response.tipo_combustible_vehiculo,
      fechaUltimaActualizacion: response.fecha_ultima_actualizacion,
    };

    return { status: 200, message: 'Vehiculo actualizado', vehiculo: vehicle };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar vehiculo',
    };
  } finally {
    client.release();
  }
};

export const deleteVehicle = async (id: number): Promise<Response> => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(queries.DELETE_VEHICLE, [id]);
    await client.query('COMMIT');
    return { status: 200, message: 'Vehiculo eliminado' };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al eliminar vehiculo',
    };
  } finally {
    client.release();
  }
};

export const updateVehicleSubcategory = async (payload: VehicleSubcategory, id: number) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query('COMMIT');
    return;
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar categoria de vehiculos',
    };
  } finally {
    client.release();
  }
};

interface Vehicle {
  id: number;
  marca: number;
  subcategoria: number;
  modelo: string;
  placa: string;
  serialCarroceria: string;
  serialMotor: string;
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
