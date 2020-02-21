import { Router } from "express";
import auth from "./auth";
import official from "./officials";
//import notification from "./notification";
import banks from "./banks";
import procedures from "./procedures";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";

const router = Router();

router.use("/auth", auth);
router.use("/banks", banks);
router.use("/official", official);
router.use("/procedures", procedures);
// router.use('/file', file);
//router.use("/notification", notification);

router.get("/", (req, res) => {
  res.status(200).json({
    status: 200,
    message: "Ok"
  });
});

export default router;
