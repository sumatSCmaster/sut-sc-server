import { Router } from "express";
import {
  getOfficialsByInstitution,
  createOfficial,
  updateOfficial,
  deleteOfficial
} from "@helpers/officials";
import { createOfficial as validateOfficial } from "@validations/auth";
import { checkResult } from "@validations/index";
import { authenticate } from "passport";
import { fulfill } from "@utils/resolver";

const router = Router();

//TODO: añadir validacion de tipo de usuario
router.get("/", authenticate("jwt"), async (req: any, res) => {
  console.log(req.user);
  const { id_institucion } = req.user.user.cuentaFuncionario;
  if (id_institucion) {
    const [err, data] = await fulfill(
      getOfficialsByInstitution(id_institucion)
    );
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
  } else {
    res.status(401).json({
      message: "No tiene permisos para obtener los funcionarios.",
      status: 401
    });
  }
});

router.post(
  "/",
  authenticate("jwt"),
  validateOfficial,
  checkResult,
  async (req: any, res) => {
    const { id_institucion } = req.user.user.cuentaFuncionario;
    if (id_institucion) {
      const { funcionario } = req.body;
      const [err, data] = await fulfill(
        createOfficial(funcionario, id_institucion)
      );
      if (err) res.status(500).json(err);
      if (data) res.status(data.status).json(data);
    } else {
      res.status(401).json({
        message: "No tiene permisos para crear funcionarios.",
        status: 401
      });
    }
  }
);

router.put(
  "/:id",
  authenticate("jwt"),
  validateOfficial,
  checkResult,
  async (req, res) => {
    const { id_institucion } = req.user.user.cuentaFuncionario;
    if (id_institucion) {
      const { official } = req.body;
      const { id } = req.params;
      const [err, data] = await fulfill(updateOfficial(official, id));
      if (err) res.status(500).json(err);
      if (data) res.status(data.status).json(data);
    } else {
      res.status(401).json({
        message: "No tiene permisos para editar funcionarios.",
        status: 401
      });
    }
  }
);

router.delete("/:id", authenticate("jwt"), async (req: any, res) => {
  const { id_institucion } = req.user.user.cuentaFuncionario;
  if (id_institucion) {
    const { id } = req.params;
    const [err, data] = await fulfill(deleteOfficial(id, id_institucion));
    if (err) res.status(500).json(err);
    if (data) res.status(data.status).json(data);
  } else {
    res.status(401).json({
      message: "No tiene permisos para editar funcionarios.",
      status: 401
    });
  }
});

export default router;
