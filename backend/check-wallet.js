const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkWallet() {
  try {
    // Find user by email
    const user = await prisma.user.findUnique({
      where: { email: 'prashantkrupd5999@gmail.com' },
      include: { wallet: true }
    });

    if (!user) {
      console.log('❌ User not found in database');
      return;
    }

    console.log('✅ User found:');
    console.log('  ID:', user.id);
    console.log('  Name:', user.name);
    console.log('  Email:', user.email);
    console.log('  Role:', user.role);

    if (user.wallet) {
      console.log('\n✅ Wallet exists:');
      console.log('  Wallet ID:', user.wallet.id);
      console.log('  Balance:', user.wallet.balance);
      console.log('  Created:', user.wallet.createdAt);
    } else {
      console.log('\n❌ Wallet NOT FOUND - This is the problem!');
      console.log('   Creating wallet with welcome bonus...');

      const wallet = await prisma.wallet.create({
        data: {
          userId: user.id,
          balance: 1000
        }
      });

      console.log('✅ Wallet created with 1000 coins');
      console.log('  Wallet ID:', wallet.id);
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkWallet();
