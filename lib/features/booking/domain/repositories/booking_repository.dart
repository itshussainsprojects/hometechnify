
import '../../data/models/booking_model.dart';
import '../../../../core/utils/result.dart'; // Added Result import

abstract class BookingRepository {
  Future<Result<List<BookingModel>>> getMyBookings(String userId);
  Future<Result<BookingModel>> createBooking(BookingModel booking);
  Future<Result<BookingModel>> cancelBooking(String bookingId);
  Future<Result<BookingModel>> rateBooking(String bookingId, double rating, String review);
  Future<Result<BookingModel>> rescheduleBooking(String bookingId, DateTime newDate);
  Future<Result<BookingModel>> respondReschedule(String bookingId, bool accept);

  /// Withdraw your OWN pending reschedule request — for when it was made by
  /// mistake. Only the proposer may do this.
  Future<Result<BookingModel>> cancelReschedule(String bookingId);
  Future<Result<BookingModel>> getBookingById(String bookingId);
  Future<Result<BookingModel>> updateBookingStatus(String bookingId, String status);
  Future<Result<BookingModel>> counterOffer(String bookingId, String price);
  Future<Result<BookingModel>> acceptOffer(String bookingId);

  // Two-OTP work lock
  Future<Result<BookingModel>> markArrived(String bookingId, double lat, double lng);
  Future<Result<BookingModel>> startWork(String bookingId, String otp, String beforePhotoUrl);
  Future<Result<BookingModel>> completeWork(String bookingId, String otp, String afterPhotoUrl);
}
