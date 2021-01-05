import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { Usuario } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getBrands = async () => {
  const client = await pool.connect();
  try {
    const res = await client.query(queries.GET_VEHICLE_BRANDS);
    return { data: res.rows, status: 200, message: 'Marcas de vehiculos obtenidas' };
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

export const getVehicleTypes = async () => {
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
      message: errorMessageGenerator(error) || error.message || 'Error al obtener subcategorias de vehiculos',
    };
  }
};

export const getVehiclesByContributor = async (id: number) => {
  const client = await pool.connect();
  try {
    const vehicles = (await client.query(queries.GET_VEHICLES_BY_CONTRIBUTOR, [id])).rows;
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

export const createVehicle = async (payload: Vehicle, user: Usuario) => {
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
      message: errorMessageGenerator(error) || error.message || 'Error al crear vehiculo',
    };
  } finally {
    client.release();
  }
};

export const updateVehicle = async (payload: Vehicle, id: number) => {
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
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar vehiculo',
    };
  } finally {
    client.release();
  }
};

export const deleteVehicle = async (id: number) => {
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
  anio: number;
  color: string;
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
