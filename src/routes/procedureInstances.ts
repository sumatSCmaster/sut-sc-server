import { Router } from 'express';
import { authenticate } from 'passport';
import { fulfill } from '@utils/resolver';
import { updateProcedureInstanceCost } from '@helpers/procedureInstances';

const router = Router();

router.patch("/:id", authenticate('jwt'), async (req, res) => {
    const [error, data] = await fulfill(updateProcedureInstanceCost({ ...req.body, id: req.params['id'] }));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ status: 200, result: data });
})

export default router;