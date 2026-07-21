
const express = require('express');
const { syncUser, getMe, updateMe, checkEmail, notifyAdminLogin } = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Public: lets a registration form warn about an email already used by a
// different role before the user fills out the rest of the form.
router.get('/check-email', checkEmail);

// Admin Login screen calls this once, right after confirming a successful
// sign-in — sends a "thanks for logging in" security notice.
router.post('/notify-login', authMiddleware, notifyAdminLogin);

// Sync Firebase User to Postgres
// Uses authMiddleware (which skips DB check for this route, but verifies Token)
// Sync Firebase User to Postgres
router.post('/sync', authMiddleware, syncUser);

// User Profile Routes
router.get('/me', authMiddleware, getMe);
router.put('/me', authMiddleware, updateMe);
router.delete('/me', authMiddleware, require('../controllers/authController').deleteUser);

module.exports = router;
