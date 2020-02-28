import { Router } from "express";
import { getAvailableProcedures, procedureInit } from "@helpers/procedures";
import { validate } from "@validations/auth";
import { checkResult } from "@validations/index";
import { authenticate } from "passport";
import { fulfill } from "@utils/resolver";

const router = Router();

router.get("/", authenticate("jwt"), async (req, res) => {
  const [error, data] = await fulfill(getAvailableProcedures());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

router.post(
  "/init",
  validate(),
  checkResult,
  authenticate("jwt"),
  async (req: any, res) => {
    const { id } = req.user;
    const { tramite } = req.body;
    const [error, data] = await fulfill(procedureInit(tramite, id));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json(data);
  }
);

export default router;
