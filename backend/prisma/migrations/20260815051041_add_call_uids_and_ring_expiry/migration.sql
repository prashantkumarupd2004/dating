-- AlterTable
ALTER TABLE "Call" ADD COLUMN     "listenerUid" INTEGER,
ADD COLUMN     "ringExpiresAt" TIMESTAMP(3),
ADD COLUMN     "userUid" INTEGER;
