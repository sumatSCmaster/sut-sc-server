import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getFiscalizations, createFiscalization, updateOneFiscalization } from '@helpers/fiscalization';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getFiscalizations());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
})

router.post('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(createFiscalization(req.user ,req.body));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.patch('/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(updateOneFiscalization(req.user , {idFiscalizacion: req.params['id'], ...req.body}));
  console.log(error, data)
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});


export default router;
