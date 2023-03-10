import { Router } from 'express';
import { generateToken } from '@utils/Strategies';
import { authenticate } from 'passport';
//import { createAdmin } from "@helpers/user";
import * as authValidations from '@validations/auth';
import { checkIfAdmin, checkIfSuperuser, checkIfOfficial, checkIfDirector, checkIfChief } from '@utils/user';
import { hashSync, genSaltSync } from 'bcryptjs';
import { checkResult } from '@validations/index';
import { createSuperuser, createAdmin, completeExtUserSignUp, addInstitute, signUpUser, addPermissions, isBlocked } from '@helpers/user';
import { isSuperuser, isAdmin } from '@middlewares/auth';
import { fulfill } from '@utils/resolver';
import { errorMessageGenerator, errorMessageExtractor } from '@helpers/errors';
import { forgotPassword, recoverPassword, getUserData } from '@helpers/auth';
import { mainLogger } from '@utils/logger';

const router = Router();

router.post('/login', authValidations.isLogged, authValidations.login, checkResult, isBlocked(), authenticate('local'), async (req: any, res) => {
  if (await checkIfSuperuser(req.user.cedula)) {
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso',
      token: generateToken(req.user),
      superuser: true,
      user: req.user,
    });
  } else if (await checkIfChief(req.user.cedula)) {
    req.user = await addInstitute(req.user);
    req.user = await addPermissions(req.user);
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso.',
      token: generateToken(req.user),
      user: req.user,
    });
  } else if (await checkIfAdmin(req.user.cedula)) {
    req.user = await addInstitute(req.user);
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso.',
      token: generateToken(req.user),
      user: req.user,
    });
  } else if (await checkIfOfficial(req.user.cedula)) {
    req.user = await addInstitute(req.user);
    req.user = await addPermissions(req.user);
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso.',
      token: generateToken(req.user),
      user: req.user,
    });
  } else if (await checkIfDirector(req.user.cedula)) {
    req.user = await addInstitute(req.user);
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso.',
      token: generateToken(req.user),
      user: req.user,
    });
  } else {
    res.status(200).json({
      status: 200,
      message: 'Inicio de sesion exitoso.',
      token: generateToken(req.user),
      user: req.user,
    });
  }
});

router.get('/logout', authValidations.isAuth, (req, res) => {
  req.logout();
  res.json({ status: 200, message: 'Sesi??n finalizada.' });
});

router.post('/createAdmin', authenticate('jwt'), isSuperuser, authValidations.createAdmin, checkResult, async (req, res) => {
  try {
    const salt = genSaltSync(10);
    req.body.usuario.password = hashSync(req.body.usuario.password, salt);
    const user = await createAdmin({ ...req.body.usuario }).catch((e) => {
      mainLogger.error(`Error ${e.message}`);
      res.status(500).json({
        status: 500,
        error: errorMessageExtractor(e),
        message: errorMessageGenerator(e) || e.message,
      });
    });
    if (user) {
      res.status(200).json({
        status: 200,
        message: 'Admin creado.',
        usuario: user,
      });
    }
  } catch (e: any) {
    mainLogger.error(`Error ${e.message}`);
    res.status(500).json({
      status: 500,
      error: errorMessageExtractor(e),
      message: errorMessageGenerator(e) || 'Error en la creaci??n de un administrador',
    });
  }
});

router.post('/createSuperuser', authValidations.createSuperuser, checkResult, async (req, res) => {
  if (req.body.password === process.env.SUPERUSER_CREATION_PASSWORD) {
    try {
      const salt = genSaltSync(10);
      req.body.usuario.password = hashSync(req.body.usuario.password, salt);
      const user = await createSuperuser({ ...req.body.usuario }).catch((e) => {
        res.status(500).json({
          status: 500,
          error: errorMessageExtractor(e),
          message: errorMessageGenerator(e) || 'La creaci??n del superusuario fall??',
        });
      });
      if (user) {
        res.status(200).json({
          status: 200,
          message: 'Superuser creado.',
          user,
        });
      }
    } catch (e) {
      res.status(500).json({
        status: 500,
        error: errorMessageExtractor(e),
        message: errorMessageGenerator(e) || 'La creaci??n del superusuario fall??',
      });
    }
  } else {
    res.status(401).json({
      status: 401,
      message: 'Clave de creacion de superuser invalida',
    });
  }
});

router.get(
  '/google',
  authenticate('google', {
    scope: ['openid', 'profile', 'email'],
  })
);

router.get(
  '/google/callback',
  authenticate('google', {
    session: false,
    failureRedirect: `${process.env.CLIENT_URL}/ingresar`,
  }),
  async (req: any, res) => {
    const token = generateToken(req.user);
    if (req.user!['cedula']) {
      res.redirect(`${process.env.CLIENT_URL}/auth/${token}`);
    } else {
      res.redirect(`${process.env.CLIENT_URL}/registro?name=${req.user.nombreCompleto}&oauth=${req.user.nombreUsuario}&token=${token}`);
    }
  }
);

router.get('/facebook', authenticate('facebook'));

router.get(
  '/facebook/callback',
  authenticate('facebook', {
    session: false,
    failureRedirect: `${process.env.CLIENT_URL}/ingresar`,
  }),
  async (req: any, res) => {
    const token = generateToken(req.user);
    if (req.user!['cedula']) {
      res.redirect(`${process.env.CLIENT_URL}/auth/${token}`);
    } else {
      res.redirect(`${process.env.CLIENT_URL}/registro?name=${req.user.nombreCompleto}&token=${token}`);
    }
  }
);

router.post('/complete', authenticate('jwt'), async (req: any, res) => {
  const { user } = req.body;
  const { id } = req.user;
  const salt = genSaltSync(10);
  user.password = hashSync(user.password, salt);
  const [error, data] = await fulfill(completeExtUserSignUp(user, id));
  if (error) res.status(error.status).json(error);
  if (data) res.status(data.status).json(data);
});

router.get('/user', authenticate('jwt'), async (req: any, res) => {
  const user = await getUserData(req.user.id, req.user.tipoUsuario);
  res.status(200).json({ user, status: 200, message: 'Usuario obtenido' });
});

router.post('/signup', async (req: any, res) => {
  const { user } = req.body;
  const salt = genSaltSync(10);
  user.password = hashSync(user.password, salt);
  const [error, data] = await fulfill(signUpUser(user));
  if (error) res.status(error.status).json(error);
  if (data) {
    req.logIn(data.user, { session: false }, (error) => {
      if (error) {
        res.status(500).send({
          message: 'Error al iniciar sesion del usuario',
          error,
        });
      }
      res.status(data.status).json(data);
    });
  }
});

router.post('/forgotPassword', async (req, res) => {
  const { email } = req.body;
  const [error, result] = await fulfill(forgotPassword(email));
  if (error) res.status(error.status).json(error);
  if (result) res.status(result.status).json(result);
});

router.patch('/recoverPassword', async (req, res) => {
  const { password, recvId } = req.body;
  const [error, result] = await fulfill(recoverPassword(recvId, password));
  if (error) res.status(error.status).json(error);
  if (result) res.status(result.status).json(result);
});

export default router;
