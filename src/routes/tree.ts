import { Router } from 'express';
import { authenticate } from 'passport';
import { getTree, updateTree, getChildren, getChildrenUsers } from '@helpers/tree';
import { isAdmin } from '@middlewares/auth';
import * as treeValidations from '@validations/tree';
import { checkResult } from '@validations/index';

const router = Router();

router.get('/', authenticate('jwt'), async (req, res) => {
  try {
    const tree = await getTree();
    res.status(200).json({
      status: 200,
      message: 'Arbol retornado exitosamente.',
      tree
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.put('/', authenticate('jwt'), treeValidations.updateTree, checkResult, isAdmin, async (req, res) => {
  try {
    const tree = await updateTree(req.body.flat, req.body.tree);  
    res.status(200).json({ 
      status: 200,
      message: 'Arbol actualizado exitosamente.',
      tree 
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/children', authenticate('jwt'), async (req: any, res) => {
  try {
    const children = await getChildren(parseInt(req.user.left), parseInt(req.user.right));
    res.status(200).json({
      status: 200,
      message: 'Hijos retornados exitosamente.',
      children
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

router.get('/children/user', authenticate('jwt'), async (req: any, res) => {
  try {
    const users = await getChildrenUsers(parseInt(req.user.left), parseInt(req.user.right));
    res.status(200).json({
      status: 200,
      message: 'Usuarios retornados exitosamente',
      users
    });
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  }
});

export default router;