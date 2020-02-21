import { Router } from "express";
import auth from "./auth";
import official from "./officials";
//import notification from "./notification";
import banks from "./banks";
import institutions from "./institutions";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";
import { getAvailableProcedures } from "@helpers/institutions";

const router = Router();

router.use("/auth", auth);
// router.use('/file', file);
//router.use("/notification", notification);
router.use("/banks", banks);
router.use("/officials", official);
router.use("/institutions", institutions);

router.get("/", (req, res) => {
  res.status(200).json({
    status: 200,
    message: "Ok"
  });
});

router.get("/institutions", async (req, res) => {
  try {
    const options = await getAvailableProcedures();
    res.json({ status: 200, options });
  } catch (e) {
    res.json({ status: 401, error: e });
  }
});

export default router;
