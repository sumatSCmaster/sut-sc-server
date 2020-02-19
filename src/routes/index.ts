import { Router } from 'express';
import auth from './auth';
import tree from './tree';
import institution from './institution';
import role from './role';
import invite from './invite';
import task from './task';
import file from './file';
import permission from './permission';
import twilio from './twilio';
import notification from './notification';
import project from './project';
import { authenticate  } from 'passport';
import { isAdmin } from '@middlewares/auth';
import { endWizard } from '@helpers/user';

const router = Router();

router.use('/auth', auth);
router.use('/tree', tree);
router.use('/institution', institution);
router.use('/role', role);
router.use('/invite', invite);
router.use('/task', task);
router.use('/file', file);
router.use('/permission', permission);
router.use('/twilio', twilio);
router.use('/notification', notification);
router.use('/project', project);

router.get('/', (req, res) => {
  res.status(200).json({
    status: 200,
    message: 'Ok'
  })
});

router.put('/endWizard', authenticate('jwt'), isAdmin, async (req, res) => {
  try {
    const ended = await endWizard();
    if(ended) {
      res.status(200).json({
        status: 200,
        message: 'Wizard finalizado de manera exitosa.',
      });
    } else {
      res.status(409).json({
        status: 409,
        message: 'Wizard ya esta terminado.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

export default router;