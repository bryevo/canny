import { Request, Response } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import {
  AccountBase,
  AccountsGetResponse,
  CountryCode,
  LinkTokenCreateRequest,
  Products,
} from 'plaid';
import { AxiosResponse } from 'axios';
import plaidClient from '../../client/plaid';
import supabase from '../../client/supabase';

interface Plaid {
  id?: string;
  user_id: string;
  access_token: string;
}

export const getLinkToken = async (req: Request, res: Response) => {
  try {
    const { id, email } = req.body;
    console.log(id, email);
    const request: LinkTokenCreateRequest = {
      user: {
        client_user_id: id,
      },
      client_name: 'canny',
      language: 'en',
      country_codes: [CountryCode.Us],
      products: [Products.Transactions],
      redirect_uri: 'http://localhost:3000/oauth-redirect',
    };
    console.log('Making request to plaid');
    const response = await plaidClient.linkTokenCreate(request);
    res.status(200).send(response.data.link_token);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to create link token' });
  }
};

export const exchangePublicTokenForAccessToken = async (req: Request, res: Response) => {
  try {
    const publicToken = req.headers['plaid-public-token'] as string;
    if (!publicToken) {
      throw new Error('Unable to find public token');
    }
    const response = await plaidClient.itemPublicTokenExchange({
      public_token: publicToken,
    });
    const jwtToken = req.headers['canny-access-token'] as string;
    const jwtTokenPayload = jwt.decode(jwtToken) as JwtPayload;

    const plaidUserToken: Plaid = {
      user_id: jwtTokenPayload.userId,
      access_token: response.data.access_token,
    };
    // Create userToPlaid
    const { error } = await supabase
      .from('plaid') // Assuming your table is named 'users'
      .insert([plaidUserToken]);
    if (error) {
      throw error;
    }
    const successMessage = 'Updated plaid db successfully';
    console.log(`${successMessage}`);
    res.status(200).send(response.data.access_token);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to exchange public token for access token' });
  }
};

export const getAccessTokens = async (req: Request, res: Response) => {
  try {
    const jwtToken = req.headers['canny-access-token'] as string;
    const { userId } = jwt.decode(jwtToken) as JwtPayload;
    const { data, error } = await supabase
      .from('plaid')
      .select('access_token')
      .eq('user_id', userId);
    if (error) {
      throw error;
    }
    res.status(200).send(data.map((o) => o.access_token));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Unable to fetch account summary' });
  }
};

export const getAccountSummary = async (req: Request, res: Response) => {
  try {
    const accessTokens: string[] = req.body;
    // get info from each access_token
    const accountGetPromises: Promise<AxiosResponse<AccountsGetResponse>>[] = [];
    accessTokens.forEach((access_token) => {
      accountGetPromises.push(plaidClient.accountsGet({ access_token }));
    });
    const responses = await Promise.all(accountGetPromises);
    const accounts: { [key: string]: AccountBase[] } = {};
    responses.forEach((response) => {
      response.data.accounts.forEach((account) => {
        if (!accounts[account.type]) {
          accounts[account.type] = [];
        }
        accounts[account.type].push(account);
      });
    });
    res.status(200).send(accounts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Unable to fetch account summary' });
  }
};

// Plaid OAuth Redirect Handler
export const oauthRedirect = (req: Request, res: Response) => {
  const { oauth_state_id, public_token } = req.query;
  // Handle the OAuth state and public token here
  console.log('OAuth State ID:', oauth_state_id);
  console.log('Public Token:', public_token);

  if (public_token) {
    // Exchange public token for access token
    // This would use Plaid's SDK or API to exchange the token
    res.status(200).send(`OAuth completed successfully. Public Token: ${public_token}`);
  } else {
    res.status(400).send('OAuth failed. Missing public token.');
  }
};
