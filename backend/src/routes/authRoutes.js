
const express = require('express');
const { syncUser, getMe, updateMe } = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Sync Firebase User to Postgres
// Uses authMiddleware (which skips DB check for this route, but verifies Token)
// Sync Firebase User to Postgres
router.post('/sync', authMiddleware, syncUser);

// User Profile Routes
router.get('/me', authMiddleware, getMe);
router.put('/me', authMiddleware, updateMe);
router.delete('/me', authMiddleware, require('../controllers/authController').deleteUser);

module.exports = router;
