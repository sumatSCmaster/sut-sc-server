import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { updateUser, getUsersByContributor } from '@helpers/user';

const router = Router();

const validateUser = (req, res, next) => {
  if (req.user.tipoUsuario === 4) {
    next();
  } else {
    res.json({ status: 400, message: 'Operación no válida' });
  }
};

router.patch('/', authenticate('jwt'), validateUser, async (req, res) => {
  const [err, data] = await fulfill(updateUser(req.body.user));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.get('/:contributor', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(getUsersByContributor(req.params.contributor));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json({ status: 200, message: 'Usuarios SUT obtenidos', usuarios: data });
});

export default router;
