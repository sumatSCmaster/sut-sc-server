import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getActivities, getMunicipalReferenceActivities, updateContributorActivities } from '@helpers/activities';
import { authenticate } from 'passport';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivities());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/rim', authenticate('jwt'), async (req, res) => {
  const { tipoDocumento, documento } = req.query;
  const [error, data] = await fulfill(getMunicipalReferenceActivities({ docType: tipoDocumento, document: documento }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.put('/rim/:id', authenticate('jwt'), async (req, res) => {
  const { id } = req.params;
  const { datosSucursal, actividades } = req.body;
  const [error, data] = await fulfill(updateContributorActivities({ branchId: id, branchInfo: datosSucursal, activities: actividades }));
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

export default router;
