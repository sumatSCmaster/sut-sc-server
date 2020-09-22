import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor, fixatedAmount, isExonerated } from './settlement';
import { Usuario } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getAEDeclarationsForAlteration = async ({ document, reference, docType, user }: { document: string; reference: string | null; docType: string; user: Usuario }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'La sucursal proporcionada no existe' };
    const UTMM = (await client.query(queries.GET_UTMM_VALUE)).rows[0].valor_en_bs;
    const liquidaciones = await Promise.all(
      (await client.query(queries.GET_ACTIVE_AE_SETTLEMENTS_FOR_ALTERATION, [branch.id_registro_municipal])).rows.map(async (el) => {
        const startingDate = moment().locale('ES').month(el.datos.fecha.month).year(el.datos.fecha.year).startOf('month');
        el.datos.desglose = await Promise.all(
          el.datos.desglose.map(async (d) => {
            const aforo = (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_ID, [d.aforo])).rows[0];
            const exonerado = await isExonerated({ branch: 112, contributor: branch?.id_registro_municipal, activity: aforo.id_actividad_economica, startingDate }, client);
            return {
              id: aforo.id_actividad_economica,
              minimoTributable: Math.round(aforo.minimo_tributable) * UTMM,
              nombreActividad: aforo.descripcion,
              // idContribuyente: +branch.id_registro_municipal,
              alicuota: aforo.alicuota / 100,
              exonerado,
              montoDeclarado: fixatedAmount(d.montoDeclarado),
              montoCobrado: d.montoCobrado,
              costoSolvencia: UTMM * 2,
            };
          })
        );
        return {
          id: el.id_liquidacion,
          monto: fixatedAmount(el.monto),
          datos: el.datos,
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
        const liquidacion = (await client.query(queries.GET_SETTLEMENT_BY_ID, [s.id])).rows[0];
        delete liquidacion.datos[tiposCorreccion.complementaria];
        delete liquidacion.datos[tiposCorreccion.sustitutiva];
        const newDatos = { ...liquidacion.datos, desglose: s.desglose, [tiposCorreccion[type]]: true };
        const newSettlement = (await client.query(queries.UPDATE_SETTLEMENT_AMOUNT_AND_DATA, [newDatos, fixatedAmount(s.monto), s.id])).rows[0];
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
