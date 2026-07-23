const { randomUUID } = require('crypto');
const admin = require('../config/firebase');
const prisma = require('../utils/prisma');

const { sendNotification, clearJobNotifications } = require('../services/notificationService');
const { getIO, broadcastToAll } = require('../services/socketService');
const { getCommissionPercent } = require('../utils/settings');

// The admin Bookings screen showed nothing new until a manual refresh — none
// of the booking_status_changed emits below are broadcast, they're all
// targeted at the specific customer/provider room, which the admin panel
// never joins.
const notifyAdminBookings = (bookingId) => broadcastToAll('admin_booking_updated', { bookingId });

// Helper wrapper
const notifyUser = async (userId, title, body, type, data = {}) => {
    // Uses the new Postgres + FCM service
    await sendNotification(userId, title, body, type, data);
};

// 4-digit OTP for the two-step work lock
const genOtp = () => String(Math.floor(1000 + Math.random() * 9000));

// The OTPs must be visible to the CUSTOMER only — the provider gets them
// verbally on-site. Strip them from any payload sent to the provider.
const stripOtpForProvider = (booking, userId) => {
    if (booking && booking.provider_id === userId) {
        return { ...booking, start_otp: null, completion_otp: null };
    }
    return booking;
};

// Smart Bidding price fence — shared with jobController so the provider's first
// quote is bounded by the same admin-set range as every later offer.
const { validateBidPrice } = require('../utils/bidding');

const createBooking = async (req, res) => {
    try {
        console.log("Creating Booking Request:", JSON.stringify(req.body, null, 2));
        const customerId = req.user.id;
        const { provider_id, service_id, total_amount, scheduled_at, lat, lng, address, notes, job_post_id } = req.body;

        // Map to internal variables if needed, or use directly
        const providerId = provider_id;
        const serviceId = service_id;
        const totalAmount = total_amount; // It's already number 900 in JSON? No, verify log. Log says 900 (number).
        const scheduledAt = scheduled_at;
        const jobPostId = job_post_id;

        // Resolve to a REAL Service id. The client may send: a valid service id,
        // a category id (direct request from job flow), or a service/category NAME.
        // Always verify it maps to an existing Service, else resolve one, so the
        // booking never fails on a foreign-key violation.
        let service = null;
        if (serviceId) {
            service = await prisma.service.findUnique({ where: { id: serviceId } });
        }
        if (!service) {
            service = await prisma.service.findFirst({
                where: {
                    OR: [
                        { name: { equals: String(serviceId || ''), mode: 'insensitive' } },
                        { category: { name: { equals: String(serviceId || ''), mode: 'insensitive' } } },
                        { category_id: serviceId || undefined }, // serviceId might be a category id
                    ],
                },
            });
        }
        if (!service) {
            // Fall back to the provider's category, then any service.
            const providerProfile = await prisma.providerProfile.findUnique({ where: { user_id: providerId } });
            if (providerProfile) {
                service = await prisma.service.findFirst({ where: { category_id: providerProfile.service_category_id } });
            }
        }
        if (!service) service = await prisma.service.findFirst();
        if (!service) {
            return res.status(400).json({ success: false, message: 'No services configured in the system' });
        }
        const finalServiceId = service.id;
        console.log(`Resolved Service ID: ${finalServiceId} (${service.name})`);


        // Smart Bidding — enforce the service's price floor/ceiling
        const priceCheck = await validateBidPrice(finalServiceId, totalAmount);
        if (!priceCheck.ok) {
            return res.status(400).json({ success: false, message: priceCheck.message });
        }

        const booking = await prisma.booking.create({
            data: {
                customer_id: customerId,
                provider_id: providerId,
                service_id: finalServiceId,
                total_amount: parseFloat(totalAmount),
                scheduled_at: new Date(scheduledAt),
                lat: parseFloat(lat),
                lng: parseFloat(lng),
                address: address || '',
                notes: notes || '',
                status: 'PENDING',
                job_post_id: jobPostId || undefined, // Link to Job Post if provided
            },
            include: { customer: true, service: true }
        });

        // Notify Provider
        await notifyUser(
            providerId,
            "New Booking Request",
            `You have a new booking request for ${booking.service.name}`,
            "booking_request",
            { bookingId: booking.id }
        );

        console.log("Booking Created Successfully:", booking.id);
        notifyAdminBookings(booking.id);
        res.status(201).json({ success: true, data: booking });
    } catch (err) {
        console.error("Booking Creation Failed:", err);
        res.status(500).json({ success: false, message: err.message });
    }
};

const getMyBookings = async (req, res) => {
    try {
        const userId = req.user.id;
        const role = req.user.role;

        const where =
            role === 'PROVIDER'
                ? { provider_id: userId }
                : { customer_id: userId };

        const bookings = await prisma.booking.findMany({
            where,
            include: {
                service: true,
                // The original job post (what the customer actually asked for,
                // including any photo/video/voice attachment) so both sides can
                // see it from the booking screen.
                job_post: {
                    select: {
                        id: true,
                        title: true,
                        description: true,
                        mediaUrls: true,
                        location: true,
                        created_at: true,
                    },
                },
                customer: { select: { email: true, phone: true, name: true, profileImage: true } },
                provider: {
                    select: {
                        email: true,
                        phone: true,
                        name: true,
                        profileImage: true,
                        provider_profile: {
                            select: {
                                current_lat: true,
                                current_lng: true,
                                rating: true,
                                hourly_rate: true,
                                is_verified: true
                            }
                        }
                    }
                },
            },
            orderBy: { created_at: 'desc' },
        });

        // Providers must not see the OTPs
        const safe = bookings.map(b => stripOtpForProvider(b, userId));
        res.json({ success: true, data: safe });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Cancel a booking.
//
// This used to write WHATEVER status the client sent, with no validation at all.
// A provider could PUT status=COMPLETED and the job was done: no OTP, no before
// or after photo, no commission charged, jobs_completed never incremented. Every
// provider on the platform could work for free, forever, with one request.
// status=ACCEPTED was just as bad — it skipped acceptOffer entirely, so no start
// OTP was minted, the job post stayed OPEN for other providers, and the
// "one job at a time" rule never ran.
//
// Every other transition has a guarded endpoint and must go through it:
//   ACCEPTED   -> acceptOffer   (one-job rule, mints the start OTP, closes the job)
//   ONGOING    -> startWork     (start OTP + mandatory "before" photo)
//   COMPLETED  -> completeWork  (completion OTP + "after" photo + commission)
// So this one only cancels.
const CANCELLABLE_FROM = ['PENDING', 'NEGOTIATING', 'ACCEPTED'];

const updateBookingStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;
        const userId = req.user.id;
        const role = req.user.role;

        const booking = await prisma.booking.findUnique({
            where: { id },
            include: { service: true }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: 'Booking not found' });
        }

        if (
            booking.customer_id !== userId &&
            booking.provider_id !== userId &&
            role !== 'ADMIN'
        ) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        const wanted = String(status || '').toUpperCase();

        if (wanted !== 'CANCELLED') {
            const guarded = {
                ACCEPTED: 'PUT /bookings/:id/accept-offer',
                ONGOING: 'PUT /bookings/:id/start (requires the start OTP and a "before" photo)',
                COMPLETED: 'PUT /bookings/:id/complete (requires the completion OTP and an "after" photo)',
            }[wanted];

            return res.status(400).json({
                success: false,
                message: guarded
                    ? `A booking cannot be set to ${wanted} here. Use ${guarded}.`
                    : `Unsupported status "${status}". This endpoint only cancels a booking.`,
            });
        }

        // A job that is already under way, finished, or cancelled cannot be
        // cancelled: once the provider is on site and working, walking away is a
        // dispute, not a cancellation.
        if (!CANCELLABLE_FROM.includes(booking.status)) {
            return res.status(409).json({
                success: false,
                message: booking.status === 'ONGOING'
                    ? 'Work has already started — this booking can no longer be cancelled.'
                    : `A ${booking.status.toLowerCase()} booking cannot be cancelled.`,
            });
        }

        const updatedBooking = await prisma.booking.update({
            where: { id },
            data: { status: 'CANCELLED' },
        });

        // Cancelling frees the provider AND reopens the job for everyone else —
        // otherwise the customer is left with a dead job post nobody can quote on.
        if (booking.job_post_id) {
            const stillLive = await prisma.booking.count({
                where: {
                    job_post_id: booking.job_post_id,
                    id: { not: id },
                    status: { in: ['ACCEPTED', 'ONGOING', 'COMPLETED'] },
                },
            });
            if (stillLive === 0) {
                await prisma.jobPost.update({
                    where: { id: booking.job_post_id },
                    data: { status: 'OPEN' },
                });
            }
        }

        // Determine who to notify and what to say
        const recipientId = role === 'CUSTOMER' ? booking.provider_id : booking.customer_id;
        const serviceName = booking.service?.name || 'the service';

        const notifications = {
            ACCEPTED: {
                title: '✅ Booking Accepted',
                body: `Your booking for ${serviceName} has been accepted! The provider is on their way.`,
                route: '/booking-detail',
            },
            ONGOING: {
                title: '🔧 Service Started',
                body: `The provider has started ${serviceName}. Job timer is running.`,
                route: '/booking-detail',
            },
            COMPLETED: {
                title: '🎉 Service Completed',
                body: `${serviceName} has been marked as completed. Please rate your experience.`,
                route: '/booking-detail',
            },
            CANCELLED: {
                title: '❌ Booking Cancelled',
                body: `Your booking for ${serviceName} has been cancelled.`,
                route: role === 'CUSTOMER' ? '/provider/dashboard' : '/home',
            },
        };

        const notif = notifications[status] || {
            title: 'Booking Updated',
            body: `Booking status updated to ${status}.`,
            route: '/booking-detail',
        };

        const payloadData = {
            bookingId: booking.id,
            status,
            route: notif.route,
            arguments: JSON.stringify({ bookingId: booking.id }),
        };

        await notifyUser(recipientId, notif.title, notif.body, 'booking_update', payloadData);

        // Emit real-time socket event so recipient sees update instantly
        try {
            const io = getIO();
            if (io) {
                io.to(`user:${recipientId}`).emit('booking_status_changed', {
                    bookingId: booking.id,
                    status,
                    message: notif.body,
                });
            }
        } catch (socketErr) {
            console.warn('Socket emit failed (non-critical):', socketErr.message);
        }

        notifyAdminBookings(booking.id);
        res.json({ success: true, data: updatedBooking });
    } catch (err) {
        console.error('updateBookingStatus error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

// --- NEW NEGOTIATION LOGIC ---

// Counter Offer (Negotiation)
const counterOffer = async (req, res) => {
    try {
        const { id } = req.params; // Booking ID
        const { price } = req.body;
        const userId = req.user.id;
        const role = req.user.role; // CUSTOMER or PROVIDER

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

        // A settled booking is not open to haggling any more.
        if (!['PENDING', 'NEGOTIATING'].includes(booking.status)) {
            return res.status(409).json({
                success: false,
                message: `This booking is already ${booking.status.toLowerCase()} and can no longer be negotiated.`,
            });
        }

        // You cannot bid against yourself: the ball has to be in the other
        // side's court before you may move the price again.
        if (booking.last_offer_by === role) {
            return res.status(409).json({
                success: false,
                message: 'Your offer is already on the table. Wait for the other side to respond.',
            });
        }

        // Smart Bidding — counter offers must also respect the price range
        const priceCheck = await validateBidPrice(booking.service_id, price);
        if (!priceCheck.ok) {
            return res.status(400).json({ success: false, message: priceCheck.message });
        }

        // Identify recipient
        let recipientId;
        let notificationTitle;
        let notificationBody;

        if (role === 'CUSTOMER') {
            if (booking.customer_id !== userId) return res.status(403).json({ message: 'Unauthorized' });
            recipientId = booking.provider_id;
            notificationTitle = "Counter Offer Received";
            notificationBody = `Customer countered with Rs. ${price}`;
        } else if (role === 'PROVIDER') {
            if (booking.provider_id !== userId) return res.status(403).json({ message: 'Unauthorized' });
            recipientId = booking.customer_id;
            notificationTitle = "Counter Offer Received";
            notificationBody = `Provider countered with Rs. ${price}`;
        } else {
            return res.status(403).json({ message: 'Unauthorized role' });
        }

        const updatedBooking = await prisma.booking.update({
            where: { id },
            data: {
                total_amount: parseFloat(price),
                status: 'NEGOTIATING',
                last_offer_by: role
            }
        });

        const payloadData = {
            bookingId: booking.id, // Keep for backward compatibility/reference
            route: role === 'CUSTOMER' ? '/provider/ongoing' : '/booking-detail',
            arguments: JSON.stringify({ bookingId: booking.id })
        };

        await notifyUser(recipientId, notificationTitle, notificationBody, "offer_received", payloadData);

        // Emit real-time socket event to the counterparty
        try {
            const io = getIO();
            if (io) io.to(`user:${recipientId}`).emit('booking_status_changed', {
                bookingId: booking.id, status: 'NEGOTIATING', message: notificationBody,
            });
        } catch (_) { /* non-critical */ }

        res.json({ success: true, data: updatedBooking });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Accept Offer (Finalize Negotiation)
const acceptOffer = async (req, res) => {
    try {
        const { id } = req.params; // Booking ID
        const userId = req.user.id;
        const role = req.user.role;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

        // Only a live negotiation can be accepted — never a booking that is
        // already accepted, cancelled or completed.
        if (!['PENDING', 'NEGOTIATING'].includes(booking.status)) {
            return res.status(409).json({
                success: false,
                message: `This booking is already ${booking.status.toLowerCase()}.`,
            });
        }

        // You accept the OTHER side's offer, never your own. Without this, a
        // customer could counter to Rs. 1 and immediately "accept" it.
        if (booking.last_offer_by === role) {
            return res.status(409).json({
                success: false,
                message: 'You cannot accept your own offer. Wait for the other side to respond.',
            });
        }

        let recipientId;
        let notificationTitle;
        let notificationBody;

        if (role === 'CUSTOMER') {
            if (booking.customer_id !== userId) return res.status(403).json({ message: 'Unauthorized' });
            recipientId = booking.provider_id;
            notificationTitle = "Offer Accepted!";
            notificationBody = `Customer accepted your price.`;
        } else if (role === 'PROVIDER') {
            if (booking.provider_id !== userId) return res.status(403).json({ message: 'Unauthorized' });
            recipientId = booking.customer_id;
            notificationTitle = "Offer Accepted!";
            notificationBody = `Provider accepted your price.`;
        } else {
            return res.status(403).json({ message: 'Unauthorized role' });
        }

        // ── One job at a time ──
        // A provider can only work one job at once. If they already have an
        // ACCEPTED/ONGOING booking, this acceptance is blocked - the existing
        // job must be completed/cancelled first (or rescheduled around).
        const busy = await prisma.booking.findFirst({
            where: {
                provider_id: booking.provider_id,
                id: { not: id },
                status: { in: ['ACCEPTED', 'ONGOING'] },
            },
            select: { id: true },
        });
        if (busy) {
            return res.status(409).json({
                success: false,
                message: role === 'PROVIDER'
                    ? 'You already have an active job. Complete it first, or reschedule it before accepting a new one.'
                    : 'This provider is currently busy on another job. Please pick another provider or try later.',
            });
        }

        // Claim the acceptance atomically. Two taps on "Accept" would otherwise
        // both run this block: two starting OTPs minted, the losing bids cancelled
        // twice, and two "offer accepted" notifications sent.
        const claimed = await prisma.booking.updateMany({
            where: { id, status: { in: ['PENDING', 'NEGOTIATING'] } },
            data: {
                status: 'ACCEPTED',
                start_otp: booking.start_otp || genOtp(),
            },
        });
        if (claimed.count === 0) {
            return res.status(409).json({ success: false, message: 'This offer has already been accepted.' });
        }

        const updatedBooking = await prisma.booking.findUnique({ where: { id } });

        // 3. IF this was a Job Post Bid, Close the Job and Cancel other Bids
        let losingBids = [];
        if (booking.job_post_id) {
            // Close the Job
            await prisma.jobPost.update({
                where: { id: booking.job_post_id },
                data: { status: 'IN_PROGRESS' }
            });

            // The job is taken — every other provider's "New Job Posted" alert is
            // now a dead end that opens nothing. Clear them.
            await clearJobNotifications(booking.job_post_id);

            // Cancel ALL other competing offers/requests for this job
            // (both provider bids in NEGOTIATING and customer direct requests in PENDING).
            losingBids = await prisma.booking.findMany({
                where: {
                    job_post_id: booking.job_post_id,
                    id: { not: id },
                    status: { in: ['NEGOTIATING', 'PENDING'] },
                },
                select: { id: true, provider_id: true },
            });
            await prisma.booking.updateMany({
                where: { id: { in: losingBids.map(b => b.id) } },
                data: { status: 'CANCELLED' }
            });
            console.log(`🔒 Closed Job ${booking.job_post_id} and cancelled ${losingBids.length} competing bids.`);
        }

        const payloadData = {
            bookingId: booking.id,
            route: role === 'CUSTOMER' ? '/provider/ongoing' : '/booking-detail',
            arguments: JSON.stringify({ bookingId: booking.id })
        };

        await notifyUser(recipientId, notificationTitle, notificationBody, "booking_accepted", payloadData);

        // Push the new state to both sides live. counterOffer already did this;
        // accept did not, so the counterparty's screen sat on the stale
        // NEGOTIATING state until it was manually refreshed.
        try {
            const io = getIO();
            if (io) {
                for (const uid of [recipientId, userId]) {
                    io.to(`user:${uid}`).emit('booking_status_changed', {
                        bookingId: booking.id,
                        status: 'ACCEPTED',
                        message: notificationBody,
                    });
                }
                // Providers who lost the job deserve to know immediately, too.
                for (const lost of losingBids) {
                    io.to(`user:${lost.provider_id}`).emit('booking_status_changed', {
                        bookingId: lost.id,
                        status: 'CANCELLED',
                        message: 'The customer picked another provider for this job.',
                    });
                }
            }
        } catch (_) { /* non-critical */ }

        notifyAdminBookings(booking.id);
        res.json({ success: true, data: updatedBooking });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Update Booking Details (e.g. Schedule)
const updateBookingDetails = async (req, res) => {
    try {
        const { id } = req.params;
        const { scheduledAt, notes } = req.body;
        const userId = req.user.id;
        const role = req.user.role;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

        if (booking.customer_id !== userId && booking.provider_id !== userId && role !== 'ADMIN') {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        // A reschedule is a PROPOSAL — the other side must accept it.
        const proposerRole = (booking.customer_id === userId) ? 'CUSTOMER' : 'PROVIDER';
        const updatedBooking = await prisma.booking.update({
            where: { id },
            data: {
                reschedule_proposed_at: scheduledAt ? new Date(scheduledAt) : undefined,
                reschedule_by: scheduledAt ? proposerRole : undefined,
                // Stamp WHEN the request was made. The expiry and the reminder are
                // measured from this — reschedule_proposed_at is the proposed new
                // time and says nothing about when it was asked for. Clear any
                // previous reminder so a fresh proposal gets a fresh nudge.
                reschedule_requested_at: scheduledAt ? new Date() : undefined,
                reschedule_reminded_at: scheduledAt ? null : undefined,
                notes: notes
            }
        });

        // Notify counterparty that a reschedule was REQUESTED (needs accept/decline)
        if (scheduledAt) {
            const recipientId = (proposerRole === 'CUSTOMER') ? booking.provider_id : booking.customer_id;
            const title = "Reschedule Requested";
            const body = `${proposerRole === 'CUSTOMER' ? 'Customer' : 'Provider'} requested to reschedule the booking to ${new Date(scheduledAt).toLocaleString()}. Please accept or decline.`;
            notifyUser(recipientId, title, body, "booking_rescheduled", { bookingId: booking.id });
        }

        res.json({ success: true, data: updatedBooking });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Accept or decline a pending reschedule proposal.
// On accept, the new time is applied and BOTH sides get a confirmation
// notification (acts as the automatic reminder of the new date/time).
const respondReschedule = async (req, res) => {
    try {
        const { id } = req.params;
        const { accept } = req.body;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
        if (booking.customer_id !== userId && booking.provider_id !== userId) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }
        if (!booking.reschedule_proposed_at) {
            return res.status(400).json({ success: false, message: 'No pending reschedule request' });
        }
        // The proposer cannot accept their own request
        const responderRole = (booking.customer_id === userId) ? 'CUSTOMER' : 'PROVIDER';
        if (booking.reschedule_by === responderRole) {
            return res.status(400).json({ success: false, message: 'Waiting for the other party to respond' });
        }

        const newTime = booking.reschedule_proposed_at;
        const cleared = {
            reschedule_proposed_at: null,
            reschedule_by: null,
            reschedule_requested_at: null,
            reschedule_reminded_at: null,
        };
        const updated = await prisma.booking.update({
            where: { id },
            data: accept === true
                ? { scheduled_at: newTime, ...cleared }
                : cleared,
        });

        const when = new Date(newTime).toLocaleString();
        if (accept === true) {
            // Confirmation to BOTH customer and provider (automatic reminder)
            const body = `Your booking has been rescheduled to ${when}.`;
            notifyUser(booking.customer_id, "Booking Rescheduled", body, "booking_rescheduled", { bookingId: booking.id });
            notifyUser(booking.provider_id, "Booking Rescheduled", body, "booking_rescheduled", { bookingId: booking.id });
        } else {
            const proposerId = (booking.reschedule_by === 'CUSTOMER') ? booking.customer_id : booking.provider_id;
            notifyUser(proposerId, "Reschedule Declined", `Your request to reschedule to ${when} was declined. The original time stands.`, "booking_update", { bookingId: booking.id });
        }

        res.json({ success: true, data: updated });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Withdraw your OWN pending reschedule request.
//
// Only the other side could act on a proposal — accept it or decline it. Whoever
// made it was stuck: pick the wrong date by mistake and there was no way to take
// it back, only to wait for the other party (or the 24h expiry) to clear it.
const cancelReschedule = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
        if (booking.customer_id !== userId && booking.provider_id !== userId) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }
        if (!booking.reschedule_proposed_at) {
            return res.status(400).json({ success: false, message: 'There is no pending reschedule request' });
        }

        // You can only withdraw what YOU asked for. Withdrawing someone else's
        // request would be a silent decline with no notification to them.
        const myRole = (booking.customer_id === userId) ? 'CUSTOMER' : 'PROVIDER';
        if (booking.reschedule_by !== myRole) {
            return res.status(403).json({
                success: false,
                message: 'This request was made by the other party. You can accept or decline it instead.',
            });
        }

        const proposed = new Date(booking.reschedule_proposed_at).toLocaleString();
        const original = new Date(booking.scheduled_at).toLocaleString();

        const updated = await prisma.booking.update({
            where: { id },
            data: {
                reschedule_proposed_at: null,
                reschedule_by: null,
                reschedule_requested_at: null,
                reschedule_reminded_at: null,
            },
        });

        // The other side may already have seen the request; tell them it's gone.
        const otherId = (myRole === 'CUSTOMER') ? booking.provider_id : booking.customer_id;
        notifyUser(
            otherId,
            'Reschedule Request Withdrawn',
            `The request to move the booking to ${proposed} was withdrawn. The original time (${original}) stands.`,
            'booking_update',
            { bookingId: booking.id }
        );

        try {
            const io = getIO();
            if (io) {
                for (const uid of [otherId, userId]) {
                    io.to(`user:${uid}`).emit('booking_status_changed', { bookingId: booking.id });
                }
            }
        } catch (_) { /* non-critical */ }

        res.json({ success: true, data: updated });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ── TWO-OTP WORK LOCK ──────────────────────────────────────────────

// Provider marks "I've arrived" (GPS proof). Ensures a Start OTP exists.
const providerArrived = async (req, res) => {
    try {
        const { id } = req.params;
        const { lat, lng } = req.body;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
        if (booking.provider_id !== userId) return res.status(403).json({ success: false, message: 'Only the assigned provider can do this' });
        if (booking.status !== 'ACCEPTED') return res.status(400).json({ success: false, message: 'Booking must be ACCEPTED first' });

        const updated = await prisma.booking.update({
            where: { id },
            data: {
                arrived_at: new Date(),
                start_otp: booking.start_otp || genOtp(),
                lat: lat != null ? parseFloat(lat) : booking.lat,
                lng: lng != null ? parseFloat(lng) : booking.lng,
            },
        });

        await notifyUser(booking.customer_id, 'Provider Arrived',
            'Your provider has arrived. Share the Start OTP shown in your booking to begin the work.',
            'provider_arrived', { bookingId: id });

        // Provider must NOT see the OTP
        res.json({ success: true, data: stripOtpForProvider(updated, userId) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Provider starts work: submits the Start OTP + a mandatory "before" photo.
const startWork = async (req, res) => {
    try {
        const { id } = req.params;
        const { otp, beforePhoto } = req.body;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
        if (booking.provider_id !== userId) return res.status(403).json({ success: false, message: 'Only the assigned provider can start work' });
        if (booking.status === 'ONGOING') return res.status(400).json({ success: false, message: 'Work already started' });
        if (booking.status !== 'ACCEPTED') return res.status(400).json({ success: false, message: 'Booking must be ACCEPTED to start' });
        if (!booking.start_otp || String(otp) !== String(booking.start_otp)) {
            return res.status(400).json({ success: false, message: 'Invalid Start OTP' });
        }
        if (!beforePhoto) return res.status(400).json({ success: false, message: 'A "before" work photo is required' });

        // Claim ACCEPTED -> ONGOING atomically. A double tap here would mint a
        // SECOND completion OTP, silently invalidating the one the customer is
        // already holding — and they would then be unable to let the provider
        // finish the job.
        const claimed = await prisma.booking.updateMany({
            where: { id, status: 'ACCEPTED' },
            data: {
                status: 'ONGOING',
                started_at: new Date(),
                before_photo: beforePhoto,
                completion_otp: genOtp(), // customer will share this at the end
            },
        });
        if (claimed.count === 0) {
            return res.status(409).json({ success: false, message: 'Work has already been started.' });
        }

        const updated = await prisma.booking.findUnique({ where: { id } });

        await notifyUser(booking.customer_id, 'Work Started',
            'The provider has started the work. You can track progress in your booking.',
            'work_started', { bookingId: id });

        try {
            const io = getIO();
            if (io) io.to(`user:${booking.customer_id}`).emit('booking_status_changed', { bookingId: id, status: 'ONGOING' });
        } catch (_) {}

        notifyAdminBookings(id);
        res.json({ success: true, data: stripOtpForProvider(updated, userId) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Provider completes work: submits the Completion OTP + mandatory "after" photo.
// Only after this does payment + rating unlock for the customer.
const completeWork = async (req, res) => {
    try {
        const { id } = req.params;
        const { otp, afterPhoto } = req.body;
        const userId = req.user.id;

        const booking = await prisma.booking.findUnique({ where: { id } });
        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
        if (booking.provider_id !== userId) return res.status(403).json({ success: false, message: 'Only the assigned provider can complete work' });
        if (booking.status !== 'ONGOING') return res.status(400).json({ success: false, message: 'Work must be ONGOING to complete' });
        if (!booking.completion_otp || String(otp) !== String(booking.completion_otp)) {
            return res.status(400).json({ success: false, message: 'Invalid Completion OTP' });
        }
        if (!afterPhoto) return res.status(400).json({ success: false, message: 'An "after" work photo is required' });

        // CLAIM the transition atomically.
        //
        // This was a check-then-act race: read the booking, see ONGOING, then
        // update. Two requests arriving together — a double tap, or a retry after
        // a flaky connection — both passed the check and both went on to charge
        // commission. Five concurrent completes billed the provider FIVE times for
        // one job and counted it five times in jobs_completed. A provider on a bad
        // network was quietly overcharged.
        //
        // updateMany with the status in the WHERE clause makes the database the
        // arbiter: exactly one request flips ONGOING -> COMPLETED, and only that
        // one gets count === 1. Everyone else does nothing.
        const claimed = await prisma.booking.updateMany({
            where: { id, status: 'ONGOING' },
            data: {
                status: 'COMPLETED',
                completed_at: new Date(),
                after_photo: afterPhoto,
            },
        });
        if (claimed.count === 0) {
            return res.status(409).json({ success: false, message: 'This job has already been completed.' });
        }

        const updated = await prisma.booking.findUnique({ where: { id } });

        // Count the completed job for the provider (used in ranking).
        await prisma.providerProfile.updateMany({
            where: { user_id: userId },
            data: { jobs_completed: { increment: 1 } },
        });

        // COMMISSION (inDrive-style): deduct the admin-set % of the job value
        // from the provider's prepaid wallet. The % is read live from
        // AppSetting, so when admin changes it, every provider's next
        // completion uses the new rate automatically.
        try {
            const pct = await getCommissionPercent();
            const commission = Math.round(((updated.total_amount || 0) * pct) / 100 * 100) / 100;
            if (commission > 0) {
                const [profile] = await prisma.$transaction([
                    prisma.providerProfile.update({
                        where: { user_id: userId },
                        data: { wallet_balance: { decrement: commission } },
                        select: { wallet_balance: true },
                    }),
                    prisma.transaction.create({
                        data: {
                            user_id: userId,
                            type: 'COMMISSION',
                            // Unique key: Date.now() collides when two jobs finish in the same
                            // millisecond, which rolls back the whole transaction — and the
                            // commission charge with it.
                            transaction_ref: `COMM-${randomUUID()}`,
                            amount: commission,
                            payment_method: 'WALLET',
                            status: 'SUCCESS',
                            response_message: `Commission ${pct}% of Rs. ${updated.total_amount} (booking ${id})`,
                        },
                    }),
                ]);
                try {
                    const io = getIO();
                    if (io) io.to(`user:${userId}`).emit('wallet_updated', {
                        balance: profile.wallet_balance,
                        deducted: commission,
                        commission_percent: pct,
                        bookingId: id,
                    });
                } catch (_) {}
                console.log(`💰 Commission Rs.${commission} (${pct}%) deducted from provider ${userId}; balance Rs.${profile.wallet_balance}`);
            }
        } catch (commErr) {
            // Never block completion on a commission failure — log for admin follow-up.
            console.error('Commission deduction failed for booking', id, commErr);
        }

        await notifyUser(booking.customer_id, '🎉 Service Completed',
            'The work is complete. Please make the payment and rate your provider.',
            'work_completed', { bookingId: id });

        try {
            const io = getIO();
            if (io) io.to(`user:${booking.customer_id}`).emit('booking_status_changed', { bookingId: id, status: 'COMPLETED' });
        } catch (_) {}

        notifyAdminBookings(id);
        res.json({ success: true, data: stripOtpForProvider(updated, userId) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// Get Booking By ID
const getBookingById = async (req, res) => {
    try {
        const { id } = req.params;
        const booking = await prisma.booking.findUnique({
            where: { id },
            include: {
                service: true,
                customer: { select: { email: true, phone: true, name: true, profileImage: true } },
                provider: {
                    select: {
                        email: true,
                        phone: true,
                        name: true,
                        profileImage: true,
                        provider_profile: {
                            select: {
                                current_lat: true,
                                current_lng: true,
                                rating: true,
                                hourly_rate: true,
                                is_verified: true
                            }
                        }
                    }
                },
            }
        });

        if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });

        // Only the customer, the assigned provider, or an admin may view it.
        if (booking.customer_id !== req.user.id && booking.provider_id !== req.user.id && req.user.role !== 'ADMIN') {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        res.json({ success: true, data: stripOtpForProvider(booking, req.user.id) });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = {
    createBooking,
    getMyBookings,
    getBookingById, // Added export
    updateBookingStatus,
    updateBookingDetails,
    respondReschedule,
    cancelReschedule,
    counterOffer,
    acceptOffer,
    providerArrived,
    startWork,
    completeWork,
};
