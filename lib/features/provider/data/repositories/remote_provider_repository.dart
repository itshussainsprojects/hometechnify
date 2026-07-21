import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/repositories/provider_repository.dart';
import '../../data/models/provider_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/errors/failures.dart';

class RemoteProviderRepository implements ProviderRepository {
  final ApiService _apiService = ApiService();

  @override
  Future<Result<List<ProviderModel>>> getProviders({String? categoryId, String? search, bool availableOnly = false, double? lat, double? lng}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (categoryId != null) queryParams['categoryId'] = categoryId;
      if (search != null) queryParams['search'] = search;
      if (availableOnly) queryParams['available'] = 'true';
      if (lat != null && lng != null) { queryParams['lat'] = lat; queryParams['lng'] = lng; }

      final response = await _apiService.dio.get('/providers', queryParameters: queryParams);
      
      final data = response.data['data'] as List;
      final providers = data.map((json) => ProviderModel.fromJson(json)).toList();
      return Result.success(providers);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<ProviderModel>> getProviderById(String id) async {
    try {
      final response = await _apiService.dio.get('/providers/$id');
      final data = response.data['data'];
      return Result.success(ProviderModel.fromJson(data));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<bool>> setAvailability(bool isOnline, {double? lat, double? lng}) async {
    try {
      final res = await _apiService.dio.put('/providers/availability', data: {
        'is_online': isOnline,
        // Sent when going Available - powers nearest-first for customers.
        if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
      });
      return Result.success(res.data['is_online'] == true);
    } on DioException catch (e) {
      // Surface the server's reason (e.g. "complete your profile first").
      final msg = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      return Result.failure(ServerFailure(
          msg ?? 'Could not update availability. Check your connection.'));
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> updateMyLocation(double lat, double lng) async {
    try {
      await _apiService.dio
          .put('/providers/location', data: {'lat': lat, 'lng': lng});
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<double>> topUpWallet(double amount, String paymentMethod) async {
    try {
      // DEV MOCK endpoint - credits instantly until the payment gateway
      // (JazzCash/EasyPaisa) API is integrated.
      final res = await _apiService.dio.post('/providers/wallet/topup', data: {
        'amount': amount,
        'payment_method': paymentMethod,
      });
      final balance =
          double.tryParse(res.data['wallet_balance']?.toString() ?? '') ?? 0.0;
      return Result.success(balance);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> updateProfile(Map<String, dynamic> data) async {
    try {
      await _apiService.dio.put('/providers/profile', data: data);
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await _apiService.dio.get('/providers/dashboard/stats');
      return Result.success(response.data['data']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<List<dynamic>>> getWalletHistory() async {
    try {
      final response = await _apiService.dio.get('/providers/wallet/history');
      return Result.success(response.data['data']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  /// Real ledger rows (TOPUP / COMMISSION / WITHDRAWAL) with the amount that was
  /// actually charged. The wallet screen used to re-derive commission from
  /// bookings at a hardcoded 10%, which disagreed with what the backend charged.
  @override
  Future<Result<List<dynamic>>> getMyTransactions() async {
    try {
      final response = await _apiService.dio.get('/providers/transactions');
      return Result.success(response.data['data']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<List<dynamic>>> getActiveBookings() async {
    try {
      final response = await _apiService.dio.get('/providers/bookings/active');
      return Result.success(response.data['data']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      // 1. Delete from Backend (Postgres)
      try {
        await _apiService.dio.delete('/providers/account');
      } catch (e) {
        // Proceed to Firebase delete anyway — otherwise a provider whose
        // Postgres row is already gone (or fails for some other reason)
        // keeps a live Firebase credential forever with no way back in to
        // retry, since the app has no record of them anymore.
      }

      // 2. Delete from Firebase. This was missing entirely — the account
      // "deleted successfully" toast fired while the person's Firebase Auth
      // credential (their actual login) stayed alive, letting them log back
      // in to a provider with no profile, or blocking re-registration with
      // that same email.
      String? error;
      await FirebaseAuthService.deleteUser(onError: (e) => error = e);
      if (error != null) {
        return Result.failure(ServerFailure(error!));
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<String>> uploadProfileImage(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await _apiService.dio.post('/upload', data: formData);
      return Result.success(response.data['data']['url']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  Future<Result<String>> uploadFile(File file) async {
     return uploadProfileImage(file); // Reuse same logic for now
  }

  @override
  Future<Result<void>> submitBannerRequest(Map<String, dynamic> data) async {
    try {
      await _apiService.dio.post('/providers/banner-request', data: data);
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> toggleNotifications(bool enabled) async {
    try {
      await _apiService.dio.put('/notifications/toggle', data: {'enabled': enabled});
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getNotifications({int page = 1}) async {
    try {
      final response = await _apiService.dio.get('/notifications', queryParameters: {'page': page});
      return Result.success(response.data);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> markNotificationAsRead(String id) async {
    try {
      await _apiService.dio.put('/notifications/$id/read');
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<void>> deleteNotification(String id) async {
    try {
      await _apiService.dio.delete('/notifications/$id');
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getMyReviews() async {
    try {
      final response = await _apiService.dio.get('/reviews/my');
      return Result.success(response.data['data']);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> requestWithdrawal(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.dio.post('/providers/withdraw', data: data);
      return Result.success(response.data);
    } catch (e) {
      if (e is DioException && e.response != null) {
        final msg = e.response?.data?['message'] ?? 'Withdrawal failed';
        return Result.failure(ServerFailure(msg));
      }
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }
}


