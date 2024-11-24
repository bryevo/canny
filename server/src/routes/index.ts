import { Router } from 'express';
import { AUTH_API, PLAID_API } from './constants';
import authController from './controller/auth-controller';
import plaidController from './controller/plaid-controller';

const routes = Router();

routes.use(AUTH_API, authController);
routes.use(PLAID_API, plaidController);

export default routes;
