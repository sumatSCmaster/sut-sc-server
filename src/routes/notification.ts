/* import { Router } from 'express';
import { authenticate } from 'passport';
import { getNotifications, markAllAsRead } from '@helpers/notification';

const router = Router();

// router.get("/", authenticate("jwt"), async (req: any, res) => {
//   try {
//     const notifications = await getNotifications(req.user.id);
//     res.status(200).json({
//       status: 200,
//       message: "Notificaciones retornadas de manera exitosa.",
//       notifications
//     });
//   } catch (e) {
//     res.status(500).json({
//       status: 500,
//       error: e
//     });
//   }
// });

// router.put("/markAsRead", authenticate("jwt"), async (req: any, res) => {
//   try {
//     const read = await markAllAsRead(req.user.id);
//     res.status(200).json({
//       status: 200,
//       message: "Notificaciones marcadas como leidas",
//       read
//     });
//   } catch (e) {
//     res.status(500).json({
//       status: 500,
//       error: e
//     });
//   }
// });

export default router; */