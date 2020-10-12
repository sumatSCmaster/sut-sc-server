import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor, fixatedAmount, isExonerated } from './settlement';
import { Usuario } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getAEDeclarationsForAlteration = async ({ document, reference, docType, user, type }: { document: string; reference: string | null; docType: string; user: Usuario; type: string }) => {
  const client = await pool.connect();
  try {
    enum tiposCorreccion {
      complementaria = 'complementaria',
      sustitutiva = 'sustitutiva',
    }
    if (!tiposCorreccion[type]) throw { status: 404, message: 'Debe definir un tipo de declaracion correctiva valida' };
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'La sucursal proporcionada no existe' };
    const PETRO = (await client.query(queries.GET_PETRO_VALUE)).rows[0].valor_en_bs;
    const liquidaciones = await Promise.all(
      (await client.query(tiposCorreccion[type] === 'complementaria' ? queries.GET_ACTIVE_AE_SETTLEMENTS_FOR_COMPLEMENTATION : queries.GET_ACTIVE_AE_SETTLEMENTS_FOR_SUSTITUTION, [branch.id_registro_municipal])).rows.map(async (el) => {
        const startingDate = moment().locale('ES').month(el.datos.fecha.month).year(el.datos.fecha.year).startOf('month');
        el.datos.desglose = await Promise.all(
          el.datos.desglose.map(async (d) => {
            const aforo = (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_ID, [d.aforo])).rows[0];
            const exonerado = await isExonerated({ branch: 112, contributor: branch?.id_registro_municipal, activity: aforo.id_actividad_economica, startingDate }, client);
            return {
              id: aforo.id_actividad_economica,
              minimoTributable: Math.round(aforo.minimo_tributable) * PETRO,
              nombreActividad: aforo.descripcion,
              // idContribuyente: +branch.id_registro_municipal,
              alicuota: aforo.alicuota / 100,
              exonerado,
              montoDeclarado: fixatedAmount(d.montoDeclarado),
              montoCobrado: d.montoCobrado,
              costoSolvencia: PETRO * 2,
            };
          })
        );
        return {
          id: el.id_liquidacion,
          monto: fixatedAmount(el.monto),
          datos: el.datos,
          estado: el.estado,
          fecha: el.datos.fecha,
        };
      })
    );
    return { status: 200, message: 'Liquidaciones para declaracion correctiva/sustitutiva obtenida', liquidaciones };
  } catch (error) {
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener liquidaciones de AE para declaracion correctiva/sustitutiva',
    };
  } finally {
    client.release();
  }
};

export const alterateAESettlements = async ({ settlements, type }) => {
  const client = await pool.connect();
  try {
    enum tiposCorreccion {
      complementaria = 'complementaria',
      sustitutiva = 'sustitutiva',
    }
    if (!tiposCorreccion[type]) throw { status: 404, message: 'Debe definir un tipo de declaracion correctiva valida' };
    await client.query('BEGIN');
    const liqs = await Promise.all(
      settlements.map(async (s) => {
        let newSettlement;
        const liquidacion = (await client.query(queries.GET_SETTLEMENT_BY_ID, [s.id])).rows[0];
        const state = (await client.query(queries.GET_APPLICATION_STATE, [liquidacion.id_solicitud])).rows[0]?.state;
        delete liquidacion.datos[tiposCorreccion.complementaria];
        delete liquidacion.datos[tiposCorreccion.sustitutiva];
        const newDatos = { ...liquidacion.datos, desglose: s.desglose, [tiposCorreccion[type]]: true };
        if (state === 'ingresardatos') {
          newSettlement = (await client.query(queries.UPDATE_SETTLEMENT_AMOUNT_AND_DATA, [newDatos, fixatedAmount(s.monto), s.id])).rows[0];
        } else if (state === 'finalizado' && tiposCorreccion[type] === 'complementaria') {
          let application = (await client.query(queries.GET_PATCH_APPLICATION_BY_ORIGINAL_ID_AND_STATE, [liquidacion.id_solicitud, 'ingresardatos'])).rows[0];
          if (!application) {
            const { id_usuario: usuario, id_contribuyente: contribuyente } = (await client.query(queries.GET_APPLICATION_BY_ID, [liquidacion.id_solicitud])).rows[0];
            application = (await client.query(queries.CREATE_TAX_PAYMENT_APPLICATION, [usuario, contribuyente])).rows[0];
            await client.query(queries.ADD_ORIGINAL_APPLICATION_ID_IN_PATCH_APPLICATION, [liquidacion.id_solicitud, application.id_solicitud]);
            await client.query(queries.UPDATE_TAX_APPLICATION_PAYMENT, [application.id_solicitud, 'ingresardatos_pi']);
            await client.query(queries.SET_DATE_FOR_LINKED_ACTIVE_APPLICATION, [moment(liquidacion.fecha_liquidacion).format('MM-DD-YYYY'), application.id_solicitud]);
          }
          newSettlement = (
            await client.query(queries.CREATE_SETTLEMENT_FOR_TAX_PAYMENT_APPLICATION, [
              application.id_solicitud,
              fixatedAmount(s.monto),
              'AE',
              s.descripcion || 'Pago ordinario',
              newDatos,
              liquidacion.fecha_vencimiento,
              liquidacion.id_registro_municipal || null,
            ])
          ).rows[0];
          await client.query(queries.SET_DATE_FOR_LINKED_SETTLEMENT, [moment(liquidacion.fecha_liquidacion).format('MM-DD-YYYY'), newSettlement.id_liquidacion]);
        } else {
          throw { status: 409, message: 'La solicitud no posee un estado valido para realizar una declaracion correctiva' };
        }
        return {
          id: newSettlement.id_liquidacion,
          ramo: branchNames.AE,
          fecha: newSettlement.datos.fecha,
          monto: fixatedAmount(newSettlement.monto),
          certificado: newSettlement.certificado,
          recibo: newSettlement.recibo,
          desglose: newSettlement.datos.desglose,
        };
      })
    );
    await client.query('COMMIT');
    return { status: 201, message: `Declaracion ${type} de Actividades Economicas realizada satisfactoriamente`, liqs };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || `Error al realizar la declaracion correctiva`,
    };
  } finally {
    client.release();
  }
};

const branchNames = {
  AE: 'ACTIVIDADES ECONOMICAS COMERCIALES, INDUSTRIALES, DE SERVICIO Y SIMILARES',
  SM: 'SERVICIOS MUNICIPALES',
  IU: 'PROPIEDAD INMOBILIARIA',
  PP: 'PROPAGANDAS Y AVISOS COMERCIALES',
  SAE: 'TASA ADMINISTRATIVA DE SOLVENCIA DE AE',
};
