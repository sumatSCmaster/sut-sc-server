import { Request } from "express"
import { mainLogger } from "@utils/logger";
import { inspect } from 'util';

export const apiCheckMiddleware = async (req: Request, res, next) => {
  mainLogger.info(inspect(req.body, true, 2, true))
  mainLogger.info(inspect(req.headers, true, 2, true));
  if(req.headers['x-sut-api-key'] === undefined){
    return res.status(401).json({error: "No Autorizado"});
  }
  next();
} 