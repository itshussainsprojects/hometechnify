
require('dotenv').config();
const app = require('./app');
const http = require('http');
const { initializeSocket } = require('./services/socketService');
const rescheduleScheduler = require('./services/rescheduleScheduler');

const PORT = process.env.PORT || 3000;

// Create HTTP server
const server = http.createServer(app);

// Initialize Socket.IO
const io = initializeSocket(server);
console.log('✅ Socket.IO initialized');

// Start server
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`📡 Socket.IO ready for real-time connections`);
    console.log(`🔌 Binding to 0.0.0.0 (All interfaces)`);

    // Nudge, then auto-decline, reschedule proposals nobody answered. Started
    // after listen so a slow first sweep never delays the server coming up.
    rescheduleScheduler.start();
});
