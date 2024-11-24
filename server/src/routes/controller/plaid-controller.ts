import { Router } from 'express';
import {
  PLAID_EXCHANGE_TOKEN,
  PLAID_GET_ACCESS_TOKENS,
  PLAID_GET_ACCOUNT_SUMMARY,
  PLAID_GET_LINK_TOKEN,
  PLAID_OAUTH_REDIRECT,
} from '../constants';
import {
  exchangePublicTokenForAccessToken,
  getAccessTokens,
  getAccountSummary,
  getLinkToken,
  oauthRedirect,
} from '../service/plaid-service';
import verifyOrRefreshJWT from '../../middleware/verifyJWT';

const router = Router();

router.post(PLAID_GET_LINK_TOKEN, verifyOrRefreshJWT, getLinkToken);
router.get(PLAID_EXCHANGE_TOKEN, verifyOrRefreshJWT, exchangePublicTokenForAccessToken);
router.get(PLAID_GET_ACCESS_TOKENS, verifyOrRefreshJWT, getAccessTokens);
router.post(PLAID_GET_ACCOUNT_SUMMARY, verifyOrRefreshJWT, getAccountSummary);
router.get(PLAID_OAUTH_REDIRECT, oauthRedirect);

export default router;
