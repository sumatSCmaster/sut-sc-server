import Pool from '@utils/Pool';
import queries from '@utils/queries';
import moment from 'moment';
import { errorMessageGenerator } from './errors';
import { Usuario, IDsTipoUsuario } from '@root/interfaces/sigt';
const pool = Pool.getInstance();

const fixMonth = (m: string) => m.charAt(0).toUpperCase() + m.slice(1).toLowerCase();

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

export const getStats = (user: Usuario) => {
  if (user.tipoUsuario === IDsTipoUsuario.Superuser) return getSuperUserStats();
  if (user.tipoUsuario === IDsTipoUsuario.UsuarioExterno) return getExternalStats(user.id);
  else
    return user.institucion?.id !== 0
      ? user.institucion?.id === 6 || user.institucion?.id === 7
        ? getOfficialFiningStats(user.institucion?.id)
        : getOfficialStats(user.institucion?.id)
      : getMayoraltyStats();
};

const getSuperUserStats = async () => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_COUNT)).rows[0].count;
    const monthCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_IN_MONTH, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_SUPER_PROC_TOTAL_IN_MONTH, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))]))
      .rows[0].count;
    const receivedMonthGains = (((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2);
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
    const percentageCompleted = ((totalCompleted * 100) / totalCount).toFixed(2);
    const monthCompleted = (await client.query(queries.GET_SUPER_PROC_BY_STATUS_MONTHLY, [new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (
      await client.query(queries.GET_SUPER_PROC_BY_STATUS_MONTHLY, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])
    ).rows[0].count;
    const completedMonthGains = (((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2);
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
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

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
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

const getMayoraltyStats = async () => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_AFFAIR_TOTAL_COUNT)).rows[0].count;
    const monthCount = (await client.query(queries.GET_AFFAIR_TOTAL_IN_MONTH, [new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_AFFAIR_TOTAL_IN_MONTH, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))])).rows[0]
      .count;
    const receivedMonthGains = (((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2);
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
    const percentageCompleted = ((totalCompleted * 100) / totalCount).toFixed(2);
    const monthCompleted = (await client.query(queries.GET_AFFAIR_BY_STATUS_MONTHLY, [new Date().getMonth() + 1, 'atendido'])).rows[0].count;
    const lastMonthCompleted = (
      await client.query(queries.GET_AFFAIR_BY_STATUS_MONTHLY, [parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'atendido'])
    ).rows[0].count;
    const completedMonthGains = (((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2);
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
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

const getOfficialStats = async (institution: number | undefined) => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_PROC_TOTAL_COUNT, [institution])).rows[0].count;
    const monthCount = (await client.query(queries.GET_PROC_TOTAL_IN_MONTH, [institution, new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_PROC_TOTAL_IN_MONTH, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))]))
      .rows[0].count;
    const receivedMonthGains = (((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2);
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
    const percentageCompleted = ((totalCompleted * 100) / totalCount).toFixed(2);
    const monthCompleted = (await client.query(queries.GET_PROC_BY_STATUS_MONTHLY, [institution, new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (
      await client.query(queries.GET_PROC_BY_STATUS_MONTHLY, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])
    ).rows[0].count;
    const completedMonthGains = (((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2);
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
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

const getOfficialFiningStats = async (institution: number | undefined) => {
  const client = await pool.connect();
  try {
    // GRAFICO 1
    const totalCount = (await client.query(queries.GET_FINE_TOTAL_COUNT, [institution])).rows[0].count;
    const monthCount = (await client.query(queries.GET_FINE_TOTAL_IN_MONTH, [institution, new Date().getMonth() + 1])).rows[0].count;
    const lastMonthCount = (await client.query(queries.GET_FINE_TOTAL_IN_MONTH, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM'))]))
      .rows[0].count;
    const receivedMonthGains = (((monthCount - lastMonthCount) / monthCount) * 100).toFixed(2);
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
    const percentageCompleted = ((totalCompleted * 100) / totalCount).toFixed(2);
    const monthCompleted = (await client.query(queries.GET_FINE_BY_STATUS_MONTHLY, [institution, new Date().getMonth() + 1, 'finalizado'])).rows[0].count;
    const lastMonthCompleted = (
      await client.query(queries.GET_FINE_BY_STATUS_MONTHLY, [institution, parseInt(moment(Date.now()).subtract(1, 'months').format('MM')), 'finalizado'])
    ).rows[0].count;
    const completedMonthGains = (((monthCompleted - lastMonthCompleted) / monthCompleted) * 100).toFixed(2);
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
      error,
      message: errorMessageGenerator(error) || 'Error al obtener las estadisticas',
    };
  } finally {
    client.release();
  }
};

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
