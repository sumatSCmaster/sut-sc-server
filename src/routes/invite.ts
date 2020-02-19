import { Router } from 'express';
import { authenticate } from 'passport';
import { isAdmin } from '@middlewares/auth';
import { hashSync, genSaltSync } from 'bcryptjs';
import { getInvites, createInvite, deleteInvite, acceptInvite, checkToken, resendInvitation } from '@helpers/invite';
import * as inviteValidations from '@validations/invite';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/', authenticate('jwt'), isAdmin, async (req, res) => {
  try {
    const invitations = await getInvites();
    res.status(200).json({
      status: 200,
      message: 'Invitaciones retornadas exitosamente.',
      invitations
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/', authenticate('jwt'), inviteValidations.createInvitation, checkResult, isAdmin, async (req, res) => {
  try {
    const invitation = await createInvite(req.body.usuario);
    if(invitation) {
      res.status(200).json({
        status: 200,
        message: 'Invitacion enviada exitosamente.',
        invitation
      });
    } else {
      res.status(409).json({
        status: 409,
        message: `Ya existe una invitacion para el correo ${req.body.usuario.correo} o para el usuario con la cedula ${req.body.usuario.cedula}.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.patch('/:id/resend', authenticate('jwt'), inviteValidations.idExists, checkResult, isAdmin, async (req: any, res) => {
  try {
    const sent = await resendInvitation(parseInt(req.params.id));
    if(sent) {
      res.status(200).json({
        status: 200,
        message: 'Invitacion reenviada exitosamente',
        sent
      });
    } else {
      res.status(404).json({
        status: 404,
        message: 'Invitacion no existe',
        sent
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.delete('/:id', authenticate('jwt'), inviteValidations.idExists, checkResult, isAdmin, async (req: any, res) => {
  try {
    const id = await deleteInvite(parseInt(req.params.id));
    if(id) {
      res.status(200).json({
        status: 200,
        message: `Invitacion eliminada con el id ${id}`
      });
    } else {
      res.status(404).json({
        status: 404,
        message: `Invitacion con id ${req.params.id} no encontrada.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.post('/:id/accept', inviteValidations.acceptInvitation, checkResult, async (req: any, res) => {
  try {
    const salt = genSaltSync(10);
    req.body.usuario.password = hashSync(req.body.usuario.password, salt);
    const id = await acceptInvite(parseInt(req.params.id), req.body.usuario);
    if(id) {
      res.status(200).json({
        status: 200,
        message: 'Usuario registrado de manera exitosa.',
        id
      });
    } else {
      res.status(401).json({
        status: 401,
        message: 'Codigo de autenticacion invalido o expirado. Por favor intente de nuevo.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/:id/check', inviteValidations.redirect, checkResult, async (req: any, res) => {
  try {
    const isValid = await checkToken(parseInt(req.params.id), req.query.token);
    if(isValid) {
      res.redirect(`${process.env.CLIENT_URL}/registro?token=${req.query.token}&id=${req.params.id}`);
    } else {
      res.redirect(`${process.env.CLIENT_URL}/tokenInvalido`);
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

export default router;