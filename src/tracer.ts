import tracer from 'dd-trace';
import { verify } from 'jsonwebtoken';
tracer.init(); // initialized in a different file to avoid hoisting
tracer.use('express', {
  hooks: {
    request: (span, req, res) => {
      if (req?.headers.authorization) {
        const jwt: any = verify(req.headers.authorization.split(' ')[1], process.env.JWT_SECRET as string);
        span?.setTag('user.id', jwt.id);
      }
    },
  },
});
export default tracer;
