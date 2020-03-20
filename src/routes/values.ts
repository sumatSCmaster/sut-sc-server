import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { updateUtmmValue, getUtmmValue } from '@helpers/values';
import { isSuperuser } from '@validations/auth';
import { authenticate } from 'passport';

const router = Router();

router.patch('/utmm', authenticate('jwt'),isSuperuser ,async (req,res) => {
    const [error, data] = await fulfill(updateUtmmValue(req.body.value));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ ...data });
});

router.get('/utmm', authenticate('jwt'), isSuperuser ,async (req,res) => {
    const [error, data] = await fulfill(getUtmmValue());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ ...data });
});

export default router;