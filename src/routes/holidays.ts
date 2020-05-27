import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getHolidays, createHolidays, deleteHoliday } from '@helpers/holidays';
import { isOfficialAdmin } from '@validations/auth';
import { authenticate } from 'passport';

const router = Router();

router.get('/', authenticate('jwt'), isOfficialAdmin ,async (req,res) => {
    const [error, data] = await fulfill(getHolidays());
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ holidays: data });
});

router.post('/', authenticate('jwt'), isOfficialAdmin ,async (req,res) => {
    const [error, data] = await fulfill(createHolidays(req.body.data));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ holidays: data });
});

router.delete('/:id', authenticate('jwt'), isOfficialAdmin ,async (req,res) => {
    const [error, data] = await fulfill(deleteHoliday(req.params['id']));
    if (error) res.status(500).json({ error, status: 500 });
    if (data) res.status(200).json({ holiday: data });
});


export default router;