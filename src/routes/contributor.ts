import { Router } from 'express';
import { updateContributor, updateRIM } from '@helpers/contributor';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';

const router = Router();


router.patch('/:id/', async (req, res) => {
  const [err, data] = await fulfill(updateContributor({ id: req.params['id'], ...req.body}));
  if (err) res.status(500).json(err);
  if (data) res.status(data.status).json(data);
})

router.patch('/rim/:id/',  async (req, res) => {
    const [err, data] = await fulfill(updateRIM({ id: req.params['id'], ...req.body}));
    if (err) res.status(500).json(err);
    if (data) res.status(data.status).json(data);
  })

export default router;
