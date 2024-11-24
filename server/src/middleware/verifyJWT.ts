import { Request, Response, NextFunction } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import { SECRET_KEY } from '..';

const verifyOrRefreshJWT = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const jwtToken = req.headers['canny-access-token'] as string;
    const refreshToken = req.headers['canny-refresh-token'] as string;
    if (!jwtToken || !refreshToken) {
      res.status(401).send('Unable to find canny jwt token');
      return;
    }
    try {
      jwt.verify(jwtToken, SECRET_KEY);

      try {
        jwt.verify(refreshToken, SECRET_KEY);
        // good
        next();
      } catch {
        res.status(401).send('Refresh token expired');
        return;
      }
    } catch {
      try {
        const refreshPayload = jwt.verify(refreshToken, SECRET_KEY) as JwtPayload;
        // refresh jwt
        const updatedToken = jwt.sign({ userId: refreshPayload.userId }, SECRET_KEY, {
          expiresIn: '1h',
        });
        res.setHeader('canny-access-token', updatedToken);
        next();
      } catch {
        res.status(401).send('JWT and Refresh token expired');
      }
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to verify canny jwt token' });
  }
};
export default verifyOrRefreshJWT;
