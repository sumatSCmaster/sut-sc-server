import * as multer from 'multer';
import path from 'path';
import crypto from 'crypto';
import fs from 'fs';
import S3Client from './s3';
import multerS3 from 'multer-s3';
import switchcase from './switch';

export const diskStorage = (type: string): multer.StorageEngine =>
  switchcase({
    development: multer.diskStorage({
      destination: (req, file, cb) => {
        const saveTo = path.join(process.env.STORAGE_DIR || '/', type);
        if (!fs.existsSync(saveTo)) fs.mkdirSync(saveTo);
        cb(null, saveTo);
      },
      filename: (req: any, file, cb) => {
        const hex = crypto.randomBytes(16);
        cb(null, 1 + hex.toString('hex') + '.png');
      },
    }),
    production: multerS3({
      s3: S3Client,
      bucket: 'sut-maracaibo',
      acl: 'public-read',
      key: function(req, file, cb) {
        const hex = crypto.randomBytes(16);
        cb(null, `${type}/1${hex.toString('hex')}.png`);
      },
    }),
  })(null)(process.env.NODE_ENV);

export const photoFilter = (req, file, cb) => {
  if (!file.originalname.match(/\.(jpg|jpeg|png|gif)$/)) {
    req.res.status(409).json({
      status: 409,
      message: 'File must be photo',
    });
  }
  cb(null, true);
};
