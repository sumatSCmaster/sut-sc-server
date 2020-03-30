import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getOrdinancesByProcedure, getOrdinancesByProcedureWithCodCat, disableOrdinance, updateOrdinance, getVariables, createOrdinance } from '@helpers/ordinance';

const router = Router();

router.get('/variables', async (req, res) => {
    const [error, data] = await fulfill(getVariables());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

router.get('/:id', async (req,res) => {
    const [error, data] = await fulfill(getOrdinancesByProcedure(req.params['id']));
    console.log(error);
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.get('/:property/:procedure', async (req, res) => {
    const [error, data] = await fulfill(getOrdinancesByProcedureWithCodCat(req.params['procedure'], req.params['property']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.post('/', async (req, res) => {
    const [error, data] = await fulfill(createOrdinance(req.body));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

router.delete('/:idOrdenanza', async (req, res) => {
    const [error, data] = await fulfill(disableOrdinance(req.params['idOrdenanza']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.patch('/:idOrdenanza', async (req, res) => {
    const [error, data] = await fulfill(updateOrdinance(req.params['idOrdenanza'], req.body.precioUtmm));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

export default router;