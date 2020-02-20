import { Router } from "express";
import {
  getOfficialsByInstitution,
  createOfficial,
  updateOfficial,
  deleteOfficial
} from "@helpers/officials";
import { fulfill } from "@utils/resolver";

const router = Router();

export default router;
