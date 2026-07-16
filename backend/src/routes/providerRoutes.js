
const express = require('express');
const { getProviders, getProviderById, updateProfile, updateLocation, toggleAvailability, getDashboardStats, getActiveBookings, getMyTransactions, getWalletHistory, topUpWallet, deleteAccount, createBannerRequest, requestWithdrawal } = require('../controllers/providerController');
const authMiddleware = require('../middleware/authMiddleware');
const optionalAuth = require('../middleware/optionalAuth');

const router = express.Router();

router.get('/', getProviders);
// Wallet history must come before :id to avoiding conflict if id is string
router.get('/wallet/history', authMiddleware, getWalletHistory);
// Active (in-progress) bookings — wallet screen pending commission
router.get('/bookings/active', authMiddleware, getActiveBookings);
// Provider's own transaction history (real-time wallet history)
router.get('/transactions', authMiddleware, getMyTransactions);
// DEV MOCK: instant wallet credit until the payment gateway is integrated
router.post('/wallet/topup', authMiddleware, topUpWallet);
router.delete('/account', authMiddleware, deleteAccount);

router.post('/banner-request', authMiddleware, createBannerRequest);

// Public provider card. optionalAuth means the provider themselves (or an
// admin) additionally sees their CNIC / bank details / wallet; everyone else
// gets the public fields only.
router.get('/:id', optionalAuth, getProviderById); // Keep this last as it captures any string

// Protected: Update Profile (Onboarding)
router.put('/profile', authMiddleware, updateProfile);

// Protected: Toggle availability (Available / Not Available)
router.put('/availability', authMiddleware, toggleAvailability);

// Protected: Update live location (powers nearest-first for customers)
router.put('/location', authMiddleware, updateLocation);

// Protected: Dashboard Stats
router.get('/dashboard/stats', authMiddleware, getDashboardStats);
router.post('/withdraw', authMiddleware, requestWithdrawal);

module.exports = router;
