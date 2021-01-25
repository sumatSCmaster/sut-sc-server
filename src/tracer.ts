import tracer from 'dd-trace';
import { decode } from 'jsonwebtoken';
import { mainLogger } from './utils/logger';
tracer.init(); // initialized in a different file to avoid hoisting
tracer.use('express', {
  hooks: {
    request: (span, req, res) => {
      try {
        if (req?.headers.authorization) {
          let token = req.headers.authorization.split(' ')[1];
          const payload = decode(token, { json: true });
          span?.setTag('user.id', payload ? payload?.sub?.id : null);
        }
      } catch (e) {
        mainLogger.error(`Error setting span user id`);
      }
    },
  },
});
export default tracer;
