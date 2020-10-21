import { Router } from 'express';
import { authenticate } from 'passport';
import multer = require('multer');
import { diskStorage, photoFilter } from '@utils/multer';
import path from 'path';
import switchcase from '@utils/switch';
import fs from 'fs';
import Pool from '@utils/Pool';
import { errorMessageGenerator, errorMessageExtractor } from '@helpers/errors';
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
    case 'finings':
      multer({
        storage: diskStorage('tramites/' + req.params.id),
        fileFilter: photoFilter,
      }).array('boleta')(req, res, next);
      break;
    case 'inmueble':
      multer({
        storage: diskStorage('inmueble/' + req.params.id),
        fileFilter: photoFilter,
      }).single('inmueble')(req, res, next);
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
  console.log('media', media);
  const client = await pool.connect();
  try {
    if (media.length > 0 && type === 'takings') {
      const procedure = (await client.query(queries.GET_ID_FROM_PROCEDURE_STATE_BY_CODE, [id])).rows[0];
      client.query('BEGIN');
      await Promise.all(
        media.map(async (urlRecaudo) => {
          await client.query(queries.INSERT_TAKINGS_IN_PROCEDURE, [procedure.id, urlRecaudo]);
        })
      );
      client.query('COMMIT');
    }

    if (media.length > 0 && type === 'finings') {
      const fining = (await client.query(queries.GET_FINING_ID_FROM_FINING_STATE_BY_CODE, [id])).rows[0];
      client.query('BEGIN');
      await Promise.all(
        media.map(async (urlRecaudo) => {
          await client.query(queries.UPDATE_FINING_BALLOT, [urlRecaudo, fining.id]);
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
      error: errorMessageExtractor(error),
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
  } catch (e) {
    res.setHeader('ContentType', 'application/json');
    res.status(404).json({
      status: 404,
      error: errorMessageExtractor(e),
      message: 'Archivo no encontrado',
    });
  }
});

router.put('/:id', authenticate('jwt'), async (req, res) => {
  const client = await pool.connect();
  const { file, prop } = req.body;
  const { id } = req.params;
  try {
    client.query('BEGIN');
    if (!fs.existsSync(process.env.STORAGE_DIR + '/' + file)) res.status(500).json({ status: 500, message: 'El archivo no existe' });
    const procedure = (await client.query(queries.GET_PROCEDURE_BY_ID, [id])).rows[0];
    const { datos } = procedure;
    delete datos.funcionario[prop];
    await client.query('UPDATE tramite SET datos=$1 WHERE id_tramite =$2', [JSON.stringify(datos), id]);
    fs.unlinkSync(process.env.STORAGE_DIR + '/' + file);
    client.query('COMMIT');
    res.status(200).json({ status: 200, message: 'Eliminado satisfactoriamente' });
  } catch (e) {
    client.query('ROLLBACK');
    res.status(500).json({ status: 500, message: 'Error al eliminar el archivo', error: errorMessageExtractor(e) });
  } finally {
    client.release();
  }
});

const typeMedia = (type) => (file) => switchcase({ production: `${process.env.AWS_ACCESS_URL}/${file.key}`, development: `${process.env.SERVER_URL}/${type}/${file.filename}` })('No es un estado valido');

export default router;
