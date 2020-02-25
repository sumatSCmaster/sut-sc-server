import { Router } from "express";
import { getAllBanks, validatePayments } from "@helpers/banks";
import { fulfill } from "@utils/resolver";

const router = Router();

//TODO: realizar estructura correcta en el helper, y tipificar
router.get("/", async (req, res) => {
  const [err, data] = await fulfill(getAllBanks());
  if (err) res.json({ status: 500, err });
  if (data) res.json(data);
});

router.put(
  "/validatePayments",
  async (req, res) => {
    const [err, data] = await fulfill(validatePayments(req.body));
    if (err) res.json({ status: 500, err });
    if (data) res.json(data);
  }
)

export default router;
