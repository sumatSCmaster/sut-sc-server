import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { createOnDemandCertificate, generateReceipt } from '@helpers/receipt';
import { authenticate } from 'passport';

const router = Router();

router.post('/:id', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(generateReceipt({ application: +req.params['id'] }));
  console.log(error, data);
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/:type/generate', authenticate('jwt'), async (req, res) => {
  const { type } = req.params;
  const { datos } = req.body;
  const [error, data] = await fulfill(createOnDemandCertificate(type, datos));
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
});

export default router;
