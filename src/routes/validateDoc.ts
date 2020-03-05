import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { validateDocById } from '@helpers/validateDocs';

const router = Router();

router.get('/:id', authenticate('jwt'), async (req, res) => {
const [err, data] = await fulfill(validateDocById(req.params['id']));
  if (err) res.status(err.status).json(err);
  if (data) res.status(data.status).json(data);
})
export default router;