import './config/aliases';
import express from 'express';
import compression from 'compression';
import session from 'express-session';
import passport from 'passport';
import cors from 'cors';
import router from './routes';
import { resolve } from 'path';
import { JwtStrategy, LocalStrategy, GoogleStrategy, FacebookStrategy } from './utils/Strategies';

require('dotenv').config();
const app = express();

app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(
  session({
    resave: true,
    saveUninitialized: true,
    secret: process.env.SESSION_SECRET || 'keyboard cat',
  })
);

if(process.env.NODE_ENV !== 'production'){
  app.use(express.static(resolve(__dirname, '../archivos' )));
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

app.use(passport.initialize());
app.use(passport.session());

app.use(
  cors({
    origin: true,
    methods: 'POST, PUT, GET, DELETE, OPTIONS, PATCH',
    allowedHeaders: 'Accept, Content-Type, Accept-Encoding, Content-Length, Authorization',
    credentials: true,
  })
);

app.use('/', router);

export default app;
