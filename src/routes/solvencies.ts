import Router from 'express';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { createSolvencyAB, getSolvencyACandidates, getSolvencyBCandidates } from '@helpers/solvencies';
import { createQRForm } from '@helpers/formsHelper';
import { generateQRAlone } from '@utils/forms';

const router = Router();

router.get('/b', authenticate('jwt'), async (req, res) => {
    const {tipoDocumento, documento} = req.query;
    const [error, data] = await fulfill(getSolvencyBCandidates({tipoDocumento, documento}));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

router.post('/b', authenticate('jwt'), async (req, res) => {
    const {tramite} = req.body;
    const [error, data] = await fulfill(createSolvencyAB(tramite, req.user, 'b'));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

router.get('/a', authenticate('jwt'), async (req, res) => {
    const {tipoDocumento, documento} = req.query;
    const [error, data] = await fulfill(getSolvencyACandidates({tipoDocumento, documento}));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})

router.post('/a', authenticate('jwt'), async (req, res) => {
    const {tramite} = req.body;
    const [error, data] = await fulfill(createSolvencyAB(tramite, req.user, 'a'));
    if (error) res.status(error.status).json(error);
    if (data) res.status(data.status).json(data);
})
//NO DESCOMENTAR
// router.post('/generateQRAlone', authenticate('jwt'), async (req, res) => {
//     const [error, data] = await fulfill(generateQRAlone());
//     if (error) res.status(error.status).json(error);
//     if (data) res.status(data.status).json(data);
// })

export default router;