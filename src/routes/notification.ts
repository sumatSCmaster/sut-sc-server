import { Router } from 'express';
import { authenticate } from 'passport';
import { getNotifications, markAllAsRead } from '@helpers/notification';
import { fulfill } from '@utils/resolver';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
  const { cedula } = req.user;
  const [error, data] = await fulfill(getNotifications(cedula));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

router.put('/markAsRead', authenticate('jwt'), async (req: any, res) => {
  const { cedula } = req.user;
  const [error, data] = await fulfill(markAllAsRead(cedula));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

export default router;
