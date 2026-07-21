const express = require('express');
const router = express.Router();
const {
    getDashboardStats,
    getUsers,
    getCustomerPaymentMethods,
    blockUser,
    deleteUser,
    restoreUser,
    getProviders,
    verifyProvider,
    setProviderCategory,
    blockProvider,
    deleteProvider,
    restoreProvider,
    getBookings,
    getWithdrawals,
    updateWithdrawal,
    getProviderTransactions,
    createTransaction,
    updateTransaction,
    deleteTransaction,
    getPromos,
    createPromo,
    updatePromo,
    deletePromo,
    sendAdminNotification,
    getFinanceStats,
    getRatings,
    setProviderRating,
    resetProviderRating,
    getRatingThreshold,
    setRatingThreshold,
    getPlatformSettings,
    setPlatformSettings,
} = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const requireAdmin = require('../middleware/requireAdmin');

// All admin routes require a logged-in ADMIN
router.use(authMiddleware);
router.use(requireAdmin);

// Dashboard
router.get('/stats', getDashboardStats);
router.get('/finance', getFinanceStats);

// Users
router.get('/users', getUsers);
router.get('/users/payment-methods', getCustomerPaymentMethods);
router.put('/users/:id/block', blockUser);
router.delete('/users/:id', deleteUser);
router.put('/users/:id/restore', restoreUser);   // recycle bin -> restore

// Providers
router.get('/providers', getProviders);
router.put('/providers/:id/verify', verifyProvider);
// Set a provider's trade. Job matching is by category, and nothing else could set one.
router.put('/providers/:id/category', setProviderCategory);
router.put('/providers/:id/block', blockProvider);
router.delete('/providers/:id', deleteProvider);
router.put('/providers/:id/restore', restoreProvider);   // recycle bin -> restore

// Bookings
router.get('/bookings', getBookings);

// Withdrawals
router.get('/withdrawals', getWithdrawals);
router.put('/withdrawals/:id', updateWithdrawal);

// Manual payout transactions (under a withdrawal): record/edit/remove
router.get('/providers/:id/transactions', getProviderTransactions);
router.post('/transactions', createTransaction);
router.put('/transactions/:id', updateTransaction);
router.delete('/transactions/:id', deleteTransaction);

// Promos
router.get('/promos', getPromos);
router.post('/promos', createPromo);
router.put('/promos/:id', updatePromo);
router.delete('/promos/:id', deletePromo);

// Ratings management
router.get('/ratings', getRatings);
router.put('/providers/:id/rating', setProviderRating);       // add / edit
router.delete('/providers/:id/rating', resetProviderRating);  // remove
router.get('/settings/rating-threshold', getRatingThreshold);
router.put('/settings/rating-threshold', setRatingThreshold);

// Platform settings: commission % + provider search radius (applies to ALL providers live)
router.get('/settings/platform', getPlatformSettings);
router.put('/settings/platform', setPlatformSettings);

// Notifications
router.post('/notify', sendAdminNotification);

module.exports = router;
