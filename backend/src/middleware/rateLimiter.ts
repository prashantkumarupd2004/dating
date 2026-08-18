import rateLimit from 'express-rate-limit';

export const defaultLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  message: { success: false, message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, message: 'Too many auth attempts, try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

export const callLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { success: false, message: 'Too many call requests.' },
  standardHeaders: true,
  legacyHeaders: false,
});
