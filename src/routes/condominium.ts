import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getCondominium, getCondominiums, deleteCondominium, createCondominium, addOwner, deleteOwner, editCondominiumApart } from '@helpers/condominium';
import { authenticate } from 'passport';

const router = Router();

router.get('/', async (req, res) => {
  const [error, data] = await fulfill(getCondominiums());
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/:id', async (req, res) => {
  const [error, data] = await fulfill(getCondominium(req.params.id));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.delete('/:id', async (req, res) => {
  const [error, data] = await fulfill(deleteCondominium(req.params.id));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/', async (req, res) => {
  const [error, data] = await fulfill(createCondominium(req.body));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.post('/:id/owner', async (req, res) => {
  const [error, data] = await fulfill(addOwner({ condo_id: req.params.id, ...req.body }));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.delete('/:id_condo/owner/:id_owner', async (req, res) => {
  const [error, data] = await fulfill(deleteOwner(req.params.id_condo, req.params.id_owner));
  if (error) res.status(500).json({ message: error.message, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.put('/apart/edit/:id', authenticate('jwt'), async (req: any, res) => {
  const { id } = req.params;
  const { apartments } = req.body;
  const [err, data] = await fulfill(editCondominiumApart(id, apartments ));
  if (err) res.status(500).json({ err, status: 500 });
  if (data) res.status(200).json(data);
});

export default router;
