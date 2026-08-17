import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Admin user
  const hashedPassword = await bcrypt.hash('Admin@123', 12);
  await prisma.adminUser.upsert({
    where: { email: 'admin@app.com' },
    update: {},
    create: { email: 'admin@app.com', password: hashedPassword, name: 'Super Admin', role: 'SUPER_ADMIN' },
  });
  console.log('Admin user created: admin@app.com / Admin@123');

  // Settings
  const settings = [
    { key: 'audio_rate', value: '10', type: 'NUMBER', group: 'calling', description: 'Audio call rate in coins per minute' },
    { key: 'video_rate', value: '60', type: 'NUMBER', group: 'calling', description: 'Video call rate in coins per minute' },
    { key: 'min_call_balance', value: '10', type: 'NUMBER', group: 'calling', description: 'Minimum coins required to start a call' },
    { key: 'max_call_duration_minutes', value: '60', type: 'NUMBER', group: 'calling', description: 'Maximum call duration in minutes' },
    { key: 'audio_calls_enabled', value: 'true', type: 'BOOLEAN', group: 'features', description: 'Enable/disable audio calls' },
    { key: 'video_calls_enabled', value: 'false', type: 'BOOLEAN', group: 'features', description: 'Enable/disable video calls' },
    { key: 'listener_registration_enabled', value: 'true', type: 'BOOLEAN', group: 'features', description: 'Allow new listener registrations' },
    { key: 'switch_to_listener_enabled', value: 'true', type: 'BOOLEAN', group: 'features', description: 'Allow users to switch to listener mode' },
    { key: 'platform_commission_rate', value: '30', type: 'NUMBER', group: 'commission', description: 'Platform commission percentage' },
    { key: 'listener_commission_rate', value: '70', type: 'NUMBER', group: 'commission', description: 'Listener earnings percentage' },
    { key: 'min_payout_amount', value: '500', type: 'NUMBER', group: 'payout', description: 'Minimum payout amount in INR' },
    { key: 'app_name', value: 'Milan', type: 'STRING', group: 'general', description: 'Application name' },
    { key: 'support_email', value: 'support@app.com', type: 'STRING', group: 'general', description: 'Support email' },
    { key: 'maintenance_mode', value: 'false', type: 'BOOLEAN', group: 'general', description: 'Put app in maintenance mode' },
  ];

  for (const s of settings) {
    await prisma.setting.upsert({
      where: { key: s.key },
      update: { value: s.value },
      create: s as any,
    });
  }
  console.log(`${settings.length} settings seeded`);

  // Coin packages
  const packages = [
    { name: '100 Coins', coins: 100, bonusCoins: 0, priceInr: 9, sortOrder: 1 },
    { name: '500 Coins', coins: 500, bonusCoins: 50, priceInr: 45, sortOrder: 2 },
    { name: '1000 Coins', coins: 1000, bonusCoins: 100, priceInr: 89, sortOrder: 3 },
    { name: '2500 Coins', coins: 2500, bonusCoins: 300, priceInr: 199, sortOrder: 4 },
    { name: '5000 Coins', coins: 5000, bonusCoins: 750, priceInr: 399, sortOrder: 5 },
  ];

  for (const pkg of packages) {
    const existing = await prisma.coinPackage.findFirst({ where: { coins: pkg.coins } });
    if (!existing) await prisma.coinPackage.create({ data: pkg as any });
  }
  console.log(`${packages.length} coin packages seeded`);

  // Languages
  const languages = [
    { code: 'en', name: 'English' },
    { code: 'hi', name: 'Hindi' },
    { code: 'gu', name: 'Gujarati' },
  ];
  for (const lang of languages) {
    await prisma.language.upsert({ where: { code: lang.code }, update: {}, create: lang });
  }
  console.log(`${languages.length} languages seeded`);

  // Interests
  const interests = ['Music', 'Movies', 'Travel', 'Gaming', 'Fitness', 'Cooking', 'Art', 'Reading', 'Fashion', 'Sports'];
  for (const name of interests) {
    await prisma.interest.upsert({ where: { name }, update: {}, create: { name } });
  }
  console.log(`${interests.length} interests seeded`);

  console.log('Seeding complete.');
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
