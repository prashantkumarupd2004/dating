-- Seed critical settings for production readiness
-- Run this script against your database

-- Insert calling rates
INSERT INTO "Setting" (id, key, value, type, "group", description, "updatedAt")
VALUES
  (gen_random_uuid(), 'audio_rate', '10', 'NUMBER', 'calling', 'Audio call rate per minute (coins)', NOW()),
  (gen_random_uuid(), 'video_rate', '60', 'NUMBER', 'calling', 'Video call rate per minute (coins)', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  "updatedAt" = NOW();

-- Insert feature flags
INSERT INTO "Setting" (id, key, value, type, "group", description, "updatedAt")
VALUES
  (gen_random_uuid(), 'audio_calls_enabled', 'true', 'BOOLEAN', 'calling', 'Enable audio calls', NOW()),
  (gen_random_uuid(), 'video_calls_enabled', 'true', 'BOOLEAN', 'calling', 'Enable video calls', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  "updatedAt" = NOW();

-- Insert platform commission rate
INSERT INTO "Setting" (id, key, value, type, "group", description, "updatedAt")
VALUES
  (gen_random_uuid(), 'platform_commission_rate', '30', 'NUMBER', 'earning', 'Platform commission percentage', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  "updatedAt" = NOW();

-- Verify settings inserted
SELECT key, value, type, "group", description FROM "Setting" WHERE "group" IN ('calling', 'earning');
