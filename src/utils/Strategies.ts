import { Strategy as JWT, ExtractJwt } from "passport-jwt";
import { OAuth2Strategy as Google } from "passport-google-oauth";
import { Strategy as Facebook } from "passport-facebook";
import { Strategy as Local, VerifyFunction } from "passport-local";
import {
  getUserByUsername,
  comparePassword,
  getByGoogleID,
  verifyExternalUser,
  initialExtUserSignUp
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
    let request = await getByGoogleID(profile.id);
    if (request?.data.length > 0) {
      const exists = await verifyExternalUser(request?.data[0].id_usuario);
      console.log(exists);
      return exists?.data ? done(null, exists?.data) : done(null);
    }

    const googleOpts = {
      name: profile._json.name,
      googleID: profile._json.sub,
      username: profile._json.email
    };

    request = await initialExtUserSignUp(googleOpts);
    if (request) {
      return done(null, request);
    } else {
      return done(null);
    }
  }
);

const FacebookStrategy = new Facebook(
  optFacebook,
  async (accessToken, refreshToken, profile, done) => {
    console.log(profile);
    // let request = await getByGoogleID(profile.id);
    // if (request?.data.length > 0) {
    //   const exists = await verifyExternalUser(request?.data[0].id_usuario);
    //   console.log(exists);
    //   return exists?.data ? done(null, exists?.data) : done(null);
    // }

    // const googleOpts = {
    //   name: profile._json.name,
    //   googleID: profile._json.sub,
    //   username: profile._json.email
    // };

    // request = await initialExtUserSignUp(googleOpts);
    // if (request) {
    //   return done(null, request);
    // } else {
    //   return done(null);
    // }
  }
);

const optLocal = {
  usernameField: "username",
  passwordField: "password"
};

const verifyLocal: VerifyFunction = async (
  username: string,
  password: string,
  done: any
) => {
  const user: Usuario | null = await getUserByUsername(username);
  console.log(user);
  if (!user) return done(null, false, { message: "Bad Credentials" });
  if (
    await comparePassword(password, user.cuenta_funcionario?.password || "")
  ) {
    // const newNotifications = await hasNotifications(user.cedula);
    return done(null, {
      id: user.cedula,
      admin: user.tipo_usuario.descripcion === "Administrador",
      superuser: user.tipo_usuario.descripcion === "Superuser",
      user: {
        ...user,
        cuenta_funcionario: { id_usuario: user.id_usuario, password: undefined }
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
