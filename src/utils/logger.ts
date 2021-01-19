import { createLogger, format, transports } from 'winston';
const { combine, json, timestamp, colorize } = format;

const mainLogger = createLogger({
  level: 'info',
  defaultMeta: { logger: 'Main logger' },
  transports: [
    new transports.Console({
      format: combine(timestamp(), json()),
    }),
  ],
  exceptionHandlers: [
    new transports.Console({
      format: combine(timestamp(), json()),
    }),
  ],
});

export { mainLogger };
