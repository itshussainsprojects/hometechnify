import 'dart:io';
import '../../../../core/utils/result.dart';
import '../../data/models/provider_model.dart';

abstract class ProviderRepository {
  Future<Result<List<ProviderModel>>> getProviders({String? categoryId, String? search, bool availableOnly, double? lat, double? lng});
  Future<Result<ProviderModel>> getProviderById(String id);
  Future<Result<void>> updateProfile(Map<String, dynamic> data);
  Future<Result<bool>> setAvailability(bool isOnline, {double? lat, double? lng});
  Future<Result<void>> updateMyLocation(double lat, double lng);
  Future<Result<Map<String, dynamic>>> getDashboardStats();
  Future<Result<List<dynamic>>> getWalletHistory();

  /// The provider's real wallet ledger: TOPUP / COMMISSION / WITHDRAWAL rows
  /// with the amounts actually charged.
  Future<Result<List<dynamic>>> getMyTransactions();
  Future<Result<double>> topUpWallet(double amount, String paymentMethod);
  Future<Result<List<dynamic>>> getActiveBookings();
  Future<Result<String>> uploadProfileImage(File imageFile);
  Future<Result<void>> deleteAccount();
  Future<Result<void>> submitBannerRequest(Map<String, dynamic> data);
  Future<Result<void>> toggleNotifications(bool enabled);
  Future<Result<Map<String, dynamic>>> getNotifications({int page = 1});
  Future<Result<void>> markNotificationAsRead(String id);
  Future<Result<void>> deleteNotification(String id);
  Future<Result<Map<String, dynamic>>> getMyReviews();
  Future<Result<Map<String, dynamic>>> requestWithdrawal(Map<String, dynamic> data);
}
