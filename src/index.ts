import './config/aliases';
import express from 'express';
import compression from 'compression';
import session from 'express-session';
import passport from 'passport';
import cors from 'cors';
import router from './routes';
import { resolve } from 'path';
import { JwtStrategy, LocalStrategy, GoogleStrategy, FacebookStrategy } from './utils/Strategies';
import MemoryStore from 'memorystore';
import Pool from '@utils/Pool';

require('dotenv').config();
const app = express();

app.use(compression());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

const memStore = MemoryStore(session);
app.use(
  session({
    resave: true,
    saveUninitialized: true,
    secret: process.env.SESSION_SECRET || 'keyboard cat',
    store: new memStore({
      checkPeriod: 86400000,
    }),
  })
);

if (process.env.NODE_ENV !== 'production') {
  app.use(express.static(resolve(__dirname, '../archivos')));
}

passport.use('jwt', JwtStrategy);
passport.use(LocalStrategy);
passport.use('google', GoogleStrategy);
passport.use('facebook', FacebookStrategy);

passport.serializeUser((user, done) => {
  done(null, JSON.stringify(user));
});

passport.deserializeUser((user: string, done) => {
  done(null, JSON.parse(user));
});

// app.use((req, res, next) => {
//   const { totalCount, waitingCount, idleCount } = Pool.getInstance();
//   console.log('idleCount', idleCount);
//   console.log('waitingCount', waitingCount);
//   console.log('totalCount', totalCount);
//   return next();
// });

app.use(passport.initialize());
app.use(passport.session());

app.use(
  cors({
    // origin: process.env.NODE_ENV !== 'production' ? process.env.CLIENT_URL : true,
    origin: '*',
    methods: 'POST, PUT, GET, DELETE, OPTIONS, PATCH',
    allowedHeaders: 'Accept, Content-Type, Accept-Encoding, Content-Length, Authorization, X-SUT-API-Key',
    credentials: true,
  })
);

app.use('/', router);

app.use(function (err, req, res, next) {
  res.type('application/json');
  res.status(400);
  res.send(JSON.stringify({ error: err }));
});

export default app;
