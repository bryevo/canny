import bcrypt from 'bcrypt';
import { Request, Response } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import { SECRET_KEY } from '../..';
import supabase from '../../client/supabase';

interface User {
  id?: string;
  full_name: string;
  email: string;
  phone_number: string;
  password: string;
}

export const createAccount = async (req: Request, res: Response) => {
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
};

// Endpoint 2: Login
export const login = async (req: Request, res: Response) => {
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
};

// Endpoint 3: Logout
export const logout = async (req: Request, res: Response) => {
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
};

// // Endpoint 3: Forgot password
// const forgotPassword = '/forgot-password', async (req: Request, res: Response) => {
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
// const resetPassword = '/reset-password', async (req: Request, res: Response) => {
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
// const loginOTP = '/login-with-otp', async (req: Request, res: Response) => {
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
