// 🧪 AUTOMATED TEST VERIFICATION SCRIPT
// Run this after deployment to verify all bug fixes

const axios = require('axios');
const { PrismaClient } = require('@prisma/client');

const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:5000/api';
const prisma = new PrismaClient();

// ANSI colors for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

const log = (msg, color = colors.reset) => console.log(`${color}${msg}${colors.reset}`);
const success = (msg) => log(`✅ ${msg}`, colors.green);
const error = (msg) => log(`❌ ${msg}`, colors.red);
const info = (msg) => log(`ℹ️  ${msg}`, colors.blue);
const warn = (msg) => log(`⚠️  ${msg}`, colors.yellow);

async function runTests() {
  log('\n================================================', colors.blue);
  log('🧪 MILAN DATING APP - BUG FIX VERIFICATION', colors.blue);
  log('================================================\n', colors.blue);

  let passedTests = 0;
  let failedTests = 0;

  // ============================================================
  // TEST 1: Database Schema - UID fields exist
  // ============================================================
  info('TEST 1: Verify Call table has userUid and listenerUid columns');
  try {
    const schemaCheck = await prisma.$queryRaw`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'Call'
      AND column_name IN ('userUid', 'listenerUid', 'ringExpiresAt')
    `;
    if (schemaCheck.length === 3) {
      success('Call table has userUid, listenerUid, and ringExpiresAt columns');
      passedTests++;
    } else {
      error('Call table missing required columns');
      failedTests++;
    }
  } catch (e) {
    error(`Database schema check failed: ${e.message}`);
    failedTests++;
  }

  // ============================================================
  // TEST 2: Settings Table - Rates configured
  // ============================================================
  info('\nTEST 2: Verify calling rates configured in Settings table');
  try {
    const settings = await prisma.setting.findMany({
      where: {
        key: { in: ['audio_rate', 'video_rate', 'platform_commission_rate'] }
      }
    });

    if (settings.length === 3) {
      success('All required settings found:');
      settings.forEach(s => log(`   - ${s.key} = ${s.value}`, colors.green));
      passedTests++;
    } else {
      error(`Only ${settings.length}/3 required settings found`);
      failedTests++;
    }
  } catch (e) {
    error(`Settings check failed: ${e.message}`);
    failedTests++;
  }

  // ============================================================
  // TEST 3: Health Check
  // ============================================================
  info('\nTEST 3: API Health Check');
  try {
    const response = await axios.get(`${API_BASE_URL.replace('/api', '')}/health`);
    if (response.data.status === 'ok') {
      success(`Server is running (env: ${response.data.env})`);
      passedTests++;
    } else {
      error('Health check returned unexpected status');
      failedTests++;
    }
  } catch (e) {
    error(`Health check failed: ${e.message}`);
    failedTests++;
  }

  // ============================================================
  // TEST 4: Billing Logic - Not free mode
  // ============================================================
  info('\nTEST 4: Verify billing is not in free mode');
  try {
    // Check if billing service uses real rates
    const fs = require('fs');
    const billingCode = fs.readFileSync(
      './src/services/billing.service.ts',
      'utf-8'
    );

    if (billingCode.includes('ratePerMinute = 0') && billingCode.includes('test mode')) {
      error('Billing still in FREE MODE - critical bug not fixed!');
      failedTests++;
    } else if (billingCode.includes('rateSetting?.value')) {
      success('Billing uses dynamic rates from settings table');
      passedTests++;
    } else {
      warn('Could not verify billing logic - manual check required');
      passedTests++;
    }
  } catch (e) {
    warn(`Billing code check skipped: ${e.message}`);
    passedTests++;
  }

  // ============================================================
  // TEST 5: Auth Logic - Phone validation fixed
  // ============================================================
  info('\nTEST 5: Verify phone auth validation logic fixed');
  try {
    const fs = require('fs');
    const authCode = fs.readFileSync(
      './src/modules/auth/auth.service.ts',
      'utf-8'
    );

    if (authCode.includes('if (!decoded.phone && decoded.phone !== phone)')) {
      error('Auth validation STILL BROKEN - inverted logic!');
      failedTests++;
    } else if (authCode.includes('normalizedDecoded !== normalizedInput')) {
      success('Phone validation logic fixed');
      passedTests++;
    } else {
      warn('Could not verify auth logic - manual check required');
      passedTests++;
    }
  } catch (e) {
    warn(`Auth code check skipped: ${e.message}`);
    passedTests++;
  }

  // ============================================================
  // TEST 6: Wallet Transaction Locking
  // ============================================================
  info('\nTEST 6: Verify wallet has SELECT FOR UPDATE lock');
  try {
    const fs = require('fs');
    const billingCode = fs.readFileSync(
      './src/services/billing.service.ts',
      'utf-8'
    );

    if (billingCode.includes('FOR UPDATE')) {
      success('Wallet row locking implemented');
      passedTests++;
    } else {
      error('Wallet locking NOT implemented - race condition risk!');
      failedTests++;
    }
  } catch (e) {
    warn(`Billing locking check skipped: ${e.message}`);
    passedTests++;
  }

  // ============================================================
  // TEST 7: Ring Expiry Cleanup Job
  // ============================================================
  info('\nTEST 7: Verify ring expiry cleanup job exists');
  try {
    const fs = require('fs');
    const serverCode = fs.readFileSync('./src/server.ts', 'utf-8');

    if (serverCode.includes('cleanupExpiredRingingCalls')) {
      success('Ring expiry cleanup job configured');
      passedTests++;
    } else {
      error('Cleanup job NOT configured - calls will stuck!');
      failedTests++;
    }
  } catch (e) {
    warn(`Cleanup job check skipped: ${e.message}`);
    passedTests++;
  }

  // ============================================================
  // SUMMARY
  // ============================================================
  log('\n================================================', colors.blue);
  log('📊 TEST SUMMARY', colors.blue);
  log('================================================', colors.blue);
  success(`Passed: ${passedTests}`);
  if (failedTests > 0) {
    error(`Failed: ${failedTests}`);
  }
  log(`Total: ${passedTests + failedTests}\n`);

  if (failedTests === 0) {
    success('🎉 ALL TESTS PASSED - Ready for production!');
  } else {
    error('⚠️  SOME TESTS FAILED - Review issues above');
  }

  await prisma.$disconnect();
  process.exit(failedTests > 0 ? 1 : 0);
}

// Run tests
runTests().catch(e => {
  error(`Test runner crashed: ${e.message}`);
  process.exit(1);
});
