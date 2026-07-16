-- AlterTable
ALTER TABLE "User" ADD COLUMN     "otp" TEXT,
ADD COLUMN     "otp_expiry" TIMESTAMP(3),
ALTER COLUMN "password_hash" DROP NOT NULL;
