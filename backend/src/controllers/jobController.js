const prisma = require('../utils/prisma');
const { sendNotification, sendBroadcastNotification, clearJobNotifications } = require('../services/notificationService');
const { getProviderRadiusKm } = require('../utils/settings');
const { validateBidPrice } = require('../utils/bidding');

// ── Location-based matching ────────────────────────────────────────────

// Haversine distance in km between two coordinates
const distanceKm = (lat1, lng1, lat2, lng2) => {
    const toRad = (d) => (d * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

// Create a new job post with media
exports.createJob = async (req, res) => {
    try {
        console.log('\n=== CREATE JOB REQUEST ===');
        const userId = req.user.id; // From authMiddleware
        console.log('User ID:', userId);

        const { title, description, budget, location, serviceId } = req.body;

        // Validate what the provider will actually see. A blank title rendered as
        // an empty card in every provider's feed; a 5,000-character one wrecked
        // the layout of every list it appeared in.
        const cleanTitle = String(title ?? '').trim();
        const cleanDescription = String(description ?? '').trim();
        const cleanLocation = String(location ?? '').trim();

        if (!cleanTitle) {
            return res.status(400).json({ error: 'A job title is required' });
        }
        if (cleanTitle.length > 120) {
            return res.status(400).json({ error: 'The job title is too long (max 120 characters)' });
        }
        if (cleanDescription.length > 2000) {
            return res.status(400).json({ error: 'The description is too long (max 2000 characters)' });
        }
        if (!cleanLocation) {
            return res.status(400).json({ error: 'A location is required' });
        }

        // Job-site coordinates: prefer what the app sends; fall back to the
        // customer's most recent saved address that has coordinates. These
        // power the provider-side map / arrived-GPS check on the booking.
        let lat = req.body.lat != null ? parseFloat(req.body.lat) : null;
        let lng = req.body.lng != null ? parseFloat(req.body.lng) : null;
        if (isNaN(lat)) lat = null;
        if (isNaN(lng)) lng = null;
        if (lat == null || lng == null) {
            const addr = await prisma.address.findFirst({
                where: { user_id: userId, lat: { not: null }, lng: { not: null } },
                orderBy: { created_at: 'desc' },
                select: { lat: true, lng: true },
            });
            if (addr) { lat = addr.lat; lng = addr.lng; }
        }
        console.log('Title:', title);
        console.log('Description:', description);
        console.log('Location:', location);
        console.log('Budget:', budget);

        // Resolve the job's category from the chosen service so that providers
        // of that service (and the customer's provider list) match correctly.
        // Falls back to an explicit category, then "General".
        let category = req.body.category || 'General';
        if (serviceId) {
            const svc = await prisma.service.findUnique({
                where: { id: serviceId },
                select: { category: { select: { name: true } } },
            });
            if (svc && svc.category && svc.category.name) category = svc.category.name;
        }
        console.log('Resolved category:', category);

        // Handle uploaded files (from uploadCloudinary middleware)
        // Expecting req.files to be an array or object
        let mediaUrls = [];
        if (req.files && Array.isArray(req.files)) {
            console.log('Files received:', req.files.length);
            mediaUrls = req.files.map(file => file.path);
            console.log('Media URLs:', mediaUrls);
        } else {
            console.log('No files received');
        }

        console.log('Attempting to save to database...');
        const job = await prisma.jobPost.create({
            data: {
                customer_id: userId,
                title: cleanTitle,
                description: cleanDescription,
                budget: budget ? parseFloat(budget) : null,
                location: cleanLocation,
                lat,
                lng,
                category, // resolved from the service's category above
                mediaUrls: mediaUrls,
                status: 'OPEN'
            }
        });

        // Notify AVAILABLE providers of this job's category, nearest first.
        //
        // This is a location-based marketplace: notifications now use the SAME
        // rule the customer's browse list does, so the two can never disagree.
        // When the job has coordinates, a provider must have a known location
        // within the radius to be pinged — sending a "job near you" to someone
        // whose position is unknown (and could be 200 km away) is spam, and it
        // let providers who never turn their location on quietly hoover up work
        // they should never have seen. No location, no job.
        //
        // When the job has NO coordinates (the customer never shared theirs),
        // distance can't be measured for anyone, so we fall back to notifying
        // every eligible provider of that trade — nobody is unfairly excluded on
        // a job that has no location to compare against either.
        let notifyFailed = false;
        try {
            const radiusKm = await getProviderRadiusKm();
            const profiles = await prisma.providerProfile.findMany({
                where: {
                    is_online: true,
                    is_verified: true,
                    // Blocked / recycle-binned providers get no work.
                    user: { is_blocked: false, deleted_at: null },
                    ...(category && category !== 'General'
                        ? { category: { name: { equals: category, mode: 'insensitive' } } }
                        : {}),
                },
                select: { user_id: true, current_lat: true, current_lng: true },
            });

            const jobHasLocation = lat != null && lng != null;

            let targets;
            if (jobHasLocation) {
                // Distance-fenced: exactly like the browse list. A provider with
                // no known location is dropped, not guessed at.
                targets = profiles
                    .map(p => ({
                        user_id: p.user_id,
                        dist: (p.current_lat != null && p.current_lng != null)
                            ? distanceKm(lat, lng, p.current_lat, p.current_lng)
                            : null,
                    }))
                    .filter(p => p.dist != null && p.dist <= radiusKm)
                    .sort((a, b) => a.dist - b.dist);
            } else {
                // No job location -> distance is meaningless for everyone, so
                // notify the whole trade.
                targets = profiles.map(p => ({ user_id: p.user_id, dist: null }));
            }

            for (const p of targets) {
                sendNotification(
                    p.user_id,
                    p.dist != null ? 'New Job Near You' : 'New Job Posted',
                    p.dist != null
                        ? `New Job: ${title} in ${location} (${p.dist.toFixed(1)} km away)`
                        : `New Job: ${title} in ${location}`,
                    'job_post',
                    { jobId: job.id, ...(p.dist != null ? { distanceKm: p.dist.toFixed(1) } : {}) }
                );
            }
            const dropped = jobHasLocation
                ? profiles.filter(p => p.current_lat == null || p.current_lng == null).length
                : 0;
            console.log(`📍 Notified ${targets.length} providers (radius ${radiusKm} km, ${dropped} dropped for no location)`);
        } catch (e) {
            notifyFailed = true;
            console.error('Provider notify failed, falling back to broadcast:', e.message);
        }
        if (notifyFailed) {
            await sendBroadcastNotification(
                'PROVIDER',
                'New Job Posted',
                `New Job: ${title} in ${location}`,
                { type: 'job_post', jobId: job.id },
                { category }
            );
        }

        console.log('✅ JOB CREATED SUCCESSFULLY:', job.id);
        res.status(201).json(job);
    } catch (error) {
        console.error('❌ Create Job Error:', error);
        res.status(500).json({ error: 'Failed to create job post', details: error.message });
    }
};

// Get My Jobs (Customer)
exports.getMyJobs = async (req, res) => {
    try {
        console.log('\n=== GET MY JOBS REQUEST ===');
        const userId = req.user.id;
        console.log('User ID:', userId);

        const jobs = await prisma.jobPost.findMany({
            where: { customer_id: userId },
            orderBy: { created_at: 'desc' },
        });

        console.log('Jobs found:', jobs.length);
        jobs.forEach(j => console.log(' - Job:', j.id, j.title));

        res.json(jobs);
    } catch (error) {
        console.error('❌ Get My Jobs Error:', error);
        res.status(500).json({ error: 'Failed to fetch jobs' });
    }
};

// Get Nearby Jobs (Provider) - Simplified to All Open Jobs for now
exports.getNearbyJobs = async (req, res) => {
    try {
        let { category } = req.query;

        const profile = req.user
            ? await prisma.providerProfile.findUnique({
                where: { user_id: req.user.id },
                select: {
                    is_online: true,
                    current_lat: true,
                    current_lng: true,
                    category: { select: { name: true } },
                },
            })
            : null;

        // The availability toggle has to actually mean something: a provider
        // who set themselves Not Available gets no job feed at all.
        if (profile && !profile.is_online) {
            console.log('Provider is offline — returning empty job feed');
            return res.json([]);
        }

        // Default to the provider's OWN trade: a plumber's feed shows
        // plumbing jobs (plus uncategorized "General" ones), never other
        // categories' work.
        if (!category && profile?.category?.name) category = profile.category.name;
        console.log('Fetching nearby jobs with category:', category);

        const whereClause = { status: 'OPEN' };

        if (category && category !== 'General') {
            whereClause.OR = [
                { category: { equals: category, mode: 'insensitive' } },
                { category: 'General' }, // uncategorized jobs visible to all
                { title: { contains: category, mode: 'insensitive' } },
                { description: { contains: category, mode: 'insensitive' } }
            ];
        }

        let jobs = await prisma.jobPost.findMany({
            where: whereClause, // Use the dynamic where clause
            orderBy: { created_at: 'desc' },
            include: {
                customer: {
                    select: {
                        name: true,
                        profileImage: true,
                        is_verified: true,
                        addresses: {
                            select: { address: true }
                        }
                    }
                }
            }
        });

        // Location-based: sort by distance from the provider's current
        // location and hide jobs beyond the admin-configured radius. Jobs
        // without coordinates stay visible (at the end). If the provider has
        // no location saved, the feed is unchanged.
        //
        // This used to hide anything past a hardcoded 30km regardless of what
        // the admin set provider_radius_km to elsewhere in the app (customer's
        // provider browse list, job-post notification fan-out) — an admin
        // narrowing the radius to, say, 10km had no effect on this screen.
        if (profile?.current_lat != null && profile?.current_lng != null) {
            const radiusKm = await getProviderRadiusKm();
            jobs = jobs
                .map(j => ({
                    ...j,
                    distance_km: (j.lat != null && j.lng != null)
                        ? Math.round(distanceKm(profile.current_lat, profile.current_lng, j.lat, j.lng) * 10) / 10
                        : null,
                }))
                .filter(j => j.distance_km == null || j.distance_km <= radiusKm)
                .sort((a, b) => (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity));
        }
        res.json(jobs);
    } catch (error) {
        console.error("Get Nearby Jobs Error:", error);
        res.status(500).json({ error: 'Failed to fetch nearby jobs' });
    }
};


// Update Job
exports.updateJob = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        const { title, description, budget, location, status } = req.body;

        // Check ownership
        const existingJob = await prisma.jobPost.findUnique({ where: { id } });
        if (!existingJob) return res.status(404).json({ error: 'Job not found' });
        if (existingJob.customer_id !== userId) return res.status(403).json({ error: 'Unauthorized' });

        // Parse mediaToDelete
        let mediaToDelete = [];
        console.log('[UpdateJob] Body mediaToDelete:', req.body.mediaToDelete);

        if (req.body.mediaToDelete) {
            try {
                // Handle double-encoded JSON if happens, or standard JSON
                if (typeof req.body.mediaToDelete === 'string') {
                    mediaToDelete = JSON.parse(req.body.mediaToDelete);
                } else if (Array.isArray(req.body.mediaToDelete)) {
                    mediaToDelete = req.body.mediaToDelete;
                }
            } catch (e) {
                console.error('[UpdateJob] JSON Parse Error:', e);
                // Fallback: if it's a single string URL somehow
                if (typeof req.body.mediaToDelete === 'string') mediaToDelete = [req.body.mediaToDelete];
            }
        }

        console.log('[UpdateJob] Parsed mediaToDelete:', mediaToDelete);

        let updatedMedia = existingJob.mediaUrls;
        console.log('[UpdateJob] Original Media:', updatedMedia);

        // Remove deleted media (Exact Match)
        if (mediaToDelete.length > 0) {
            updatedMedia = updatedMedia.filter(url => !mediaToDelete.includes(url));
            console.log('[UpdateJob] After Deletion:', updatedMedia);
        }

        // Add new media
        if (req.files && req.files.length > 0) {
            const newUrls = req.files.map(file => file.path); // Use Supabase URL from file.path
            updatedMedia = [...updatedMedia, ...newUrls];
        }

        const job = await prisma.jobPost.update({
            where: { id },
            data: {
                title,
                description,
                budget: budget ? parseFloat(budget) : undefined,
                location,
                status,
                mediaUrls: updatedMedia
            }
        });

        // If the customer closed the job, the providers' "New Job Posted" alerts
        // now open nothing.
        if (job.status !== 'OPEN') await clearJobNotifications(id);

        res.json(job);
    } catch (error) {
        res.status(500).json({ error: 'Failed to update job' });
    }
};

// Delete Job
exports.deleteJob = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const existingJob = await prisma.jobPost.findUnique({ where: { id } });
        if (!existingJob) return res.status(404).json({ error: 'Job not found' });
        if (existingJob.customer_id !== userId) return res.status(403).json({ error: 'Unauthorized' });

        await prisma.jobPost.delete({ where: { id } });

        // The notifications outlive the job otherwise: every provider who was
        // alerted keeps a card that opens nothing, and their unread badge never
        // comes back down.
        await clearJobNotifications(id);

        res.json({ message: 'Job deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete job' });
    }
};

// Which service does this job map to?
//   1) a service whose category matches the job's category
//   2) else a service in the provider's own category
//   3) else any service (last resort)
const resolveServiceForJob = async (job, providerId) => {
    let service = await prisma.service.findFirst({
        where: { category: { name: { equals: job.category, mode: 'insensitive' } } },
    });
    if (!service) {
        const profile = await prisma.providerProfile.findUnique({ where: { user_id: providerId } });
        if (profile) {
            service = await prisma.service.findFirst({
                where: { category_id: profile.service_category_id },
            });
        }
    }
    if (!service) service = await prisma.service.findFirst();
    return service;
};

// Accept Job (Provider) - Converts JobPost to Booking
exports.acceptJob = async (req, res) => {
    try {
        const { id } = req.params; // Job ID
        const providerId = req.user.id;
        const { price } = req.body; // Provider's bid/price

        // 1. Check if job exists and is OPEN
        const job = await prisma.jobPost.findUnique({
            where: { id },
            include: { customer: true } // Need customer info to create booking
        });

        if (!job) return res.status(404).json({ error: 'Job not found' });
        if (job.status !== 'OPEN') return res.status(400).json({ error: 'Job is no longer available' });
        if (job.customer_id === providerId) return res.status(400).json({ error: 'Cannot accept your own job' });

        // Smart Bidding fence. THIS is the screen where a provider names their
        // price, and it was the one place the admin's min/max was never checked —
        // so a service bounded to Rs. 500-1,500 would happily take a Rs. 1 quote.
        const quotedService = await resolveServiceForJob(job, providerId);
        if (quotedService) {
            const priceCheck = await validateBidPrice(quotedService.id, price);
            if (!priceCheck.ok) {
                return res.status(400).json({ success: false, error: priceCheck.message, message: priceCheck.message });
            }
        }

        // Commission-wallet gate (inDrive model): a provider whose wallet has
        // gone negative owes commission and must top up before taking new work.
        const gateProfile = await prisma.providerProfile.findUnique({
            where: { user_id: providerId },
            select: { wallet_balance: true },
        });
        if (gateProfile && gateProfile.wallet_balance < 0) {
            return res.status(403).json({
                error: 'Wallet balance is negative. Please top up your wallet to accept new jobs.',
                code: 'WALLET_TOPUP_REQUIRED',
                wallet_balance: gateProfile.wallet_balance,
            });
        }

        // 2. Create Booking
        // Use a transaction to ensure atomicity
        const result = await prisma.$transaction(async (prisma) => {
            // NO LONGER CLOSING JOB HERE - Job remains OPEN for other bids
            // await prisma.jobPost.update({
            //     where: { id },
            //     data: { status: 'IN_PROGRESS' }
            // });

            // Find or Create Service (Technical Debt: We need a Service ID for booking. For now, use a generic "Custom Job" service or find one)
            // Ideally, we should have a 'Custom Service' type. 
            // Fallback: Use the provider's valid category service if possible, or create a placeholder.
            // Simplified: We'll assume a "General Service" exists or use the first available service for the category.
            // BETTER: Use job.title as service name dynamically? Booking expects valid service_id.

            // Same service the price fence above was checked against — resolving
            // it twice by different rules would let a quote be validated against
            // one service and booked against another.
            const defaultService = quotedService;
            if (!defaultService) throw new Error("No services configured in system");

            // Check if this provider already placed a bid/booking for this job
            const existingBooking = await prisma.booking.findFirst({
                where: { job_post_id: id, provider_id: providerId }
            });

            if (existingBooking) {
                // Update existing bid
                return await prisma.booking.update({
                    where: { id: existingBooking.id },
                    data: {
                        total_amount: parseFloat(price || job.budget || 0),
                        status: 'NEGOTIATING',
                        last_offer_by: 'PROVIDER',
                        notes: `Bid Updated: ${job.title}`
                    }
                });
            }

            return await prisma.booking.create({
                data: {
                    customer_id: job.customer_id,
                    provider_id: providerId,
                    service_id: defaultService.id, // TODO: Link to correct service type
                    job_post_id: job.id,           // Link to Job Post
                    total_amount: parseFloat(price || job.budget || 0),
                    scheduled_at: new Date(), // Now
                    address: job.location,
                    // Real job-site coordinates from the job post (0.0 only
                    // for legacy jobs posted before coordinates existed).
                    lat: job.lat ?? 0.0,
                    lng: job.lng ?? 0.0,
                    status: 'NEGOTIATING', // Changed from IN_PROGRESS
                    last_offer_by: 'PROVIDER', // Add this
                    notes: `Job: ${job.title} - ${job.description}`
                }
            });

            // Notify Customer about Offer (Handled below transaction)
        });

        // Fetch the created/updated booking with details for notification
        const booking = result;

        // Notify Customer about Offer
        await sendNotification(
            job.customer_id,
            "New Offer Received",
            `Provider has offered Rs. ${price} for your job: ${job.title}`,
            "offer_received",
            { bookingId: booking.id, jobId: job.id }
        );

        return res.status(201).json({ success: true, data: booking });

    } catch (error) {
        console.error("Accept Job Error:", error);
        res.status(500).json({ error: 'Failed to accept job', details: error.message });
    }
};
