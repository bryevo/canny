import { Router } from 'express';
import { AUTH_CREATE_ACCOUNT, AUTH_LOGIN, AUTH_LOGOUT } from '../constants';
import { createAccount, login, logout } from '../service/auth-service';

const router = Router();

router.post(AUTH_CREATE_ACCOUNT, createAccount);
router.post(AUTH_LOGIN, login);
router.get(AUTH_LOGOUT, logout);

export default router;
