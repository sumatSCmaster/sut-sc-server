import { Router } from "express";
import auth from "./auth";
//import notification from "./notification";
import banks from "./banks";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";

const router = Router();

router.use("/auth", auth);
// router.use('/file', file);
//router.use("/notification", notification);
router.use("/banks", banks);

router.get("/", (req, res) => {
  res.status(200).json({
    status: 200,
    message: "Ok"
  });
});


export default router;
