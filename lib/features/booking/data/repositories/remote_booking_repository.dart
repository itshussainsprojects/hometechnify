import 'package:dio/dio.dart';
import '../../domain/repositories/booking_repository.dart';
import '../models/booking_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';

class RemoteBookingRepository implements BookingRepository {
  final ApiService _apiService = ApiService();

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Could not connect to server. Please check your internet connection.';
      }
      final msg = e.response?.data?['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<Result<BookingModel>> createBooking(BookingModel booking) async {
    try {
      final response = await _apiService.dio.post(
        '/bookings',
        data: booking.toJson(), 
      );
      
      // Backend returns { status: 'success', data: { booking } }
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<List<BookingModel>>> getMyBookings(String userId) async {
    try {
      final response = await _apiService.dio.get('/bookings/my');
      // Backend returns { status: 'success', data: [ ...bookings ] }
      final data = response.data['data'] as List;
      final bookings = data.map((json) => BookingModel.fromJson(json)).toList();
      return Result.success(bookings);
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> cancelBooking(String bookingId) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/status',
        data: {'status': 'CANCELLED'},
      );
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<BookingModel>> rescheduleBooking(String bookingId, DateTime newDate) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/details',
        data: {
          'scheduledAt': newDate.toIso8601String(),
          // 'notes': notes // Optional, if we want to update notes too
        },
      );
      // Backend returns { success: true, data: { ... } }
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<BookingModel>> respondReschedule(String bookingId, bool accept) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/reschedule-respond',
        data: {'accept': accept},
      );
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> cancelReschedule(String bookingId) async {
    try {
      final response = await _apiService.dio.put('/bookings/$bookingId/reschedule-cancel');
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> rateBooking(String bookingId, double rating, String review) async {
    try {
      // The review system lives at POST /reviews (reviewRoutes.js), not
      // /bookings/:id/review — that route never existed, so every rating
      // submission 404'd silently. It also expects bookingId IN the body
      // and the comment field named 'comment', and it returns the created
      // Review row, not a Booking, so BookingModel.fromJson(data) on its
      // response would have thrown even once the URL was fixed.
      await _apiService.dio.post(
        '/reviews',
        data: {
          'bookingId': bookingId,
          'rating': rating.round(),
          'comment': review,
        },
      );
      final response = await _apiService.dio.get('/bookings/$bookingId');
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<BookingModel>> getBookingById(String bookingId) async {
    try {
      final response = await _apiService.dio.get('/bookings/$bookingId');
      
      // Backend returns { status: 'success', data: { ...booking } }
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<BookingModel>> updateBookingStatus(String bookingId, String status) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/status',
        data: {'status': status},
      );
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<BookingModel>> counterOffer(String bookingId, String price) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/counter',
        data: {'price': price},
      );
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      // Surfaces server messages like "Wait for the other side to respond."
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> acceptOffer(String bookingId) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/accept-offer',
        data: {},
      );
      final data = response.data['data'];
      return Result.success(BookingModel.fromJson(data));
    } catch (e) {
      // Surfaces server messages like "provider is busy on another job".
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> markArrived(String bookingId, double lat, double lng) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/arrived',
        data: {'lat': lat, 'lng': lng},
      );
      return Result.success(BookingModel.fromJson(response.data['data']));
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> startWork(String bookingId, String otp, String beforePhotoUrl) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/start',
        data: {'otp': otp, 'beforePhoto': beforePhotoUrl},
      );
      return Result.success(BookingModel.fromJson(response.data['data']));
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }

  @override
  Future<Result<BookingModel>> completeWork(String bookingId, String otp, String afterPhotoUrl) async {
    try {
      final response = await _apiService.dio.put(
        '/bookings/$bookingId/complete',
        data: {'otp': otp, 'afterPhoto': afterPhotoUrl},
      );
      return Result.success(BookingModel.fromJson(response.data['data']));
    } catch (e) {
      return Result.failure(ServerFailure(_friendlyError(e)));
    }
  }
}
