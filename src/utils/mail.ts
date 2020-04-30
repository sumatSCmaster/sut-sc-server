import { createTransport } from 'nodemailer';

const transporter = createTransport({
  host: process.env.MAIL_SERVER as string,
  port: Number(process.env.MAIL_PORT),
  secure: true,
  auth: {
    user: process.env.MAIL_ADDRESS,
    pass: process.env.MAIL_PASSWORD,
  },
});


export default transporter;
