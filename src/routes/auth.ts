import { Router } from "express";
import { generateToken } from "@utils/Strategies";
import { authenticate } from "passport";
import { createAdmin } from "@helpers/user";
import * as authValidations from "@validations/auth";
import { checkIfAdmin, getInit } from "@utils/user";
import { hashSync, genSaltSync } from "bcryptjs";
import { checkResult } from "@validations/index";

const router = Router();

router.post(
  "/login",
  authenticate("local"),
  authValidations.login,
  checkResult,
  async (req: any, res) => {
    if (await checkIfAdmin(req.user.id)) {
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso.",
        token: generateToken(req.user),
        init: await getInit(),
        admin: req.user.admin,
        user: req.user.user,
        hasNewNotifications: req.user.hasNewNotifications
      });
    } else {
      res.status(200).json({
        status: 200,
        message: "Inicio de sesion exitoso.",
        token: generateToken(req.user),
        admin: req.user.admin,
        user: req.user.user,
        hasNewNotifications: req.user.hasNewNotifications
      });
    }
  }
);

router.post(
  "/createAdmin",
  authValidations.createAdmin,
  checkResult,
  async (req, res) => {
    if (req.body.password === process.env.ADMIN_PASSWORD) {
      try {
        req.body.usuario.rol = "Administrador";
        const salt = genSaltSync(10);
        req.body.usuario.password = hashSync(req.body.usuario.password, salt);
        const user = await createAdmin({ ...req.body.usuario }).catch(e => {
          res.status(500).json({
            status: 500,
            message: e.detail
          });
        });
        if (user) {
          res.status(200).json({
            status: 200,
            message: "Administrador creado.",
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
        message: "Clave de administrador invalida"
      });
    }
  }
);

export default router;
