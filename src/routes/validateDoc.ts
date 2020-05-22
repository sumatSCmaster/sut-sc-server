import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { validateDocById, validateSedematById } from '@helpers/validateDocs';

const router = Router();

router.get('/sedemat/:id', async (req, res) => {
  const [err, data] = await fulfill(validateSedematById(req.params['id']));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
})

router.get('/:id(\\d+)', async (req, res) => {
  const [err, data] = await fulfill(validateDocById(req.params['id']));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
});


export default router;