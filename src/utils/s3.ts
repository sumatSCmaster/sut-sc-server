import S3 from 'aws-sdk/clients/s3';

const s3Client = new S3({
  accessKeyId: process.env.AWS_ACCESS_KEY,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
});

export default s3Client;
