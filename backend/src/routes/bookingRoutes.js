
const express = require('express');
const {
    createBooking,
    getMyBookings,
    updateBookingStatus,
    updateBookingDetails,
    respondReschedule,
    cancelReschedule,
    counterOffer,
    acceptOffer,
    getBookingById,
    providerArrived,
    startWork,
    completeWork
} = require('../controllers/bookingController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware); // Protect all booking routes

router.post('/', createBooking);
router.get('/my', getMyBookings);
router.get('/:id', getBookingById); // Added Route
router.put('/:id/status', updateBookingStatus);
router.put('/:id/details', updateBookingDetails);
router.put('/:id/reschedule-respond', respondReschedule);
// Withdraw your OWN pending reschedule request (asked by mistake).
router.put('/:id/reschedule-cancel', cancelReschedule);
router.put('/:id/counter', counterOffer);
router.put('/:id/accept-offer', acceptOffer);

// Two-OTP work lock
router.put('/:id/arrived', providerArrived);
router.put('/:id/start', startWork);       // provider: Start OTP + before photo
router.put('/:id/complete', completeWork); // provider: Completion OTP + after photo

module.exports = router;
