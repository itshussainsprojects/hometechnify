
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

        // Blocked users lose all API access. `role` is included here because a
        // blocked account's /auth/me call always fails with this same 403 - the
        // client then had NO reliable way to know if this is a customer or a
        // provider (it fell back to a locally-cached copy that can be stale or
        // just wrong), so a blocked provider's Logout button silently sent them
        // to the customer login. This 403 response IS the database read, so
        // it's the one place a role can never be stale.
        if (user.is_blocked) {
            return res.status(403).json({
                success: false,
                message: 'Your account has been blocked. Please contact support.',
                code: 'ACCOUNT_BLOCKED',
                role: user.role,
            });
        }

        // Deleted (recycle bin) accounts lose access too — an admin can restore
        // them, but until then they must not be able to touch the API.
        if (user.deleted_at) {
            return res.status(403).json({
                success: false,
                message: 'This account has been removed. Please contact support.',
                code: 'ACCOUNT_DELETED',
                role: user.role,
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
