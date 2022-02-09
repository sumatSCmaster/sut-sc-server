import { Router } from 'express';
import { fulfill } from '@utils/resolver';
import { createMockCertificate } from '@utils/forms';

const router = Router();

router.get('/reportSolvRRI', async (req: any, res) => {
  const { id } = req.query;
  const [error, data] = await fulfill(createMockCertificate(id));
  if (error) res.status(500).json(error);
  if (data)
    data.toBuffer(async (err, buffer) => {
      if (err) res.status(500).json({ status: 500, message: 'Error al procesar el pdf' });
      res.contentType('application/pdf').send(buffer);
    });
});

export default router;
