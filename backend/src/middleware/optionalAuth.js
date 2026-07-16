const admin = require('../config/firebase');
const prisma = require('../utils/prisma');

/// Populates req.user when a valid token is present, and simply continues when
/// it is not. For endpoints that are readable by anyone but must reveal more to
/// the owner — e.g. a provider viewing their own profile sees their CNIC and
/// bank details, while a browsing customer sees only the public card.
///
/// Never rejects: a bad or missing token just means "anonymous".
const optionalAuth = async (req, _res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) return next();

        const decoded = await admin.auth().verifyIdToken(authHeader.split(' ')[1]);
        const user = await prisma.user.findUnique({
            where: { firebaseUid: decoded.uid },
        });

        // A blocked user is treated as anonymous here rather than 403'd, since
        // this endpoint is public anyway — they just get no private fields.
        if (user && !user.is_blocked) {
            req.firebaseUser = decoded;
            req.user = user;
        }
    } catch (_) {
        // Anonymous. Public data only.
    }
    next();
};

module.exports = optionalAuth;
