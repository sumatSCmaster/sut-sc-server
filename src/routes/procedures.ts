import { Router } from "express";
import { getAvailableProcedures } from "@helpers/procedures";
import { authenticate } from "passport";
import { fulfill } from "@utils/resolver";

const router = Router();

router.get("/", authenticate("jwt"), async (req, res) => {
  const [error, data] = await fulfill(getAvailableProcedures());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, options: data });
});

export default router;
