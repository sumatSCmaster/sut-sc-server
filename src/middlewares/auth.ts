export const isAdmin = async (req, res, next) => {
  if (req.user.admin) {
    next();
  } else {
    res.status(401).json({
      status: 401,
      message: "Forbidden. Can only be accesed by admin."
    });
  }
};
