import { Campo, Institucion, TipoTramite } from '@root/interfaces/sigt';
import Pool from '@utils/Pool';
import queries from '@utils/queries';
import switchcase from '@utils/switch';
import { PoolClient } from 'pg';
import { errorMessageExtractor, errorMessageGenerator } from './errors';
import { mainLogger } from '@utils/logger';
import Redis from '@utils/redis';

const pool = Pool.getInstance();

/**
 *
 * @param user
 */
export const getMenu = async (user): Promise<Institucion[] | undefined> => {
  let REDIS_KEY = `options:${user.tipoUsuario}`;
  let client: (PoolClient & { tipoUsuario?: any }) | undefined = undefined;
  const redisClient = Redis.getInstance();
  let options: Institucion[] | undefined = undefined;
  try {
    mainLogger.info('getMenu - try');
    let cachedOptions = await redisClient.getAsync(REDIS_KEY);
    if (cachedOptions !== null) {
      mainLogger.info(`getMenu - getting cached options ${REDIS_KEY}`);
      options = JSON.parse(cachedOptions);
    } else {
      client = await pool.connect();
      if (client !== undefined) {
        client.tipoUsuario = user.tipoUsuario;
      }
      mainLogger.info(`client tipoUsuario ${client?.tipoUsuario}`);
      if (client) {
        const response = await client.query(queries.GET_ALL_INSTITUTION);
        let institution: Institucion[] = response.rows.map((el) => {
          return {
            id: el.id_institucion,
            nombreCompleto: el.nombre_completo,
            nombreCorto: el.nombre_corto,
          };
        });
        if (user.tipoUsuario === 4) {
          institution = institution.filter((el) => el.id !== 0);
        }
        options = await getProcedureByInstitution(institution, client);
        await client.release();
        await redisClient.setAsync(REDIS_KEY, JSON.stringify(options));
        await redisClient.expireAsync(REDIS_KEY, 36000);
      }
    }
    return options;
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los tramites',
    };
  }
};

/**
 *
 * @param institution
 * @param client
 */
const getProcedureByInstitution = async (institution, client: PoolClient): Promise<Institucion[] | any> => {
  return Promise.all(
    institution.map(async (institucion) => {
      institucion.tiposUsuarios = await Promise.all(
        (await client.query(queries.GET_USER_TYPES)).rows.map(async (el) => ({
          id: el.id_tipo_usuario,
          descripcion: el.descripcion,
          cargos: await Promise.all((await client.query(queries.GET_JOBS_BY_TYPES_AND_INSTITUTION, [el.id_tipo_usuario, institucion.id])).rows),
        }))
      );
      const procedures = (await client.query(queries.GET_PROCEDURE_BY_INSTITUTION, [institucion.id])).rows;
      institucion.cuentasBancarias = (await client.query(queries.GET_BANK_ACCOUNTS_FOR_INSTITUTION, [institucion.id])).rows.map((cuenta) => {
        const documento = cuenta.documento.split(':');
        return {
          id: cuenta.id,
          institucion: cuenta.institucion,
          banco: cuenta.banco,
          numeroCuenta: cuenta.numerocuenta,
          nombreTitular: cuenta.nombretitular,
          [documento[0]]: documento[1].trim(),
        };
      });
      institucion.tramitesDisponibles = await getSectionByProcedure(procedures, client);
      return institucion;
    })
  ).catch((error) => {
    throw errorMessageGenerator(error) || error.message || 'Error al obtener las instituciones';
  });
};

/**
 *
 * @param procedure
 * @param client
 */
const getSectionByProcedure = async (procedure, client: PoolClient): Promise<TipoTramite[] | any> => {
  return await Promise.all(
    procedure.map(async (al) => {
      const tramite: Partial<TipoTramite> = {
        id: al.id_tipo_tramite,
        titulo: al.nombre_tramite,
        costo: al.costo_base,
        petro: al.costo_petro,
        pagoPrevio: al.pago_previo,
        sufijo: al.sufijo,
        necesitaCodCat: al.utiliza_informacion_catastral,
      };
      const secciones = (await client.query(queries.GET_SECTIONS_BY_PROCEDURE, [tramite.id])).rows;
      tramite.secciones = await getFieldsBySection(secciones, tramite.id, client);
      tramite.secciones = tramite.secciones?.filter((el) => el.campos!.length > 0);
      if (tramite.secciones!.length < 1) {
        delete tramite.secciones;
      }
      tramite.recaudos = (await client.query(queries.GET_TAKINGS_BY_PROCEDURE, [tramite.id])).rows.map((el) => {
        return {
          nombreCompleto: el.nombrecompleto,
          nombreCorto: el.nombrecorto,
          id: el.id,
          fisico: el.fisico,
          obligatorio: el.obligatorio,
          planilla: el.planilla,
          extension: el.extension,
        };
      });
      return tramite;
    })
  ).catch((error) => {
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener las secciones',
    };
  });
};

/**
 *
 * @param section
 * @param tramiteId
 * @param client
 */
const getFieldsBySection = async (section, tramiteId, client): Promise<Campo[] | any> => {
  return Promise.all(
    section.map(async (el) => {
      el.campos = (await fieldsBySectionHandler(tramiteId === 0 ? 0 : client.tipoUsuario, [el.id, tramiteId], client)).rows.map((ul) => {
        const id = ul.id_campo;
        delete ul.id_tipo_tramite;
        delete ul.id_campo;
        return { id, ...ul };
      });
      return el;
    })
  ).catch((error) => {
    throw {
      message: errorMessageGenerator(error) || error.message || 'Error al obtener los campos',
    };
  });
};

/**
 *
 */
const fieldsBySection = switchcase({
  0: queries.GET_FIELDS_FOR_SOCIAL_CASE,
  4: queries.GET_FIELDS_BY_SECTION,
})(queries.GET_FIELDS_BY_SECTION_FOR_OFFICIALS);

/**
 *
 * @param typeUser
 * @param payload
 * @param client
 */
const fieldsBySectionHandler = (typeUser, payload, client) => {
  return client.query(fieldsBySection(typeUser), [...payload]);
};
