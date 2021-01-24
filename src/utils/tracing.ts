import tracer from '@root/tracer';
import { mainLogger } from './logger';

export const setTracingTag = (key: string, value: any) => {
  const span = tracer.scope().active();
  if (span !== null) {
    mainLogger.info(`Setting tracing tag ${key} ${value}`);
    span.setTag(key, value);
  }
};

export const getUserIdFromReq = (req) => {
  return req.user.id;
};
