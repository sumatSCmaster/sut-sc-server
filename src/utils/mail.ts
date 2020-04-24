import { createTransport } from 'nodemailer';

const transporter = createTransport({
  pool: true,
  host: 'smtp.ethereal.email',
  port: 587,
  auth: {
    user: 'marcia22@ethereal.email',
    pass: 'ymY3GE7ZMkbYM4nDdP',
  },
});

export default transporter;
