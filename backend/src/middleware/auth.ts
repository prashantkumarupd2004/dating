import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken, verifyAdminToken } from '../utils/jwt';
import { sendUnauthorized, sendForbidden } from '../utils/response';
import { prisma } from '../config/database';

export interface AuthRequest extends Request {
  userId?: string;
  userType?: 'user' | 'listener';
}

export interface AdminRequest extends Request {
  adminId?: string;
  adminRole?: string;
}

export const authenticate = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      sendUnauthorized(res);
      return;
    }
    const token = header.slice(7);
    const payload = verifyAccessToken(token);

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true, isActive: true, isBanned: true, isSuspended: true },
    });

    if (!user || !user.isActive || user.isBanned) {
      sendForbidden(res, 'Account is inactive or banned');
      return;
    }

    req.userId = payload.userId;
    req.userType = payload.type;
    next();
  } catch {
    sendUnauthorized(res, 'Invalid or expired token');
  }
};

export const authenticateAdmin = async (
  req: AdminRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      sendUnauthorized(res);
      return;
    }
    const token = header.slice(7);
    const payload = verifyAdminToken(token);

    const admin = await prisma.adminUser.findUnique({
      where: { id: payload.adminId },
      select: { id: true, isActive: true, role: true },
    });

    if (!admin || !admin.isActive) {
      sendForbidden(res, 'Admin account is inactive');
      return;
    }

    req.adminId = admin.id;
    req.adminRole = admin.role;
    next();
  } catch {
    sendUnauthorized(res, 'Invalid or expired admin token');
  }
};

export const requireSuperAdmin = (
  req: AdminRequest,
  res: Response,
  next: NextFunction
): void => {
  if (req.adminRole !== 'SUPER_ADMIN') {
    sendForbidden(res, 'Super admin access required');
    return;
  }
  next();
};
