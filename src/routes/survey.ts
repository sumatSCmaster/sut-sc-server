import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getSurvey, addSurvey } from '@helpers/survey';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getSurvey(req.query.id_contribuyente));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(data.status).json({ ...data });
});

router.post('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(addSurvey(req.body));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(data.status).json({ ...data });
});

export default router;
