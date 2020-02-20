import { Router } from "express";
import { authenticate } from "passport";
import { isAdmin } from "@middlewares/auth";
// import { getPermissions, getUserPermissions } from "@helpers/role";

const router = Router();

// router.get("/", authenticate("jwt"), isAdmin, async (req, res) => {
//   try {
//     const permissions = await getPermissions();
//     res.status(200).json({
//       status: 200,
//       message: "Permisos retornados de manera exitosa.",
//       permissions
//     });
//   } catch (e) {
//     res.status(500).json({
//       status: 500,
//       error: e
//     });
//   }
// });

// router.get("/user", authenticate("jwt"), async (req: any, res) => {
//   try {
//     const permissions = await getUserPermissions(req.user.id);
//     res.status(200).json({
//       status: 200,
//       message: "Permisos retornados de manera exitosa.",
//       permissions
//     });
//   } catch (e) {
//     res.status(500).json({
//       status: 500,
//       error: e
//     });
//   }
// });

export default router;
