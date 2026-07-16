
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const authRoutes = require('./routes/authRoutes');
const coreRoutes = require('./routes/coreRoutes');
const providerRoutes = require('./routes/providerRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const addressRoutes = require('./routes/addressRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const jobRoutes = require('./routes/jobRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const adminRoutes = require('./routes/adminRoutes');

const app = express();

// Restrict origins in production via ALLOWED_ORIGINS="https://a.com,https://b.com"
app.use(cors(
    process.env.ALLOWED_ORIGINS
        ? { origin: process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim()) }
        : {}
));
app.use(helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true })); // For form data from payment gateways

// Behind a proxy (Render/Railway/nginx) the client IP arrives in X-Forwarded-For.
// Without this the rate limiter would see every request as coming from the proxy
// and throttle all users as one.
app.set('trust proxy', 1);

// ── Rate limiting ─────────────────────────────────────────────────────────
// The API had none: a single script could hammer sign-in, spam job posts, or
// walk the provider list without any brake.
const generalLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 120,                 // per IP per minute — comfortably above real usage
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many requests. Please slow down.' },
});

// Auth and uploads are the expensive, abusable ones.
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 30,                  // 30 sign-in / sync attempts per IP per 15 min
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many attempts. Please try again later.' },
});

const uploadLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 20,                  // uploads are 100 MB-capable; don't let them flood
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many uploads. Please wait a moment.' },
});

app.use('/api', generalLimiter);

app.use('/api/auth', authLimiter, authRoutes);
app.use('/api', coreRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/addresses', addressRoutes);
app.use('/api/providers', providerRoutes);
app.use('/api/upload', uploadLimiter, uploadRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/jobs', jobRoutes);
// Payment gateway callbacks are server-to-server; the general limiter is enough
// and a stricter one risks dropping a legitimate settlement callback.
app.use('/api/payments', paymentRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/admin', adminRoutes);

// Serve static assets (images)
const path = require('path');
app.use('/assets', express.static(path.join(__dirname, '../assets')));

// Unmatched API route -> a clean 404, not the HTML default.
app.use('/api', (req, res) => {
    res.status(404).json({ success: false, message: `No such endpoint: ${req.method} ${req.originalUrl}` });
});

// Error Handling Middleware
app.use((err, req, res, next) => {
    console.error(err.stack);

    // Multer rejects oversized or wrong-type uploads — that is the client's
    // fault, not a server fault, and it deserves a message it can act on.
    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ success: false, message: 'File is too large (max 100 MB).' });
    }
    if (err.message && err.message.includes('Only image, video, and audio')) {
        return res.status(415).json({ success: false, message: err.message });
    }

    // Never hand an internal error message to a client in production — it leaks
    // table names, file paths and query fragments.
    const isProd = process.env.NODE_ENV === 'production';
    res.status(err.status || 500).json({
        success: false,
        message: isProd ? 'Something went wrong. Please try again.' : (err.message || 'Internal Server Error'),
    });
});

module.exports = app;
