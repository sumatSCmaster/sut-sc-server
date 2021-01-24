import tracer from 'dd-trace';
import { verify } from 'jsonwebtoken';
import { mainLogger } from '@utils/logger';
tracer.init(); // initialized in a different file to avoid hoisting
tracer.use('express', {
  hooks: {
    request: (span, req, res) => {
      mainLogger.info(`Adding user ID tag to span ${req?.headers.authorization}`);
      if (req?.headers.authorization) {
        mainLogger.info('Adding user ID tag to span');
        const jwt: any = verify(req.headers.authorization.split(' ')[1], process.env.JWT_SECRET as string);
        span?.setTag('user.id', jwt.id);
      }
    },
  },
});
export default tracer;
