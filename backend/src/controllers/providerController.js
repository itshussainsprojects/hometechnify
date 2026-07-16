const { randomUUID } = require('crypto');

const prisma = require('../utils/prisma');
const { getProviderRadiusKm, getCommissionPercent } = require('../utils/settings');

// Haversine distance in km between two lat/lng points.
const distanceKm = (lat1, lng1, lat2, lng2) => {
    if ([lat1, lng1, lat2, lng2].some(v => v == null || isNaN(v))) return null;
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

// Get all providers (with filters). Supports:
//   ?categoryId=  ?search=  ?available=true (only online)  ?lat=&lng= (nearest first)
const getProviders = async (req, res) => {
    try {
        const { categoryId, search, available, lat, lng } = req.query;
        const onlineOnly = available === 'true' || available === true;
        const userLat = lat != null ? parseFloat(lat) : null;
        const userLng = lng != null ? parseFloat(lng) : null;

        // Build the provider_profile relation filter incrementally.
        const profileFilter = {};
        if (categoryId) {
            // The app may pass a Category id, a Category name, OR a Service
            // id (e.g. from the job-post flow). Resolve a service id to its
            // parent category so "Plumbing > Tap Repair" still finds plumbers.
            let resolvedCategoryId = categoryId;
            try {
                const svc = await prisma.service.findUnique({
                    where: { id: categoryId },
                    select: { category_id: true },
                });
                if (svc?.category_id) resolvedCategoryId = svc.category_id;
            } catch (_) { /* not a service id - use as-is */ }

            profileFilter.category = {
                OR: [
                    { id: resolvedCategoryId },
                    { name: { equals: categoryId, mode: 'insensitive' } },
                ],
            };
        }
        if (onlineOnly) profileFilter.is_online = true;

        const where = {
            role: 'PROVIDER',
            // A blocked or recycle-binned provider must never be offered to a customer.
            is_blocked: false,
            deleted_at: null,
            // Field filters imply the profile exists; else require it to exist.
            provider_profile: Object.keys(profileFilter).length ? profileFilter : { isNot: null },
        };

        if (search) {
            where.name = { contains: search, mode: 'insensitive' };
        }

        const providers = await prisma.user.findMany({
            where,
            // Public endpoint - expose only safe fields (no firebaseUid, fcmToken,
            // email, phone, CNIC images or bank details).
            select: {
                id: true,
                name: true,
                profileImage: true,
                is_verified: true,
                created_at: true,
                provider_profile: {
                    select: {
                        bio: true,
                        hourly_rate: true,
                        rating: true,
                        is_online: true,
                        is_verified: true,
                        experience: true,
                        services: true,
                        jobs_completed: true,
                        current_lat: true,
                        current_lng: true,
                        category: true,
                    },
                },
            },
        });

        // Attach distance from the customer when a location was provided.
        const hasUserLoc = userLat != null && !isNaN(userLat) && userLng != null && !isNaN(userLng);
        for (const u of providers) {
            const p = u.provider_profile;
            u.distance_km = hasUserLoc && p ? distanceKm(userLat, userLng, p.current_lat, p.current_lng) : null;
        }

        // inDrive-style radius fence: with a customer location, only show
        // providers within the admin-set radius (default 20 km). Far-away
        // providers are dropped entirely, not just ranked lower. Providers
        // with no known location can't prove they're near — drop them too.
        let filtered = providers;
        if (hasUserLoc) {
            const radiusKm = await getProviderRadiusKm();
            filtered = providers.filter(u => u.distance_km != null && u.distance_km <= radiusKm);
        }

        if (hasUserLoc) {
            // Location-based: nearest active providers first (unknown distance last),
            // rating as a tiebreaker.
            // Blended: reward BOTH closeness AND a good rating so a nearby,
            // well-rated provider ranks highest. A great provider slightly
            // farther can still beat a poor one next door; unknown-distance last.
            const geoScore = (u) => {
                const p = u.provider_profile;
                const rating = p?.rating || 0;
                const jobs = Math.min(p?.jobs_completed || 0, 50);
                const d = u.distance_km == null ? 60 : Math.min(u.distance_km, 60);
                return rating * 3            // rating matters a lot
                     - d * 0.5               // nearer is better
                     + (p?.is_verified ? 1.5 : 0)
                     + jobs * 0.05;          // experience nudge
            };
            filtered.sort((a, b) => geoScore(b) - geoScore(a));
        } else {
            // No location: blended rating rank (rating + jobs + online + verified).
            const score = (u) => {
                const p = u.provider_profile;
                if (!p) return -1;
                const rating = p.rating || 0;
                const jobs = Math.min(p.jobs_completed || 0, 100);
                return rating * 10 + jobs * 0.15 + (p.is_online ? 5 : 0) + (p.is_verified ? 3 : 0);
            };
            filtered.sort((a, b) => score(b) - score(a));
        }

        console.log(`getProviders: Found ${filtered.length}/${providers.length} for '${categoryId || 'ALL'}' (online=${onlineOnly}, geo=${hasUserLoc})`);
        res.json({ success: true, data: filtered });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Get provider details.
//
// Customers hit this to view a provider's public card, so it must NEVER return
// the provider's private data. A bare `include` here previously returned the
// whole row: CNIC images, bank account number, phone, email, firebaseUid and
// FCM token. Only the provider themselves (or an admin) gets the private half.
const getProviderById = async (req, res) => {
    try {
        const { id } = req.params;
        const isSelf = req.user?.id === id;
        const isAdmin = req.user?.role === 'ADMIN';
        const privileged = isSelf || isAdmin;

        const provider = await prisma.user.findUnique({
            where: { id },
            select: {
                id: true,
                name: true,
                profileImage: true,
                is_verified: true,
                created_at: true,
                // Contact details are for the two parties of a booking, not the
                // whole internet.
                ...(privileged && { email: true, phone: true }),
                provider_profile: {
                    select: {
                        bio: true,
                        hourly_rate: true,
                        rating: true,
                        is_online: true,
                        is_verified: true,
                        selfie_verified: true,
                        experience: true,
                        services: true,
                        jobs_completed: true,
                        city: true,
                        current_lat: true,
                        current_lng: true,
                        category: true,
                        // Identity documents, payout details and the commission
                        // wallet are private to the provider.
                        ...(privileged && {
                            cnic_front: true,
                            cnic_back: true,
                            selfie_url: true,
                            bank_name: true,
                            account_title: true,
                            account_number: true,
                            wallet_balance: true,
                        }),
                    },
                },
                reviews_received: {
                    select: {
                        rating: true,
                        comment: true,
                        created_at: true,
                        author: { select: { name: true, profileImage: true } },
                    },
                    orderBy: { created_at: 'desc' },
                },
            },
        });

        if (!provider) {
            return res.status(404).json({ success: false, message: 'Provider not found' });
        }

        // Lifetime earnings — only the provider (or an admin) may see it.
        let extra = {};
        if (privileged) {
            const completed = await prisma.booking.aggregate({
                where: { provider_id: id, status: 'COMPLETED' },
                _sum: { total_amount: true },
            });
            extra = {
                totalEarnings: completed._sum.total_amount ?? 0,
                walletBalance: provider.provider_profile?.wallet_balance ?? 0,
            };
        }

        res.json({ success: true, data: { ...provider, ...extra } });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Update Provider Profile (Onboarding/Settings)
const updateProfile = async (req, res) => {
    try {
        const { id } = req.user; // From Auth Middleware
        console.log(`Updating Profile for User ID: ${id}`);
        console.log('Update Data:', req.body);

        const { bio, hourly_rate, service_category_id, experience, cnic_front, cnic_back, name, profileImage, services, bank_name, account_title, account_number, city } = req.body;

        // 1. Update User Basic Info (Name, Image) if provided
        if (name || profileImage) {
            await prisma.user.update({
                where: { id },
                data: {
                    name: name || undefined,
                    profileImage: profileImage || undefined
                }
            });
        }

        // 2. Upsert Provider Profile
        // Ensure we have a valid category ID if creating new
        // The upsert's `create` branch needs SOME category to satisfy the foreign
        // key. It used to take `category.findFirst()` — whatever happened to be
        // first in the table — which is how providers ended up filed as plumbers
        // without anyone choosing that. Park them in "Uncategorized" instead: it
        // matches no jobs, so a wrong guess can never send them the wrong work.
        // An explicit service_category_id from the client always wins.
        let categoryId = service_category_id;
        if (!categoryId) {
            const parking = await prisma.category.findFirst({ where: { name: 'Uncategorized' } })
                ?? await prisma.category.create({ data: { name: 'Uncategorized' } });
            categoryId = parking.id;
        }

        const profile = await prisma.providerProfile.upsert({
            where: { user_id: id },
            update: {
                bio,
                hourly_rate: hourly_rate ? parseFloat(hourly_rate) : undefined,
                // Use 'connect' for relations
                category: service_category_id ? { connect: { id: service_category_id } } : undefined,
                experience,
                cnic_front,
                cnic_back,
                services,
                bank_name,
                account_title,
                account_number,
                city,
                // NOTE: do NOT force is_online here — availability is controlled
                // solely by the toggleAvailability endpoint, so editing the
                // profile never silently flips the provider back to "available".
            },
            create: {
                user: { connect: { id } }, // Connect to existing user
                bio,
                hourly_rate: parseFloat(hourly_rate || 500),
                // Use 'connect' for relations
                category: { connect: { id: categoryId } },
                experience,
                cnic_front,
                cnic_back,
                services: services || [],
                bank_name,
                account_title,
                account_number,
                city,
                is_online: true,
            },
        });

        console.log('Profile Updated Successfully:', profile);
        res.json({ success: true, data: profile });
    } catch (err) {
        console.error("Update Profile Error:", err);
        res.status(500).json({ success: false, message: err.message || "Failed to update profile", error: err.toString() });
    }
};

// Toggle provider availability (Available / Not Available).
// When not available, the provider is hidden from customers and won't be
// surfaced for new jobs.
const toggleAvailability = async (req, res) => {
    try {
        const { id } = req.user;
        const isOnline = req.body.is_online === true || req.body.is_online === 'true';

        // If the app sent the provider's current position along with the
        // toggle, store it - this is what powers "nearest providers first"
        // for customers.
        const data = { is_online: isOnline };
        const lat = parseFloat(req.body.lat);
        const lng = parseFloat(req.body.lng);
        if (!isNaN(lat) && !isNaN(lng)) {
            data.current_lat = lat;
            data.current_lng = lng;
        }

        const profile = await prisma.providerProfile.update({
            where: { user_id: id },
            data,
            select: { is_online: true },
        });

        res.json({ success: true, is_online: profile.is_online });
    } catch (err) {
        // P2025 = no provider profile row yet (onboarding not finished).
        // Return a clear 400 instead of a generic 500 so the app can tell
        // the provider what to do.
        if (err.code === 'P2025') {
            return res.status(400).json({
                success: false,
                message: 'Complete your provider profile first, then you can go available.',
            });
        }
        console.error('Toggle Availability Error:', err);
        res.status(500).json({ success: false, message: 'Failed to update availability' });
    }
};

// Update the provider's live location (used while available so customers
// see accurate distances).
const updateLocation = async (req, res) => {
    try {
        const { id } = req.user;
        const lat = parseFloat(req.body.lat);
        const lng = parseFloat(req.body.lng);
        if (isNaN(lat) || isNaN(lng)) {
            return res.status(400).json({ success: false, message: 'lat and lng are required' });
        }

        await prisma.providerProfile.update({
            where: { user_id: id },
            data: { current_lat: lat, current_lng: lng },
        });

        res.json({ success: true });
    } catch (err) {
        console.error('Update Location Error:', err);
        res.status(500).json({ success: false, message: 'Failed to update location' });
    }
};

// Create Banner Request
const createBannerRequest = async (req, res) => {
    try {
        const providerId = req.user.id;
        console.log(`Creating Banner Request for Provider: ${providerId}`);
        console.log('Banner Request Data:', req.body);

        const { content, banner_image, voice_note, payment_method, account_number, amount } = req.body;

        if (!content || !account_number || !payment_method) {
            return res.status(400).json({ success: false, message: "Missing required fields" });
        }

        const bannerRequest = await prisma.bannerRequest.create({
            data: {
                provider_id: providerId,
                content,
                banner_image,
                voice_note,
                payment_method,
                account_number,
                amount: parseFloat(amount || 500),
                status: 'PENDING'
            }
        });

        console.log('Banner Request Created:', bannerRequest);
        res.json({ success: true, message: "Banner request submitted successfully", data: bannerRequest });
    } catch (err) {
        console.error("Create Banner Request Error:", err);
        res.status(500).json({ success: false, message: "Failed to submit banner request", error: err.toString() });
    }
};

// Get the provider's own transaction history (top-ups, commissions,
// withdrawals, manual admin payouts) — powers the real-time wallet history.
const getMyTransactions = async (req, res) => {
    try {
        const providerId = req.user.id;
        const txns = await prisma.transaction.findMany({
            where: { user_id: providerId },
            orderBy: { created_at: 'desc' },
            take: 100,
        });
        res.json({ success: true, data: txns });
    } catch (err) {
        console.error('Get My Transactions Error:', err);
        res.status(500).json({ success: false, message: 'Failed to fetch transactions' });
    }
};

// Get the provider's active (in-progress) bookings — used by the wallet screen
// to show pending commission. Returns ACCEPTED/ONGOING/NEGOTIATING bookings.
const getActiveBookings = async (req, res) => {
    try {
        const providerId = req.user.id;
        const bookings = await prisma.booking.findMany({
            where: {
                provider_id: providerId,
                status: { in: ['ACCEPTED', 'ONGOING', 'NEGOTIATING'] },
            },
            include: {
                service: { select: { name: true } },
                customer: { select: { name: true, profileImage: true } },
            },
            orderBy: { created_at: 'desc' },
        });
        res.json({ success: true, data: bookings });
    } catch (err) {
        console.error('Get Active Bookings Error:', err);
        res.status(500).json({ success: false, message: 'Failed to fetch active bookings' });
    }
};

// Get Provider Dashboard Stats
const getDashboardStats = async (req, res) => {
    try {
        const providerId = req.user.id;

        // This screen used to fire six queries one after another — a total count,
        // two status counts, all completed bookings pulled back to be summed and
        // bucketed in Node, then the profile — which against a remote database is
        // roughly a second of pure round-trips. The counts, the earnings total and
        // the six-month revenue series are all one scan of the same table, so they
        // fold into ONE query the database buckets itself. That plus the profile
        // and the live commission run in parallel: three round-trips, not six.
        //
        //   "Deal Done"     = jobs won (accepted / ongoing / completed)
        //   "Deal Not Done" = deals still in play (pending / negotiating)
        const [stats, profile, commissionPercent] = await Promise.all([
            prisma.$queryRawUnsafe(`
                SELECT
                  COUNT(*)                                                                    AS total_bookings,
                  COUNT(*) FILTER (WHERE status IN ('ACCEPTED','ONGOING','COMPLETED'))         AS deal_done,
                  COUNT(*) FILTER (WHERE status IN ('PENDING','NEGOTIATING'))                  AS deal_not_done,
                  COALESCE(SUM(total_amount) FILTER (WHERE status='COMPLETED'), 0)             AS total_earnings
                FROM "Booking" WHERE provider_id = $1
            `, providerId),
            prisma.providerProfile.findUnique({
                where: { user_id: providerId },
                select: { rating: true, hourly_rate: true, is_online: true, wallet_balance: true, jobs_completed: true },
            }),
            getCommissionPercent(),
        ]);

        // Last 6 completed-revenue months, bucketed in the DB.
        const monthlyRows = await prisma.$queryRawUnsafe(`
            WITH months AS (
              SELECT to_char(d, 'Mon') AS month, date_trunc('month', d) AS m
              FROM generate_series(date_trunc('month', CURRENT_DATE) - INTERVAL '5 months',
                                   date_trunc('month', CURRENT_DATE), INTERVAL '1 month') d
            )
            SELECT months.month,
              COALESCE((SELECT SUM(b.total_amount) FROM "Booking" b
                        WHERE b.provider_id = $1 AND b.status='COMPLETED'
                          AND date_trunc('month', b.created_at) = months.m), 0) AS amount
            FROM months ORDER BY months.m
        `, providerId);

        const s = stats[0];
        const n = (v) => Number(v) || 0;

        res.json({
            success: true,
            data: {
                totalBookings: n(s.total_bookings),
                dealDone: n(s.deal_done),
                dealNotDone: n(s.deal_not_done),
                totalEarnings: Math.round(n(s.total_earnings)),
                rating: Math.round((profile?.rating || 0.0) * 10) / 10,
                hourlyRate: profile?.hourly_rate || 0.0,
                // No profile = not visible to customers, so default false.
                isAvailable: profile?.is_online ?? false,
                walletBalance: profile?.wallet_balance ?? 0,
                jobsCompleted: profile?.jobs_completed ?? 0,
                // Live admin-set commission % so the bid screen shows the real rate.
                commissionPercent,
                monthlyRevenue: monthlyRows.map(r => ({ month: r.month, amount: n(r.amount) })),
            }
        });
    } catch (err) {
        console.error("Dashboard Stats Error:", err);
        res.status(500).json({ success: false, message: "Failed to fetch dashboard stats" });
    }
};

// DEV MOCK wallet top-up.
// The real payment gateway (JazzCash/EasyPaisa) API is not integrated yet,
// so this credits the wallet instantly for ANY amount - it exists purely so
// the job-post / commission flow can be tested end to end.
// TODO: replace with real gateway verification before production.
const topUpWallet = async (req, res) => {
    try {
        const { id } = req.user;
        const amount = parseFloat(req.body.amount);
        const method = (req.body.payment_method || 'JAZZCASH').toUpperCase();
        if (isNaN(amount) || amount <= 0) {
            return res.status(400).json({ success: false, message: 'A valid amount is required' });
        }

        const [profile] = await prisma.$transaction([
            prisma.providerProfile.update({
                where: { user_id: id },
                data: { wallet_balance: { increment: amount } },
                select: { wallet_balance: true },
            }),
            prisma.transaction.create({
                data: {
                    user_id: id,
                    type: 'TOPUP',
                    // transaction_ref is UNIQUE and this used to be
                    // `DEV-TOPUP-<id>-${Date.now()}`. Date.now() only has
                    // millisecond resolution, so two top-ups landing in the same
                    // millisecond collided on that unique key, the whole
                    // $transaction rolled back — and the wallet increment went
                    // with it. Ten concurrent Rs.100 top-ups credited Rs.400.
                    // The provider's money simply vanished.
                    transaction_ref: `TOPUP-${randomUUID()}`,
                    amount,
                    payment_method: method,
                    status: 'SUCCESS',
                    response_message: 'Dev mock top-up (gateway not integrated)',
                },
            }),
        ]);

        console.log(`DEV top-up: +Rs.${amount} for provider ${id} -> balance Rs.${profile.wallet_balance}`);
        res.json({ success: true, wallet_balance: profile.wallet_balance });
    } catch (err) {
        console.error('TopUp Error:', err);
        res.status(500).json({ success: false, message: 'Failed to top up wallet' });
    }
};

// Get Wallet History (Completed Bookings)
const getWalletHistory = async (req, res) => {
    try {
        const providerId = req.user.id;

        const history = await prisma.booking.findMany({
            where: {
                provider_id: providerId,
                status: 'COMPLETED'
            },
            include: {
                customer: { select: { name: true, profileImage: true } },
                service: { select: { name: true } }
            },
            orderBy: { updated_at: 'desc' }
        });

        res.json({ success: true, data: history });
    } catch (err) {
        console.error("Wallet History Error:", err);
        res.status(500).json({ success: false, message: "Failed to fetch wallet history" });
    }
};

// Request Withdrawal
const requestWithdrawal = async (req, res) => {
    try {
        const providerId = req.user.id;
        const { amount, payment_method, account_number } = req.body;

        if (!amount || !payment_method || !account_number) {
            return res.status(400).json({ success: false, message: 'Amount, payment method, and account number are required' });
        }

        const withdrawAmount = parseFloat(amount);
        if (withdrawAmount < 100) {
            return res.status(400).json({ success: false, message: 'Minimum withdrawal amount is Rs. 100' });
        }

        // Calculate available balance from completed bookings
        const completedBookings = await prisma.booking.findMany({
            where: { provider_id: providerId, status: 'COMPLETED' },
            select: { total_amount: true }
        });
        const totalEarnings = completedBookings.reduce((sum, b) => sum + b.total_amount, 0);

        // Get pending + approved withdrawal requests to deduce available balance
        const previousWithdrawals = await prisma.withdrawalRequest.findMany({
            where: { provider_id: providerId, status: { in: ['PENDING', 'APPROVED'] } },
            select: { amount: true }
        });
        const totalWithdrawn = previousWithdrawals.reduce((sum, t) => sum + t.amount, 0);

        const availableBalance = totalEarnings - totalWithdrawn;

        if (withdrawAmount > availableBalance) {
            return res.status(400).json({ success: false, message: `Insufficient balance. Available: Rs. ${availableBalance.toFixed(0)}` });
        }

        // Create WithdrawalRequest (admin will approve/reject via admin panel)
        const withdrawalRequest = await prisma.withdrawalRequest.create({
            data: {
                provider_id: providerId,
                amount: withdrawAmount,
                payment_method: payment_method,
                account_number: account_number,
                status: 'PENDING',
            }
        });

        res.json({
            success: true,
            message: `Withdrawal of Rs. ${withdrawAmount.toFixed(0)} requested. Will be processed within 24 hours.`,
            data: withdrawalRequest
        });
    } catch (err) {
        console.error('Withdrawal Error:', err);
        res.status(500).json({ success: false, message: 'Failed to process withdrawal' });
    }
};

// Delete Provider Account
const deleteAccount = async (req, res) => {
    try {
        const providerId = req.user.id;

        await prisma.$transaction([
            prisma.providerProfile.deleteMany({ where: { user_id: providerId } }),
            prisma.user.delete({ where: { id: providerId } })
        ]);

        res.json({ success: true, message: "Account deleted successfully" });
    } catch (err) {
        console.error("Delete Account Error:", err);
        res.status(500).json({ success: false, message: "Failed to delete account" });
    }
};

module.exports = {
    getProviders,
    getProviderById,
    updateProfile,
    updateLocation,
    topUpWallet,
    toggleAvailability,
    getDashboardStats,
    getActiveBookings,
    getMyTransactions,
    getWalletHistory,
    deleteAccount,
    createBannerRequest,
    requestWithdrawal
};
