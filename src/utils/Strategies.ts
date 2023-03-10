import { Strategy as JWT, ExtractJwt } from 'passport-jwt';
import { OAuth2Strategy as Google } from 'passport-google-oauth';
import { Strategy as Facebook } from 'passport-facebook';
import { Strategy as Local, VerifyFunction } from 'passport-local';
import { getUserByUsername, comparePassword, verifyExternalUser, initialExtUserSignUp, getByOAuthID, hasLinkedContributor } from '@helpers/user';
import { encode } from 'jwt-simple';
import { Usuario, TipoUsuario } from '@interfaces/sigt';
import { hasNotifications } from '@helpers/user';

const optJwt = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET || 'not a secret',
};

const optGoogle = {
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_SECRET_ID,
  callbackURL: '/auth/google/callback',
  proxy: true,
};

const optFacebook = {
  clientID: process.env.FACEBOOK_CLIENT_ID,
  clientSecret: process.env.FACEBOOK_SECRET_ID,
  callbackURL: '/auth/facebook/callback',
  proxy: true,
};

const JwtStrategy = new JWT(optJwt, async (payload, done) => {
  return done(null, payload.sub);
});

/**
 *
 */
const GoogleStrategy = new Google(optGoogle, async (accessToken, refreshToken, profile, done) => {
  let request = await getByOAuthID(profile.id);
  if (request?.err) {
    done(request.err);
  }
  if (request?.data.length > 0) {
    const exists = await verifyExternalUser(request?.data[0].id_usuario);
    if (exists) {
      exists.hasNewNotifications = await hasNotifications(`${exists.nacionalidad}-${exists.cedula}`);
      exists.contribuyente = await hasLinkedContributor(exists.id);
    }
    return exists
      ? done(null, {
          ...exists,
          nombreUsuario: profile._json.email,
        })
      : done(null);
  }

  const googleOpts = {
    name: profile._json.name,
    OAuthID: profile._json.sub,
    provider: profile.provider,
    email: profile._json.email,
  };

  request = await initialExtUserSignUp(googleOpts);
  request.hasNewNotifications = await hasNotifications(`${request.nacionalidad}-${request.cedula}`);
  request.contribuyente = await hasLinkedContributor(request.id);
  if (request) {
    return done(null, { ...request, nombreUsuario: googleOpts.email });
  } else {
    return done(null);
  }
});

/**
 *
 */
const FacebookStrategy = new Facebook(optFacebook, async (accessToken, refreshToken, profile, done) => {
  let request = await getByOAuthID(profile.id);
  if (request?.err) {
    done(request.err);
  }
  if (request?.data.length > 0) {
    const exists = await verifyExternalUser(request?.data[0].id_usuario);
    if (exists) {
      exists.hasNewNotifications = await hasNotifications(`${exists.nacionalidad}-${exists.cedula}`);
      exists.contribuyente = await hasLinkedContributor(exists.id);
    }
    return exists ? done(null, exists) : done(null);
  }

  const facebookOpts = {
    name: profile._json.name,
    OAuthID: profile._json.id,
    provider: profile.provider,
  };

  request = await initialExtUserSignUp(facebookOpts);
  request.hasNewNotifications = await hasNotifications(`${request.nacionalidad}-${request.cedula}`);
  request.contribuyente = await hasLinkedContributor(request.id);

  if (request) {
    return done(null, request);
  } else {
    return done(null);
  }
});

const optLocal = {
  usernameField: 'nombreUsuario',
  passwordField: 'password',
};

/**
 *
 * @param username
 * @param password
 * @param done
 */
const verifyLocal: VerifyFunction = async (username: string, password: string, done: any) => {
  const user: Usuario | null = await getUserByUsername(username);
  if (!user) return done(null, false, { message: 'Bad Credentials' });
  if (await comparePassword(password, user.password || '')) {
    if ((user.tipoUsuario as TipoUsuario).descripcion === 'Funcionario') {
      return done(null, {
        ...user,
        password: undefined,
      });
    }

    const newNotifications = await hasNotifications(`${user.nacionalidad}-${user.cedula}`);
    const userContributor = await hasLinkedContributor(user.id);
    return done(null, {
      ...user,
      password: undefined,
      hasNewNotifications: newNotifications,
      contribuyente: userContributor,
    });
  } else {
    return done(null, false, { message: 'Usuario/Contrase??a invalida' });
  }
};

const LocalStrategy = new Local(optLocal, verifyLocal);

const generateToken = (user: any) => {
  const timestamp = new Date().getTime();
  return encode({ sub: user, iat: timestamp }, process.env.JWT_SECRET || 'not a secret');
};

export { JwtStrategy, LocalStrategy, generateToken, GoogleStrategy, FacebookStrategy };
