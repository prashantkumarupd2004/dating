import { prisma } from '../../config/database';

const PUBLIC_KEYS = [
  'audio_rate',
  'video_rate',
  'min_call_balance',
  'max_call_duration_minutes',
  'audio_calls_enabled',
  'video_calls_enabled',
  'listener_registration_enabled',
  'switch_to_listener_enabled',
];

export const getAppSettings = async (): Promise<Record<string, string>> => {
  const settings = await prisma.setting.findMany({
    where: { key: { in: PUBLIC_KEYS } },
  });
  return Object.fromEntries(settings.map((s) => [s.key, s.value]));
};

export const getSetting = async (key: string): Promise<string | null> => {
  const s = await prisma.setting.findUnique({ where: { key } });
  return s?.value ?? null;
};

export const getSettingNumber = async (key: string, fallback: number): Promise<number> => {
  const val = await getSetting(key);
  return val ? parseFloat(val) : fallback;
};

export const getSettingBool = async (key: string, fallback = true): Promise<boolean> => {
  const val = await getSetting(key);
  if (val === null) return fallback;
  return val === 'true' || val === '1';
};
