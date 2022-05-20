import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { getActivities, getMunicipalReferenceActivities, updateActivitiesAliquots, updateContributorActivities, generatePatentDocument, getSMActivities } from '@helpers/activities';
import { authenticate } from 'passport';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getActivities());
  if (error) res.status(500).json({ error, status: 500 });
  if (data) res.status(200).json({ status: 200, data });
});

router.get('/sm', authenticate('jwt'), async (req, res) => {
  const [error, data] = await fulfill(getSMActivities());
  if (error) res.status(500).json(error);
  if (data) res.status(200).json(data);
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

router.put('/', authenticate('jwt'), async (req, res) => {
  const { alicuotas: aliquots } = req.body;
  const [error, data] = await fulfill(updateActivitiesAliquots({ aliquots }));
  if (error) res.status(500).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/generatePatentDocument', async (req, res) => {
  const { branchId } = req.query;
  const [error, data] = await fulfill(generatePatentDocument({branchId}));
  if (error) res.status(500).json(error);
  if (data){
    data.toBuffer(async (err, buffer) => {
      if (err) res.status(500).json({ status: 500, message: 'Error al procesar el pdf' });
      res.contentType('application/pdf').send(buffer);
    });
  }
});

export default router;
