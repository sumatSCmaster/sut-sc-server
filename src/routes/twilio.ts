import { Router } from 'express';
import { twiml } from 'twilio';

const router = Router();

router.post('/webhook', (req, res) => {
  const twilioMessage = new twiml.MessagingResponse();
  twilioMessage.message('Mensaje recibido!');
  res.writeHead(200, { 'Content-Type': 'text/xml' });
  res.end(twilioMessage.toString());
});

router.post('/status/webhook', (req, res) => {
  console.log(req);
  res.status(200).json({
    status: 200,
    message: 'Ok'
  })
});

export default router;