import { resolve } from 'path';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import * as pdf from 'html-pdf';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { formatBranch } from './settlement';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getActivities = async () => {
  const client = await pool.connect();
  try {
    const activities = (await client.query(queries.GET_ALL_ACTIVITIES)).rows;
    return activities;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

export const getMunicipalReferenceActivities = async ({ docType, document }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branches = (await client.query(queries.GET_BRANCHES_BY_CONTRIBUTOR_ID, [contributor.id_contribuyente])).rows;
    if (branches.length < 1) throw { status: 404, message: 'El contribuyente no posee sucursales' };
    const sucursales = branches.length > 0 ? await Promise.all(branches.map((el) => formatBranch(el, client))) : undefined;
    return { status: 200, message: 'Sucursales obtenidas', sucursales };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las sucursales',
    };
  } finally {
    client.release();
  }
};

export const updateContributorActivities = async ({ branchId, activities, branchInfo }) => {
  const client = await pool.connect();
  const { denomComercial, nombreRepresentante, telefonoMovil, email, estadoLicencia } = branchInfo;
  try {
    const updatedRegistry = (
      await client.query('UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4, estado_licencia = $5 WHERE id_registro_municipal = $6', [
        denomComercial,
        nombreRepresentante,
        telefonoMovil,
        email,
        estadoLicencia,
        branchId,
      ])
    ).rows[0];
    await Promise.all(activities.map(async (x) => await client.query(queries.UPDATE_ECONOMIC_ACTIVITIES_FOR_BRANCH, [branchId, x.codigo, x.desde])));
    return { status: 200, message: 'Actividades ecónomicas y/o estado de licencia actualizado' };
  } catch (error) {
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las sucursales',
    };
  } finally {
    client.release();
  }
};
