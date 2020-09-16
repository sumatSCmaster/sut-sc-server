import { resolve } from 'path';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import * as pdf from 'html-pdf';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { formatBranch, codigosRamo } from './settlement';
import moment from 'moment';

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
  const { denomComercial, nombreRepresentante, telefonoMovil, email, estadoLicencia, tipoSociedad, capitalSuscrito, actualizado, otrosImpuestos } = branchInfo;
  try {
    await client.query('BEGIN');
    const updatedRegistry = (
      await client.query(
        'UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4, estado_licencia = $5, tipo_sociedad = $6, capital_suscrito = $7 WHERE id_registro_municipal = $8 RETURNING *',
        [denomComercial, nombreRepresentante, telefonoMovil, email, estadoLicencia, tipoSociedad, capitalSuscrito, branchId]
      )
    ).rows[0];

    if (!actualizado) {
      await client.query('DELETE FROM impuesto.actividad_economica_sucursal WHERE id_registro_municipal = $1', [branchId]);
      await client.query(queries.DELETE_SETTLEMENTS_BY_BRANCH_CODE_AND_RIM, [codigosRamo.AE, branchId]);

      if (otrosImpuestos.length > 0) {
        await Promise.all(
          otrosImpuestos.map(async (impuesto) => {
            const { desde, ramo } = impuesto;
            const fromDate = moment(desde).subtract(1, 'M');
            const expireDate = moment(desde).subtract(1, 'M').endOf('month');
            await client.query(queries.DELETE_SETTLEMENTS_BY_BRANCH_CODE_AND_RIM, [codigosRamo[ramo], branchId]);
            const ghostSettlement = (
              await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                null,
                0.0,
                ramo,
                'Pago ordinario',
                { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year() },
                expireDate.format('MM-DD-YYYY'),
                branchId,
              ])
            ).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
          })
        );
      }

      await Promise.all(
        activities
          .sort((a, b) => (moment(a.desde).isSameOrBefore(moment(b.desde)) ? 1 : -1))
          .map(async (x, index) => {
            const ae = (await client.query(queries.UPDATE_ECONOMIC_ACTIVITIES_FOR_BRANCH, [branchId, x.codigo, x.desde])).rows[0];
            const aeExists = (await client.query(queries.GET_LAST_AE_SETTLEMENT_BY_AE_ID, [x.id, branchId])).rows[0];
            const settlement =
              // !aeExists &&
              (
                await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                  null,
                  0.0,
                  'AE',
                  'Pago ordinario',
                  { month: moment(x.desde).toDate().toLocaleString('es-ES', { month: 'long' }), year: moment(x.desde).year(), desglose: [{ aforo: x.id }] },
                  moment(x.desde).endOf('month').format('MM-DD-YYYY'),
                  branchId,
                ])
              ).rows[0];
            await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [x.desde, settlement.id_liquidacion]);
            // if (index === 0) {
            //   const lastSMSettlement = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM, [codigosRamo.SM, updatedRegistry.referencia_municipal])).rows[0];
            //   // const lastIUSettlement = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM, [codigosRamo.IU, updatedRegistry.referencia_municipal])).rows[0];
            //   const lastPPSettlement = (await client.query(queries.GET_LAST_SETTLEMENT_FOR_CODE_AND_RIM, [codigosRamo.PP, updatedRegistry.referencia_municipal])).rows[0];
            //   const fromDate = moment(x.desde).subtract(1, 'M');
            //   if (!lastSMSettlement || (!!lastSMSettlement && fromDate.isSameOrAfter(moment(lastSMSettlement.fecha_liquidacion)))) {
            //     const ghostSettlement = (
            //       await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            //         null,
            //         0.0,
            //         'SM',
            //         'Pago ordinario',
            //         { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year() },
            //         fromDate.endOf('month').format('MM-DD-YYYY'),
            //         branchId,
            //       ])
            //     ).rows[0];
            //     await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
            //   }

            //   // if (!lastIUSettlement || (!!lastIUSettlement && fromDate.isSameOrAfter(moment(lastIUSettlement.fecha_liquidacion)))) {
            //   //   const ghostSettlement = (
            //   //     await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            //   //       null,
            //   //       0.0,
            //   //       'IU',
            //   //       'Pago ordinario',
            //   //       { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year() },
            //   //       fromDate.endOf('month').format('MM-DD-YYYY'),
            //   //       branchId,
            //   //     ])
            //   //   ).rows[0];
            //   //   await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
            //   // }

            //   if (!lastPPSettlement || (!!lastPPSettlement && fromDate.isSameOrAfter(moment(lastPPSettlement.fecha_liquidacion)))) {
            //     const ghostSettlement = (
            //       await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
            //         null,
            //         0.0,
            //         'PP',
            //         'Pago ordinario',
            //         { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year() },
            //         fromDate.endOf('month').format('MM-DD-YYYY'),
            //         branchId,
            //       ])
            //     ).rows[0];
            //     await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
            //   }
            // }
          })
      );
    } else {
      if (activities.length) {
        await client.query('DELETE FROM impuesto.actividad_economica_sucursal WHERE id_registro_municipal = $1', [branchId]);
        await Promise.all(
          activities
            .sort((a, b) => (moment(a.desde).isSameOrBefore(moment(b.desde)) ? 1 : -1))
            .map(async (x, index) => {
              const ae = (await client.query(queries.UPDATE_ECONOMIC_ACTIVITIES_FOR_BRANCH, [branchId, x.codigo, x.desde])).rows[0];
              const aeExists = (await client.query(queries.GET_LAST_AE_SETTLEMENT_BY_AE_ID, [x.id, branchId])).rows[0];
              const settlement =
                !aeExists &&
                (
                  await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
                    null,
                    0.0,
                    'AE',
                    'Pago ordinario',
                    { month: moment(x.desde).toDate().toLocaleString('es-ES', { month: 'long' }), year: moment(x.desde).year(), desglose: [{ aforo: x.id }] },
                    moment(x.desde).endOf('month').format('MM-DD-YYYY'),
                    branchId,
                  ])
                ).rows[0];
              await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [x.desde, settlement.id_liquidacion]);
            })
        );
      }
    }

    await client.query(queries.UPDATE_LAST_UPDATE_DATE, [updatedRegistry.id_contribuyente]);
    await client.query('COMMIT');
    return { status: 200, message: 'Actividades ecónomicas y/o estado de licencia actualizado' };
  } catch (error) {
    console.log(error);
    await client.query('ROLLBACK');
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las sucursales',
    };
  } finally {
    client.release();
  }
};
