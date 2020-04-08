import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getDestinations, createDestination, updateDestination, disableDestination } from '@helpers/terminal';

const router = Router();

router.get('/', async (req, res) => {
    const [error, data] = await fulfill(getDestinations());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.post('/', async (req, res) => {
    const [error, data] = await fulfill(createDestination(req.body));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

router.patch('/:id', async (req, res) => {
    const [error, data] = await fulfill(updateDestination({ ...req.body, id: req.params['id']}));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
});

router.delete('/:id', async (req, res) => {
    const [error, data] = await fulfill(disableDestination(req.params['id']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(data.status).json({ ...data });
})

export default router;