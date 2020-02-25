import { Strategy as JWT, ExtractJwt } from "passport-jwt";
import { OAuth2Strategy as Google } from "passport-google-oauth";
import { Strategy as Facebook } from "passport-facebook";
import { Strategy as Local, VerifyFunction } from "passport-local";
import {
  getUserByUsername,
  comparePassword,
  verifyExternalUser,
  initialExtUserSignUp,
  getByOAuthID
} from "@helpers/user";
import { encode } from "jwt-simple";
import { Usuario } from "@interfaces/sigt";

const optJwt = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET || "not a secret"
};

const optGoogle = {
  clientID: process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_SECRET_ID,
  callbackURL: "/auth/google/callback",
  proxy: true
};

const optFacebook = {
  clientID: process.env.FACEBOOK_CLIENT_ID,
  clientSecret: process.env.FACEBOOK_SECRET_ID,
  callbackURL: "/auth/facebook/callback",
  proxy: true
};

const JwtStrategy = new JWT(optJwt, async (payload, done) => {
  return done(null, payload.sub);
});

const GoogleStrategy = new Google(
  optGoogle,
  async (accessToken, refreshToken, profile, done) => {
    let request = await getByOAuthID(profile.id);
    if (request?.err) {
      done(request.err);
    }
    if (request?.data.length > 0) {
      const exists = await verifyExternalUser(request?.data[0].id_usuario);
      return exists?.data
        ? done(null, {
            ...exists?.data,
            nombre_de_usuario: profile._json.email
          })
        : done(null);
    }

    const googleOpts = {
      name: profile._json.name,
      OAuthID: profile._json.sub,
      provider: profile.provider,
      email: profile._json.email
    };

    request = await initialExtUserSignUp(googleOpts);
    if (request) {
      return done(null, { ...request, nombre_de_usuario: googleOpts.email });
    } else {
      return done(null);
    }
  }
);

const FacebookStrategy = new Facebook(
  optFacebook,
  async (accessToken, refreshToken, profile, done) => {
    let request = await getByOAuthID(profile.id);
    if (request?.err) {
      done(request.err);
    }
    if (request?.data.length > 0) {
      const exists = await verifyExternalUser(request?.data[0].id_usuario);
      return exists?.data ? done(null, exists?.data) : done(null);
    }

    const facebookOpts = {
      name: profile._json.name,
      OAuthID: profile._json.id,
      provider: profile.provider
    };

    request = await initialExtUserSignUp(facebookOpts);
    if (request) {
      return done(null, request);
    } else {
      return done(null);
    }
  }
);

const optLocal = {
  usernameField: "nombreUsuario",
  passwordField: "password"
};

const verifyLocal: VerifyFunction = async (
  username: string,
  password: string,
  done: any
) => {
  console.log("username", username);
  const user: Usuario | null = await getUserByUsername(username);
  console.log(user);
  if (!user) return done(null, false, { message: "Bad Credentials" });
  if (await comparePassword(password, user.password || "")) {
    if (user.tipoUsuario.descripcion === "Funcionario") {
      return done(null, {
        id: user.cedula,
        admin: false,
        user: {
          ...user,
          password: undefined
        }
      });
    }

    // const newNotifications = await hasNotifications(user.cedula);
    return done(null, {
      id: user.cedula,
      admin: user.tipoUsuario.descripcion === "Administrador",
      superuser: user.tipoUsuario.descripcion === "Superuser",
      user: {
        ...user,
        password: undefined
      }
      // hasNewNotifications: newNotifications
    });
  } else {
    return done(null, false);
  }
};

const LocalStrategy = new Local(optLocal, verifyLocal);

const generateToken = (user: any) => {
  const timestamp = new Date().getTime();
  return encode(
    { sub: user, iat: timestamp },
    process.env.JWT_SECRET || "not a secret"
  );
};

export {
  JwtStrategy,
  LocalStrategy,
  generateToken,
  GoogleStrategy,
  FacebookStrategy
};
