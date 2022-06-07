import Router from 'express';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { createSolvencyB, getSolvencyBCandidates } from '@helpers/solvencies';
import { initProcedureAnalistAB } from '@helpers/procedures';
import Pool from '@utils/Pool';

const router = Router();

router.get('/b', authenticate('jwt'), async (req, res) => {
    const {tipoDocumento, documento} = req.query;
    const [error, data] = await fulfill(getSolvencyBCandidates({tipoDocumento, documento}));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

router.post('/b', authenticate('jwt'), async (req, res) => {
    const {tramite} = req.body;
    const [error, data] = await fulfill(createSolvencyB(tramite, req.user));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

export default router;