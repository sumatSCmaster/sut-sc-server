import { Router } from 'express';
import { authenticate } from 'passport';
import multer = require('multer');
import { diskStorage, photoFilter } from '@utils/multer';
import path from 'path';
import switchcase from '@utils/switch';
import fs from 'fs';
import Pool from '@utils/Pool';
import { errorMessageGenerator } from '@helpers/errors';
import queries from '@utils/queries';

const pool = Pool.getInstance();

const router = Router();

const uploadFile = (req, res, next) => {
  // if (process.env.NODE_ENV === 'development') {
  switch (req.params.type) {
    case 'avatar':
      multer({
        storage: diskStorage('avatar'),
        fileFilter: photoFilter,
      }).single('file')(req, res, next);
      break;
    case 'takings':
      multer({
        storage: diskStorage('tramites/' + req.params.id),
        fileFilter: photoFilter,
      }).array('recaudos')(req, res, next);
      break;
    case 'procedures':
      multer({
        storage: diskStorage('tramites/' + req.params.id),
        fileFilter: photoFilter,
      }).array('media')(req, res, next);
      break;
    default:
      res.status(500).json({
        status: 500,
        message: 'Tipo de archivo no definido.',
      });
  }
  // } else {
  //   //TODO: AWS
  //   res.status(500).json({
  //     status: 500,
  //     message: 'El servidor esta en produccion y no he hecho lo de AWS',
  //   });
  // }
};

router.post('/:type/:id?', uploadFile, async (req: any, res) => {
  const { id, type } = req.params;
  const media = req.files.map((file) => typeMedia(`tramites/${id}`)(file)(process.env.NODE_ENV));
  const client = await pool.connect();
  try {
    if (media.length > 0 && type === 'takings') {
      const procedure = (await client.query('SELECT id FROM TRAMITES_STATE_WITH_RESOURCES WHERE codigotramite=$1', [id])).rows[0];
      client.query('BEGIN');
      await Promise.all(
        media.map(async (urlRecaudo) => {
          await client.query(queries.INSERT_TAKINGS_IN_PROCEDURE, [procedure.id, urlRecaudo]);
        })
      );
      client.query('COMMIT');
    }

    res.status(200).json({
      status: 200,
      message: 'Recaudos subidos de manera exitosa',
      [type === 'takings' ? 'recaudos' : 'archivos']: media,
    });
  } catch (error) {
    res.status(500).json({
      status: 500,
      error,
      message: errorMessageGenerator(error) || error.message || 'No se logró insertar los recaudos',
    });
  } finally {
    client.release();
  }
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

router.put('/:id', authenticate('jwt'), async (req, res) => {
  const { file } = req.body;
  if (!fs.existsSync(process.env.STORAGE_DIR + '/' + file)) res.status(500).json({ status: 500, message: 'El archivo no existe' });
  fs.unlinkSync(process.env.STORAGE_DIR + '/' + file);
  res.status(200).json({ status: 200, message: 'Eliminado satisfactoriamente' });
});

const typeMedia = (type) => (file) =>
  switchcase({ production: `${process.env.AWS_ACCESS_URL}/${file.key}`, development: `${process.env.SERVER_URL}/${type}/${file.filename}` })(
    'No es un estado valido'
  );

export default router;
