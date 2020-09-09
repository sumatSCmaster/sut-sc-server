import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { PoolClient } from 'pg';
import moment, { Moment } from 'moment';
import switchcase from '@utils/switch';
import { formatContributor, fixatedAmount } from './settlement';
import { Usuario } from '@root/interfaces/sigt';

const pool = Pool.getInstance();

export const getAEDeclarationsForAlteration = async ({ document, reference, docType, user }: { document: string; reference: string | null; docType: string; user: Usuario }) => {
  const client = await pool.connect();
  try {
    const contributor = (await client.query(queries.TAX_PAYER_EXISTS, [docType, document])).rows[0];
    if (!contributor) throw { status: 404, message: 'El contribuyente proporcionado no existe' };
    const branch = (await client.query(queries.GET_MUNICIPAL_REGISTRY_BY_RIM_AND_CONTRIBUTOR, [reference, contributor.id_contribuyente])).rows[0];
    if (!branch) throw { status: 404, message: 'La sucursal proporcionada no existe' };
    const liquidaciones = (await client.query(queries.GET_ACTIVE_AE_SETTLEMENTS_FOR_ALTERATION, [branch.id_registro_municipal])).rows.map((el) => ({
      id: el.id_liquidacion,
      monto: +fixatedAmount(el.monto),
      datos: el.datos,
      fecha: el.datos.fecha,
    }));
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
