const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function listAllUsers() {
  try {
    const users = await prisma.user.findMany({
      include: { wallet: true },
      orderBy: { createdAt: 'desc' },
      take: 10
    });

    console.log(`Found ${users.length} users in database:\n`);

    users.forEach((user, i) => {
      console.log(`${i + 1}. ${user.name || 'No name'}`);
      console.log(`   Email: ${user.email}`);
      console.log(`   Role: ${user.role}`);
      console.log(`   Wallet Balance: ${user.wallet?.balance ?? 'NO WALLET'}`);
      console.log(`   Created: ${user.createdAt}`);
      console.log('');
    });

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

listAllUsers();
