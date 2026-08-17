import { prisma } from '../../config/database';
import bcrypt from 'bcrypt';
import { AppError } from '../../middleware/errorHandler';
import { signAdminToken } from '../../utils/jwt';

export const adminLogin = async (email: string, password: string) => {
  console.log('[ADMIN LOGIN] Attempt:', email);
  const admin = await prisma.adminUser.findUnique({ where: { email } });
  console.log('[ADMIN LOGIN] Admin found:', !!admin, 'isActive:', admin?.isActive);
  if (!admin || !admin.isActive) throw new AppError(401, 'Invalid credentials');

  const valid = await bcrypt.compare(password, admin.password);
  console.log('[ADMIN LOGIN] Password valid:', valid);
  if (!valid) throw new AppError(401, 'Invalid credentials');

  await prisma.adminUser.update({
    where: { id: admin.id },
    data: { lastLoginAt: new Date() },
  });

  const token = signAdminToken({ adminId: admin.id, role: admin.role });
  console.log('[ADMIN LOGIN] Success for:', admin.email);
  return { token, admin: { id: admin.id, name: admin.name, email: admin.email, role: admin.role } };
};
