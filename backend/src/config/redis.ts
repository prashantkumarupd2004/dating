import Redis from 'ioredis';
import { config } from './index';
import { logger } from '../utils/logger';

export const redis = new Redis(config.redisUrl, {
  lazyConnect: true,
  retryStrategy: () => null, // stop retrying — presence features are optional
  enableOfflineQueue: false,
});

redis.on('connect', () => logger.info('Redis connected'));
redis.on('error', () => {}); // suppress repeated error logs

export const connectRedis = async (): Promise<void> => {
  await redis.connect();
};
