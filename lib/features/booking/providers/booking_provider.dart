import 'package:flutter/foundation.dart';
import '../../../../core/utils/result.dart'; // Result class
import '../domain/repositories/booking_repository.dart';
import '../data/models/booking_model.dart';

enum BookingStatusState { idle, loading, success, error }

class BookingProvider extends ChangeNotifier {
  final BookingRepository _bookingRepository;

  BookingProvider(this._bookingRepository);

  List<BookingModel> _bookings = [];
  List<BookingModel> get bookings => _bookings;
  
  String? _lastCreatedBookingId;
  String? get lastCreatedBookingId => _lastCreatedBookingId;

  BookingStatusState _status = BookingStatusState.idle;
  BookingStatusState get status => _status;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == BookingStatusState.loading;

  Future<void> fetchMyBookings(String userId) async {
    _status = BookingStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _bookingRepository.getMyBookings(userId);

    if (result.isSuccess) {
      _bookings = result.data!;
      _status = BookingStatusState.success;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<bool> createBooking(BookingModel booking) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.createBooking(booking);

    if (result.isSuccess) {
      _bookings.add(result.data!);
      _lastCreatedBookingId = result.data!.id; // Store the booking ID
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    // Optimistic update or loading? Loading for safety.
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.cancelBooking(bookingId);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rescheduleBooking(String bookingId, DateTime newDate) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.rescheduleBooking(bookingId, newDate);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  /// Withdraw your own pending reschedule request (wrong date picked, etc.).
  Future<bool> cancelReschedule(String bookingId) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.cancelReschedule(bookingId);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) _bookings[index] = result.data!;
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    }
    _status = BookingStatusState.error;
    _errorMessage = result.error?.message;
    notifyListeners();
    return false;
  }

  Future<bool> respondReschedule(String bookingId, bool accept) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.respondReschedule(bookingId, accept);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<BookingModel?> fetchBookingById(String bookingId) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    // Check if we already have it
    try {
      final existing = _bookings.firstWhere((b) => b.id == bookingId);
      _status = BookingStatusState.success;
      notifyListeners();
      return existing;
    } catch (_) {
      // Not found, fetch from repo
    }

    final result = await _bookingRepository.getBookingById(bookingId);

    if (result.isSuccess) {
      final booking = result.data!;
      // Update local list if exists, else add
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = booking;
      } else {
        _bookings.add(booking);
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return booking;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return null;
    }
  }


  Future<bool> counterOffer(String bookingId, String price) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    // Assuming repository has counterOffer method (need to add it to Repo too)
    // But since I don't want to edit Repository interface and impl now, I will add it to repo if needed.
    // Wait, I must edit Repository to call the new API endpoints.
    
    final result = await _bookingRepository.counterOffer(bookingId, price);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptOffer(String bookingId) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.acceptOffer(bookingId);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }


  Future<bool> rateBooking(String bookingId, double rating, String review) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.rateBooking(bookingId, rating, review);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return true;
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<Result<BookingModel>> updateBookingStatus(String bookingId, String status) async {
    _status = BookingStatusState.loading;
    notifyListeners();

    final result = await _bookingRepository.updateBookingStatus(bookingId, status);

    if (result.isSuccess) {
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _bookings[index] = result.data!;
      }
      _status = BookingStatusState.success;
      notifyListeners();
      return Result.success(result.data!);
    } else {
      _status = BookingStatusState.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return Result.failure(result.error!);
    }
  }

  // ── Two-OTP work lock ──
  void _replace(BookingModel b) {
    final i = _bookings.indexWhere((x) => x.id == b.id);
    if (i != -1) _bookings[i] = b;
    notifyListeners();
  }

  Future<Result<BookingModel>> markArrived(String bookingId, double lat, double lng) async {
    final result = await _bookingRepository.markArrived(bookingId, lat, lng);
    if (result.isSuccess) { _replace(result.data!); }
    else { _errorMessage = result.error?.message; notifyListeners(); }
    return result;
  }

  Future<Result<BookingModel>> startWork(String bookingId, String otp, String beforePhotoUrl) async {
    final result = await _bookingRepository.startWork(bookingId, otp, beforePhotoUrl);
    if (result.isSuccess) { _replace(result.data!); }
    else { _errorMessage = result.error?.message; notifyListeners(); }
    return result;
  }

  Future<Result<BookingModel>> completeWork(String bookingId, String otp, String afterPhotoUrl) async {
    final result = await _bookingRepository.completeWork(bookingId, otp, afterPhotoUrl);
    if (result.isSuccess) { _replace(result.data!); }
    else { _errorMessage = result.error?.message; notifyListeners(); }
    return result;
  }
}
