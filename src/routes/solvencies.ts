import Router from 'express';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { getSolvencyBCandidates } from '@helpers/solvencies';

const router = Router();

router.get('/b', authenticate('jwt'), async (req, res) => {
    const {tipoDocumento, documento} = req.query;
    const [error, data] = await fulfill(getSolvencyBCandidates({tipoDocumento, documento}));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

export default router;