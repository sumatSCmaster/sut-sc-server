import { Router } from "express";
import { generateToken } from "@utils/Strategies";
import { authenticate } from "passport";
//import { createAdmin } from "@helpers/user";
import * as authValidations from "@validations/auth";
import { checkIfAdmin, checkIfSuperuser, checkIfOfficial } from "@utils/user";
import { hashSync, genSaltSync } from "bcryptjs";
import { checkResult } from "@validations/index";
import {
  createSuperuser,
  createAdmin,
  completeExtUserSignUp,
  addInstitute
} from "@helpers/user";
import { isSuperuser, isAdmin } from "@middlewares/auth";
import { fulfill } from "@utils/resolver";
import e = require("express");

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
      req.user.user = await addInstitute(req.user.user);
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso.",
        token: generateToken(req.user),
        admin: req.user.admin,
        user: req.user.user
      });
    } else if (await checkIfOfficial(req.user.user.cedula)) {
      req.user.user = await addInstitute(req.user.user);
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
      req.body.usuario.password = hashSync(
        req.body.usuario.password,
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
        req.body.usuario.password = hashSync(
          req.body.usuario.password,
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
        message: "Clave de creacion de superuser invalida"
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
  async (req: any, res) => {
    const token = generateToken(req.user);
    console.log(req.user);
    if (req.user!["cedula"]) {
      res.redirect(`${process.env.CLIENT_URL}/auth/${token}`);
    } else {
      res.redirect(
        `${process.env.CLIENT_URL}/signup/oauth=${req.user.nombre_de_usuario}&token=${token}`
      );
    }
  }
);

router.get("/facebook", authenticate("facebook"));

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
  console.log(error);
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.get("/user", authenticate("jwt"), async (req: any, res) => {
  const user = {
    id: req.user.id_usuario,
    nombreCompleto: req.user.nombre_completo,
    nombreUsuario: req.user.nombre_de_usuario,
    direccion: req.user.direccion,
    cedula: req.user.cedula,
    rif: req.user.rif,
    nacionalidad: req.user.nacionalidad,
    tipoUsuario: req.user.id_tipo_usuario
  };
  res.status(200).json({ user, status: 200 });
});

export default router;
