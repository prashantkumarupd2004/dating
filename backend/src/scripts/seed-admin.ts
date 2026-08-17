import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const email = 'admin@milan.app';
  const password = 'Admin@123';

  const existing = await prisma.adminUser.findUnique({ where: { email } });
  if (existing) {
    console.log('Admin already exists:', email);
    return;
  }

  const hash = await bcrypt.hash(password, 10);
  const admin = await prisma.adminUser.create({
    data: {
      email,
      password: hash,
      name: 'Super Admin',
      role: 'SUPER_ADMIN',
      isActive: true,
    },
  });

  console.log('Admin created:', admin.email);
  console.log('Password: Admin@123');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
