import jwt, { SignOptions } from 'jsonwebtoken';
import { config } from '../config';

export interface JwtPayload {
  userId: string;
  type: 'user' | 'listener';
  iat?: number;
  exp?: number;
}

export interface AdminJwtPayload {
  adminId: string;
  role: string;
  iat?: number;
  exp?: number;
}

export const signAccessToken = (payload: JwtPayload): string =>
  jwt.sign(payload, config.jwt.accessSecret, {
    expiresIn: config.jwt.accessExpiresIn,
  } as SignOptions);

export const signRefreshToken = (payload: Omit<JwtPayload, 'type'>): string =>
  jwt.sign(payload, config.jwt.refreshSecret, {
    expiresIn: config.jwt.refreshExpiresIn,
  } as SignOptions);

export const signAdminToken = (payload: AdminJwtPayload): string =>
  jwt.sign(payload, config.jwt.accessSecret, { expiresIn: '8h' } as SignOptions);

export const verifyAccessToken = (token: string): JwtPayload =>
  jwt.verify(token, config.jwt.accessSecret) as JwtPayload;

export const verifyRefreshToken = (token: string): Omit<JwtPayload, 'type'> =>
  jwt.verify(token, config.jwt.refreshSecret) as Omit<JwtPayload, 'type'>;

export const verifyAdminToken = (token: string): AdminJwtPayload =>
  jwt.verify(token, config.jwt.accessSecret) as AdminJwtPayload;
