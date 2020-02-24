import { Router } from "express";
import {
  getOfficialsByInstitution,
  createOfficial,
  updateOfficial,
  deleteOfficial
} from "@helpers/officials";
// import { authenticate } from "passport";
import { fulfill } from "@utils/resolver";

const router = Router();

router.get("/:institution", async (req: any, res) => {
  const { institution } = req.params;
  const [err, data] = await fulfill(getOfficialsByInstitution(institution));
  if (err) res.status(401).json(err);
  if (data) res.status(200).json(data);
});

//TODO: agregar auth y sacar id de institucion del req.user
router.post("/", async (req, res) => {
  const { official } = req.body;
  // const {id_institucion} = req.user;
  const [err, data] = await fulfill(createOfficial(official));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
});

//TODO: agregar auth y sacar id de institucion del req.user
router.put("/:id", async (req, res) => {
  const { official } = req.body;
  const { id } = req.params;
  // const {id_institucion} = req.user;
  const [err, data] = await fulfill(updateOfficial(official, id));
  if (err) res.status(500).json({ error: err, status: 500 });
  if (data) res.status(data.status).json(data);
});

//TODO: agregar auth y sacar id de institucion del req.user
router.delete("/:id", async (req, res) => {
  const { id } = req.params;
  // const {id_institucion} = req.user;
  const [err, data] = await fulfill(deleteOfficial(id, 1));
  if (err) res.status(500).json({ error: err, status: 500 });
  if (data) res.status(data.status).json(data);
});

export default router;
