import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getOrdinancesByProcedure, getOrdinancesByProcedureWithCodCat } from '@helpers/ordinance';

const router = Router();

router.get('/:id', async (req,res) => {
    const [error, data] = await fulfill(getOrdinancesByProcedure(req.params['id']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.get('/:property/:procedure', async (req, res) => {
    const [error, data] = await fulfill(getOrdinancesByProcedureWithCodCat(req.params['procedure'], req.params['property']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

export default router;