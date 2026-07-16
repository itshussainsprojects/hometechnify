// Admin-only guard. Must run AFTER authMiddleware (which sets req.user).
const requireAdmin = (req, res, next) => {
    if (!req.user || req.user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Admin access required',
            code: 'FORBIDDEN',
        });
    }
    next();
};

module.exports = requireAdmin;
