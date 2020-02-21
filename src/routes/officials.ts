import { Router } from "express";
import {
  getOfficialsByInstitution,
  createOfficial,
  updateOfficial,
  deleteOfficial
} from "@helpers/officials";
import { authenticate } from "passport";
import { fulfill } from "@utils/resolver";

const router = Router();

router.get("/:institution", async (req: any, res) => {
  const { institution } = req.params;
  const [err, data] = await fulfill(getOfficialsByInstitution(institution));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.post("/", async (req, res) => {
  const { official } = req.body;
  const [err, data] = await fulfill(createOfficial(official));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.put("/:id", async (req, res) => {
  const { official } = req.body;
  const { id } = req.params;
  const [err, data] = await fulfill(updateOfficial(official, id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(deleteOfficial(id));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

export default router;
