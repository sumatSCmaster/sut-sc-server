import tracer from 'dd-trace';
import { decode } from 'jsonwebtoken';
tracer.init(); // initialized in a different file to avoid hoisting
tracer.use('express', {
  hooks: {
    request: (span, req, res) => {
      if (req?.headers.authorization) {
        let token = req.headers.authorization.split(' ')[1];
        const payload = decode(token, { json: true });
        span?.setTag('user.id', payload ? payload['id'] : null);
      }
    },
  },
});
export default tracer;
