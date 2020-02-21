import { Router } from "express";
import auth from "./auth";
import notification from "./notification";
import official from "./officials";
import banks from "./banks";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";
// import { endWizard } from "@helpers/user";

const router = Router();

router.use("/auth", auth);
// router.use('/file', file);
router.use("/notification", notification);
router.use("/banks", banks);
router.use("/officials", official);

router.get("/", (req, res) => {
  res.status(200).json({
    status: 200,
    message: "Ok"
  });
});

// router.put("/endWizard", authenticate("jwt"), isAdmin, async (req, res) => {
//   try {
//     const ended = await endWizard();
//     if (ended) {
//       res.status(200).json({
//         status: 200,
//         message: "Wizard finalizado de manera exitosa."
//       });
//     } else {
//       res.status(409).json({
//         status: 409,
//         message: "Wizard ya esta terminado."
//       });
//     }
//   } catch (e) {
//     res.status(500).json({
//       status: 500,
//       error: e
//     });
//   }
// });

export default router;
