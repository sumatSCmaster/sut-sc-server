import { Request } from "express"

export const apiCheckMiddleware = async (req: Request, res, next) => {
  if(req.headers['x-sut-api-key'] === undefined){
    return res.status(400).json({error: "Error de parámetros"});
  }
  next();
} 