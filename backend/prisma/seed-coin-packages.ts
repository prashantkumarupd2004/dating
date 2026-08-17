import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding coin packages...');

  // Delete existing packages (optional - comment out if you want to keep existing)
  await prisma.coinPackage.deleteMany({});

  const packages = [
    {
      name: 'Starter Pack',
      coins: 100,
      bonusCoins: 10,
      priceInr: 99,
      sortOrder: 1,
      isActive: true,
    },
    {
      name: 'Popular Pack',
      coins: 500,
      bonusCoins: 100,
      priceInr: 449,
      sortOrder: 2,
      isActive: true,
    },
    {
      name: 'Value Pack',
      coins: 1000,
      bonusCoins: 250,
      priceInr: 849,
      sortOrder: 3,
      isActive: true,
    },
    {
      name: 'Super Saver',
      coins: 2000,
      bonusCoins: 600,
      priceInr: 1599,
      sortOrder: 4,
      isActive: true,
    },
    {
      name: 'Mega Pack',
      coins: 5000,
      bonusCoins: 2000,
      priceInr: 3799,
      sortOrder: 5,
      isActive: true,
    },
    {
      name: 'Ultimate Pack',
      coins: 10000,
      bonusCoins: 5000,
      priceInr: 6999,
      sortOrder: 6,
      isActive: true,
    },
  ];

  for (const pkg of packages) {
    const created = await prisma.coinPackage.create({ data: pkg });
    console.log(`Created package: ${created.name} - ${created.coins} coins + ${created.bonusCoins} bonus = ₹${created.priceInr}`);
  }

  console.log('✅ Coin packages seeded successfully!');
}

main()
  .catch((e) => {
    console.error('Error seeding coin packages:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
