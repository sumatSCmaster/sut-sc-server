import moment, { Moment } from 'moment';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { Usuario, Liquidacion } from '@root/interfaces/sigt';
import { uniqBy } from 'lodash';
import { fixatedAmount, getApplicationsAndSettlementsById } from './settlement';
import { PoolClient } from 'pg';

const dev = process.env.NODE_ENV !== 'production';

const pool = Pool.getInstance();

export const getInspectionSynchro = async (date) => {
  const client = await pool.connect();
  try {
    const contribuyentes = await (await client.query('SELECT * FROM impuesto.contribuyente WHERE fecha_ultima_actualizacion >= $1', [date])).rows.map((el) => formatContributorForInspection(el, client));
    return { status: 200, message: 'Contribuyentes sincronizados satisfactoriamente', contribuyentes };
  } catch (error) {
    client.query('ROLLBACK');
    console.log(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al sincronizar los contribuyentes',
    };
  } finally {
    client.release();
  }
};

const formatContributorForInspection = async (contributor, client: PoolClient) => {
  try {
    const branches = (await client.query(queries.GET_BRANCHES_BY_CONTRIBUTOR_ID, [contributor.id_contribuyente])).rows;
    return {
      id: contributor.id_contribuyente,
      tipoDocumento: contributor.tipo_documento,
      tipoContribuyente: contributor.tipo_contribuyente,
      documento: contributor.documento,
      razonSocial: contributor.razon_social,
      denomComercial: contributor.denominacion_comercial || undefined,
      siglas: contributor.siglas || undefined,
      parroquia: contributor.id_parroquia,
      sector: contributor.sector,
      direccion: contributor.direccion,
      creditoFiscal: (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [contributor.id_contribuyente, 'NATURAL'])).rows[0]?.credito || 0,
      puntoReferencia: contributor.punto_referencia,
      verificado: contributor.verificado,
      esAgenteRetencion: contributor.es_agente_retencion,
      liquidaciones: (contributor.tipo_contribuyente === 'NATURAL' && getLastSettlementsForInspection(contributor.tipo_contribuyente, contributor.id_contribuyente, client)) || undefined,
      //   usuarios: await getUsersByContributor(contributor.id_contribuyente),
      sucursales: branches.length > 0 ? await Promise.all(branches.map((el) => formatBranchForInspection(el, client))) : undefined,
    };
  } catch (e) {
    throw e;
  }
};

const formatBranchForInspection = async (branch, client) => {
  return {
    id: branch.id_registro_municipal,
    referenciaMunicipal: branch.referencia_municipal,
    fechaAprobacion: branch.fecha_aprobacion,
    direccion: branch.direccion,
    telefono: branch.telefono_celular,
    email: branch.email,
    denomComercial: branch.denominacion_comercial,
    nombreRepresentante: branch.nombre_representante,
    capitalSuscrito: branch.capital_suscrito,
    creditoFiscal: (await client.query(queries.GET_FISCAL_CREDIT_BY_PERSON_AND_CONCEPT, [branch.id_registro_municipal, 'JURIDICO'])).rows[0]?.credito || 0,
    tipoSociedad: branch.tipo_sociedad,
    actualizado: branch.actualizado,
    estadoLicencia: branch.estado_licencia,
    actividadesEconomicas: (await client.query(queries.GET_ECONOMIC_ACTIVITY_BY_RIM, [branch.id_registro_municipal])).rows,
    liquidaciones: await getLastSettlementsForInspection('JURIDICO', branch.id_registro_municipal, client),
  };
};

const getLastSettlementsForInspection = async (type, payload, client: PoolClient) => {
  try {
    const query = type === 'JURIDICO' ? queries.GET_LAST_SETTLEMENTS_FOR_INSPECTION_BY_RIM : queries.GET_LAST_SETTLEMENTS_FOR_INSPECTION_BY_CONTRIBUTOR;
    const liquidaciones = (await client.query(query, [payload])).rows.map((x) => {
      return {};
    });
    return liquidaciones;
  } catch (error) {
    console.log(error);
    throw error;
  }
};
