const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const requireAdmin = require('../middleware/requireAdmin');
const { sendPushNotification, sendBroadcastNotification } = require('../services/notificationService');

const {
    getNotifications,
    markAsRead,
    toggleNotifications,
    broadcastNotification,
    deleteNotification
} = require('../controllers/notificationController');

router.use(authMiddleware);

// Get User Notifications
router.get('/', getNotifications);

// Mark as Read (id or 'all')
router.put('/:id/read', markAsRead);

// Toggle Notifications
router.put('/toggle', toggleNotifications);

// Broadcast Notification (admin only)
router.post('/broadcast', requireAdmin, broadcastNotification);

// Delete Notification
router.delete('/:id', deleteNotification);

// POST /api/notifications/send-test
router.post('/send-test', async (req, res) => {
    try {
        const { title, message } = req.body;

        console.log("Sending test push to user:", req.user.name, "(", req.user.id, ")");

        // Send to self (the authenticated user)
        const success = await sendPushNotification(
            req.user.id,
            title || 'Test Notification',
            message || 'This is a test notification from backend',
            { type: 'test' }
        );

        if (success) {
            res.json({ success: true, message: 'Notification sent successfully' });
        } else {
            res.status(400).json({ success: false, message: 'Failed to send notification. Check if FCM Token exists.' });
        }
    } catch (e) {
        console.error("Test push error:", e);
        res.status(500).json({ success: false, error: e.message });
    }
});

// POST /api/notifications/send-custom (admin only)
router.post('/send-custom', requireAdmin, async (req, res) => {
    try {
        const { targetId, title, message } = req.body;
        if (!targetId || !title || !message) return res.status(400).json({ error: "Missing fields" });

        const success = await sendPushNotification(targetId, title, message, { type: 'admin_msg' });

        if (success) res.json({ success: true });
        else res.status(400).json({ success: false, message: 'Failed to send' });
    } catch (e) {
        res.status(500).json({ success: false, error: e.message });
    }
});

// POST /api/notifications/send-broadcast (admin only)
router.post('/send-broadcast', requireAdmin, async (req, res) => {
    try {
        const { title, message, isProvider } = req.body;
        if (!title || !message) return res.status(400).json({ error: "Missing fields" });

        // Role: 'PROVIDER' or 'CUSTOMER'
        const role = isProvider ? 'PROVIDER' : 'CUSTOMER';
        const count = await sendBroadcastNotification(role, title, message, { type: 'broadcast' });

        res.json({ success: true, count });
    } catch (e) {
        res.status(500).json({ success: false, error: e.message });
    }
});

module.exports = router;
