import tracer from 'dd-trace';
import { decode } from 'jsonwebtoken';
import { mainLogger } from './utils/logger';
import { inspect } from 'util';
tracer.init(); // initialized in a different file to avoid hoisting
tracer.use('express', {
  hooks: {
    request: (span, req, res) => {
      if (req?.headers.authorization) {
        mainLogger.info(`req headers ${req.headers.authorization}`);
        let token = req.headers.authorization.split(' ')[1];
        const payload = decode(token, { json: true });
        mainLogger.info(`payload ${inspect(payload)}`);
        span?.setTag('user.id', payload ? payload?.sub?.user?.id : null);
      }
    },
  },
});
export default tracer;
