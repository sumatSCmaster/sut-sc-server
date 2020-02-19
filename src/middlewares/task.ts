import Pool from "@utils/Pool";
import queries from "@utils/queries";

const pool = Pool.getInstance();

export const hasTaskPermission = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.HAS_PERMISSION, [req.user.id, 1]);
    if(result.rowCount > 0) {
      next();
    } else {
      res.status(403).json({
        status: 403,
        message: 'Forbidden. You don\'t have permissions to assign tasks.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};

export const isUnderInTree = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.IS_UNDER_IN_TREE, [req.user.id, req.body.tarea.responsable]);
    if(result.rows[0].is_under) {
      next();
    } else {
      res.status(403).json({
        status: 403,
        message: 'Forbidden. The user assigned is not under you in the hierarchical tree.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};

export const isTaskSender = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_TASK_BY_ID, [req.params.id]);
    if(result.rowCount > 0) {
      if(result.rows[0].emisor === req.user.id) {
        next();
      } else {
        res.status(403).json({
          status: 403,
          message: 'Forbidden. You are not the user that assigned the task.'
        });
      }
    } else {
      res.status(404).json({
        status: 404,
        message: `Task with id ${req.params.id} not found.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};

export const isTaskReceiverOrSender = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.GET_TASK_BY_ID, [req.params.id]);
    if(result.rowCount > 0) {
      if(result.rows[0].responsable === req.user.id || result.rows[0].emisor === req.user.id) {
        next();
      } else {
        res.status(403).json({
          status: 403,
          message: 'Forbidden. You are not the user that is assigned to this task.'
        });
      }
    } else {
      res.status(404).json({
        status: 404,
        message: `Task with id ${req.params.id} not found.`
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};

export const canComment = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CAN_COMMENT, [req.user.id, req.params.id]);
    if(result.rowCount > 0) {
      next();
    } else {
      res.status(403).json({
        status: 403,
        message: 'Forbidden. You cannot comment in this task.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};

export const isCommentOwner = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.CAN_EDIT_COMMENT, [req.params.id, req.user.id]);
    if(result.rowCount > 0) {
      next();
    } else {
      res.status(403).json({
        status: 403,
        message: 'Forbidden. You cannot edit this comment.'
      });
    }
  } catch(e) {
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};