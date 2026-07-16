import 'dart:async';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/booking_repository.dart';
import '../models/booking_model.dart';

class MockBookingRepository implements BookingRepository {
  final List<BookingModel> _mockBookings = [
    BookingModel(
      id: 'b1',
      customerId: 'u1',
      providerId: 'p1',
      providerName: 'Ahmed Khan',
      serviceName: 'Plumbing Repair',
      serviceId: 's1',
      address: 'House 123, Block A',
      price: 1500,
      status: 'completed',
      bookingDate: DateTime.now().subtract(const Duration(days: 2)),
      lat: 31.5204,
      lng: 74.3587,
      paymentStatus: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      customerName: 'Hassaan Ali',
    ),
    BookingModel(
      id: 'b2',
      customerId: 'u1',
      providerId: 'p2',
      providerName: 'Bilal Electrician',
      serviceName: 'AC Service',
      serviceId: 's2',
      address: 'House 123, Block A',
      price: 2500,
      status: 'active',
      bookingDate: DateTime.now(),
      lat: 31.5204,
      lng: 74.3587,
      paymentStatus: 'PENDING',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerName: 'Hassaan Ali',
    ),
  ];

  @override
  Future<Result<List<BookingModel>>> getMyBookings(String userId) async {
    await Future.delayed(const Duration(seconds: 1));
    // In a real mock, we filter by userId. For now return all for demo.
    return Result.success(_mockBookings);
  }

  @override
  Future<Result<BookingModel>> createBooking(BookingModel booking) async {
    await Future.delayed(const Duration(seconds: 2));
    _mockBookings.add(booking);
    return Result.success(booking);
  }

  @override
  Future<Result<BookingModel>> cancelBooking(String bookingId) async {
    await Future.delayed(const Duration(seconds: 1));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
       // Create a copy with cancelled status (since fields are final)
       // For simplicity in mock, we'll just return a new object
       return Result.success(_mockBookings[index]); 
    }
    return Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> getBookingById(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 500));
     try {
      final booking = _mockBookings.firstWhere((b) => b.id == bookingId);
      return Result.success(booking);
    } catch (e) {
      return Result.failure(const ServerFailure('Booking not found'));
    }
  }
  @override
  Future<Result<BookingModel>> rateBooking(String bookingId, double rating, String review) async {
    await Future.delayed(const Duration(seconds: 1));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
     if (index != -1) {
       return Result.success(_mockBookings[index]);
     }
    return Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> rescheduleBooking(String bookingId, DateTime newDate) {
    // TODO: implement rescheduleBooking
    throw UnimplementedError();
  }

  @override
  Future<Result<BookingModel>> respondReschedule(String bookingId, bool accept) {
    throw UnimplementedError();
  }

  @override
  Future<Result<BookingModel>> cancelReschedule(String bookingId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<BookingModel>> updateBookingStatus(String bookingId, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
     if (index != -1) {
       // In real app, we would update status. For mock, just return it.
       return Result.success(_mockBookings[index]);
     }
    return Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> counterOffer(String bookingId, String price) async {
     await Future.delayed(const Duration(seconds: 1));
     final index = _mockBookings.indexWhere((b) => b.id == bookingId);
     if (index != -1) {
       return Result.success(_mockBookings[index]);
     }
    return Result.failure(const ServerFailure('Booking not found'));
  }

  BookingModel? _find(String id) {
    final i = _mockBookings.indexWhere((b) => b.id == id);
    return i != -1 ? _mockBookings[i] : null;
  }

  @override
  Future<Result<BookingModel>> markArrived(String bookingId, double lat, double lng) async {
    final b = _find(bookingId);
    return b != null ? Result.success(b) : Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> startWork(String bookingId, String otp, String beforePhotoUrl) async {
    final b = _find(bookingId);
    return b != null ? Result.success(b) : Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> completeWork(String bookingId, String otp, String afterPhotoUrl) async {
    final b = _find(bookingId);
    return b != null ? Result.success(b) : Result.failure(const ServerFailure('Booking not found'));
  }

  @override
  Future<Result<BookingModel>> acceptOffer(String bookingId) async {
     await Future.delayed(const Duration(seconds: 1));
     final index = _mockBookings.indexWhere((b) => b.id == bookingId);
     if (index != -1) {
       return Result.success(_mockBookings[index]);
     }
    return Result.failure(const ServerFailure('Booking not found'));
  }
}
