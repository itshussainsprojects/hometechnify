
const admin = require('../config/firebase');
const prisma = require('../utils/prisma');

const authMiddleware = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ success: false, message: 'No token provided' });
        }

        const idToken = authHeader.split(' ')[1];

        // 1. Verify Firebase Token
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.firebaseUser = decodedToken; // { uid, email, picture, ... }

        // 2. Fetch User from Database (Optional: skip for specific routes like /sync)
        if (req.originalUrl.includes('/auth/sync')) {
            return next();
        }

        const user = await prisma.user.findUnique({
            where: { firebaseUid: decodedToken.uid },
        });

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'User does not exist in database. Please call /api/auth/sync first.',
                code: 'USER_NOT_FOUND'
            });
        }

        // Blocked users lose all API access
        if (user.is_blocked) {
            return res.status(403).json({
                success: false,
                message: 'Your account has been blocked. Please contact support.',
                code: 'ACCOUNT_BLOCKED'
            });
        }

        // Deleted (recycle bin) accounts lose access too — an admin can restore
        // them, but until then they must not be able to touch the API.
        if (user.deleted_at) {
            return res.status(403).json({
                success: false,
                message: 'This account has been removed. Please contact support.',
                code: 'ACCOUNT_DELETED'
            });
        }

        req.user = user; // Database user
        next();

    } catch (error) {
        console.error('Auth Error:', error);
        return res.status(401).json({ success: false, message: 'Invalid or expired token', error: error.message });
    }
};

module.exports = authMiddleware;
