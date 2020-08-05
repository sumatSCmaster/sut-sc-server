import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { updateUser, getUsersByContributor, userSearch, unlinkContributorFromUser, updateUserInformation } from '@helpers/user';

const router = Router();

const validateUser = (req, res, next) => {
  if (req.user.tipoUsuario === 4) {
    next();
  } else {
    res.json({ status: 400, message: 'Operación no válida' });
  }
};

router.get('/search', authenticate('jwt'), async (req, res) => {
  const { doc, pref, email } = req.query;
  const [err, data] = await fulfill(userSearch({ document: doc || null, docType: pref, email: email || null }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.get('/:contributor', authenticate('jwt'), async (req, res) => {
  const [err, data] = await fulfill(getUsersByContributor(req.params.contributor));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json({ status: 200, message: 'Usuarios SUT obtenidos', usuarios: data });
});

router.put('/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { user } = req.body;
  const [err, data] = await fulfill(updateUserInformation({ user, id }));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});

router.patch('/', authenticate('jwt'), validateUser, async (req, res) => {
  const [err, data] = await fulfill(updateUser(req.body.user));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

router.patch('/contributor/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const [err, data] = await fulfill(unlinkContributorFromUser(id));
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
