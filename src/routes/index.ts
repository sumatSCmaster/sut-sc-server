import { Router } from "express";
import auth from "./auth";
import official from "./officials";
//import notification from "./notification";
import banks from "./banks";
import procedures from "./procedures";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";
import { fulfill } from "@utils/resolver";
import { getAllInstitutions } from "@helpers/institutions";

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

router.get("/institutions", authenticate("jwt"), async (req: any, res) => {
  if (req.user.tipoUsuario === 1) {
    const [err, data] = await fulfill(getAllInstitutions());
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
  } else {
    res.status(401).json({
      message: "No tiene permisos de superusuario",
      status: 401
    });
  }
});

export default router;
