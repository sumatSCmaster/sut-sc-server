import { Strategy as JWT, ExtractJwt } from "passport-jwt";
import { Strategy as Local, VerifyFunction } from "passport-local";
import { getUserByUsername, comparePassword } from "@helpers/user";
import { encode } from "jwt-simple";
import { Usuario } from "@interfaces/sigt";

const optJwt = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: process.env.JWT_SECRET || "not a secret"
};

const JwtStrategy = new JWT(optJwt, async (payload, done) => {
  return done(null, payload.sub);
});

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
  console.log(user)
  if (!user) return done(null, false, { message: "Bad Credentials" });
  if (await comparePassword(password, user.cuenta_funcionario?.password || "")) {
    // const newNotifications = await hasNotifications(user.cedula);
    return done(null, {
      id: user.cedula,
      admin: user.tipo_usuario.descripcion === "Administrador",
      superuser: user.tipo_usuario.descripcion === "Superuser",
      user: { ...user, cuenta_funcionario: { id_usuario: user.id_usuario, password: undefined } }
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

export { JwtStrategy, LocalStrategy, generateToken };
