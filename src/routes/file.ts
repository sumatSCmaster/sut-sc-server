import { Router } from 'express';
import { authenticate } from 'passport';
import multer = require('multer');
import { diskStorage, photoFilter } from '@utils/multer';
import path from 'path';

const router = Router();

const uploadFile = (req, res, next) => {
  if (process.env.NODE_ENV === 'development') {
    switch (req.params.type) {
      case 'avatar':
        multer({
          storage: diskStorage('avatar'),
          fileFilter: photoFilter,
        }).single('file')(req, res, next);
        break;
      case 'takings':
        multer({
          storage: diskStorage('takings'),
          fileFilter: photoFilter,
        }).array('recaudos')(req, res, next);
        break;
      default:
        res.status(500).json({
          status: 500,
          message: 'Tipo de archivo no definido.',
        });
    }
  } else {
    //TODO: AWS
    res.status(500).json({
      status: 500,
      message: 'El servidor esta en produccion y no he hecho lo de AWS',
    });
  }
};

router.post('/:type', uploadFile, (req: any, res) => {
  const recaudos = req.files.map(file => `${process.env.SERVER_URL}/uploads/takings/${file.filename}`);
  res.status(200).json({
    status: 200,
    message: 'Recaudos subidos de manera exitosa',
    recaudos,
  });
});

router.get('/:type/:name', (req, res) => {
  const { type, name } = req.params;
  try {
    res.setHeader('Content-Type', 'image/png');
    res.sendFile(path.join(process.env.STORAGE_DIR || '/', type, name));
  } catch {
    res.setHeader('ContentType', 'application/json');
    res.status(404).json({
      status: 404,
      message: 'Archivo no encontrado',
    });
  }
});

export default router;
