// Payment Routes
const express = require('express');
const {
    initiatePayment,
    jazzCashCallback,
    easyPaisaCallback,
    getPaymentStatus,
    getTransactionHistory
} = require('../controllers/paymentController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Initiate payment (protected)
router.post('/initiate', authMiddleware, initiatePayment);

// Payment gateway callbacks (no auth required - called by payment gateways)
router.post('/jazzcash/callback', jazzCashCallback);
router.post('/easypaisa/callback', easyPaisaCallback);

// Get payment status (protected)
router.get('/status/:bookingId', authMiddleware, getPaymentStatus);

// Get transaction history (protected)
router.get('/transactions', authMiddleware, getTransactionHistory);

module.exports = router;
