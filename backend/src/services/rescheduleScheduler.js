const prisma = require('../utils/prisma');
const { sendNotification } = require('./notificationService');
const { getIO } = require('./socketService');

/// A reschedule proposal used to sit pending forever.
///
/// If the other side never answered, nothing happened: the booking quietly kept
/// its ORIGINAL time — which by then may well have passed — while both parties
/// believed a decision was still coming. This sweeps those proposals:
///
///   • after REMINDER_HOURS  -> nudge the side that has to answer (once)
///   • after EXPIRY_HOURS    -> auto-decline; the original time stands and both
///                              sides are told, so nobody is left guessing
///
/// Windows are configurable — a marketplace with same-day jobs wants a much
/// shorter fuse than one booking a week out.
const EXPIRY_HOURS = Number(process.env.RESCHEDULE_EXPIRY_HOURS || 24);
const REMINDER_HOURS = Number(process.env.RESCHEDULE_REMINDER_HOURS || 6);
const SWEEP_EVERY_MS = Number(process.env.RESCHEDULE_SWEEP_MINUTES || 15) * 60 * 1000;

const hoursAgo = (h) => new Date(Date.now() - h * 60 * 60 * 1000);

/// Who proposed, and who therefore owes an answer.
const partiesOf = (booking) => {
    const proposerId = booking.reschedule_by === 'CUSTOMER' ? booking.customer_id : booking.provider_id;
    const responderId = booking.reschedule_by === 'CUSTOMER' ? booking.provider_id : booking.customer_id;
    return { proposerId, responderId };
};

const pushStatus = (userId, bookingId) => {
    try {
        const io = getIO();
        if (io) io.to(`user:${userId}`).emit('booking_status_changed', { bookingId });
    } catch (_) { /* socket down must never break the sweep */ }
};

/// Nudge the side that still has to accept or decline. Once only — a reminder
/// that repeats every 15 minutes is spam, not a reminder.
const sendReminders = async () => {
    const due = await prisma.booking.findMany({
        where: {
            reschedule_proposed_at: { not: null },
            reschedule_requested_at: { lt: hoursAgo(REMINDER_HOURS) },
            reschedule_reminded_at: null,
        },
        select: {
            id: true, customer_id: true, provider_id: true,
            reschedule_by: true, reschedule_proposed_at: true,
        },
    });

    for (const b of due) {
        const { responderId } = partiesOf(b);
        const when = new Date(b.reschedule_proposed_at).toLocaleString();
        const hoursLeft = Math.max(1, EXPIRY_HOURS - REMINDER_HOURS);

        await sendNotification(
            responderId,
            'Reschedule still waiting',
            `A request to move the booking to ${when} is still waiting for your answer. ` +
            `If you do not respond within ${hoursLeft} hours the original time stands.`,
            'booking_rescheduled',
            { bookingId: b.id },
        );
        await prisma.booking.update({
            where: { id: b.id },
            data: { reschedule_reminded_at: new Date() },
        });
        console.log(`⏰ Reschedule reminder sent for booking ${b.id}`);
    }
    return due.length;
};

/// Auto-decline what nobody answered. The booking keeps its original time —
/// silence is not consent.
const expireStale = async () => {
    const stale = await prisma.booking.findMany({
        where: {
            reschedule_proposed_at: { not: null },
            reschedule_requested_at: { lt: hoursAgo(EXPIRY_HOURS) },
        },
        select: {
            id: true, customer_id: true, provider_id: true,
            reschedule_by: true, reschedule_proposed_at: true, scheduled_at: true,
        },
    });

    for (const b of stale) {
        const { proposerId, responderId } = partiesOf(b);
        const proposed = new Date(b.reschedule_proposed_at).toLocaleString();
        const original = new Date(b.scheduled_at).toLocaleString();

        await prisma.booking.update({
            where: { id: b.id },
            data: {
                reschedule_proposed_at: null,
                reschedule_by: null,
                reschedule_requested_at: null,
                reschedule_reminded_at: null,
            },
        });

        // Both sides need to know the booking is back on its original footing.
        await sendNotification(
            proposerId,
            'Reschedule expired',
            `Your request to move the booking to ${proposed} went unanswered and has expired. ` +
            `The original time (${original}) stands.`,
            'booking_update',
            { bookingId: b.id },
        );
        await sendNotification(
            responderId,
            'Reschedule expired',
            `The reschedule request you did not answer has expired. ` +
            `The booking stays at its original time (${original}).`,
            'booking_update',
            { bookingId: b.id },
        );
        pushStatus(proposerId, b.id);
        pushStatus(responderId, b.id);

        console.log(`⌛ Reschedule proposal expired for booking ${b.id}; original time stands`);
    }
    return stale.length;
};

/// Notifications had no retention policy at all — every row ever written stayed
/// forever. At a few dozen users that is 358 rows; at marketplace scale it is
/// millions, and the provider's list becomes unusable long before that.
///
/// Only READ notifications are pruned: an unread one is still a message the user
/// has not seen, however old.
const NOTIFICATION_RETENTION_DAYS = Number(process.env.NOTIFICATION_RETENTION_DAYS || 30);

const pruneOldNotifications = async () => {
    const cutoff = new Date(Date.now() - NOTIFICATION_RETENTION_DAYS * 24 * 3600 * 1000);
    const { count } = await prisma.notification.deleteMany({
        where: { is_read: true, created_at: { lt: cutoff } },
    });
    if (count) console.log(`🧹 Pruned ${count} read notification(s) older than ${NOTIFICATION_RETENTION_DAYS} days`);
    return count;
};

/// "New Job Posted" alerts whose job is no longer OPEN — cancelled, taken by
/// another provider, or deleted. Each one is a dead end that opens nothing.
/// The cascade on the job itself catches these at the source; this is the safety
/// net for anything that slipped through (a crash mid-write, older rows).
const pruneDeadJobNotifications = async () => {
    const jobNotifs = await prisma.notification.findMany({
        where: { type: 'job_post' },
        select: { id: true, data: true },
    });
    if (!jobNotifs.length) return 0;

    const jobIds = [...new Set(jobNotifs.map(n => n.data?.jobId).filter(Boolean))];
    const openJobs = await prisma.jobPost.findMany({
        where: { id: { in: jobIds }, status: 'OPEN' },
        select: { id: true },
    });
    const stillOpen = new Set(openJobs.map(j => j.id));

    const dead = jobNotifs
        .filter(n => n.data?.jobId && !stillOpen.has(n.data.jobId))
        .map(n => n.id);
    if (!dead.length) return 0;

    const { count } = await prisma.notification.deleteMany({ where: { id: { in: dead } } });
    if (count) console.log(`🧹 Pruned ${count} notification(s) for jobs that are no longer open`);
    return count;
};

const sweep = async () => {
    try {
        const expired = await expireStale();   // expire first — never remind about
        const reminded = await sendReminders(); // something that is already dead
        if (expired || reminded) {
            console.log(`🔁 Reschedule sweep: ${reminded} reminded, ${expired} expired`);
        }
    } catch (err) {
        // A failed sweep must never take the server down; the next one retries.
        console.error('Reschedule sweep failed:', err.message);
    }

    try {
        await pruneDeadJobNotifications();
        await pruneOldNotifications();
    } catch (err) {
        console.error('Notification prune failed:', err.message);
    }
};

let timer = null;

const start = () => {
    if (timer) return;
    console.log(
        `🔁 Reschedule scheduler: remind after ${REMINDER_HOURS}h, ` +
        `auto-decline after ${EXPIRY_HOURS}h, sweeping every ${SWEEP_EVERY_MS / 60000} min`
    );
    sweep(); // catch anything already stale from before this process started
    timer = setInterval(sweep, SWEEP_EVERY_MS);
    timer.unref?.(); // don't hold the process open on shutdown
};

const stop = () => {
    if (timer) clearInterval(timer);
    timer = null;
};

module.exports = {
    start, stop, sweep,
    sendReminders, expireStale,
    pruneDeadJobNotifications, pruneOldNotifications,
    EXPIRY_HOURS, REMINDER_HOURS, NOTIFICATION_RETENTION_DAYS,
};
