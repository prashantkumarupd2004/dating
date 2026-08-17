import Redis from 'ioredis';
import { config } from './index';
import { logger } from '../utils/logger';

export const redis = new Redis(config.redisUrl, {
  lazyConnect: true,
  retryStrategy: (times) => times > 5 ? null : Math.min(times * 500, 5000),
  enableOfflineQueue: false,
});

redis.on('connect', () => logger.info('Redis connected'));
redis.on('error', (err) => logger.debug('Redis error', err));

export const connectRedis = async (): Promise<void> => {
  await redis.connect();
};
