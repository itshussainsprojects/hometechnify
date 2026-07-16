/*
  Warnings:

  - You are about to drop the column `cancelReason` on the `Booking` table. All the data in the column will be lost.
  - You are about to drop the column `paymentStatus` on the `Booking` table. All the data in the column will be lost.
  - Made the column `address` on table `Booking` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterEnum
ALTER TYPE "BookingStatus" ADD VALUE 'NEGOTIATING';

-- AlterTable
ALTER TABLE "Booking" DROP COLUMN "cancelReason",
DROP COLUMN "paymentStatus",
ADD COLUMN     "conversation_id" TEXT,
ADD COLUMN     "job_post_id" TEXT,
ADD COLUMN     "last_offer_by" "Role",
ALTER COLUMN "address" SET NOT NULL;

-- AlterTable
ALTER TABLE "Transaction" ADD COLUMN     "type" TEXT NOT NULL DEFAULT 'PAYMENT',
ADD COLUMN     "user_id" TEXT,
ALTER COLUMN "booking_id" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "Transaction_user_id_idx" ON "Transaction"("user_id");

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_job_post_id_fkey" FOREIGN KEY ("job_post_id") REFERENCES "JobPost"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
