import * as multer from 'multer';
import path from 'path';
import crypto from 'crypto';
import fs from 'fs';
import S3Client from './s3';
import multerS3 from 'multer-s3';
import switchcase from './switch';
import { mainLogger } from './logger';
// import { checkInm } from '@root/routes/file';

export const diskStorage = (type: string): multer.StorageEngine =>
  switchcase({
    development: multer.diskStorage({
      destination: (req, file, cb) => {
        const saveTo = path.join(process.env.STORAGE_DIR || '/', type);
        if (!fs.existsSync(saveTo)) fs.mkdirSync(saveTo, { recursive: true });
        cb(null, saveTo);
      },
      filename: (req: any, file, cb) => {
        mainLogger.info('file', file);
        if (type.startsWith('tramites')) {
          cb(null, `${file.originalname}`);
        } else {
          const hex = crypto.randomBytes(16);
          cb(null, 1 + hex.toString('hex') + '.png');
        }
      },
    }),
    production: multerS3({
      s3: S3Client,
      bucket: process.env.BUCKET_NAME,
      acl: 'public-read',
      key: function (req, file, cb) {
        mainLogger.info('file', file);
        if (type.startsWith('tramites') || type.startsWith('inmueble')) {
          cb(null, `${type}/${file.originalname}`);
        } else {
          const hex = crypto.randomBytes(16);
          cb(null, 1 + hex.toString('hex') + '.png');
        }
      },
    }),
  })(null)(process.env.NODE_ENV);

export const photoFilter = (req, file, cb) => {
  if (!file.originalname.match(/\.(jpg|jpeg|png|gif|xls|xlsx|pdf)$/)) {
    cb(null, false);
  }
  cb(null, true);
};

// export const estateFilter = (req, file, cb) => {
//   if (!file.originalname.match(/\.(jpg|jpeg|png|gif|xls|xlsx|pdf)$/)) {
//     cb(null, false);
//   }
//   if (JSON.parse(req.query.nuevoInmueble)) {
//     checkInm(req.params.id)
//       .then((res) => cb(null, !res))
//       .catch((err) => cb(null, false));
//     // if (res instanceof Error){
//     //   throw res
//     // }
//   }
// };
