import { Router } from "express";
import { generateToken } from "@utils/Strategies";
import { authenticate } from "passport";
//import { createAdmin } from "@helpers/user";
import * as authValidations from "@validations/auth";
import { checkIfAdmin, checkIfSuperuser } from "@utils/user";
import { hashSync, genSaltSync } from "bcryptjs";
import { checkResult } from "@validations/index";
import {
  createSuperuser,
  createAdmin,
  completeExtUserSignUp
} from "@helpers/user";
import { isSuperuser, isAdmin } from "@middlewares/auth";
import { fulfill } from "@utils/resolver";

const router = Router();

router.post(
  "/login",
  authValidations.isLogged,
  authValidations.login,
  checkResult,
  authenticate("local"),
  async (req: any, res) => {
    if (await checkIfSuperuser(req.user.user.cedula)) {
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso",
        token: generateToken(req.user),
        admin: req.user.admin,
        superuser: true,
        user: req.user.user
      });
    } else if (await checkIfAdmin(req.user.user.cedula)) {
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso.",
        token: generateToken(req.user),
        admin: req.user.admin,
        user: req.user.user
      });
    } else {
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso.",
        token: generateToken(req.user),
        admin: req.user.admin,
        user: req.user.user
      });
    }
  }
);

router.get("/logout", authValidations.isAuth, (req, res) => {
  req.logout();
  res.json({ status: 200, message: "Sesión finalizada." });
});

router.post(
  "/createAdmin",
  authenticate("jwt"),
  isSuperuser,
  authValidations.createAdmin,
  checkResult,
  async (req, res) => {
    try {
      const salt = genSaltSync(10);
      req.body.usuario.cuenta_funcionario = {};
      req.body.usuario.cuenta_funcionario.password = hashSync(
        req.body.password,
        salt
      );
      const user = await createAdmin({ ...req.body.usuario }).catch(e => {
        res.status(500).json({
          status: 500,
          message: e
        });
      });
      if (user) {
        res.status(200).json({
          status: 200,
          message: "Admin creado.",
          user
        });
      }
    } catch (e) {
      res.status(500).json({
        status: 500,
        error: e
      });
    }
  }
);

router.post(
  "/createSuperuser",
  authValidations.createSuperuser,
  checkResult,
  async (req, res) => {
    if (req.body.password === process.env.SUPERUSER_CREATION_PASSWORD) {
      try {
        const salt = genSaltSync(10);
        req.body.usuario.cuenta_funcionario = {};
        req.body.usuario.cuenta_funcionario.password = hashSync(
          req.body.password,
          salt
        );
        const user = await createSuperuser({ ...req.body.usuario }).catch(e => {
          res.status(500).json({
            status: 500,
            message: e
          });
        });
        if (user) {
          res.status(200).json({
            status: 200,
            message: "Superuser creado.",
            user
          });
        }
      } catch (e) {
        res.status(500).json({
          status: 500,
          error: e
        });
      }
    } else {
      res.status(401).json({
        status: 401,
        message: "Clave de creacion de superuser superuser invalida"
      });
    }
  }
);

router.get(
  "/google",
  authenticate("google", {
    scope: ["openid", "profile", "email"]
  })
);

router.get(
  "/google/callback",
  authenticate("google", {
    session: false,
    failureRedirect: `${process.env.CLIENT_URL}/ingresar`
  }),
  async (req, res) => {
    const token = generateToken(req.user);
    if (req.user!["cedula"]) {
      res.redirect(`${process.env.CLIENT_URL}/auth/${token}`);
    } else {
      res.redirect(`${process.env.CLIENT_URL}/signup/${token}`);
    }
  }
);

router.get("/facebook", authenticate("facebook", { scope: "read_stream" }));

router.get(
  "/facebook/callback",
  authenticate("facebook", {
    session: false,
    failureRedirect: `${process.env.CLIENT_URL}/ingresar`
  }),
  async (req, res) => {
    const token = generateToken(req.user);
    if (req.user!["cedula"]) {
      res.redirect(`${process.env.CLIENT_URL}/auth/${token}`);
    } else {
      res.redirect(`${process.env.CLIENT_URL}/signup/${token}`);
    }
  }
);

router.post("/complete", authenticate("jwt"), async (req: any, res) => {
  const { user } = req.body;
  const { id_usuario } = req.user;
  const [error, data] = await fulfill(completeExtUserSignUp(user, id_usuario));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

export default router;
