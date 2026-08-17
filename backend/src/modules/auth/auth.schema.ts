import { z } from 'zod';

export const googleLoginSchema = z.object({
  firebaseToken: z.string().min(1),
});

export const registerSchema = z.object({
  name: z.string().min(2),
  // Accept full ISO string or YYYY-MM-DD — slice to first 10 chars normalises both
  dateOfBirth: z.string().min(10).transform((v) => v.slice(0, 10)),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER']),
  city: z.string().optional(),
  bio: z.string().max(200).optional(),
  language: z.string().optional(),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1),
});
