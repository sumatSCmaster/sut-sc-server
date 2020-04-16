import { Router } from 'express';
import { validate, isOfficial, isExternalUser, isAuth } from '@validations/auth';
import { checkResult } from '@validations/index';
import { authenticate } from 'passport';

import { fulfill } from '@utils/resolver';

const router = Router();

export default router;
