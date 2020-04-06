export const isAdmin = async (req, res, next) => {
  if (req.user.tipoUsuario === 2) {
    next();
  } else {
    res.status(401).json({
      status: 401,
      message: 'Esta operacion solo puede ser realizada por un funcionario administrador',
    });
  }
};

export const isSuperuser = async (req, res, next) => {
  if (req.user.tipoUsuario === 1) {
    next();
  } else {
    res.status(401).json({
      status: 401,
      message: 'Esta operacion solo puede ser realizada por un superusuario',
    });
  }
};
