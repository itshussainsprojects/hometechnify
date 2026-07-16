// Socket.IO Service - Real-time Communication
const admin = require('../config/firebase');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

let io;
const activeUsers = new Map(); // userId -> socketId
const providerLocations = new Map(); // bookingId -> {lat, lng}

const initializeSocket = (httpServer) => {
    const socketIO = require('socket.io');

    // Restrict origins in production via ALLOWED_ORIGINS="https://a.com,https://b.com"
    const allowedOrigins = process.env.ALLOWED_ORIGINS
        ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
        : '*';
    io = socketIO(httpServer, {
        cors: {
            origin: allowedOrigins,
            methods: ['GET', 'POST']
        },
        transports: ['websocket', 'polling']
    });

    io.on('connection', (socket) => {
        console.log('🔌 Client connected:', socket.id);

        // User joins with their ID and name
        socket.on('join', async (data) => {
            // Backward compatible: handle both string and object
            const userId = typeof data === 'string' ? data : data.userId;
            const clientName = typeof data === 'string' ? null : data.name;

            socket.userId = userId;
            socket.userName = clientName || 'User';
            activeUsers.set(userId, socket.id);
            socket.join(`user:${userId}`);
            console.log(`👤 User ${userId} joined (${socket.userName})`);

            // Determine the best name: client-provided or Prisma fallback
            let userName = clientName || 'User';
            const isPlaceholder = !userName || userName === 'User' || userName === 'New User' || userName === 'Provider';

            if (isPlaceholder) {
                try {
                    const dbUser = await prisma.user.findUnique({ where: { id: userId }, select: { name: true } });
                    if (dbUser && dbUser.name) userName = dbUser.name;
                } catch (e) { /* Prisma may be unavailable */ }
            }

            // Sync to Firestore + backfill existing chats
            try {
                // 1. Sync profile to Firestore users collection
                await admin.firestore().collection('users').doc(userId).set({
                    name: userName,
                }, { merge: true });

                // 2. Backfill userNames in ALL existing chats for this user
                const chatsSnap = await admin.firestore().collection('chats')
                    .where('users', 'array-contains', userId).get();

                if (!chatsSnap.empty) {
                    const batch = admin.firestore().batch();
                    chatsSnap.forEach(doc => {
                        batch.update(doc.ref, { [`userNames.${userId}`]: userName });
                    });
                    await batch.commit();
                    console.log(`📋 Synced "${userName}" to ${chatsSnap.size} chat(s)`);
                } else {
                    console.log(`📋 Synced profile for ${userName} (no existing chats)`);
                }
            } catch (err) {
                console.error('Profile sync error:', err.message);
            }

            // Broadcast online status
            io.emit('user_status', { userId, online: true });
        });

        // Join specific booking room (for provider tracking)
        socket.on('join_booking', (bookingId) => {
            socket.join(`booking:${bookingId}`);
            console.log(`📍 Joined booking room: ${bookingId}`);
        });

        // Leave it when the tracking screen closes, so a client stops receiving
        // location fixes for a booking it is no longer watching.
        socket.on('leave_booking', (bookingId) => {
            socket.leave(`booking:${bookingId}`);
            console.log(`📍 Left booking room: ${bookingId}`);
        });

        // Chat: Send message
        socket.on('send_message', async (data) => {
            const { chatId, senderId, senderName, receiverId, message, type, mediaUrl } = data;

            // Save to Firestore
            try {
                const messageDoc = await admin.firestore()
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .add({
                        senderId,
                        receiverId,
                        text: message || '', // Changed 'message' to 'text' to match Flutter MessageModel
                        type: type || 'text',
                        mediaUrl: mediaUrl || null,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        isRead: false
                    });

                // Use client-provided senderName (primary), fallback to socket.userName or Prisma
                const effectiveSenderName = senderName || socket.userName || 'User';

                // CRITICAL: Update Parent Chat Document so it appears in the Chat List
                await admin.firestore().collection('chats').doc(chatId).set({
                    users: [senderId, receiverId],
                    userNames: {
                        [senderId]: effectiveSenderName,
                    },
                    lastMessage: type === 'text' ? (message || '') : `Sent ${type === 'audio' ? 'an' : 'a'} ${type}`,
                    lastTimestamp: admin.firestore.FieldValue.serverTimestamp(),
                    lastSenderId: senderId,
                    participants: {
                        [senderId]: true,
                        [receiverId]: true
                    }
                }, { merge: true });

                const newMessage = {
                    id: messageDoc.id,
                    ...data,
                    timestamp: new Date().toISOString(),
                    isRead: false
                };

                // Emit to receiver
                io.to(`user:${receiverId}`).emit('new_message', newMessage);

                // Confirm to sender
                socket.emit('message_sent', { success: true, messageId: messageDoc.id });

                console.log(`💬 Message sent from ${senderId} to ${receiverId}`);

                // Send FCM Notification to Receiver
                try {
                    const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
                    if (receiverDoc.exists) {
                        const receiverData = receiverDoc.data();
                        if (receiverData.fcmToken) {
                            await admin.messaging().send({
                                token: receiverData.fcmToken,
                                notification: {
                                    title: effectiveSenderName,
                                    body: type === 'text' ? message : (type === 'image' ? '📷 Sent an image' : (type === 'video' ? '🎥 Sent a video' : '🎤 Sent an audio')),
                                },
                                data: {
                                    type: 'chat_message',
                                    chatId: chatId,
                                    senderId: senderId,
                                    route: '/chat',
                                    arguments: JSON.stringify({ recipientId: senderId, name: effectiveSenderName })
                                }
                            });
                            console.log(`🔔 FCM sent to ${receiverId} (from: ${effectiveSenderName})`);
                        }
                    }
                } catch (fcmError) {
                    console.error('FCM Chat Error:', fcmError);
                }

            } catch (error) {
                console.error('Message error:', error);
                socket.emit('message_error', { error: error.message });
            }
        });

        // Chat: Typing indicator
        socket.on('typing', (data) => {
            const { receiverId, isTyping } = data;
            io.to(`user:${receiverId}`).emit('user_typing', {
                userId: socket.userId,
                isTyping
            });
        });

        // Provider Location Update (Real-time tracking)
        socket.on('update_location', (data) => {
            const { bookingId, lat, lng, providerId } = data;

            providerLocations.set(bookingId, { lat, lng, timestamp: Date.now() });

            // Broadcast to all users in booking room (customer watching)
            io.to(`booking:${bookingId}`).emit('provider_location', {
                bookingId,
                providerId,
                lat,
                lng,
                timestamp: Date.now()
            });

            // console.log(`📍 Provider location updated for booking ${bookingId}`);
        });

        // Booking Status Update (Real-time notification)
        socket.on('booking_update', async (data) => {
            const { bookingId, status, userId, message } = data;

            // Emit to specific user
            io.to(`user:${userId}`).emit('booking_status_changed', {
                bookingId,
                status,
                message,
                timestamp: Date.now()
            });

            // Also send Firebase notification
            try {
                const user = await admin.firestore().collection('users').doc(userId).get();
                if (user.exists && user.data().fcmToken) {
                    await admin.messaging().send({
                        token: user.data().fcmToken,
                        notification: {
                            title: 'Booking Update',
                            body: message
                        },
                        data: {
                            type: 'booking_update',
                            bookingId,
                            status
                        }
                    });
                }
            } catch (error) {
                console.error('FCM send error:', error);
            }

            console.log(`🔔 Booking ${bookingId} status: ${status}`);
        });

        // Provider Online/Offline Status
        socket.on('provider_status', (data) => {
            const { providerId, isOnline } = data;
            io.emit('provider_online_status', { providerId, isOnline });
            console.log(`🟢 Provider ${providerId} is ${isOnline ? 'online' : 'offline'}`);
        });

        // Disconnect
        socket.on('disconnect', () => {
            if (socket.userId) {
                activeUsers.delete(socket.userId);
                io.emit('user_status', { userId: socket.userId, online: false });
                console.log(`👋 User ${socket.userId} disconnected`);
            }
            console.log('🔌 Client disconnected:', socket.id);
        });
    });

    return io;
};

// Helper: Send notification to specific user
const sendNotificationToUser = (userId, data) => {
    if (io) {
        io.to(`user:${userId}`).emit('notification', data);
    }
};

// Helper: Broadcast to all users
const broadcastToAll = (event, data) => {
    if (io) {
        io.emit(event, data);
    }
};

// Check if user is online
const isUserOnline = (userId) => {
    return activeUsers.has(userId);
};

module.exports = {
    initializeSocket,
    sendNotificationToUser,
    broadcastToAll,
    isUserOnline,
    getIO: () => io
};
