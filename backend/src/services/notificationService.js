const admin = require('../config/firebase');
const prisma = require('../utils/prisma');
const { getIO } = require('./socketService');

const sendNotification = async (userId, title, body, type, data = {}) => {
    try {
        // 1. Emit Socket Event FIRST (instant real-time in-app update —
        //    never delayed by DB writes or FCM round-trips)
        try {
            const io = getIO();
            if (io) {
                io.to(`user:${userId}`).emit('notification', {
                    title,
                    body,
                    type,
                    data: data || {},
                });
                console.log(`Socket notification emitted to ${userId}`);
            }
        } catch (socketError) {
            console.error('Socket emission failed:', socketError.message);
        }

        const user = await prisma.user.findUnique({ where: { id: userId } });

        // Check if user exists and has notifications enabled
        if (!user || user.is_notifications_enabled === false) {
            console.log(`Notification skipped for user ${userId}: Disabled or User not found.`);
            return;
        }

        // 2. Save Notification to Database
        const notification = await prisma.notification.create({
            data: {
                user_id: userId,
                title,
                body,
                type,
                data: data || {},
                is_read: false
            }
        });

        // 3. Send FCM Notification (if token exists)
        if (user.fcmToken) {
            // FCM data payload values must be strings
            const stringData = Object.keys(data).reduce((acc, key) => {
                acc[key] = String(data[key]);
                return acc;
            }, {});

            const message = {
                token: user.fcmToken,
                notification: {
                    title,
                    body,
                },
                data: {
                    type,
                    notificationId: notification.id,
                    ...stringData,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                android: {
                    priority: 'high',
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                        },
                    },
                },
            };

            await admin.messaging().send(message);
            console.log(`FCM Notification sent to user ${userId}`);
        } else {
            console.log(`User ${userId} has no FCM token.`);
        }
        return true;
    } catch (error) {
        console.error('Error sending notification:', error);
        return false;
    }
};

const sendBroadcastNotification = async (role, title, body, data = {}, opts = {}) => {
    try {
        const where = {
            role: role, // 'CUSTOMER' | 'PROVIDER' | 'ADMIN'
            fcmToken: { not: null },
            is_notifications_enabled: true,
        };
        // Only notify AVAILABLE (online) providers about new jobs — providers
        // who set themselves Not Available won't be disturbed. When a
        // category is given (e.g. "Plumbing"), only providers of that trade
        // are notified — an electrician never gets plumbing jobs.
        if (role === 'PROVIDER') {
            where.provider_profile = { is_online: true };
            if (opts.category && opts.category !== 'General') {
                where.provider_profile.category = {
                    name: { equals: opts.category, mode: 'insensitive' },
                };
            }
        }

        const users = await prisma.user.findMany({
            where,
            select: { fcmToken: true, id: true }
        });

        if (users.length === 0) return 0;

        const tokens = users.map(u => u.fcmToken);

        // Save to DB for each user (optional, might be heavy)
        // For broadcast, maybe just send? Or batch create?
        // Let's batch create notifications
        await prisma.notification.createMany({
            data: users.map(u => ({
                user_id: u.id,
                title,
                body,
                type: data.type || 'BROADCAST',
                data,
                is_read: false
            }))
        });

        // FCM data payload values MUST all be strings
        const stringData = { type: 'BROADCAST', click_action: 'FLUTTER_NOTIFICATION_CLICK' };
        for (const [k, v] of Object.entries(data)) {
            stringData[k] = v == null ? '' : String(v);
        }

        // sendToDevice was removed in firebase-admin v11+. Use multicast,
        // chunked to FCM's 500-token limit.
        let successCount = 0;
        for (let i = 0; i < tokens.length; i += 500) {
            const batch = tokens.slice(i, i + 500);
            const response = await admin.messaging().sendEachForMulticast({
                tokens: batch,
                notification: { title, body },
                data: stringData,
            });
            successCount += response.successCount;
        }
        console.log(`Broadcast sent to ${tokens.length} tokens. Success: ${successCount}`);
        return successCount;
    } catch (error) {
        console.error('Broadcast Error:', error);
        return 0;
    }
};

/// Delete the "New Job Posted" notifications for a job that is no longer open.
///
/// A job post fans a notification out to every eligible provider. When that job
/// is then cancelled, won by someone else, or deleted, those notifications stay
/// behind: each one is a dead end that opens nothing, and the provider's unread
/// badge never comes back down. Providers were sitting on dozens of them.
///
/// Call this wherever a job stops being OPEN.
const clearJobNotifications = async (jobId) => {
    if (!jobId) return 0;
    try {
        const { count } = await prisma.notification.deleteMany({
            where: {
                type: 'job_post',
                data: { path: ['jobId'], equals: jobId },
            },
        });
        if (count) console.log(`🧹 Cleared ${count} stale job notification(s) for job ${jobId}`);
        return count;
    } catch (err) {
        // Housekeeping must never break the action that triggered it.
        console.error('clearJobNotifications failed:', err.message);
        return 0;
    }
};

module.exports = {
    sendNotification,
    sendPushNotification: sendNotification, // Alias for backward compatibility
    sendBroadcastNotification,
    clearJobNotifications
};
