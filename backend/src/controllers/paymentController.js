// Payment Controller - Handle JazzCash & EasyPaisa Payments
const paymentService = require('../services/paymentService');
const prisma = require('../utils/prisma');
const { sendNotificationToUser } = require('../services/socketService');
const admin = require('../config/firebase');

/**
 * Initiate Payment
 */
const initiatePayment = async (req, res) => {
    try {
        const { bookingId, paymentMethod, customerPhone, customerEmail } = req.body;
        const userId = req.user.id;

        // Get booking details
        const booking = await prisma.booking.findUnique({
            where: { id: bookingId },
            include: { service: true }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: 'Booking not found' });
        }

        if (booking.customer_id !== userId) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        const amount = booking.total_amount;
        let result;

        switch (paymentMethod.toUpperCase()) {
            case 'JAZZCASH':
                result = await paymentService.createJazzCashPayment(
                    bookingId,
                    amount,
                    customerPhone,
                    customerEmail
                );
                break;

            case 'EASYPAISA':
                result = await paymentService.createEasyPaisaPayment(
                    bookingId,
                    amount,
                    customerPhone
                );
                break;

            case 'CASH':
                result = await paymentService.processCashPayment(bookingId, amount);
                break;

            default:
                return res.status(400).json({ 
                    success: false, 
                    message: 'Invalid payment method. Use JAZZCASH, EASYPAISA, or CASH' 
                });
        }

        res.status(200).json({
            success: true,
            data: result,
            message: 'Payment initiated successfully'
        });

    } catch (error) {
        console.error('Payment initiation error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * JazzCash Payment Callback
 */
const jazzCashCallback = async (req, res) => {
    try {
        const result = await paymentService.verifyJazzCashPayment(req.body);

        if (result.success) {
            // Get booking details
            const booking = await prisma.booking.findUnique({
                where: { id: result.bookingId },
                include: { customer: true, provider: true }
            });

            // Send real-time notification to customer
            sendNotificationToUser(booking.customer_id, {
                type: 'payment_success',
                title: 'Payment Successful',
                message: 'Your payment has been received successfully',
                bookingId: result.bookingId
            });

            // Send notification to provider
            sendNotificationToUser(booking.provider_id, {
                type: 'new_booking',
                title: 'New Booking',
                message: 'You have received a new booking request',
                bookingId: result.bookingId
            });

            // Send Firebase notification to provider
            if (booking.provider.fcmToken) {
                try {
                    await admin.messaging().send({
                        token: booking.provider.fcmToken,
                        notification: {
                            title: 'New Booking Request',
                            body: `New booking for ${booking.service.name}`
                        },
                        data: {
                            type: 'new_booking',
                            bookingId: result.bookingId
                        }
                    });
                } catch (fcmError) {
                    console.error('FCM error:', fcmError);
                }
            }

            // Redirect to success page
            res.redirect(`${process.env.FRONTEND_URL || 'http://localhost'}/booking-success?bookingId=${result.bookingId}`);
        } else {
            // Redirect to failure page
            res.redirect(`${process.env.FRONTEND_URL || 'http://localhost'}/booking-failed?message=${encodeURIComponent(result.message)}`);
        }
    } catch (error) {
        console.error('JazzCash callback error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * EasyPaisa Payment Callback
 */
const easyPaisaCallback = async (req, res) => {
    try {
        const result = await paymentService.verifyEasyPaisaPayment(req.body);

        if (result.success) {
            const booking = await prisma.booking.findUnique({
                where: { id: result.bookingId },
                include: { customer: true, provider: true }
            });

            // Send notifications
            sendNotificationToUser(booking.customer_id, {
                type: 'payment_success',
                title: 'Payment Successful',
                message: 'Your payment has been received',
                bookingId: result.bookingId
            });

            sendNotificationToUser(booking.provider_id, {
                type: 'new_booking',
                title: 'New Booking',
                message: 'You have a new booking request',
                bookingId: result.bookingId
            });

            res.redirect(`${process.env.FRONTEND_URL}/booking-success?bookingId=${result.bookingId}`);
        } else {
            res.redirect(`${process.env.FRONTEND_URL}/booking-failed?message=${encodeURIComponent(result.message)}`);
        }
    } catch (error) {
        console.error('EasyPaisa callback error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Get Payment Status
 */
const getPaymentStatus = async (req, res) => {
    try {
        const { bookingId } = req.params;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({
            where: { id: bookingId }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: 'Booking not found' });
        }

        if (booking.customer_id !== userId && req.user.role !== 'ADMIN') {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        const transaction = await prisma.$queryRaw`
            SELECT * FROM transactions 
            WHERE booking_id = ${bookingId} 
            ORDER BY created_at DESC 
            LIMIT 1
        `;

        res.status(200).json({
            success: true,
            data: {
                bookingId,
                paymentStatus: booking.paymentStatus,
                transaction: transaction[0] || null
            }
        });

    } catch (error) {
        console.error('Get payment status error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Get Transaction History (for user wallet)
 */
const getTransactionHistory = async (req, res) => {
    try {
        const userId = req.user.id;

        const transactions = await prisma.$queryRaw`
            SELECT t.*, b.scheduled_at, s.name as service_name
            FROM transactions t
            JOIN bookings b ON t.booking_id = b.id
            JOIN services s ON b.service_id = s.id
            WHERE b.customer_id = ${userId}
            ORDER BY t.created_at DESC
        `;

        res.status(200).json({
            success: true,
            data: transactions
        });

    } catch (error) {
        console.error('Transaction history error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = {
    initiatePayment,
    jazzCashCallback,
    easyPaisaCallback,
    getPaymentStatus,
    getTransactionHistory
};
