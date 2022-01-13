import Pool from '@utils/Pool';
import queries from '@utils/queries';
import moment from 'moment';
import { errorMessageGenerator, errorMessageExtractor } from './errors';
import { Usuario, IDsTipoUsuario, Instituciones } from '@root/interfaces/sigt';
import { fixatedAmount } from './settlement';
import { request } from 'express';
import { mainLogger } from '@utils/logger';
import { PoolClient } from 'pg';
const pool = Pool.getInstance();

const fixMonth = (m: string) => m.charAt(0).toUpperCase() + m.slice(1).toLowerCase();

/**
 *
 * @param s
 */
const getNoiceState = (s: string): string => {
  switch (s) {
    case 'iniciado':
      return 'Iniciado';
    case 'enproceso':
      return 'En proceso';
    case 'validando':
      return 'Validando pago';
    case 'ingresardatos':
      return 'En espera de pago';
    case 'finalizado':
      return 'Finalizado';
    case 'enrevision':
      return 'En revisión';
    case 'porrevisar':
      return 'Por revisar';
    case 'atendido':
      return 'Atendido';
    case 'visto':
      return 'Visto';
    case 'aprobado':
      return 'Aprobado';
    case 'negado':
      return 'Negado';
    default:
      return 'N/A';
  }
};

//dios mio que ternario tan feo
/**
 *
 * @param user
 */
export const getStats = (user: Usuario) => {
  if (user.tipoUsuario === IDsTipoUsuario.Superuser) return getSuperUserStats();
  if (user.tipoUsuario === IDsTipoUsuario.UsuarioExterno) return getExternalStats(user.id);
  else
    return user.institucion?.id !== 0
      ? user.institucion?.id === 6 || user.institucion?.id === 7
        ? getOfficialFiningStats(user.institucion?.id)
        : user.institucion?.id === 9
        ? getOfficialApplicationStats()
        : getOfficialStats(user.institucion?.id)
      : getMayoraltyStats();
};

/**
 *
 */
const getSuperUserStats = async () => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_COUNT)).rows[0].count;
    const monthCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_IN_MONTH, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_IN_MONTH, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const receivedMonthGains = isFiniteNumber((((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2));
    // GRAFICO 2
    const totalToAttend = (await client.query(queries.GET_SUPER_PROC_TOTAL_BY_STATUS, ['enproceso'])).rows[0].count;
    const receivedByDate = (await client.query(queries.GET_SUPER_PROC_BY_DATE)).rows.map((r) => ({
      x: moment(r.fecha_creacion).format('DD-MM-YYYY'),
      y: r.count,
    }));
    const fixedReceivedByDate = new Array(30).fill(null).map(
      (x, i) =>
        receivedByDate.find((e) => e.x === moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY')) || {
          x: moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY'),
          y: 0,
        }
    );
    // GRAFICO 3
    const totalCompleted = (await client.query(queries.GET_SUPER_PROC_TOTAL_BY_STATUS, ['finalizado'])).rows[0].count;
    const percentageCompleted = isFiniteNumber(((totalCompleted * 100) / totalCount).toFixed(2));
    const monthCompleted = (await client.query(queries.GET_SUPER_PROC_BY_STATUS_MONTHLY, [new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (await client.query(queries.GET_SUPER_PROC_BY_STATUS_MONTHLY, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])).rows[0].count;
    const completedMonthGains = isFiniteNumber((((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2));
    // GRAFICO 4
    const countByStatus = (await client.query(queries.GET_SUPER_PROC_COUNT_BY_STATE)).rows.map((r) => ({
      x: getNoiceState(r.state),
      y: parseInt(r.count),
    }));
    // GRAFICO 5
    const last20Days = (await client.query(queries.GET_SUPER_PROC_COUNT_LAST_20_DAYS)).rows.map((r) => ({
      x: moment(r.fechacreacion).locale('es').format('DD MMM'),
      y: parseInt(r.count),
    }));
    const fixedLast20Days = new Array(20).fill(null).map(
      (x, i) =>
        last20Days.find((e) => e.x === moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM')) || {
          x: moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM'),
          y: 0,
        }
    );
    const last12Months = (await client.query(queries.GET_SUPER_PROC_COUNT_LAST_12_MONTHS)).rows.map((r) => ({
      x: fixMonth(
        moment(new Date(r.year, parseInt(r.month) - 1))
          .locale('es')
          .format('MMM YYYY')
      ),
      y: parseInt(r.count),
    }));
    const fixedLast12Months = new Array(12).fill(null).map(
      (x, i) =>
        last12Months.find((e) => e.x === fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY'))) || {
          x: fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY')),
          y: 0,
        }
    );
    const last5Years = (await client.query(queries.GET_SUPER_PROC_COUNT_LAST_5_YEARS)).rows.map((r) => ({
      x: r.year.toString(),
      y: parseInt(r.count),
    }));
    const fixedLast5Years = new Array(5).fill(null).map(
      (x, i) =>
        last5Years.find((e) => e.x === moment(Date.now()).subtract(i, 'years').format('YYYY')) || {
          x: moment(Date.now()).subtract(i, 'years').format('YYYY'),
          y: 0,
        }
    );
    // RESULT
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: formatStats({
        totalCount,
        monthCount,
        receivedMonthGains,
        totalToAttend,
        fixedReceivedByDate,
        totalCompleted,
        percentageCompleted,
        completedMonthGains,
        countByStatus,
        fixedLast12Months,
        fixedLast20Days,
        fixedLast5Years,
      }),
    };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param id
 */
const getExternalStats = async (id: number) => {
  const client = await pool.connect();
  try {
    const totalCount = (await client.query(queries.GET_EXTERNAL_TOTAL_COUNT, [id])).rows[0].count;
    const approvedCount = (await client.query(queries.GET_EXTERNAL_APPROVED_COUNT, [id])).rows[0].count;
    const rejectedCount = (await client.query(queries.GET_EXTERNAL_REJECTED_COUNT, [id])).rows[0].count;
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: {
        totalCount,
        approvedCount,
        rejectedCount,
      },
    };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
const getMayoraltyStats = async () => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_AFFAIR_TOTAL_COUNT)).rows[0].count;
    const monthCount = (await client.query(queries.GET_AFFAIR_TOTAL_IN_MONTH, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_AFFAIR_TOTAL_IN_MONTH, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const receivedMonthGains = isFiniteNumber((((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2));
    // GRAFICO 2
    const totalToAttend = (await client.query(queries.GET_AFFAIR_TOTAL_BY_STATUS, ['enproceso'])).rows[0].count;
    const receivedByDate = (await client.query(queries.GET_AFFAIR_BY_DATE)).rows.map((r) => ({
      x: moment(r.fecha_creacion).format('DD-MM-YYYY'),
      y: r.count,
    }));
    const fixedReceivedByDate = new Array(30).fill(null).map(
      (x, i) =>
        receivedByDate.find((e) => e.x === moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY')) || {
          x: moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY'),
          y: 0,
        }
    );
    // GRAFICO 3
    const totalCompleted = (await client.query(queries.GET_AFFAIR_TOTAL_BY_STATUS, ['atendido'])).rows[0].count;
    const percentageCompleted = isFiniteNumber(((totalCompleted * 100) / totalCount).toFixed(2));
    const monthCompleted = (await client.query(queries.GET_AFFAIR_BY_STATUS_MONTHLY, [new Date().getMonth() + 1, 'atendido'])).rows[0].count;
    const lastMonthCompleted = (await client.query(queries.GET_AFFAIR_BY_STATUS_MONTHLY, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'atendido'])).rows[0].count;
    const completedMonthGains = isFiniteNumber((((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2));
    // GRAFICO 4
    const countByStatus = (await client.query(queries.GET_AFFAIR_COUNT_BY_STATE)).rows.map((r) => ({
      x: getNoiceState(r.state),
      y: parseInt(r.count),
    }));
    // GRAFICO 5
    const last20Days = (await client.query(queries.GET_AFFAIR_COUNT_LAST_20_DAYS)).rows.map((r) => ({
      x: moment(r.fechacreacion).locale('es').format('DD MMM'),
      y: parseInt(r.count),
    }));
    const fixedLast20Days = new Array(20).fill(null).map(
      (x, i) =>
        last20Days.find((e) => e.x === moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM')) || {
          x: moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM'),
          y: 0,
        }
    );
    const last12Months = (await client.query(queries.GET_AFFAIR_COUNT_LAST_12_MONTHS)).rows.map((r) => ({
      x: fixMonth(
        moment(new Date(r.year, parseInt(r.month) - 1))
          .locale('es')
          .format('MMM YYYY')
      ),
      y: parseInt(r.count),
    }));
    const fixedLast12Months = new Array(12).fill(null).map(
      (x, i) =>
        last12Months.find((e) => e.x === fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY'))) || {
          x: fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY')),
          y: 0,
        }
    );
    const last5Years = (await client.query(queries.GET_AFFAIR_COUNT_LAST_5_YEARS)).rows.map((r) => ({
      x: r.year.toString(),
      y: parseInt(r.count),
    }));
    const fixedLast5Years = new Array(5).fill(null).map(
      (x, i) =>
        last5Years.find((e) => e.x === moment(Date.now()).subtract(i, 'years').format('YYYY')) || {
          x: moment(Date.now()).subtract(i, 'years').format('YYYY'),
          y: 0,
        }
    );
    // RESULT
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: formatStats({
        totalCount,
        monthCount,
        receivedMonthGains,
        totalToAttend,
        fixedReceivedByDate,
        totalCompleted,
        percentageCompleted,
        completedMonthGains,
        countByStatus,
        fixedLast12Months,
        fixedLast20Days,
        fixedLast5Years,
      }),
    };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param institution
 */
const getOfficialStats = async (institution: number | undefined) => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_PROC_TOTAL_COUNT, [institution])).rows[0].count;
    const monthCount = (await client.query(queries.GET_PROC_TOTAL_IN_MONTH, [institution, new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_PROC_TOTAL_IN_MONTH, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const receivedMonthGains = isFiniteNumber((((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2));
    // GRAFICO 2
    const totalToAttend = (await client.query(queries.GET_PROC_TOTAL_BY_STATUS, [institution, 'enproceso'])).rows[0].count;
    const receivedByDate = (await client.query(queries.GET_PROC_BY_DATE, [institution])).rows.map((r) => ({
      x: moment(r.fecha_creacion).format('DD-MM-YYYY'),
      y: r.count,
    }));
    const fixedReceivedByDate = new Array(30).fill(null).map(
      (x, i) =>
        receivedByDate.find((e) => e.x === moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY')) || {
          x: moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY'),
          y: 0,
        }
    );
    // GRAFICO 3
    const totalCompleted = (await client.query(queries.GET_PROC_TOTAL_BY_STATUS, [institution, 'finalizado'])).rows[0].count;
    const percentageCompleted = isFiniteNumber(((totalCompleted * 100) / totalCount).toFixed(2));
    const monthCompleted = (await client.query(queries.GET_PROC_BY_STATUS_MONTHLY, [institution, new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (await client.query(queries.GET_PROC_BY_STATUS_MONTHLY, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])).rows[0].count;
    const completedMonthGains = isFiniteNumber((((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2));
    // GRAFICO 4
    const countByStatus = (await client.query(queries.GET_PROC_COUNT_BY_STATE, [institution])).rows.map((r) => ({
      x: getNoiceState(r.state),
      y: parseInt(r.count),
    }));
    // GRAFICO 5
    const last20Days = (await client.query(queries.GET_PROC_COUNT_LAST_20_DAYS, [institution])).rows.map((r) => ({
      x: moment(r.fechacreacion).locale('es').format('DD MMM'),
      y: parseInt(r.count),
    }));
    const fixedLast20Days = new Array(20).fill(null).map(
      (x, i) =>
        last20Days.find((e) => e.x === moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM')) || {
          x: moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM'),
          y: 0,
        }
    );
    const last12Months = (await client.query(queries.GET_PROC_COUNT_LAST_12_MONTHS, [institution])).rows.map((r) => ({
      x: fixMonth(
        moment(new Date(r.year, parseInt(r.month) - 1))
          .locale('es')
          .format('MMM YYYY')
      ),
      y: parseInt(r.count),
    }));
    const fixedLast12Months = new Array(12).fill(null).map(
      (x, i) =>
        last12Months.find((e) => e.x === fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY'))) || {
          x: fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY')),
          y: 0,
        }
    );
    const last5Years = (await client.query(queries.GET_PROC_COUNT_LAST_5_YEARS, [institution])).rows.map((r) => ({
      x: r.year.toString(),
      y: parseInt(r.count),
    }));
    const fixedLast5Years = new Array(5).fill(null).map(
      (x, i) =>
        last5Years.find((e) => e.x === moment(Date.now()).subtract(i, 'years').format('YYYY')) || {
          x: moment(Date.now()).subtract(i, 'years').format('YYYY'),
          y: 0,
        }
    );
    // RESULT
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: formatStats({
        totalCount,
        monthCount,
        receivedMonthGains,
        totalToAttend,
        fixedReceivedByDate,
        totalCompleted,
        percentageCompleted,
        completedMonthGains,
        countByStatus,
        fixedLast12Months,
        fixedLast20Days,
        fixedLast5Years,
      }),
    };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param institution
 */
const getOfficialFiningStats = async (institution: number | undefined) => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_FINE_TOTAL_COUNT, [institution])).rows[0].count;
    const monthCount = (await client.query(queries.GET_FINE_TOTAL_IN_MONTH, [institution, new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_FINE_TOTAL_IN_MONTH, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const receivedMonthGains = isFiniteNumber((((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2));
    // GRAFICO 2
    const totalToAttend = (await client.query(queries.GET_FINE_TOTAL_BY_STATUS, [institution, 'enproceso'])).rows[0].count;
    const receivedByDate = (await client.query(queries.GET_FINE_BY_DATE, [institution])).rows.map((r) => ({
      x: moment(r.fecha_creacion).format('DD-MM-YYYY'),
      y: r.count,
    }));
    const fixedReceivedByDate = new Array(30).fill(null).map(
      (x, i) =>
        receivedByDate.find((e) => e.x === moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY')) || {
          x: moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY'),
          y: 0,
        }
    );
    // GRAFICO 3
    const totalCompleted = (await client.query(queries.GET_FINE_TOTAL_BY_STATUS, [institution, 'finalizado'])).rows[0].count;
    const percentageCompleted = isFiniteNumber(((totalCompleted * 100) / totalCount).toFixed(2));
    const monthCompleted = (await client.query(queries.GET_FINE_BY_STATUS_MONTHLY, [institution, new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (await client.query(queries.GET_FINE_BY_STATUS_MONTHLY, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])).rows[0].count;
    const completedMonthGains = isFiniteNumber((((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2));
    // GRAFICO 4
    const countByStatus = (await client.query(queries.GET_FINE_COUNT_BY_STATE, [institution])).rows.map((r) => ({
      x: getNoiceState(r.state),
      y: parseInt(r.count),
    }));
    // GRAFICO 5
    const last20Days = (await client.query(queries.GET_FINE_COUNT_LAST_20_DAYS, [institution])).rows.map((r) => ({
      x: moment(r.fechacreacion).locale('es').format('DD MMM'),
      y: parseInt(r.count),
    }));
    const fixedLast20Days = new Array(20).fill(null).map(
      (x, i) =>
        last20Days.find((e) => e.x === moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM')) || {
          x: moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM'),
          y: 0,
        }
    );
    const last12Months = (await client.query(queries.GET_FINE_COUNT_LAST_12_MONTHS, [institution])).rows.map((r) => ({
      x: fixMonth(
        moment(new Date(r.year, parseInt(r.month) - 1))
          .locale('es')
          .format('MMM YYYY')
      ),
      y: parseInt(r.count),
    }));
    const fixedLast12Months = new Array(12).fill(null).map(
      (x, i) =>
        last12Months.find((e) => e.x === fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY'))) || {
          x: fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY')),
          y: 0,
        }
    );
    const last5Years = (await client.query(queries.GET_FINE_COUNT_LAST_5_YEARS, [institution])).rows.map((r) => ({
      x: r.year.toString(),
      y: parseInt(r.count),
    }));
    const fixedLast5Years = new Array(5).fill(null).map(
      (x, i) =>
        last5Years.find((e) => e.x === moment(Date.now()).subtract(i, 'years').format('YYYY')) || {
          x: moment(Date.now()).subtract(i, 'years').format('YYYY'),
          y: 0,
        }
    );
    // RESULT
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: formatStats({
        totalCount,
        monthCount,
        receivedMonthGains,
        totalToAttend,
        fixedReceivedByDate,
        totalCompleted,
        percentageCompleted,
        completedMonthGains,
        countByStatus,
        fixedLast12Months,
        fixedLast20Days,
        fixedLast5Years,
      }),
    };
  } catch (error) {
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 */
const getOfficialApplicationStats = async () => {
  const client = await pool.connect();
  try {
    // GRAFICO 1 - LISTO
    const totalCount = (await client.query(queries.GET_APPLICATION_TOTAL_COUNT)).rows[0].count;
    const monthCount = (await client.query(queries.GET_APPLICATION_TOTAL_IN_MONTH, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_APPLICATION_TOTAL_IN_MONTH, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const receivedMonthGains = isFiniteNumber((((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2));

    // GRAFICO 2 - LISTO
    const totalToAttend = (await client.query(queries.GET_PENDING_SETTLEMENT_TOTAL)).rows[0].count;
    const receivedByDate = (await client.query(queries.GET_SETTLEMENTS_BY_DAY)).rows.map((r) => ({
      x: moment(r.fecha_creacion).format('DD-MM-YYYY'),
      y: r.count,
    }));
    const fixedReceivedByDate = new Array(30).fill(null).map(
      (x, i) =>
        receivedByDate.find((e) => e.x === moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY')) || {
          x: moment(Date.now()).subtract(i, 'days').format('DD-MM-YYYY'),
          y: 0,
        }
    );
    // GRAFICO 3 - LISTO
    const totalCompleted = (await client.query(queries.GET_COMPLETED_APPLICATION_TOTAL)).rows[0].count;
    const percentageCompleted = isFiniteNumber(((totalCompleted * 100) / totalCount).toFixed(2));
    const monthCompleted = (await client.query(queries.GET_MONTHLY_COMPLETED_APPLICATION_TOTAL, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCompleted = (await client.query(queries.GET_MONTHLY_COMPLETED_APPLICATION_TOTAL, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0].count;
    const completedMonthGains = isFiniteNumber((((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2));
    // GRAFICO 4 - LISTO
    const countByStatus = (await client.query(queries.GET_RAISED_MONEY_BY_BRANCH)).rows.map((r) => ({
      x: r.descripcionRamo,
      y: +parseFloat(r.sum).toFixed(2),
    }));
    // GRAFICO 5
    const last20Days = (await client.query(queries.GET_APPLICATION_COUNT_LAST_20_DAYS)).rows.map((r) => ({
      x: moment(r.fechacreacion).locale('es').format('DD MMM'),
      y: parseInt(r.count),
    }));
    const fixedLast20Days = new Array(20).fill(null).map(
      (x, i) =>
        last20Days.find((e) => e.x === moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM')) || {
          x: moment(Date.now()).subtract(i, 'days').locale('es').format('DD MMM'),
          y: 0,
        }
    );
    const last12Months = (await client.query(queries.GET_APPLICATION_COUNT_LAST_12_MONTHS)).rows.map((r) => ({
      x: fixMonth(
        moment(new Date(r.year, parseInt(r.month) - 1))
          .locale('es')
          .format('MMM YYYY')
      ),
      y: parseInt(r.count),
    }));
    const fixedLast12Months = new Array(12).fill(null).map(
      (x, i) =>
        last12Months.find((e) => e.x === fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY'))) || {
          x: fixMonth(moment(Date.now()).subtract(i, 'months').locale('es').format('MMM YYYY')),
          y: 0,
        }
    );
    const last5Years = (await client.query(queries.GET_APPLICATION_COUNT_LAST_5_YEARS)).rows.map((r) => ({
      x: r.year.toString(),
      y: parseInt(r.count),
    }));
    const fixedLast5Years = new Array(5).fill(null).map(
      (x, i) =>
        last5Years.find((e) => e.x === moment(Date.now()).subtract(i, 'years').format('YYYY')) || {
          x: moment(Date.now()).subtract(i, 'years').format('YYYY'),
          y: 0,
        }
    );
    // RESULT
    return {
      status: 200,
      message: 'Estadisticas obtenidas de manera exitosa',
      stats: formatStats({
        totalCount,
        monthCount,
        receivedMonthGains,
        totalToAttend,
        fixedReceivedByDate,
        totalCompleted,
        percentageCompleted,
        completedMonthGains,
        countByStatus,
        fixedLast12Months,
        fixedLast20Days,
        fixedLast5Years,
      }),
    };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param struct
 */
const formatStats = (struct) => ({
  totalGraph: {
    count: struct.totalCount,
    monthCount: struct.monthCount,
    gains: struct.receivedMonthGains,
  },
  lineChart: {
    count: struct.totalToAttend,
    graph: struct.fixedReceivedByDate,
  },
  progressChart: {
    count: struct.totalCompleted,
    percentage: struct.percentageCompleted,
    gains: struct.completedMonthGains,
  },
  pieChart: {
    graph: struct.countByStatus,
  },
  barChart: {
    daily: struct.fixedLast20Days,
    monthly: struct.fixedLast12Months,
    yearly: struct.fixedLast5Years,
  },
});

/**
 *
 * @param expression
 */
const isFiniteNumber = (expression) => {
  return isFinite(expression) ? expression : 0;
};

export const getStatsSedematSettlements = async ({ institution }: { institution: number }) => {
  const client = await pool.connect();
  const AE: any[] = [],
    SM: any[] = [],
    IU: any[] = [],
    PP: any[] = [];
  try {
    await client.query('BEGIN');

    // 4. Total de liquidaciones pagadas/vigentes (%) [1 por ramo]
    const settlementArrAEP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_AE, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrSMP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_SM, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrIUP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_IU, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrPPP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_PP, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    // Top contribuyentes
    // 1. Agentes de retención que han declarado/pagado por mes
    const totalARDeclarationsP = client.query(queries.TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH);
    // 2. Top 1000 contribuyentes que han declarado/pagado por mes
    const totalTopContrDeclarationsP = client.query(queries.TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH, [moment().locale('ES').subtract(2, 'M').format('MMMM'), moment().locale('ES').subtract(2, 'M').year()]);

    const [settlementArrAE, settlementArrSM, settlementArrIU, settlementArrPP, totalARDeclarationsA, totalTopContrDeclarationsA] = await Promise.all([
      settlementArrAEP,
      settlementArrSMP,
      settlementArrIUP,
      settlementArrPPP,
      totalARDeclarationsP,
      totalTopContrDeclarationsP,
    ]);

    settlementArrAE.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        AE.push(liquidado);
        AE.push(pagado);
      });

    settlementArrSM.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        SM.push(liquidado);
        SM.push(pagado);
      });

    settlementArrIU.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        IU.push(liquidado);
        IU.push(pagado);
      });

    settlementArrPP.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        PP.push(liquidado);
        PP.push(pagado);
      });

    const totalARDeclarations = totalARDeclarationsA.rows.map((el) => ({ total: +el.total, liquidado: +el.liquidado, pagado: +el.pagado }))[0];
    const totalTopContrDeclarations = totalTopContrDeclarationsA.rows.map((el) => ({
      total: +el.total,
      liquidado: +el.liquidado,
      pagado: +el.pagado,
    }))[0];

    const estadisticas = {
      contribuyentes: {
        AR: totalARDeclarations,
        top: totalTopContrDeclarations,
      },
      mensual: {
        totalLiquidaciones: { AE, SM, IU, PP },
      },
    };
    await client.query('COMMIT');
    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error: any) {
    await client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

export const getStatsSedematTotal = async ({ institution }: { institution: number }) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    const now = moment().locale('ES');

    // Totales
    // 1. Total de usuarios registrados en SUT
    const totalRegisteredUsersP = client.query(queries.TOTAL_REGISTERED_USERS);
    // 2. Total de contribuyentes
    const totalRegisteredContributorsP = client.query(queries.TOTAL_REGISTERED_CONTRIBUTORS);
    // 3. Total de RIMs / Total de RIMs que declararon en el mes (AE) / Total de RIMs que pagaron en el mes (AE)
    const totalRegisteredRimsP = client.query(queries.TOTAL_REGISTERED_RIMS);
    const totalAEDeclarationsP = client.query(queries.TOTAL_AE_DECLARATIONS_IN_MONTH);
    const totalAEPaymentsP = client.query(queries.TOTAL_AE_APPLICATION_PAYMENTS_IN_MONTH);

    // Coeficientes
    // 1. Tasa de Default Intermensual (TDI)
    // TDI = Cantidad de Contribuyentes que pagaron mes anterior pero no mes actual (gráfico de barra o linea por mes, incluyendo coeficiente y cantidad de contribuyentes)
    const TDI = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month')).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const secondPivot = moment('08-01-2020').locale('ES').add(i, 'M').subtract(1, 'M');
        const defaultCount = (await client.query(queries.TOTAL_CONTRIBUTOR_DEFAULT_RATE, [pivotDate.format('MMMM'), pivotDate.year(), secondPivot.format('MMMM'), secondPivot.year()])).rows[0].valor;
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), valor: +defaultCount, coeficiente: 0 };
      })
    );
    mainLogger.info(TDI);
    TDI.reduce((x, j) => {
      j.coeficiente = fixatedAmount(isFiniteNumber(j.valor / x));
      return j.valor;
    }, 0);

    // 2. Promedio Días para Pago (PDP)
    // PDP = Promedio de días que demoran los contribuyentes en realizar pagos vencidos medidos por mes (gráfico de linea o de barra)
    const PDP = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { promedio, limiteSuperior } = (await client.query(queries.TOTAL_PAYMENT_DAYS_AVERAGE_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), promedio: fixatedAmount(promedio), limiteSuperior };
      })
    );

    // 3. Tasa Nuevas Licencias (TNL)
    // TNL = Cantidad de Licencias Nuevas mes actual/Cantidad de Licencias Nuevas mes anterior (por mes en grafico de barra o linea, incluyendo el coeficiente y la cantidad de nuevas licencias)
    const TNL = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { coeficiente, valor } = (await client.query(queries.TOTAL_NEW_LICENSES_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), coeficiente: fixatedAmount(coeficiente), valor: +valor };
      })
    );

    const [totalRegisteredUsersA, totalRegisteredContributorsA, totalRegisteredRimsA, totalAEDeclarationsA, totalAEPaymentsA] = await Promise.all([
      totalRegisteredUsersP,
      totalRegisteredContributorsP,
      totalRegisteredRimsP,
      totalAEDeclarationsP,
      totalAEPaymentsP,
    ]);

    const totalRegisteredUsers = +totalRegisteredUsersA.rows[0].total;
    const totalRegisteredContributors = +totalRegisteredContributorsA.rows[0].total;
    const totalRegisteredRims = +totalRegisteredRimsA.rows[0].total;
    const totalAEDeclarations = +totalAEDeclarationsA.rows[0].count;
    const totalAEPayments = +totalAEPaymentsA.rows[0].count;

    const estadisticas = {
      total: {
        cantidadUsuarios: totalRegisteredUsers,
        cantidadContribuyentes: totalRegisteredContributors,
        cantidadRIMs: {
          registrados: totalRegisteredRims,
          liquidados: totalAEDeclarations,
          pagados: totalAEPayments,
        },
      },
      coeficientes: {
        TDI,
        PDP,
        TNL,
      },
    };
    await client.query('COMMIT');
    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error: any) {
    await client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getStatsSedematGraphs = async ({ institution }: { institution: number }) => {
  const client = await pool.connect();
  const totalSolvencyRate: any[] = [];

  try {
    await client.query('BEGIN');
    // if (institution !== Instituciones.SEDEMAT) throw { status: 403, message: 'Sólo un miembro de SEDEMAT puede acceder a esta información' };

    // Graficas mensuales
    // 1. Tasas de AE liquidadas/pagadas (por día reflejado en gráfico de barras)
    const solvencyArrP = client.query(queries.TOTAL_SOLVENCY_RATES_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    // 2. Bs por ramo por día liquidado/ingresado (4 ramos principales reflejado en gráfico de torta)
    const totalBsByBranchP = client.query(queries.TOTAL_BS_BY_BRANCH_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    // 3. Total recaudado por mes (gráfico de linea con anotaciones)
    const totalGainingsP = client.query(queries.TOTAL_GAININGS_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    const extraInfoP = client.query(queries.ECONOMIC_ACTIVITIES_EXONERATION_INTERVALS);
    // extraInfo.push({ fechaInicio: moment('09-01-2020').format('DD/MM'), fechaFin: moment('10-01-2020').format('DD/MM'), descripcion: 'Remisión de Multas', color: 'purple' });

    // Top contribuyentes
    // 1. Agentes de retención que han declarado/pagado por mes
    const totalARDeclarationsP = client.query(queries.TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH);
    // 2. Top 1000 contribuyentes que han declarado/pagado por mes
    const totalTopContrDeclarationsP = client.query(queries.TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH, [moment().locale('ES').subtract(2, 'M').format('MMMM'), moment().locale('ES').subtract(2, 'M').year()]);

    const [solvencyArr, totalBsByBranchA, totalGainingsA, extraInfoA, totalARDeclarationsA, totalTopContrDeclarationsA] = await Promise.all([
      solvencyArrP,
      totalBsByBranchP,
      totalGainingsP,
      extraInfoP,
      totalARDeclarationsP,
      totalTopContrDeclarationsP,
    ]);

    solvencyArr.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        totalSolvencyRate.push(liquidado);
        totalSolvencyRate.push(pagado);
      });
    const totalBsByBranch = totalBsByBranchA.rows
      .filter((el) => moment().startOf('day').isSame(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });

    const totalGainings = totalGainingsA.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });

    const extraInfo = extraInfoA.rows.map((el) => {
      el.descripcion = `Exoneración de ${el.cantidad} Aforo${el.cantidad > 1 ? 's' : ''} por motivo de COVID-19`;
      el.color = 'red';
      el.fechaInicio = moment(el.fechaInicio).format('DD/MM');
      el.fechaFin = moment(el.fechaFin).format('DD/MM');
      delete el.cantidad;
      return el;
    });
    extraInfo.push({ fechaInicio: moment('09-01-2020').format('DD/MM'), fechaFin: moment('10-01-2020').format('DD/MM'), descripcion: 'Remisión de Multas', color: 'purple' });

    const totalARDeclarations = totalARDeclarationsA.rows.map((el) => ({ total: +el.total, liquidado: +el.liquidado, pagado: +el.pagado }))[0];
    const totalTopContrDeclarations = totalTopContrDeclarationsA.rows.map((el) => ({
      total: +el.total,
      liquidado: +el.liquidado,
      pagado: +el.pagado,
    }))[0];

    const estadisticas = {
      mensual: {
        totalTasasAE: totalSolvencyRate,
        totalBsPorRamo: totalBsByBranch,
        recaudado: { totalRecaudacion: totalGainings, extra: extraInfo },
      },
      contribuyentes: {
        AR: totalARDeclarations,
        top: totalTopContrDeclarations,
      },
    };
    await client.query('COMMIT');
    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error: any) {
    await client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getStatsSedematTop = async ({ institution }: { institution: number }) => {
  const client = await pool.connect();
  const totalSolvencyRate: any[] = [];
  const AE: any[] = [],
    SM: any[] = [],
    IU: any[] = [],
    PP: any[] = [];
  try {
    await client.query('BEGIN');
    // if (institution !== Instituciones.SEDEMAT) throw { status: 403, message: 'Sólo un miembro de SEDEMAT puede acceder a esta información' };
    // Top contribuyentes
    // 1. Agentes de retención que han declarado/pagado por mes
    const totalARDeclarationsP = client.query(queries.TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH);
    // 2. Top 1000 contribuyentes que han declarado/pagado por mes
    const totalTopContrDeclarationsP = client.query(queries.TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH, [moment().locale('ES').subtract(2, 'M').format('MMMM'), moment().locale('ES').subtract(2, 'M').year()]);

    const [totalARDeclarationsA, totalTopContrDeclarationsA] = await Promise.all([totalARDeclarationsP, totalTopContrDeclarationsP]);

    const totalARDeclarations = totalARDeclarationsA.rows.map((el) => ({ total: +el.total, liquidado: +el.liquidado, pagado: +el.pagado }))[0];
    const totalTopContrDeclarations = totalTopContrDeclarationsA.rows.map((el) => ({
      total: +el.total,
      liquidado: +el.liquidado,
      pagado: +el.pagado,
    }))[0];

    const estadisticas = {
      contribuyentes: {
        AR: totalARDeclarations,
        top: totalTopContrDeclarations,
      },
    };
    await client.query('COMMIT');
    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error: any) {
    await client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getStatsSedemat = async ({ institution }: { institution: number }) => {
  const client = await pool.connect();
  const totalSolvencyRate: any[] = [];
  const AE: any[] = [],
    SM: any[] = [],
    IU: any[] = [],
    PP: any[] = [];
  try {
    await client.query('BEGIN');
    // if (institution !== Instituciones.SEDEMAT) throw { status: 403, message: 'Sólo un miembro de SEDEMAT puede acceder a esta información' };
    const now = moment().locale('ES');
    // Totales
    // 1. Total de usuarios registrados en SUT
    const totalRegisteredUsersP = client.query(queries.TOTAL_REGISTERED_USERS);
    // 2. Total de contribuyentes
    const totalRegisteredContributorsP = client.query(queries.TOTAL_REGISTERED_CONTRIBUTORS);
    // 3. Total de RIMs / Total de RIMs que declararon en el mes (AE) / Total de RIMs que pagaron en el mes (AE)
    const totalRegisteredRimsP = client.query(queries.TOTAL_REGISTERED_RIMS);
    const totalAEDeclarationsP = client.query(queries.TOTAL_AE_DECLARATIONS_IN_MONTH);
    const totalAEPaymentsP = client.query(queries.TOTAL_AE_APPLICATION_PAYMENTS_IN_MONTH);

    // Graficas mensuales
    // 1. Tasas de AE liquidadas/pagadas (por día reflejado en gráfico de barras)
    const solvencyArrP = client.query(queries.TOTAL_SOLVENCY_RATES_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    // 2. Bs por ramo por día liquidado/ingresado (4 ramos principales reflejado en gráfico de torta)
    const totalBsByBranchP = client.query(queries.TOTAL_BS_BY_BRANCH_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    // 3. Total recaudado por mes (gráfico de linea con anotaciones)
    const totalGainingsP = client.query(queries.TOTAL_GAININGS_IN_MONTH, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    const extraInfoP = client.query(queries.ECONOMIC_ACTIVITIES_EXONERATION_INTERVALS);
    // extraInfo.push({ fechaInicio: moment('09-01-2020').format('DD/MM'), fechaFin: moment('10-01-2020').format('DD/MM'), descripcion: 'Remisión de Multas', color: 'purple' });

    // 4. Total de liquidaciones pagadas/vigentes (%) [1 por ramo]
    const settlementArrAEP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_AE, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrSMP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_SM, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrIUP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_IU, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);

    const settlementArrPPP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_PP, [moment().startOf('month').format('MM-DD-YYYY'), moment().endOf('month').format('MM-DD-YYYY')]);
    // Top contribuyentes
    // 1. Agentes de retención que han declarado/pagado por mes
    const totalARDeclarationsP = client.query(queries.TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH);
    // 2. Top 1000 contribuyentes que han declarado/pagado por mes
    const totalTopContrDeclarationsP = client.query(queries.TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH, [moment().locale('ES').subtract(2, 'M').format('MMMM'), moment().locale('ES').subtract(2, 'M').year()]);

    // Coeficientes
    // 1. Tasa de Default Intermensual (TDI)
    // TDI = Cantidad de Contribuyentes que pagaron mes anterior pero no mes actual (gráfico de barra o linea por mes, incluyendo coeficiente y cantidad de contribuyentes)
    mainLogger.info(now.format('MM-DD-YYYY'));
    // mainLogger.info(now.startOf('month').diff(moment('08-01-2020'), 'month'));

    const TDI = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month')).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const secondPivot = moment('08-01-2020').locale('ES').add(i, 'M').subtract(1, 'M');
        const defaultCount = (await client.query(queries.TOTAL_CONTRIBUTOR_DEFAULT_RATE, [pivotDate.format('MMMM'), pivotDate.year(), secondPivot.format('MMMM'), secondPivot.year()])).rows[0].valor;
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), valor: +defaultCount, coeficiente: 0 };
      })
    );
    mainLogger.info(TDI);
    TDI.reduce((x, j) => {
      j.coeficiente = fixatedAmount(isFiniteNumber(j.valor / x));
      return j.valor;
    }, 0);
    // 2. Promedio Días para Pago (PDP)
    // PDP = Promedio de días que demoran los contribuyentes en realizar pagos vencidos medidos por mes (gráfico de linea o de barra)
    const PDP = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { promedio, limiteSuperior } = (await client.query(queries.TOTAL_PAYMENT_DAYS_AVERAGE_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), promedio: fixatedAmount(promedio), limiteSuperior };
      })
    );
    // 3. Tasa Nuevas Licencias (TNL)
    // TNL = Cantidad de Licencias Nuevas mes actual/Cantidad de Licencias Nuevas mes anterior (por mes en grafico de barra o linea, incluyendo el coeficiente y la cantidad de nuevas licencias)
    const TNL = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { coeficiente, valor } = (await client.query(queries.TOTAL_NEW_LICENSES_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), coeficiente: fixatedAmount(coeficiente), valor: +valor };
      })
    );

    const [
      totalRegisteredUsersA,
      totalRegisteredContributorsA,
      totalRegisteredRimsA,
      totalAEDeclarationsA,
      totalAEPaymentsA,
      solvencyArr,
      totalBsByBranchA,
      totalGainingsA,
      extraInfoA,
      settlementArrAE,
      settlementArrSM,
      settlementArrIU,
      settlementArrPP,
      totalARDeclarationsA,
      totalTopContrDeclarationsA,
    ] = await Promise.all([
      totalRegisteredUsersP,
      totalRegisteredContributorsP,
      totalRegisteredRimsP,
      totalAEDeclarationsP,
      totalAEPaymentsP,
      solvencyArrP,
      totalBsByBranchP,
      totalGainingsP,
      extraInfoP,
      settlementArrAEP,
      settlementArrSMP,
      settlementArrIUP,
      settlementArrPPP,
      totalARDeclarationsP,
      totalTopContrDeclarationsP,
    ]);

    const totalRegisteredUsers = +totalRegisteredUsersA.rows[0].total;
    const totalRegisteredContributors = +totalRegisteredContributorsA.rows[0].total;
    const totalRegisteredRims = +totalRegisteredRimsA.rows[0].total;
    const totalAEDeclarations = +totalAEDeclarationsA.rows[0].count;
    const totalAEPayments = +totalAEPaymentsA.rows[0].count;
    solvencyArr.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        totalSolvencyRate.push(liquidado);
        totalSolvencyRate.push(pagado);
      });
    const totalBsByBranch = totalBsByBranchA.rows
      .filter((el) => moment().startOf('day').isSame(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });

    const totalGainings = totalGainingsA.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });

    const extraInfo = extraInfoA.rows.map((el) => {
      el.descripcion = `Exoneración de ${el.cantidad} Aforo${el.cantidad > 1 ? 's' : ''} por motivo de COVID-19`;
      el.color = 'red';
      el.fechaInicio = moment(el.fechaInicio).format('DD/MM');
      el.fechaFin = moment(el.fechaFin).format('DD/MM');
      delete el.cantidad;
      return el;
    });
    extraInfo.push({ fechaInicio: moment('09-01-2020').format('DD/MM'), fechaFin: moment('10-01-2020').format('DD/MM'), descripcion: 'Remisión de Multas', color: 'purple' });

    settlementArrAE.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        AE.push(liquidado);
        AE.push(pagado);
      });

    settlementArrSM.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        SM.push(liquidado);
        SM.push(pagado);
      });

    settlementArrIU.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        IU.push(liquidado);
        IU.push(pagado);
      });

    settlementArrPP.rows
      .filter((el) => moment().startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        PP.push(liquidado);
        PP.push(pagado);
      });

    const totalARDeclarations = totalARDeclarationsA.rows.map((el) => ({ total: +el.total, liquidado: +el.liquidado, pagado: +el.pagado }))[0];
    const totalTopContrDeclarations = totalTopContrDeclarationsA.rows.map((el) => ({
      total: +el.total,
      liquidado: +el.liquidado,
      pagado: +el.pagado,
    }))[0];

    const estadisticas = {
      total: {
        cantidadUsuarios: totalRegisteredUsers,
        cantidadContribuyentes: totalRegisteredContributors,
        cantidadRIMs: {
          registrados: totalRegisteredRims,
          liquidados: totalAEDeclarations,
          pagados: totalAEPayments,
        },
      },
      mensual: {
        totalTasasAE: totalSolvencyRate,
        totalBsPorRamo: totalBsByBranch,
        recaudado: { totalRecaudacion: totalGainings, extra: extraInfo },
        totalLiquidaciones: { AE, SM, IU, PP },
      },
      contribuyentes: {
        AR: totalARDeclarations,
        top: totalTopContrDeclarations,
      },
      coeficientes: {
        TDI,
        PDP,
        TNL,
      },
    };
    await client.query('COMMIT');
    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error) {
    await client.query('ROLLBACK');
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

export const getContributorsStatistics = async (): Promise<any> => {
  const client: PoolClient = await pool.connect();
  try {
    const contributors = (await client.query(queries.GET_ALL_CONTRIBUTORS_WITH_DECLARED_MUNICIPAL_SERVICES));
    return {
      message: 'ok',
      data: contributors,
      status: 200,
    };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de contribuyentes',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const getStatsSedematWithDate = async ({ institution, date }: { institution: number; date: string }) => {
  const client = await pool.connect();
  const totalSolvencyRate: any[] = [];
  const AE: any[] = [],
    SM: any[] = [],
    IU: any[] = [],
    PP: any[] = [];
  try {
    // if (institution !== Instituciones.SEDEMAT) throw { status: 403, message: 'Sólo un miembro de SEDEMAT puede acceder a esta información' };
    const now = moment().locale('ES');
    const requestedDate = moment(date).locale('ES');
    mainLogger.error(requestedDate.format('MM-DD-YYYY'));
    // Totales
    // 1. Total de usuarios registrados en SUT
    const totalRegisteredUsersP = client.query(queries.TOTAL_REGISTERED_USERS);
    // 2. Total de contribuyentes
    const totalRegisteredContributorsP = client.query(queries.TOTAL_REGISTERED_CONTRIBUTORS);
    // 3. Total de RIMs / Total de RIMs que declararon en el mes (AE) / Total de RIMs que pagaron en el mes (AE)
    const totalRegisteredRimsP = client.query(queries.TOTAL_REGISTERED_RIMS);
    const totalAEDeclarationsP = client.query(queries.TOTAL_AE_DECLARATIONS_IN_MONTH_WITH_DATE, [requestedDate.format('MM-DD-YYYY')]);
    const totalAEPaymentsP = client.query(queries.TOTAL_AE_APPLICATION_PAYMENTS_IN_MONTH_WITH_DATE, [requestedDate.format('MM-DD-YYYY')]);

    // Graficas mensuales
    // 1. Tasas de AE liquidadas/pagadas (por día reflejado en gráfico de barras)
    const solvencyArrP = client.query(queries.TOTAL_SOLVENCY_RATES_IN_MONTH_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);
    // 2. Bs por ramo por día liquidado/ingresado (4 ramos principales reflejado en gráfico de torta)
    const totalBsByBranchP = client.query(queries.TOTAL_BS_BY_BRANCH_IN_MONTH_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);
    // 3. Total recaudado por mes (gráfico de linea con anotaciones)
    const totalGainingsP = client.query(queries.TOTAL_GAININGS_IN_MONTH_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);
    const extraInfoP = client.query(queries.ECONOMIC_ACTIVITIES_EXONERATION_INTERVALS);
    // 4. Total de liquidaciones pagadas/vigentes (%) [1 por ramo]
    const settlementArrAEP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_AE_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);

    const settlementArrSMP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_SM_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);

    const settlementArrIUP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_IU_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);

    const settlementArrPPP = client.query(queries.TOTAL_SETTLEMENTS_IN_MONTH_PP_WITH_DATE, [moment(date).startOf('month').format('MM-DD-YYYY'), moment(date).endOf('month').format('MM-DD-YYYY'), requestedDate.format('MM-DD-YYYY')]);

    // Top contribuyentes
    // 1. Agentes de retención que han declarado/pagado por mes
    const totalARDeclarationsP = client.query(queries.TOTAL_AR_DECLARATIONS_AND_PAYMENTS_IN_MONTH_WITH_DATE, [requestedDate.format('MM-DD-YYYY')]);
    // 2. Top 1000 contribuyentes que han declarado/pagado por mes
    const totalTopContrDeclarationsP = client.query(queries.TOTAL_TOP_CONTRIBUTOR_DECLARATIONS_AND_PAYMENTS_IN_MONTH_WITH_DATE, [
      moment(date).locale('ES').subtract(2, 'M').format('MMMM'),
      moment(date).locale('ES').subtract(2, 'M').year(),
      requestedDate.format('MM-DD-YYYY'),
    ]);

    const [
      totalRegisteredUsersA,
      totalRegisteredContributorsA,
      totalRegisteredRimsA,
      totalAEDeclarationsA,
      totalAEPaymentsA,
      solvencyArr,
      totalBsByBranchA,
      totalGainingsA,
      extraInfoA,
      settlementArrAE,
      settlementArrSM,
      settlementArrIU,
      settlementArrPP,
      totalARDeclarationsA,
      totalTopContrDeclarationsA,
    ] = await Promise.all([
      totalRegisteredUsersP,
      totalRegisteredContributorsP,
      totalRegisteredRimsP,
      totalAEDeclarationsP,
      totalAEPaymentsP,
      solvencyArrP,
      totalBsByBranchP,
      totalGainingsP,
      extraInfoP,
      settlementArrAEP,
      settlementArrSMP,
      settlementArrIUP,
      settlementArrPPP,
      totalARDeclarationsP,
      totalTopContrDeclarationsP,
    ]);

    // Coeficientes
    // 1. Tasa de Default Intermensual (TDI)
    // TDI = Cantidad de Contribuyentes que pagaron mes anterior pero no mes actual (gráfico de barra o linea por mes, incluyendo coeficiente y cantidad de contribuyentes)
    mainLogger.info(now.format('MM-DD-YYYY'));
    // mainLogger.info(now.startOf('month').diff(moment('08-01-2020'), 'month'));

    const TDI = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month')).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const secondPivot = moment('08-01-2020').locale('ES').add(i, 'M').subtract(1, 'M');
        const defaultCount = (await client.query(queries.TOTAL_CONTRIBUTOR_DEFAULT_RATE, [pivotDate.format('MMMM'), pivotDate.year(), secondPivot.format('MMMM'), secondPivot.year()])).rows[0].valor;
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), valor: +defaultCount, coeficiente: 0 };
      })
    );
    mainLogger.info(TDI);
    TDI.reduce((x, j) => {
      j.coeficiente = fixatedAmount(isFiniteNumber(j.valor / x));
      return j.valor;
    }, 0);
    // 2. Promedio Días para Pago (PDP)
    // PDP = Promedio de días que demoran los contribuyentes en realizar pagos vencidos medidos por mes (gráfico de linea o de barra)
    const PDP = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { promedio, limiteSuperior } = (await client.query(queries.TOTAL_PAYMENT_DAYS_AVERAGE_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), promedio: fixatedAmount(promedio), limiteSuperior };
      })
    );
    // 3. Tasa Nuevas Licencias (TNL)
    // TNL = Cantidad de Licencias Nuevas mes actual/Cantidad de Licencias Nuevas mes anterior (por mes en grafico de barra o linea, incluyendo el coeficiente y la cantidad de nuevas licencias)
    const TNL = await Promise.all(
      new Array(now.startOf('month').diff(moment('08-01-2020'), 'month') + 1).fill({}).map(async (el, i) => {
        const pivotDate = moment('08-01-2020').locale('ES').add(i, 'M');
        const { coeficiente, valor } = (await client.query(queries.TOTAL_NEW_LICENSES_IN_MONTH_WITH_DATE, [pivotDate.format('MM-DD-YYYY')])).rows[0];
        return { mes: fixMonth(pivotDate.format('MMMM')), anio: pivotDate.year(), coeficiente: fixatedAmount(coeficiente), valor: +valor };
      })
    );

    const totalRegisteredUsers = +totalRegisteredUsersA.rows[0].total;
    const totalRegisteredContributors = +totalRegisteredContributorsA.rows[0].total;
    const totalRegisteredRims = +totalRegisteredRimsA.rows[0].total;
    const totalAEDeclarations = +totalAEDeclarationsA.rows[0].count;
    const totalAEPayments = +totalAEPaymentsA.rows[0].count;
    solvencyArr.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        totalSolvencyRate.push(liquidado);
        totalSolvencyRate.push(pagado);
      });
    const totalBsByBranch = totalBsByBranchA.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });

    const totalGainings = totalGainingsA.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        el.valor = fixatedAmount(el.valor);
        el.fecha = moment(el.fecha).format('DD/MM');
        return el;
      });
    const extraInfo = extraInfoA.rows.map((el) => {
      el.descripcion = `Exoneración de ${el.cantidad} Aforo${el.cantidad > 1 ? 's' : ''} por motivo de COVID-19`;
      el.color = 'red';
      el.fechaInicio = moment(el.fechaInicio).format('DD/MM');
      el.fechaFin = moment(el.fechaFin).format('DD/MM');
      delete el.cantidad;
      return el;
    });
    extraInfo.push({ fechaInicio: moment('09-01-2020').format('DD/MM'), fechaFin: moment('10-01-2020').format('DD/MM'), descripcion: 'Remisión de Multas', color: 'purple' });

    settlementArrAE.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        AE.push(liquidado);
        AE.push(pagado);
      });
    settlementArrSM.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        SM.push(liquidado);
        SM.push(pagado);
      });
    settlementArrIU.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        IU.push(liquidado);
        IU.push(pagado);
      });
    settlementArrPP.rows
      .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
      .map((el) => {
        const liquidado = { name: 'Liquidado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.liquidado };
        const pagado = { name: 'Pagado', fecha: moment(el.fecha).format('DD/MM'), valor: +el.pagado };
        PP.push(liquidado);
        PP.push(pagado);
      });
    const totalARDeclarations = totalARDeclarationsA.rows.map((el) => ({ total: +el.total, liquidado: +el.liquidado, pagado: +el.pagado }))[0];
    const totalTopContrDeclarations = totalTopContrDeclarationsA.rows.map((el) => ({
      total: +el.total,
      liquidado: +el.liquidado,
      pagado: +el.pagado,
    }))[0];

    const estadisticas = {
      total: {
        cantidadUsuarios: totalRegisteredUsers,
        cantidadContribuyentes: totalRegisteredContributors,
        cantidadRIMs: {
          registrados: totalRegisteredRims,
          liquidados: totalAEDeclarations,
          pagados: totalAEPayments,
        },
      },
      mensual: {
        totalTasasAE: totalSolvencyRate,
        totalBsPorRamo: totalBsByBranch,
        recaudado: { totalRecaudacion: totalGainings, extra: extraInfo },
        totalLiquidaciones: { AE, SM, IU, PP },
      },
      contribuyentes: {
        AR: totalARDeclarations,
        top: totalTopContrDeclarations,
      },
      coeficientes: {
        TDI,
        PDP,
        TNL,
      },
    };

    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};

/**
 *
 * @param param0
 */
export const bsByBranchInterval = async ({ institution, startingDate, endingDate }) => {
  mainLogger.info('bsByBranchInterval -> endingDate', endingDate);
  mainLogger.info('bsByBranchInterval -> startingDate', startingDate);
  const client = await pool.connect();
  const totalSolvencyRate: any[] = [];
  const totalSettlements: any[] = [];
  try {
    // if (institution !== Instituciones.SEDEMAT) throw { status: 403, message: 'Sólo un miembro de SEDEMAT puede acceder a esta información' };
    const now = moment().locale('ES');
    const requestedDateS = moment(startingDate).locale('ES');
    mainLogger.info('//if -> requestedDateS', requestedDateS);
    const requestedDateE = moment(endingDate).locale('ES');
    mainLogger.info('//if -> requestedDateE', requestedDateE);
    // 2. Bs por ramo por día liquidado/ingresado (4 ramos principales reflejado en gráfico de torta)
    const { rows: result, rowCount: totalCount } = await client.query(queries.TOTAL_BS_BY_BRANCH_IN_MONTH_WITH_INTERVAL, [requestedDateS.format('MM-DD-YYYY'), requestedDateE.format('MM-DD-YYYY')]);
    // .filter((el) => moment(date).endOf('month').startOf('day').isSameOrAfter(moment(el.fecha)))
    const totalBsPorRamo =
      totalCount > 0
        ? result.map((el) => {
            el.valor = fixatedAmount(el.valor);
            return el;
          })
        : [
            { ramo: 'AE', valor: 0 },
            { ramo: 'SM', valor: 0 },
            { ramo: 'IU', valor: 0 },
            { ramo: 'PP', valor: 0 },
          ];

    return { status: 200, message: 'Estadisticas obtenidas!', estadisticas: { totalBsPorRamo } };
  } catch (error) {
    mainLogger.error(error);
    throw {
      status: error.status || 500,
      error: errorMessageExtractor(error),
      message: errorMessageGenerator(error) || error.message || 'Error al obtener estadisticas de SEDEMAT',
    };
  } finally {
    client.release();
  }
};
