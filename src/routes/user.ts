import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { updateUser } from '@helpers/user';

const router = Router();

const validateUser = (req, res, next) => {
    console.log(req.user)
    if(req.user.tipoUsuario === 4){
        next()
    }else{
        res.json({status: 400, message: 'Operación no válida'})
    }
}


router.patch('/', authenticate('jwt'), validateUser, async (req,res) => {
    const [err, data] = await fulfill(updateUser(req.body.user));
    if (err) res.status(500).json(err);
    if (data) res.status(200).json(data);
});



export default router;