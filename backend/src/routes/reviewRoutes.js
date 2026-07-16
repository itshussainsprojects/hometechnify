// Review Routes

const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { getProviderReviews, createReview, getMyReviews } = require('../controllers/reviewController');

// Get my received reviews (authenticated)
router.get('/my', authMiddleware, getMyReviews);

// Get reviews for a specific provider (public)
router.get('/provider/:providerId', getProviderReviews);

// Create a review (authenticated)
router.post('/', authMiddleware, createReview);

module.exports = router;
