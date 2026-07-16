// Payment Service - JazzCash & EasyPaisa Integration
const axios = require('axios');
const crypto = require('crypto');
const prisma = require('../utils/prisma');

/**
 * JazzCash Payment Gateway Integration
 * Note: This requires JazzCash Merchant Account
 * Sandbox: https://sandbox.jazzcash.com.pk
 * Production: https://payments.jazzcash.com.pk
 */

class PaymentService {
    constructor() {
        // JazzCash Credentials (Add to .env)
        this.jazzCashMerchantId = process.env.JAZZCASH_MERCHANT_ID || 'MC12345';
        this.jazzCashPassword = process.env.JAZZCASH_PASSWORD || 'password';
        this.jazzCashIntegritySalt = process.env.JAZZCASH_INTEGRITY_SALT || 'salt123';
        this.jazzCashReturnUrl = process.env.JAZZCASH_RETURN_URL || 'http://localhost:3000/api/payments/jazzcash/callback';
        
        // EasyPaisa Credentials (Add to .env)
        this.easyPaisaStoreId = process.env.EASYPAISA_STORE_ID || 'store123';
        this.easyPaisaHashKey = process.env.EASYPAISA_HASH_KEY || 'hashkey123';
        
        // URLs
        this.jazzCashUrl = process.env.JAZZCASH_URL || 'https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/';
        this.easyPaisaUrl = process.env.EASYPAISA_URL || 'https://easypaisa.com.pk/easypay';
    }

    /**
     * Generate Secure Hash for JazzCash
     */
    generateJazzCashHash(data) {
        const sortedKeys = Object.keys(data).sort();
        let hashString = this.jazzCashIntegritySalt + '&';
        
        sortedKeys.forEach(key => {
            if (data[key] !== '' && data[key] !== null) {
                hashString += data[key] + '&';
            }
        });
        
        hashString = hashString.slice(0, -1); // Remove last &
        return crypto.createHmac('sha256', this.jazzCashIntegritySalt)
            .update(hashString)
            .digest('hex')
            .toUpperCase();
    }

    /**
     * Create JazzCash Payment Request
     */
    async createJazzCashPayment(bookingId, amount, customerPhone, customerEmail) {
        try {
            const txnRefNo = `TXN${Date.now()}`;
            const txnDateTime = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
            const expiryDateTime = new Date(Date.now() + 30 * 60000).toISOString().replace(/[-:]/g, '').split('.')[0]; // 30 min

            const paymentData = {
                pp_Version: '1.1',
                pp_TxnType: 'MWALLET', // Mobile Wallet
                pp_Language: 'EN',
                pp_MerchantID: this.jazzCashMerchantId,
                pp_SubMerchantID: '',
                pp_Password: this.jazzCashPassword,
                pp_TxnRefNo: txnRefNo,
                pp_Amount: Math.round(amount * 100), // Amount in paisa
                pp_TxnCurrency: 'PKR',
                pp_TxnDateTime: txnDateTime,
                pp_BillReference: bookingId,
                pp_Description: `HomeTechnify Booking #${bookingId}`,
                pp_TxnExpiryDateTime: expiryDateTime,
                pp_ReturnURL: this.jazzCashReturnUrl,
                pp_SecureHash: '',
                ppmpf_1: customerPhone || '',
                ppmpf_2: customerEmail || '',
                ppmpf_3: '',
                ppmpf_4: '',
                ppmpf_5: ''
            };

            // Generate secure hash
            paymentData.pp_SecureHash = this.generateJazzCashHash(paymentData);

            // Store transaction in database
            await prisma.$executeRaw`
                INSERT INTO transactions (booking_id, transaction_ref, amount, payment_method, status, created_at)
                VALUES (${bookingId}, ${txnRefNo}, ${amount}, 'JAZZCASH', 'PENDING', NOW())
            `;

            return {
                success: true,
                paymentUrl: this.jazzCashUrl,
                paymentData,
                transactionRef: txnRefNo
            };
        } catch (error) {
            console.error('JazzCash payment creation error:', error);
            throw error;
        }
    }

    /**
     * Verify JazzCash Payment Callback
     */
    async verifyJazzCashPayment(callbackData) {
        try {
            const receivedHash = callbackData.pp_SecureHash;
            delete callbackData.pp_SecureHash;

            const calculatedHash = this.generateJazzCashHash(callbackData);

            if (receivedHash !== calculatedHash) {
                return { success: false, message: 'Invalid payment signature' };
            }

            const status = callbackData.pp_ResponseCode === '000' ? 'SUCCESS' : 'FAILED';
            const bookingId = callbackData.pp_BillReference;
            const txnRefNo = callbackData.pp_TxnRefNo;

            // The table is "Transaction", not `transactions`. Postgres folds an
            // unquoted identifier to lower case, so this raw UPDATE was pointed at
            // a table that does not exist — the very first real payment callback
            // would have thrown, the customer's money would have left their
            // account, and the booking would have stayed unpaid forever.
            const txn = await prisma.transaction.findUnique({
                where: { transaction_ref: txnRefNo },
                select: { id: true, status: true },
            });
            if (!txn) {
                return { success: false, message: 'Unknown transaction reference' };
            }

            // Gateways retry callbacks. Settling the same payment twice would
            // double-notify both parties.
            if (txn.status === 'SUCCESS') {
                return { success: true, bookingId, transactionRef: txnRefNo, message: 'Already settled' };
            }

            await prisma.transaction.update({
                where: { id: txn.id },
                data: {
                    status,
                    response_code: callbackData.pp_ResponseCode,
                    response_message: callbackData.pp_ResponseMessage,
                },
            });

            // Update booking payment status.
            // `paymentStatus` is not a field on the model — the column is
            // `payment_status` — so this threw "Unknown argument" too.
            if (status === 'SUCCESS') {
                await prisma.booking.update({
                    where: { id: bookingId },
                    data: { payment_status: 'PAID', payment_method: 'JAZZCASH' },
                });
            }

            return {
                success: status === 'SUCCESS',
                bookingId,
                transactionRef: txnRefNo,
                message: callbackData.pp_ResponseMessage
            };
        } catch (error) {
            console.error('JazzCash verification error:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Create EasyPaisa Payment Request
     */
    async createEasyPaisaPayment(bookingId, amount, customerPhone) {
        try {
            const orderId = `ORD${Date.now()}`;
            const expiryDate = new Date(Date.now() + 30 * 60000); // 30 minutes

            const paymentData = {
                storeId: this.easyPaisaStoreId,
                amount: amount.toFixed(2),
                postBackURL: `${process.env.BASE_URL}/api/payments/easypaisa/callback`,
                orderRefNum: orderId,
                expiryDate: expiryDate.toISOString(),
                merchantHashedReq: '',
                autoRedirect: '1',
                paymentMethod: 'MA_PAYMENT_METHOD', // Mobile Account
                emailAddress: '',
                mobileNumber: customerPhone || ''
            };

            // Generate hash
            const hashString = `${this.easyPaisaStoreId}${amount.toFixed(2)}${orderId}`;
            paymentData.merchantHashedReq = crypto
                .createHmac('sha256', this.easyPaisaHashKey)
                .update(hashString)
                .digest('hex');

            // The table is "Transaction", not `transactions` — an unquoted
            // identifier is folded to lower case by Postgres, so this INSERT was
            // pointed at a table that does not exist.
            await prisma.transaction.create({
                data: {
                    booking_id: bookingId,
                    transaction_ref: orderId,
                    amount,
                    type: 'PAYMENT',
                    payment_method: 'EASYPAISA',
                    status: 'PENDING',
                },
            });

            return {
                success: true,
                paymentUrl: this.easyPaisaUrl,
                paymentData,
                transactionRef: orderId
            };
        } catch (error) {
            console.error('EasyPaisa payment creation error:', error);
            throw error;
        }
    }

    /**
     * Verify EasyPaisa Payment Callback
     */
    async verifyEasyPaisaPayment(callbackData) {
        try {
            const { orderRefNum, status, desc } = callbackData;

            // SIGNATURE. The JazzCash callback verifies its hash; this one verified
            // NOTHING. /api/payments/easypaisa/callback is a public endpoint, so
            // anyone could POST {orderRefNum, status:'0000'} and have a booking
            // marked PAID without a rupee changing hands. It fails CLOSED: no
            // valid signature, no payment.
            const received = callbackData.merchantHashedReq
                || callbackData.hashedReq
                || callbackData.hash;

            if (!received) {
                console.error(
                    'EasyPaisa callback carried no signature — REJECTED. ' +
                    'Wire the merchant hash field from the EasyPaisa integration doc ' +
                    'before going live; without it this endpoint is free money.'
                );
                return { success: false, message: 'Unsigned payment callback rejected' };
            }

            // Same HMAC the initiate side signs with.
            const expected = crypto
                .createHmac('sha256', this.easyPaisaHashKey)
                .update(`${this.easyPaisaStoreId}${orderRefNum}${status}`)
                .digest('hex');

            if (!crypto.timingSafeEqual(
                Buffer.from(String(received).padEnd(expected.length).slice(0, expected.length)),
                Buffer.from(expected),
            )) {
                console.error(`EasyPaisa callback signature mismatch for ${orderRefNum} — REJECTED`);
                return { success: false, message: 'Invalid payment signature' };
            }

            const paymentStatus = status === '0000' ? 'SUCCESS' : 'FAILED';

            // The table is "Transaction", not `transactions`.
            const txn = await prisma.transaction.findUnique({
                where: { transaction_ref: orderRefNum },
                select: { id: true, booking_id: true, status: true },
            });
            if (!txn) {
                return { success: false, message: 'Unknown transaction reference' };
            }

            // Gateways retry callbacks. Settling the same payment twice would
            // double-notify and, once refunds exist, double-refund.
            if (txn.status === 'SUCCESS') {
                return { success: true, bookingId: txn.booking_id, transactionRef: orderRefNum, message: 'Already settled' };
            }

            await prisma.transaction.update({
                where: { id: txn.id },
                data: {
                    status: paymentStatus,
                    response_code: status,
                    response_message: desc,
                },
            });

            if (paymentStatus === 'SUCCESS' && txn.booking_id) {
                await prisma.booking.update({
                    where: { id: txn.booking_id },
                    data: { payment_status: 'PAID', payment_method: 'EASYPAISA' },
                });

                return {
                    success: true,
                    bookingId: txn.booking_id,
                    transactionRef: orderRefNum,
                    message: 'Payment successful'
                };
            }

            return {
                success: false,
                transactionRef: orderRefNum,
                message: desc
            };
        } catch (error) {
            console.error('EasyPaisa verification error:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Process Cash Payment (Mark as paid on service completion)
     */
    async processCashPayment(bookingId, amount) {
        try {
            const txnRef = `CASH${Date.now()}`;

            await prisma.$executeRaw`
                INSERT INTO transactions (booking_id, transaction_ref, amount, payment_method, status, created_at)
                VALUES (${bookingId}, ${txnRef}, ${amount}, 'CASH', 'SUCCESS', NOW())
            `;

            await prisma.booking.update({
                where: { id: bookingId },
                data: { paymentStatus: 'PENDING_CASH' } // Will be marked PAID when service completes
            });

            return {
                success: true,
                message: 'Cash payment recorded',
                transactionRef: txnRef
            };
        } catch (error) {
            console.error('Cash payment error:', error);
            throw error;
        }
    }
}

module.exports = new PaymentService();
