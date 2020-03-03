import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator } from '@helpers/errors';
import { authenticate } from 'passport';
import { getAllInstitutions } from '@helpers/institutions';
import { getAllParishes } from '@helpers/parish';

const router = Router();

router.get('/institutions', authenticate('jwt'), async (req: any, res) => {
  if (req.user.tipoUsuario === 1) {
    const [err, data] = await fulfill(getAllInstitutions());
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
  } else {
    res.status(401).json({
      message: 'No tiene permisos de superusuario',
      status: 401,
    });
  }
});

router.get('/parishes', authenticate('jwt'), async (req: any, res) => {
  const [err, data] = await fulfill(getAllParishes());
  if (err) res.status(500).json(err);
  if (data) res.status(200).json(data);
});

export default router;
