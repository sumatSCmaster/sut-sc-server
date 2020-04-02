import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { authenticate } from 'passport';
import { getOrdinancesByProcedure, getOrdinancesByProcedureWithCodCat, disableOrdinance, updateOrdinance, getVariables, createOrdinance, getOrdinancesByInstitution } from '@helpers/ordinance';

const router = Router();

router.get('/', authenticate('jwt'), async (req: any, res) => {
    const { cuentaFuncionario } = req.user;
    if (cuentaFuncionario.id_institucion) {
      const [err, data] = await fulfill(getOrdinancesByInstitution(cuentaFuncionario.id_institucion));
      if (err) res.status(500).json(err);
      if (data) res.status(200).json(data);
    } else {
      res.status(401).json({
        message: 'No tiene permisos para obtener las ordenanzas.',
        status: 401,
      });
    }
  });

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