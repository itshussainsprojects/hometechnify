// Review Controller - CRUD for booking reviews

const prisma = require('../utils/prisma');
const { sendNotification } = require('../services/notificationService');
const { broadcastToAll } = require('../services/socketService');

// Get reviews for a provider
const getProviderReviews = async (req, res) => {
    try {
        const { providerId } = req.params;

        const reviews = await prisma.review.findMany({
            where: { target_id: providerId },
            include: {
                author: { select: { name: true, profileImage: true } },
                booking: {
                    select: {
                        service: { select: { name: true } },
                        created_at: true
                    }
                }
            },
            orderBy: { created_at: 'desc' }
        });

        // Calculate stats
        const totalReviews = reviews.length;
        const avgRating = totalReviews > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
            : 0;

        // Rating breakdown
        const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
        reviews.forEach(r => {
            if (breakdown[r.rating] !== undefined) {
                breakdown[r.rating]++;
            }
        });

        res.json({
            success: true,
            data: {
                reviews,
                stats: {
                    totalReviews,
                    averageRating: Math.round(avgRating * 10) / 10,
                    breakdown
                }
            }
        });
    } catch (error) {
        console.error('Get Reviews Error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch reviews' });
    }
};

// Create a review (after service completion)
const createReview = async (req, res) => {
    try {
        const authorId = req.user.id;
        const { bookingId, rating, comment } = req.body;

        if (!bookingId || !rating) {
            return res.status(400).json({ success: false, message: 'bookingId and rating are required' });
        }

        if (rating < 1 || rating > 5) {
            return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5' });
        }

        // Get booking to find the provider
        const booking = await prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                customer: { select: { id: true, name: true } },
                provider: { select: { id: true, name: true } }
            }
        });

        if (!booking) {
            return res.status(404).json({ success: false, message: 'Booking not found' });
        }

        if (booking.status !== 'COMPLETED') {
            return res.status(400).json({ success: false, message: 'Can only review completed bookings' });
        }

        // Check if review already exists
        const existing = await prisma.review.findUnique({
            where: { booking_id: bookingId }
        });

        if (existing) {
            return res.status(400).json({ success: false, message: 'Review already submitted for this booking' });
        }

        // Determine target (the other party)
        const targetId = authorId === booking.customer_id
            ? booking.provider_id
            : booking.customer_id;

        // Create review
        const review = await prisma.review.create({
            data: {
                booking_id: bookingId,
                author_id: authorId,
                target_id: targetId,
                rating: parseInt(rating),
                comment: comment || null
            },
            include: {
                author: { select: { name: true, profileImage: true } }
            }
        });

        // Update provider's average rating
        const allReviews = await prisma.review.findMany({
            where: { target_id: targetId },
            select: { rating: true }
        });

        const newAvg = allReviews.reduce((sum, r) => sum + r.rating, 0) / allReviews.length;
        const roundedAvg = Math.round(newAvg * 10) / 10;

        const profileUpdate = await prisma.providerProfile.updateMany({
            where: { user_id: targetId },
            data: { rating: roundedAvg }
        });

        // Only a PROVIDER has a provider_profile row, so this only matches
        // when a customer rated a provider (not the reverse). Live-push the
        // new average so the provider's own app, the customer browsing their
        // listing, and the admin Ratings/Providers screens all update without
        // waiting for their next manual refetch.
        if (profileUpdate.count > 0) {
            broadcastToAll('provider_rating_updated', {
                providerId: targetId,
                rating: roundedAvg,
                reviewCount: allReviews.length,
            });
        }

        // Notify the provider
        try {
            const authorName = booking.customer?.name || 'A customer';
            await sendNotification(
                targetId,
                'New Review',
                `${authorName} left a ${rating}-star review`,
                'BOOKING',
                { bookingId }
            );
        } catch (e) {
            console.error('Failed to send review notification:', e);
        }

        res.status(201).json({ success: true, data: review });
    } catch (error) {
        console.error('Create Review Error:', error);
        res.status(500).json({ success: false, message: 'Failed to create review' });
    }
};

// Get my reviews (reviews I've received)
const getMyReviews = async (req, res) => {
    try {
        const userId = req.user.id;

        const reviews = await prisma.review.findMany({
            where: { target_id: userId },
            include: {
                author: { select: { name: true, profileImage: true } },
                booking: {
                    select: {
                        service: { select: { name: true } },
                        created_at: true
                    }
                }
            },
            orderBy: { created_at: 'desc' }
        });

        const totalReviews = reviews.length;
        const avgRating = totalReviews > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
            : 0;

        const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
        reviews.forEach(r => {
            if (breakdown[r.rating] !== undefined) {
                breakdown[r.rating]++;
            }
        });

        res.json({
            success: true,
            data: {
                reviews,
                stats: {
                    totalReviews,
                    averageRating: Math.round(avgRating * 10) / 10,
                    breakdown
                }
            }
        });
    } catch (error) {
        console.error('Get My Reviews Error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch reviews' });
    }
};

module.exports = { getProviderReviews, createReview, getMyReviews };
