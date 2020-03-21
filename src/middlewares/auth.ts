export const isAdmin = async (req, res, next) => {
  if (req.user.tipoUsuario === 2) {
    next();
  } else {
    res.status(401).json({
      status: 401,
      message: 'Forbidden. Can only be accesed by admin.',
    });
  }
};

export const isSuperuser = async (req, res, next) => {
  if (req.user.tipoUsuario === 1) {
    next();
  } else {
    res.status(401).json({
      status: 401,
      message: 'Forbidden. Can only be accesed by superuser.',
    });
  }
};
