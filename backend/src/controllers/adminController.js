const { randomUUID } = require('crypto');
const admin = require('../config/firebase');
const prisma = require('../utils/prisma');
const { runLimited } = require('../utils/prisma');
const { getIO, broadcastToAll } = require('../services/socketService');
const { sendNotification } = require('../services/notificationService');
const { sendProviderVerifiedEmail, sendProviderRevokedEmail } = require('../services/emailService');

// Real-time kick/unkick: tell the affected user's app instantly so it can
// log out (blocked) or resume (unblocked) without waiting for the next API call.
const emitBlockEvent = (userId, blocked) => {
    try {
        const io = getIO();
        if (io) io.to(`user:${userId}`).emit(blocked ? 'account_blocked' : 'account_unblocked', {
            message: blocked ? 'Your account has been blocked by admin.' : 'Your account has been unblocked.',
        });
    } catch (_) { /* socket down must never fail the admin action */ }
};

// ─────────────────────────────────────────────
// DASHBOARD STATS
// ─────────────────────────────────────────────
const getDashboardStats = async (req, res) => {
    try {
        // The database is remote (~170 ms per round-trip), so the cost of this
        // screen was almost entirely round-trips, not work: it fired TWELVE
        // separate COUNT/aggregate queries, batched three at a time, which took
        // ~2.7 s. Every one of those numbers is a single scan the database can do
        // in one pass, so they collapse into ONE query — measured ~0.4 s, over
        // six times faster. The two weekly series are a second query. Two
        // round-trips instead of fourteen.
        const [totals] = await prisma.$queryRawUnsafe(`
            SELECT
              (SELECT COUNT(*) FROM "User" WHERE role='CUSTOMER' AND is_blocked=false AND deleted_at IS NULL)                              AS total_users,
              (SELECT COUNT(*) FROM "User" WHERE role='PROVIDER' AND deleted_at IS NULL)                                                    AS total_providers,
              (SELECT COUNT(*) FROM "User" WHERE role='PROVIDER' AND is_verified=true  AND is_blocked=false AND deleted_at IS NULL)         AS verified_providers,
              (SELECT COUNT(*) FROM "User" WHERE role='PROVIDER' AND is_verified=false AND is_blocked=false AND deleted_at IS NULL)         AS pending_providers,
              (SELECT COUNT(*) FROM "User" WHERE role='PROVIDER' AND is_blocked=true)                                                       AS blocked_providers,
              (SELECT COUNT(*) FROM "Booking")                                                                                             AS total_bookings,
              (SELECT COUNT(*) FROM "Booking" WHERE status IN ('ACCEPTED','ONGOING','NEGOTIATING'))                                        AS active_bookings,
              (SELECT COUNT(*) FROM "Booking" WHERE status='COMPLETED')                                                                    AS completed_bookings,
              (SELECT COUNT(*) FROM "Booking" WHERE status='CANCELLED')                                                                    AS cancelled_bookings,
              (SELECT COALESCE(SUM(amount),0) FROM "Transaction" WHERE status='SUCCESS' AND type='PAYMENT')                                AS total_revenue,
              (SELECT COALESCE(SUM(amount),0) FROM "WithdrawalRequest" WHERE status='PENDING')                                             AS pending_withdrawals,
              (SELECT COUNT(*) FROM "Promo" WHERE is_active=true)                                                                          AS total_promos
        `);

        // Last 7 days, bucketed in the database instead of pulling every row back
        // and looping over it in Node.
        const daily = await prisma.$queryRawUnsafe(`
            WITH days AS (
              SELECT generate_series(
                (CURRENT_DATE - INTERVAL '6 days')::date, CURRENT_DATE::date, INTERVAL '1 day'
              )::date AS day
            )
            SELECT d.day,
              COALESCE((SELECT SUM(t.amount) FROM "Transaction" t
                        WHERE t.status='SUCCESS' AND t.type='PAYMENT' AND t.created_at::date = d.day), 0) AS revenue,
              COALESCE((SELECT COUNT(*) FROM "Booking" b WHERE b.created_at::date = d.day), 0)            AS bookings
            FROM days d ORDER BY d.day
        `);

        const n = (v) => Number(v) || 0;
        const weeklyRevenue = daily.map(r => n(r.revenue));
        const weeklyBookings = daily.map(r => n(r.bookings));

        res.json({
            success: true,
            data: {
                totalUsers: n(totals.total_users),
                totalProviders: n(totals.total_providers),
                verifiedProviders: n(totals.verified_providers),
                pendingProviders: n(totals.pending_providers),
                blockedProviders: n(totals.blocked_providers),
                totalBookings: n(totals.total_bookings),
                activeBookings: n(totals.active_bookings),
                completedBookings: n(totals.completed_bookings),
                cancelledBookings: n(totals.cancelled_bookings),
                totalRevenue: n(totals.total_revenue),
                pendingWithdrawalsAmount: n(totals.pending_withdrawals),
                totalActivePromos: n(totals.total_promos),
                weeklyRevenue,
                weeklyBookings,
            },
        });
    } catch (err) {
        console.error('Admin Stats Error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// USERS MANAGEMENT
// ─────────────────────────────────────────────
const getUsers = async (req, res) => {
    try {
        const { status, search, page = 1, limit = 50 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const where = { role: 'CUSTOMER' };
        // status=deleted is the recycle bin. Every other view hides deleted
        // accounts — a deleted user must not keep showing up in the main list.
        where.deleted_at = status === 'deleted' ? { not: null } : null;
        if (status === 'blocked') where.is_blocked = true;
        if (status === 'active') { where.is_blocked = false; }
        if (search) {
            where.OR = [
                { name: { contains: search, mode: 'insensitive' } },
                { email: { contains: search, mode: 'insensitive' } },
                { phone: { contains: search, mode: 'insensitive' } },
            ];
        }

        const [users, total] = await Promise.all([
            prisma.user.findMany({
                where,
                skip,
                take: parseInt(limit),
                select: {
                    id: true, name: true, email: true, phone: true,
                    profileImage: true, is_blocked: true, is_verified: true,
                    created_at: true, deleted_at: true,
                    _count: { select: { bookings_as_customer: true } },
                },
                orderBy: { created_at: 'desc' },
            }),
            prisma.user.count({ where }),
        ]);

        // How much each customer has spent and their rating — this page's
        // own profile screen computes both, but admin had no visibility into
        // either. One grouped query per metric for the whole page, not one
        // query per customer.
        const ids = users.map(u => u.id);
        const [spentByUser, ratingByUser] = ids.length ? await Promise.all([
            prisma.booking.groupBy({
                by: ['customer_id'],
                where: { customer_id: { in: ids }, status: 'COMPLETED' },
                _sum: { total_amount: true },
            }),
            prisma.review.groupBy({
                by: ['target_id'],
                where: { target_id: { in: ids } },
                _avg: { rating: true },
            }),
        ]) : [[], []];
        const spentMap = Object.fromEntries(spentByUser.map(s => [s.customer_id, s._sum.total_amount || 0]));
        const ratingMap = Object.fromEntries(ratingByUser.map(r => [r.target_id, r._avg.rating || 0]));

        const enriched = users.map(u => ({
            ...u,
            total_spent: spentMap[u.id] || 0,
            rating: ratingMap[u.id] || 0,
        }));

        res.json({ success: true, data: enriched, total, page: parseInt(page) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Which customers picked Cash vs Wallet (and which wallet). This was only
// ever saved on the customer's own device (SharedPreferences) — admin had no
// visibility into it at all until it started being synced to the backend.
const getCustomerPaymentMethods = async (req, res) => {
    try {
        const { search } = req.query;
        const where = { role: 'CUSTOMER', deleted_at: null };
        if (search) {
            where.OR = [
                { name: { contains: search, mode: 'insensitive' } },
                { email: { contains: search, mode: 'insensitive' } },
                { phone: { contains: search, mode: 'insensitive' } },
            ];
        }

        const customers = await prisma.user.findMany({
            where,
            select: {
                id: true, name: true, email: true, phone: true, profileImage: true,
                preferred_payment_method: true, preferred_wallet: true, updated_at: true,
            },
            orderBy: { updated_at: 'desc' },
        });

        res.json({ success: true, data: customers });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const blockUser = async (req, res) => {
    try {
        const { id } = req.params;
        const { block } = req.body; // true = block, false = unblock
        const user = await prisma.user.update({
            where: { id },
            data: { is_blocked: block },
            select: { id: true, name: true, is_blocked: true },
        });
        emitBlockEvent(id, block);
        res.json({ success: true, data: user });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Soft delete -> recycle bin. Distinct from blocking: the account is hidden
// everywhere and loses API access, but an admin can still restore it.
const deleteUser = async (req, res) => {
    try {
        const { id } = req.params;
        const user = await prisma.user.update({
            where: { id },
            data: { deleted_at: new Date() },
            select: { id: true, name: true, deleted_at: true },
        });
        emitBlockEvent(id, true); // kick any live session immediately
        res.json({ success: true, data: user, message: 'Moved to recycle bin' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Restore from the recycle bin.
const restoreUser = async (req, res) => {
    try {
        const { id } = req.params;
        const user = await prisma.user.update({
            where: { id },
            data: { deleted_at: null },
            select: { id: true, name: true, deleted_at: true },
        });
        emitBlockEvent(id, false);
        res.json({ success: true, data: user, message: 'Restored' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// PROVIDERS MANAGEMENT
// ─────────────────────────────────────────────
const getProviders = async (req, res) => {
    try {
        const { status, search, page = 1, limit = 50 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const where = { role: 'PROVIDER' };
        // status=deleted is the recycle bin; every other view hides deleted rows.
        where.deleted_at = status === 'deleted' ? { not: null } : null;
        if (status === 'verified') { where.is_verified = true; where.is_blocked = false; }
        if (status === 'unverified') { where.is_verified = false; where.is_blocked = false; }
        if (status === 'blocked') where.is_blocked = true;
        if (search) {
            where.OR = [
                { name: { contains: search, mode: 'insensitive' } },
                { email: { contains: search, mode: 'insensitive' } },
                { phone: { contains: search, mode: 'insensitive' } },
            ];
        }

        const [providers, total] = await Promise.all([
            prisma.user.findMany({
                where,
                skip,
                take: parseInt(limit),
                select: {
                    id: true, name: true, email: true, phone: true,
                    profileImage: true, is_blocked: true, is_verified: true,
                    created_at: true, deleted_at: true,
                    provider_profile: {
                        select: {
                            id: true, bio: true, hourly_rate: true, rating: true,
                            is_online: true, is_verified: true, experience: true,
                            cnic_front: true, cnic_back: true,
                            selfie_url: true, selfie_verified: true,
                            services: true, jobs_completed: true, wallet_balance: true,
                            current_lat: true, current_lng: true, city: true,
                            bank_name: true, account_title: true, account_number: true,
                            category: { select: { id: true, name: true } },
                        },
                    },
                    _count: { select: { bookings_as_provider: true } },
                },
                orderBy: { created_at: 'desc' },
            }),
            prisma.user.count({ where }),
        ]);

        // Earnings per provider = sum of their COMPLETED bookings (real data).
        const ids = providers.map(p => p.id);
        let earningsById = {};
        if (ids.length) {
            const grouped = await prisma.booking.groupBy({
                by: ['provider_id'],
                where: { provider_id: { in: ids }, status: 'COMPLETED' },
                _sum: { total_amount: true },
            });
            earningsById = Object.fromEntries(grouped.map(g => [g.provider_id, g._sum.total_amount || 0]));
        }

        // Attach the rating flag (low/good) vs the admin threshold so the list
        // can show a red warning icon next to low-rated providers.
        const threshold = await getThresholdValue();
        const data = providers.map(p => {
            const rating = p.provider_profile?.rating || 0;
            return {
                ...p,
                totalEarnings: earningsById[p.id] || 0,
                ratingFlag: rating === 0 ? 'none' : (rating < threshold ? 'low' : 'good'),
            };
        });

        res.json({ success: true, data, total, page: parseInt(page), ratingThreshold: threshold });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Verification is the gate that lets a provider receive work.
//
// There are TWO verified flags — User.is_verified and ProviderProfile.is_verified
// — and job matching reads the one on the PROFILE. This only ever wrote the one
// on the User, so an admin could verify a provider, see a green tick, and the
// provider would still receive no jobs at all. Both are now written together.
const verifyProvider = async (req, res) => {
    try {
        const { id } = req.params;
        const { verify } = req.body; // true = verify, false = revoke

        const [user] = await prisma.$transaction([
            prisma.user.update({
                where: { id },
                data: { is_verified: verify },
                select: { id: true, name: true, email: true, is_verified: true },
            }),
            prisma.providerProfile.updateMany({
                where: { user_id: id },
                data: { is_verified: verify },
            }),
        ]);

        // Tell them — being let into the marketplace is the thing they are waiting for.
        // In-app/push is instant; email is a backup for anyone not watching the
        // app right then. Neither is allowed to fail the admin's action.
        try {
            await sendNotification(
                id,
                verify ? 'You are verified' : 'Verification revoked',
                verify
                    ? 'Your documents were approved. Turn on Available to start receiving jobs.'
                    : 'Your verification was revoked. Please contact support.',
                'verification',
                { verified: String(verify) }
            );
        } catch (_) { /* never fail the admin action on a notification hiccup */ }

        try {
            if (verify) {
                await sendProviderVerifiedEmail(user.email, user.name);
            } else {
                await sendProviderRevokedEmail(user.email, user.name);
            }
        } catch (_) { /* never fail the admin action on an email hiccup */ }

        res.json({ success: true, data: user });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Set a provider's trade.
//
// Job matching is by CATEGORY, and until now nothing could set one. The provider
// app never sent a category (the field was commented out of onboarding to dodge a
// foreign-key error), so the backend fell back to `category.findFirst()` — and
// every single provider who ever signed up landed in whatever category happened
// to be first in the table. Fourteen of them were filed as plumbers whether they
// were plumbers or not.
//
// The knock-on effect: an admin could add an "Electrician" category and services
// for it, a customer could post an electrician job — and it would reach nobody,
// because no provider was ever in that category.
const setProviderCategory = async (req, res) => {
    try {
        const { id } = req.params;
        const { categoryId } = req.body;

        if (!categoryId) {
            return res.status(400).json({ success: false, message: 'categoryId is required' });
        }

        const category = await prisma.category.findUnique({
            where: { id: categoryId },
            select: { id: true, name: true },
        });
        if (!category) {
            return res.status(404).json({ success: false, message: 'No such category' });
        }

        const provider = await prisma.user.findUnique({
            where: { id },
            select: { id: true, name: true, role: true },
        });
        if (!provider || provider.role !== 'PROVIDER') {
            return res.status(404).json({ success: false, message: 'No such provider' });
        }

        const profile = await prisma.providerProfile.update({
            where: { user_id: id },
            data: { service_category_id: category.id },
            select: { id: true, category: { select: { id: true, name: true } } },
        });

        try {
            await sendNotification(
                id,
                'Your trade was updated',
                `An admin set your trade to ${category.name}. You will now receive ${category.name} jobs.`,
                'profile_update',
                { categoryId: category.id },
            );
        } catch (_) { /* never fail the admin action on a notification hiccup */ }

        console.log(`🔧 ${provider.name}'s trade set to "${category.name}"`);
        res.json({ success: true, data: { providerId: id, category: profile.category } });
    } catch (err) {
        // P2025 = the provider has no profile row yet.
        if (err.code === 'P2025') {
            return res.status(400).json({
                success: false,
                message: 'This provider has no profile yet. They need to sign in once first.',
            });
        }
        res.status(500).json({ success: false, message: err.message });
    }
};

const blockProvider = async (req, res) => {
    try {
        const { id } = req.params;
        const { block } = req.body;
        const user = await prisma.user.update({
            where: { id },
            data: { is_blocked: block },
            select: { id: true, name: true, is_blocked: true },
        });
        emitBlockEvent(id, block);
        res.json({ success: true, data: user });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const deleteProvider = async (req, res) => {
    try {
        const { id } = req.params;
        const provider = await prisma.user.update({
            where: { id },
            data: { deleted_at: new Date() },
            select: { id: true, name: true, deleted_at: true },
        });
        // A deleted provider must also stop being offered to customers.
        await prisma.providerProfile.updateMany({
            where: { user_id: id },
            data: { is_online: false },
        });
        emitBlockEvent(id, true);
        res.json({ success: true, data: provider, message: 'Moved to recycle bin' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const restoreProvider = async (req, res) => {
    try {
        const { id } = req.params;
        const provider = await prisma.user.update({
            where: { id },
            data: { deleted_at: null },
            select: { id: true, name: true, deleted_at: true },
        });
        emitBlockEvent(id, false);
        res.json({ success: true, data: provider, message: 'Restored' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// RATINGS MANAGEMENT
// ─────────────────────────────────────────────

// Read the admin-set rating threshold (providers below it are flagged).
const getThresholdValue = async () => {
    const row = await prisma.appSetting.findUnique({ where: { key: 'rating_threshold' } });
    const v = row ? parseFloat(row.value) : 2.0;
    return isNaN(v) ? 2.0 : v;
};

// GET /admin/ratings — every provider with rating, review count, blocked state,
// and whether they're below the admin threshold (for the red flag).
const getRatings = async (req, res) => {
    try {
        const threshold = await getThresholdValue();
        const providers = await prisma.user.findMany({
            where: { role: 'PROVIDER', provider_profile: { isNot: null } },
            select: {
                id: true,
                name: true,
                email: true,
                profileImage: true,
                is_blocked: true,
                is_verified: true,
                provider_profile: {
                    select: { rating: true, jobs_completed: true, is_online: true, category: { select: { name: true } } },
                },
                _count: { select: { reviews_received: true } },
            },
        });

        const data = providers.map(u => {
            const rating = u.provider_profile?.rating || 0;
            return {
                id: u.id,
                name: u.name,
                email: u.email,
                profileImage: u.profileImage,
                is_blocked: u.is_blocked,
                is_verified: u.is_verified,
                category: u.provider_profile?.category?.name || 'General',
                rating,
                reviewCount: u._count.reviews_received,
                belowThreshold: rating > 0 && rating < threshold,
                flag: rating === 0 ? 'none' : (rating < threshold ? 'low' : 'good'),
            };
        });
        // Worst first so the admin sees problem providers at the top.
        data.sort((a, b) => a.rating - b.rating);

        res.json({ success: true, threshold, data });
    } catch (err) {
        console.error('getRatings error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

// PUT /admin/providers/:id/rating — admin manually sets/edits a rating (0–5).
const setProviderRating = async (req, res) => {
    try {
        const { id } = req.params;
        const rating = parseFloat(req.body.rating);
        if (isNaN(rating) || rating < 0 || rating > 5) {
            return res.status(400).json({ success: false, message: 'Rating must be between 0 and 5' });
        }
        const profile = await prisma.providerProfile.update({
            where: { user_id: id },
            data: { rating: Math.round(rating * 10) / 10 },
            select: { rating: true },
        });
        res.json({ success: true, rating: profile.rating });
    } catch (err) {
        if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Provider profile not found' });
        res.status(500).json({ success: false, message: err.message });
    }
};

// DELETE /admin/providers/:id/rating — remove/reset a provider's rating to 0.
const resetProviderRating = async (req, res) => {
    try {
        const { id } = req.params;
        await prisma.providerProfile.update({ where: { user_id: id }, data: { rating: 0 } });
        res.json({ success: true, message: 'Rating reset' });
    } catch (err) {
        if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Provider profile not found' });
        res.status(500).json({ success: false, message: err.message });
    }
};

// GET /admin/settings/rating-threshold
const getRatingThreshold = async (req, res) => {
    try {
        res.json({ success: true, threshold: await getThresholdValue() });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// PUT /admin/settings/rating-threshold — admin sets the auto-flag threshold.
const setRatingThreshold = async (req, res) => {
    try {
        const t = parseFloat(req.body.threshold);
        if (isNaN(t) || t < 0 || t > 5) {
            return res.status(400).json({ success: false, message: 'Threshold must be between 0 and 5' });
        }
        await prisma.appSetting.upsert({
            where: { key: 'rating_threshold' },
            update: { value: String(t) },
            create: { key: 'rating_threshold', value: String(t) },
        });
        res.json({ success: true, threshold: t });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// PLATFORM SETTINGS (commission % + provider search radius)
// ─────────────────────────────────────────────

const { getCommissionPercent, getProviderRadiusKm } = require('../utils/settings');
const putSetting = (key, value) => prisma.appSetting.upsert({
    where: { key },
    update: { value: String(value) },
    create: { key, value: String(value) },
});

// GET /admin/settings/platform
const getPlatformSettings = async (req, res) => {
    try {
        res.json({
            success: true,
            data: {
                commission_percent: await getCommissionPercent(),
                provider_radius_km: await getProviderRadiusKm(),
            },
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// PUT /admin/settings/platform — change applies to ALL providers instantly:
// commission is read live at every job completion, radius at every search,
// and the new values are broadcast over Socket.IO so open apps update too.
const setPlatformSettings = async (req, res) => {
    try {
        const out = {};
        if (req.body.commission_percent != null) {
            const c = parseFloat(req.body.commission_percent);
            if (isNaN(c) || c < 0 || c > 50) {
                return res.status(400).json({ success: false, message: 'Commission must be between 0 and 50 (%)' });
            }
            await putSetting('commission_percent', c);
            out.commission_percent = c;
        }
        if (req.body.provider_radius_km != null) {
            const r = parseFloat(req.body.provider_radius_km);
            if (isNaN(r) || r < 1 || r > 200) {
                return res.status(400).json({ success: false, message: 'Radius must be between 1 and 200 km' });
            }
            await putSetting('provider_radius_km', r);
            out.provider_radius_km = r;
        }
        if (!Object.keys(out).length) {
            return res.status(400).json({ success: false, message: 'Nothing to update' });
        }
        broadcastToAll('platform_settings_updated', out);
        res.json({ success: true, data: out });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// BOOKINGS
// ─────────────────────────────────────────────
const getBookings = async (req, res) => {
    try {
        const { status, search, page = 1, limit = 50 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const where = {};
        if (status && status !== 'all') where.status = status.toUpperCase();

        const [bookings, total] = await Promise.all([
            prisma.booking.findMany({
                where,
                skip,
                take: parseInt(limit),
                include: {
                    customer: { select: { id: true, name: true, email: true, phone: true, profileImage: true } },
                    provider: { select: { id: true, name: true, email: true, phone: true, profileImage: true } },
                    service: { select: { id: true, name: true, price: true } },
                    review: true,
                },
                orderBy: { created_at: 'desc' },
            }),
            prisma.booking.count({ where }),
        ]);

        res.json({ success: true, data: bookings, total, page: parseInt(page) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// WITHDRAWALS
// ─────────────────────────────────────────────
const getWithdrawals = async (req, res) => {
    try {
        const { status, page = 1, limit = 50 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);
        const where = {};
        if (status && status !== 'all') where.status = status.toUpperCase();

        const [withdrawals, total] = await Promise.all([
            prisma.withdrawalRequest.findMany({
                where,
                skip,
                take: parseInt(limit),
                include: {
                    provider: {
                        select: { id: true, name: true, email: true, phone: true, profileImage: true },
                    },
                },
                orderBy: { created_at: 'desc' },
            }),
            prisma.withdrawalRequest.count({ where }),
        ]);

        // Attach a human-readable challan/reference (provider-id based) so the
        // admin can quote it when paying and tracking the request.
        const data = withdrawals.map(w => ({
            ...w,
            challan: `CH-${(w.provider_id || '').substring(0, 6).toUpperCase()}-${w.id.substring(0, 6).toUpperCase()}`,
        }));

        res.json({ success: true, data, total });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const updateWithdrawal = async (req, res) => {
    try {
        const { id } = req.params;
        const { action, admin_note } = req.body; // action: 'APPROVED' | 'REJECTED'

        const withdrawal = await prisma.withdrawalRequest.update({
            where: { id },
            data: { status: action, admin_note, updated_at: new Date() },
            include: { provider: { select: { id: true, name: true, fcmToken: true } } },
        });

        // If approved, log a transaction for provider
        if (action === 'APPROVED') {
            await prisma.transaction.create({
                data: {
                    user_id: withdrawal.provider_id,
                    type: 'WITHDRAWAL',
                    transaction_ref: `WD-${withdrawal.id}`,
                    amount: withdrawal.amount,
                    payment_method: withdrawal.payment_method,
                    status: 'SUCCESS',
                    response_message: 'Withdrawal approved by admin',
                },
            });
        }

        // The provider previously only found out by manually checking their
        // wallet history — nothing told them the outcome of their own request.
        try {
            await sendNotification(
                withdrawal.provider_id,
                action === 'APPROVED' ? 'Withdrawal Approved' : 'Withdrawal Rejected',
                action === 'APPROVED'
                    ? `Your withdrawal of Rs. ${withdrawal.amount} has been approved and processed.`
                    : `Your withdrawal request was rejected.${admin_note ? ` Reason: ${admin_note}` : ''}`,
                'withdrawal',
                { withdrawalId: withdrawal.id, status: action }
            );
        } catch (_) { /* never fail the admin action on a notification hiccup */ }

        res.json({ success: true, data: withdrawal });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// ADMIN TRANSACTIONS (manual payout records under a withdrawal)
// ─────────────────────────────────────────────

// List a provider's transactions (topups, commissions, withdrawals, manual).
const getProviderTransactions = async (req, res) => {
    try {
        const { id } = req.params; // provider user id
        const txns = await prisma.transaction.findMany({
            where: { user_id: id },
            orderBy: { created_at: 'desc' },
            take: 100,
        });
        res.json({ success: true, data: txns });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Admin manually records that a provider was paid (or any adjustment).
const createTransaction = async (req, res) => {
    try {
        const { userId, amount, type, payment_method, status, note } = req.body;
        if (!userId || amount == null) {
            return res.status(400).json({ success: false, message: 'userId and amount are required' });
        }
        const txn = await prisma.transaction.create({
            data: {
                user_id: userId,
                type: type || 'WITHDRAWAL',
                transaction_ref: `MAN-${randomUUID()}`,
                amount: parseFloat(amount),
                payment_method: payment_method || 'MANUAL',
                status: status || 'SUCCESS', // SUCCESS = paid, PENDING = not yet
                response_message: note || 'Recorded by admin',
            },
        });
        res.status(201).json({ success: true, data: txn });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Edit a transaction (fix amount / mark paid-unpaid / note).
const updateTransaction = async (req, res) => {
    try {
        const { id } = req.params;
        const { amount, status, payment_method, note } = req.body;
        const txn = await prisma.transaction.update({
            where: { id },
            data: {
                ...(amount !== undefined && { amount: parseFloat(amount) }),
                ...(status !== undefined && { status }),
                ...(payment_method !== undefined && { payment_method }),
                ...(note !== undefined && { response_message: note }),
                updated_at: new Date(),
            },
        });
        res.json({ success: true, data: txn });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Delete a transaction record.
const deleteTransaction = async (req, res) => {
    try {
        const { id } = req.params;
        await prisma.transaction.delete({ where: { id } });
        res.json({ success: true, message: 'Transaction removed' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// PROMOS
// ─────────────────────────────────────────────
const getPromos = async (req, res) => {
    try {
        const promos = await prisma.promo.findMany({ orderBy: { created_at: 'desc' } });
        res.json({ success: true, data: promos });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const createPromo = async (req, res) => {
    try {
        const { title, subtitle, code, discount, color_value, is_active } = req.body;
        const promo = await prisma.promo.create({
            data: { title, subtitle, code, discount: parseFloat(discount || 0), color_value: parseInt(color_value || 0xFF1565C0), is_active: is_active !== false },
        });
        // Nothing told a running customer app a promo changed — home_screen.dart
        // memoizes its promo fetch for the life of the widget state, so a new
        // promo was invisible until the app was fully restarted. This is what
        // that listener refetches on (see home_screen.dart's onPromosUpdated).
        broadcastToAll('promos_updated', {});
        res.status(201).json({ success: true, data: promo });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const updatePromo = async (req, res) => {
    try {
        const { id } = req.params;
        const { title, subtitle, code, discount, color_value, is_active } = req.body;
        const promo = await prisma.promo.update({
            where: { id },
            data: {
                ...(title !== undefined && { title }),
                ...(subtitle !== undefined && { subtitle }),
                ...(code !== undefined && { code }),
                ...(discount !== undefined && { discount: parseFloat(discount) }),
                ...(color_value !== undefined && { color_value: parseInt(color_value) }),
                ...(is_active !== undefined && { is_active }),
            },
        });
        broadcastToAll('promos_updated', {});
        res.json({ success: true, data: promo });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const deletePromo = async (req, res) => {
    try {
        const { id } = req.params;
        await prisma.promo.delete({ where: { id } });
        broadcastToAll('promos_updated', {});
        res.json({ success: true, message: 'Promo deleted' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// SEND NOTIFICATION (FCM via Firebase Admin)
// ─────────────────────────────────────────────
const sendAdminNotification = async (req, res) => {
    try {
        const { title, body, target_type, user_ids } = req.body;
        // target_type: 'ALL_USERS' | 'ALL_PROVIDERS' | 'SPECIFIC'

        let targetUsers = [];
        if (target_type === 'ALL_USERS') {
            targetUsers = await prisma.user.findMany({
                where: { role: 'CUSTOMER', is_blocked: false, fcmToken: { not: null } },
                select: { id: true, firebaseUid: true, fcmToken: true },
            });
        } else if (target_type === 'ALL_PROVIDERS') {
            targetUsers = await prisma.user.findMany({
                where: { role: 'PROVIDER', is_blocked: false, fcmToken: { not: null } },
                select: { id: true, firebaseUid: true, fcmToken: true },
            });
        } else if (target_type === 'ALL') {
            targetUsers = await prisma.user.findMany({
                where: { is_blocked: false, fcmToken: { not: null } },
                select: { id: true, firebaseUid: true, fcmToken: true },
            });
        } else if (target_type === 'SPECIFIC' && user_ids?.length > 0) {
            targetUsers = await prisma.user.findMany({
                where: { id: { in: user_ids }, fcmToken: { not: null } },
                select: { id: true, firebaseUid: true, fcmToken: true },
            });
        }

        // Save notifications to DB for each target user
        const notifData = targetUsers.map(u => ({
            user_id: u.id,
            title,
            body,
            type: 'SYSTEM',
            data: { source: 'admin' },
        }));

        if (notifData.length > 0) {
            await prisma.notification.createMany({ data: notifData });
        }

        // This used to stop at the DB row — an admin broadcast never
        // actually pushed to a device. It silently did nothing until (or
        // unless) the recipient happened to open their notifications screen
        // and it polled the DB. Real-time in-app (matches every other
        // notification path) plus an actual FCM push, chunked to the
        // 500-token limit like the existing broadcast helper does.
        let pushSuccessCount = 0;
        try {
            const io = getIO();
            for (const u of targetUsers) {
                if (io) {
                    io.to(`user:${u.id}`).emit('notification', {
                        title, body, type: 'SYSTEM', data: { source: 'admin' },
                    });
                }
            }

            const tokens = targetUsers.map(u => u.fcmToken).filter(Boolean);
            const stringData = { type: 'SYSTEM', source: 'admin', click_action: 'FLUTTER_NOTIFICATION_CLICK' };
            for (let i = 0; i < tokens.length; i += 500) {
                const batch = tokens.slice(i, i + 500);
                const response = await admin.messaging().sendEachForMulticast({
                    tokens: batch,
                    notification: { title, body },
                    data: stringData,
                });
                pushSuccessCount += response.successCount;
            }
        } catch (pushError) {
            console.error('Admin broadcast push failed (DB rows still saved):', pushError.message);
        }

        res.json({
            success: true,
            message: `Notification sent to ${notifData.length} users (${pushSuccessCount} push delivered)`,
            sent_count: notifData.length,
            push_success_count: pushSuccessCount,
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─────────────────────────────────────────────
// FINANCE STATS
// ─────────────────────────────────────────────
const getFinanceStats = async (req, res) => {
    try {
        const [totalRevenue, totalWithdrawn, pendingWithdrawals, recentTransactions] = await runLimited([
            () => prisma.transaction.aggregate({
                _sum: { amount: true },
                where: { status: 'SUCCESS', type: 'PAYMENT' },
            }),
            () => prisma.transaction.aggregate({
                _sum: { amount: true },
                where: { status: 'SUCCESS', type: 'WITHDRAWAL' },
            }),
            () => prisma.withdrawalRequest.findMany({
                where: { status: 'PENDING' },
                include: { provider: { select: { id: true, name: true } } },
                orderBy: { created_at: 'desc' },
                take: 10,
            }),
            () => prisma.transaction.findMany({
                orderBy: { created_at: 'desc' },
                take: 20,
                include: { user: { select: { id: true, name: true } } },
            }),
        ], 2);

        res.json({
            success: true,
            data: {
                totalRevenue: totalRevenue._sum.amount || 0,
                totalWithdrawn: totalWithdrawn._sum.amount || 0,
                netRevenue: (totalRevenue._sum.amount || 0) - (totalWithdrawn._sum.amount || 0),
                pendingWithdrawals,
                recentTransactions,
            },
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = {
    getDashboardStats,
    getUsers,
    getCustomerPaymentMethods,
    blockUser,
    deleteUser,
    restoreUser,
    getProviders,
    verifyProvider,
    setProviderCategory,
    blockProvider,
    deleteProvider,
    restoreProvider,
    getBookings,
    getWithdrawals,
    updateWithdrawal,
    getProviderTransactions,
    createTransaction,
    updateTransaction,
    deleteTransaction,
    getPromos,
    createPromo,
    updatePromo,
    deletePromo,
    sendAdminNotification,
    getFinanceStats,
    getRatings,
    setProviderRating,
    resetProviderRating,
    getRatingThreshold,
    setRatingThreshold,
    getPlatformSettings,
    setPlatformSettings,
};
