const prisma = require('../utils/prisma');
const { sendBroadcastNotification } = require('../services/notificationService');

/// A "New Job Posted" notification is only worth showing while the job is still
/// OPEN. Once the customer cancels it, another provider wins it, or it is
/// deleted, the notification is a dead end: the provider taps it and there is
/// nothing there.
///
/// Providers were carrying dozens of these — 207 of 215 job notifications in the
/// database pointed at a job that no longer existed — and the unread badge could
/// never reach zero.
const dropDeadJobNotifications = async (notifications) => {
    const jobIds = [...new Set(
        notifications
            .filter(n => n.type === 'job_post' && n.data?.jobId)
            .map(n => n.data.jobId)
    )];
    if (!jobIds.length) return notifications;

    const openJobs = await prisma.jobPost.findMany({
        where: { id: { in: jobIds }, status: 'OPEN' },
        select: { id: true },
    });
    const stillOpen = new Set(openJobs.map(j => j.id));

    return notifications.filter(n =>
        n.type !== 'job_post' || !n.data?.jobId || stillOpen.has(n.data.jobId)
    );
};

// Get all notifications for logged-in user
const getNotifications = async (req, res) => {
    try {
        const userId = req.user.id;
        const { page = 1, limit = 20 } = req.query;
        const skip = (page - 1) * limit;

        const raw = await prisma.notification.findMany({
            where: { user_id: userId },
            orderBy: { created_at: 'desc' },
            take: parseInt(limit),
            skip: parseInt(skip),
        });
        const notifications = await dropDeadJobNotifications(raw);

        // The unread badge must count what the provider can actually act on,
        // otherwise it sits at 40-odd forever and they stop trusting it.
        const unreadRaw = await prisma.notification.findMany({
            where: { user_id: userId, is_read: false },
            select: { id: true, type: true, data: true },
        });
        const unreadLive = await dropDeadJobNotifications(unreadRaw);

        res.json({
            success: true,
            data: notifications,
            meta: {
                total: notifications.length,
                page: parseInt(page),
                limit: parseInt(limit),
                unreadCount: unreadLive.length,
            }
        });
    } catch (error) {
        console.error('Get Notifications Error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch notifications' });
    }
};

// Mark notification as read
const markAsRead = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params; // Notification ID or 'all'

        if (id === 'all') {
            await prisma.notification.updateMany({
                where: { user_id: userId, is_read: false },
                data: { is_read: true }
            });
        } else {
            await prisma.notification.updateMany({
                where: { id: id, user_id: userId },
                data: { is_read: true }
            });
        }

        res.json({ success: true, message: 'Marked as read' });
    } catch (error) {
        console.error('Mark Read Error:', error);
        res.status(500).json({ success: false, message: 'Failed to update notification' });
    }
};

// Toggle Notifications
const toggleNotifications = async (req, res) => {
    try {
        const userId = req.user.id;
        const { enabled } = req.body; // boolean

        if (typeof enabled !== 'boolean') {
            return res.status(400).json({ success: false, message: 'enabled must be boolean' });
        }

        await prisma.user.update({
            where: { id: userId },
            data: { is_notifications_enabled: enabled }
        });

        res.json({ success: true, message: `Notifications ${enabled ? 'enabled' : 'disabled'}` });
    } catch (error) {
        console.error('Toggle Notifications Error:', error);
        res.status(500).json({ success: false, message: 'Failed to update settings' });
    }
};

// Admin Broadcast
const broadcastNotification = async (req, res) => {
    try {
        const { role, title, body, data } = req.body;

        if (req.user.role !== 'ADMIN') {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        const count = await sendBroadcastNotification(role, title, body, data);
        res.json({ success: true, message: `Broadcast sent to ${count} users` });
    } catch (error) {
        console.error('Broadcast Error:', error);
        res.status(500).json({ success: false, message: 'Failed to send broadcast' });
    }
};

// Delete Notification
const deleteNotification = async (req, res) => {
    try {
        const userId = req.user.id;
        const { id } = req.params;

        await prisma.notification.deleteMany({
            where: {
                id: id,
                user_id: userId // Ensure user owns the notification
            }
        });

        res.json({ success: true, message: 'Notification deleted' });
    } catch (error) {
        console.error('Delete Notification Error:', error);
        res.status(500).json({ success: false, message: 'Failed to delete notification' });
    }
};

module.exports = {
    getNotifications,
    markAsRead,
    toggleNotifications,
    broadcastNotification,
    deleteNotification
};
