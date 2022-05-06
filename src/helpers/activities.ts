import { resolve } from 'path';

import Pool from '@utils/Pool';
import queries from '@utils/queries';
import * as pdf from 'html-pdf';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { formatBranch, codigosRamo } from './settlement';
import moment from 'moment';
import { mainLogger } from '@utils/logger';
import * as qr from 'qrcode';
import S3Client from '@utils/s3';
import { renderFile } from 'pug';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

/**
 * Gets all economic activities, with its aliquots, descriptions, tributable minimum
 */
export const getActivities = async (): Promise<Aliquot[]> => {
  const client = await pool.connect();
  try {
    const activities: Aliquot[] = (await client.query(queries.GET_ALL_ACTIVITIES)).rows;
    return activities;
  } catch (e) {
    throw e;
  } finally {
    client.release();
  }
};

/**
 * Updates economic activities: code, description, tributable minimum
 * @param payload Economic activities to be updated
 * @returns Updated economic activties
 */
export const updateActivitiesAliquots = async ({ aliquots }: { aliquots: Aliquot[] }) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const newAliquots = aliquots.map(async (el) => {
      const { codigo, descripcion, alicuota, minimoTributable, id } = el;
      const actividad = (await client.query(queries.UPDATE_ALIQUOT_FOR_ACTIVITY, [codigo, descripcion, alicuota, minimoTributable, id])).rows[0];
      const response: Aliquot = {
        id: actividad.id_actividad_economica,
        codigo: actividad.numero_referencia,
        descripcion: actividad.descripcion,
        alicuota: actividad.alicuota,
        minimoTributable: actividad.minimo_tributable,
      };
      return response;
    });
    const response = await Promise.all(newAliquots);
    await client.query('COMMIT');
    return { status: 200, message: 'Alicuotas actualizadas', alicuotas: response };
  } catch (error) {
    client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al actualizar alicuotas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getMunicipalReferenceActivities = async ({ docType, document }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branches = (await client.query(queries.GET_BRANCHES_BY_CONTRIBUTOR_ID, [contributor.id_contribuyente])).rows;
    if (branches.length < 1) throw { status: 404, message: 'El contribuyente no posee sucursales' };
    const sucursales = branches.length > 0 ? await Promise.all(branches.map((el) => formatBranch(el, contributor, client))) : undefined;
    return { status: 200, message: 'Sucursales obtenidas', sucursales };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las sucursales',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const updateContributorActivities = async ({ branchId, activities, branchInfo }) => {
  const client = await pool.connect();
  const { denomComercial, nombreRepresentante, telefonoMovil, email, estadoLicencia, tipoSociedad, esMonotributo, capitalSuscrito, actualizado, otrosImpuestos } = branchInfo;
  try {
    await client.query('BEGIN');
    const updatedRegistry = (
      await client.query(
        'UPDATE impuesto.registro_municipal SET denominacion_comercial = $1, nombre_representante = $2, telefono_celular = $3, email = $4, estado_licencia = $5, tipo_sociedad = $6, capital_suscrito = $7, es_monotributo = $8 WHERE id_registro_municipal = $9 RETURNING *',
        [denomComercial, nombreRepresentante, telefonoMovil, email, estadoLicencia, tipoSociedad, capitalSuscrito, esMonotributo, branchId]
      )
    ).rows[0];

    if (otrosImpuestos?.length > 0) {
      await Promise.all(
        otrosImpuestos.map(async (impuesto) => {
          const { desde, ramo } = impuesto;
          ramo === 'RD0' &&
            (await client.query(
              'UPDATE impuesto.detalle_retencion SET id_liquidacion = null WHERE id_liquidacion IN (SELECT id_liquidacion FROM impuesto.liquidacion WHERE id_registro_municipal = $1 AND id_subramo IN (SELECT id_subramo FROM impuesto.subramo INNER JOIN impuesto.ramo r USING (id_ramo) WHERE r.descripcion_corta = $2))',
              [branchId, ramo]
            ));
          const fechaInicio = !!desde ? desde : activities.sort((a, b) => (moment(a.desde).isSameOrBefore(moment(b.desde)) ? 1 : -1))[0]?.desde;
          const fromDate = ramo !== 'RD0' ? moment(fechaInicio).subtract(1, 'M') : moment(fechaInicio);
          const expireDate = ramo !== 'RD0' ? moment(fechaInicio).subtract(1, 'M').endOf('month') : moment(fechaInicio).endOf('month');
          await client.query(queries.NULLIFY_APPLICATION_CONSTRAINT_BY_BRANCH_AND_RIM, [codigosRamo[ramo], branchId]);
          await client.query(queries.NULLIFY_SETTLEMENT_CONSTRAINT_BY_BRANCH_AND_RIM, [codigosRamo[ramo], branchId]);
          // await client.query(queries.DELETE_SETTLEMENTS_BY_BRANCH_CODE_AND_RIM, [codigosRamo[ramo], branchId]);
          const ghostSettlement = (
            await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
              null,
              0.0,
              ramo,
              'Pago ordinario',
              { fecha: { month: fromDate.toDate().toLocaleString('es-ES', { month: 'long' }), year: fromDate.year() } },
              expireDate.format('MM-DD-YYYY'),
              branchId,
            ])
          ).rows[0];
          await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [fromDate.format('MM-DD-YYYY'), ghostSettlement.id_liquidacion]);
        })
      );
    }

    if (!actualizado) {
      await client.query('DELETE FROM impuesto.actividad_economica_sucursal WHERE id_registro_municipal = $1', [branchId]);
      await client.query(queries.NULLIFY_APPLICATION_CONSTRAINT_BY_BRANCH_AND_RIM, [codigosRamo.AE, branchId]);
      await client.query(queries.NULLIFY_SETTLEMENT_CONSTRAINT_BY_BRANCH_AND_RIM, [codigosRamo.AE, branchId]);
      // await client.query(queries.DELETE_SETTLEMENTS_BY_BRANCH_CODE_AND_RIM, [codigosRamo.AE, branchId]);

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
                  { fecha: { month: moment(x.desde).toDate().toLocaleString('es-ES', { month: 'long' }), year: moment(x.desde).year() }, desglose: [{ aforo: x.id }] },
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
                    { fecha: { month: moment(x.desde).toDate().toLocaleString('es-ES', { month: 'long' }), year: moment(x.desde).year() }, desglose: [{ aforo: x.id }] },
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
    mainLogger.error(error);
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

export const generatePatentDocument = async ({branchId}) => {
  const client = await pool.connect();
  try {
    const referencia = (await client.query(queries.GET_REGISTRO_MUNICIPAL_BY_ID, [ branchId ])).rows[0];
    const economicActivities = (await pool.query(' SELECT ae.id_actividad_economica AS id, ae.numero_referencia as codigo, ae.descripcion, ae.alicuota, ae.minimo_tributable, aec.aplicable_desde AS desde FROM impuesto.actividad_economica_sucursal aec INNER JOIN impuesto.actividad_economica ae ON ae.numero_referencia = aec.numero_referencia WHERE id_registro_municipal = $1;', [branchId])).rows;
    const contribuyente = (await client.query('SELECT * FROM impuesto.contribuyente WHERE id_contribuyente = $1', [ referencia.id_contribuyente ])).rows[0];

    const html = renderFile(resolve(__dirname, `../views/planillas/sedebat-cert-LAE-SIM.pug`), {
      moment: require('moment'),
      institucion: 'SEDEBAT',
      datos: {
        usuario: {
          contribuyente:{
            ...contribuyente,
            razonSocial: contribuyente.razon_social,
            tipoDocumento: contribuyente.tipo_documento,
          }
        },
        funcionario:{
          actividadesEconomicas: economicActivities,
          referenciaMunicipal: referencia.referencia_municipal,
          nombreRepresentante: referencia.nombre_representante
        }
      },
      estado: 'finalizado',
    });

    return pdf.create(html, { format: 'Letter', border: '5mm', header: { height: '0px' }, base: 'file://' + resolve(__dirname, '../views/planillas/') + '/' });
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al generar el certificado',
    };
  } finally {
    client.release();
  }
};
interface Aliquot {
  id: number;
  codigo: string;
  descripcion: string;
  alicuota: number;
  minimoTributable: number;
}
