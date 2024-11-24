import express, { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import bodyParser from 'body-parser';
import cors from 'cors';
import jwt, { JwtPayload } from 'jsonwebtoken';
// import nodemailer from 'nodemailer';
// import otpGenerator from 'otp-generator';
import plaidClient from './client/plaid';
import {
  AccountBase,
  AccountsGetResponse,
  CountryCode,
  LinkTokenCreateRequest,
  Products,
} from 'plaid';
import supabase from './client/supabase';
import verifyOrRefreshJWT from './middleware/verifyJWT';
import { AxiosResponse } from 'axios';

// Initialize Express app
const app = express();

// Middleware
app.use(express.json());
app.use(cors());
app.use(bodyParser.json());

// Define a simple in-memory database for demonstration purposes
interface User {
  id?: string;
  full_name: string;
  email: string;
  phone_number: string;
  password: string;
}
interface Plaid {
  id?: string;
  user_id: string;
  access_token: string;
}

export const SECRET_KEY = 'canny-secret-key';

/******************************** API Endpoints /********************************/

// Endpoint 1: Create account
app.post('/create-account', async (req: Request, res: Response) => {
  try {
    const { fullName, email, phoneNumber, password } = req.body;

    // Validate input
    if (!fullName || !email || !phoneNumber || !password) {
      res.status(400).send('All fields are required');
      return console.log('All fields are required');
    }

    // Check if user already exists by email
    const { data: existingUser, error: findError } = await supabase
      .from('auth')
      .select('id')
      .eq('email', email)
      .single(); // `.single()` ensures we only get one result

    if (findError && findError.code !== 'PGRST116') {
      // Ignore the "no result found" error, otherwise throw error
      throw findError;
    }

    if (existingUser) {
      const errorMessage = 'User already exists';
      console.log(errorMessage);
      res.status(400).send(errorMessage);
      return;
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const newUser: User = {
      full_name: fullName,
      email,
      phone_number: phoneNumber,
      password: hashedPassword,
    };

    const { data, error } = await supabase
      .from('auth') // Assuming your table is named 'users'
      .insert([newUser]);

    if (error) {
      // Check if it's a unique violation error
      if (error.code === '23505') {
        // 23505 is the Postgres unique violation code
        return console.log('User with this email already exists');
      }
      throw error;
    }
    const successMessage = 'Account created successfully';
    console.log(`${successMessage}: ${data}`);
    res.send(successMessage);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to create link token' });
  }
});

// Endpoint 2: Login
app.post('/login', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    // Validate input
    if (!email || !password) {
      const errorMessage = 'All fields are required';
      console.log(errorMessage);
      res.status(401).send(errorMessage);
      return;
    }
    // Find user by email
    const { data, error } = await supabase
      .from('auth')
      .select('id, email, password')
      .eq('email', email)
      .single();
    if (error) {
      const errorMessage = 'Unable to find account';
      console.log(errorMessage);
      res.status(401).send(errorMessage);
      return;
    }
    const { id, password: pw } = data;

    // Compare passwords
    const isValidPassword = await bcrypt.compare(password, pw);
    if (!isValidPassword) {
      const errorMessage = 'Invalid email or password';
      console.log(errorMessage);
      res.status(401).send(errorMessage);
      return;
    }
    const deviceId = req.headers['device-id'];
    const deviceName = req.headers['device-name'];
    const deviceModel = req.headers['device-model'];
    // Find user by email
    const { data: cachedRefreshToken, error: refreshTokenError } = await supabase
      .from('refresh_token')
      .select('refresh_token, device_id, device_name')
      .eq('user_id', id);
    if (refreshTokenError) {
      throw refreshTokenError;
    }
    let refreshToken;
    // new user -- good
    if (cachedRefreshToken.length === 0) {
      // insert refresh_token
      // Generate JWT token
      refreshToken = jwt.sign({ userId: id, deviceId: deviceId }, SECRET_KEY, {
        expiresIn: '90d',
      });
      const { error: insertError } = await supabase
        .from('refresh_token') // Assuming your table is named 'users'
        .insert([
          {
            user_id: id,
            refresh_token: refreshToken,
            device_id: deviceId,
            device_name: `${deviceName} - ${deviceModel}`,
          },
        ]);
      if (insertError) {
        throw insertError;
      }
    } else {
      const refreshTokenObj = cachedRefreshToken.find(
        (r) => r.device_id === (deviceId as string).toLowerCase(),
      );
      // same device -- good
      if (refreshTokenObj) {
        refreshToken = refreshTokenObj.refresh_token;
      } else {
        // might be bad - flag sus
      }
    }
    // Generate JWT token
    const token = jwt.sign({ userId: id, deviceId: deviceId }, SECRET_KEY, {
      expiresIn: '1h',
    });
    console.log('Login Successful');
    res.send({ id, token, refreshToken });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to login' });
  }
});

// Endpoint 3: Logout
app.post('/logout', async (req: Request, res: Response) => {
  try {
    const jwtToken = req.headers['canny-access-token'] as string;
    const { userId, deviceId } = jwt.decode(jwtToken) as JwtPayload;

    const { error } = await supabase
      .from('refresh_token')
      .delete({ count: 'exact' })
      .eq('user_id', userId)
      .eq('device_id', deviceId);
    if (error) {
      throw error;
    }
    console.log('Logout Successful');
    res.send();
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to login' });
  }
});

// // Endpoint 3: Forgot password
// app.post('/forgot-password', async (req: Request, res: Response) => {
//   const { email } = req.body;

//   // Validate input
//   if (!email) {
//     return res.status(400).send('Email is required');
//   }

//   // Find user by email
//   const user = users.find((user) => user.email === email);
//   if (!user) {
//     return res.status(404).send('User not found');
//   }

//   // Generate OTP
//   const otp = otpGenerator.generate(6, {
//     upperCase: false,
//     specialChars: false,
//   });

//   // Update user OTP
//   user.otp = otp;

//   // Send OTP via email
//   const transporter = nodemailer.createTransport({
//     host: 'smtp.gmail.com',
//     port: 587,
//     secure: false, // or 'STARTTLS'
//     auth: {
//       user: 'your-email@gmail.com',
//       pass: 'your-password',
//     },
//   });

//   const mailOptions = {
//     from: 'your-email@gmail.com',
//     to: email,
//     subject: 'Reset Password OTP',
//     text: `Your OTP is: ${otp}`,
//   };

//   transporter.sendMail(mailOptions, (error) => {
//     if (error) {
//       return res.status(500).send('Error sending OTP');
//     }

//     res.send('OTP sent successfully');
//   });
// });

// // Endpoint 4: Reset password
// app.post('/reset-password', async (req: Request, res: Response) => {
//   const { email, otp, newPassword } = req.body;

//   // Validate input
//   if (!email || !otp || !newPassword) {
//     return res.status(400).send('All fields are required');
//   }

//   // Find user by email
//   const user = users.find((user) => user.email === email);
//   if (!user) {
//     return res.status(404).send('User not found');
//   }

//   // Check OTP
//   if (user.otp !== otp) {
//     return res.status(401).send('Invalid OTP');
//   }

//   // Hash new password
//   const hashedPassword = await bcrypt.hash(newPassword, 10);

//   // Update user password
//   user.password = hashedPassword;
//   user.otp = '';

//   res.send('Password reset successfully');
// });

// // Endpoint 5: Login with OTP
// app.post('/login-with-otp', async (req: Request, res: Response) => {
//   const { phoneNumber, otp } = req.body;

//   // Validate input
//   if (!phoneNumber || !otp) {
//     return res.status(400).send('All fields are required');
//   }

//   // Find user by phone number
//   const user = users.find((user) => user.phoneNumber === phoneNumber);
//   if (!user) {
//     return res.status(404).send('User not found');
//   }

//   // Check OTP
//   if (user.otp !== otp) {
//     return res.status(401).send('Invalid OTP');
//   }

//   // Generate JWT token
//   const token = jwt.sign({ userId: user.id }, 'secret-key', {
//     expiresIn: '1h',
//   });

//   res.send({ token });
// });

app.post('/get-link-token', verifyOrRefreshJWT, async (req: Request, res: Response) => {
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
});

app.get('/exchange-public-for-access-token', verifyOrRefreshJWT, async (req, res) => {
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
});

app.get('/get-access-tokens', verifyOrRefreshJWT, async (req, res) => {
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
});

app.post('/get-account-summaries', verifyOrRefreshJWT, async (req, res) => {
  try {
    const accessTokens: string[] = req.body;
    // get info from each access_token
    const accountGetPromises: Promise<AxiosResponse<AccountsGetResponse>>[] = [];
    accessTokens.forEach((access_token) => {
      accountGetPromises.push(plaidClient.accountsGet({ access_token }));
    });
    const responses = await Promise.all(accountGetPromises);
    const accounts: { [key: string]: AccountBase } = {};
    responses.forEach((response) => {
      response.data.accounts.forEach((account) => {
        accounts[account.account_id] = account;
      });
    });
    console.log(accounts);
    res.status(200).send(accounts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Unable to fetch account summary' });
  }
});

// Plaid OAuth Redirect Handler
app.get('/oauth-redirect', (req: Request, res: Response) => {
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
});

// Start server
const port = 3000;
app.listen(port, () => {
  console.log(`Server started on port ${port}`);
});
