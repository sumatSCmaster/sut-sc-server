import Pool from '@utils/Pool';
import queries from '@utils/queries';

const pool = Pool.getInstance();

export const hasProjectPermission = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const result = await client.query(queries.HAS_PERMISSION, [req.user.id, 4]);
    if(result.rowCount > 0) {
      next();
    } else {
      res.status(403).json({
        status: 403,
        message: 'Forbidden. You don\'t have permissions to create projects.'
      });
    }
  } catch(e) {
    console.log(e)
    res.status(500).json({
      status: 500,
      error: e
    });
  } finally {
    client.release();
  }
};