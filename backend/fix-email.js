const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function fixEmail() {
  try {
    // Find user by name
    const user = await prisma.user.findFirst({
      where: { name: 'prashantkrupd5999' }
    });

    if (!user) {
      console.log('❌ User not found');
      return;
    }

    console.log('Found user:', user.id, user.name);

    // Update email
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { email: 'prashantkrupd5999@gmail.com' },
      include: { wallet: true }
    });

    console.log('\n✅ Email updated successfully');
    console.log('  User ID:', updated.id);
    console.log('  Name:', updated.name);
    console.log('  Email:', updated.email);
    console.log('  Balance:', updated.wallet?.balance);

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

fixEmail();
