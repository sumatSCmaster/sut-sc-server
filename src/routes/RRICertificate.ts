import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getRRICertificates } from '@helpers/RRICertificate';

const router = Router();

router.post('/', async (req, res) => {
  const { ids } = req.body;
  const [err, data] = await fulfill(getRRICertificates(ids));
  if (err) res.status(500).json(err);
  if(data) res.status(200).json(data);
});

export default router;
