import { validationResult } from "express-validator";

export const checkResult = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      status: 400,
      message: "Error en datos enviados",
      error: errors.array()[0]
    });
  } else {
    next();
  }
};
