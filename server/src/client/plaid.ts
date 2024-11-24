import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import { PLAID_CLIENT_ID, PLAID_CLIENT_SECRET } from '../config/env';

// Create configuration object for Plaid API
const configuration = new Configuration({
  basePath: PlaidEnvironments.sandbox, // Use sandbox; switch to production when ready
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': PLAID_CLIENT_ID,
      'PLAID-SECRET': PLAID_CLIENT_SECRET,
    },
  },
});

// Create a singleton instance of PlaidApi
const plaidClient = new PlaidApi(configuration);

// Export the singleton instance of plaidClient
export default plaidClient;
