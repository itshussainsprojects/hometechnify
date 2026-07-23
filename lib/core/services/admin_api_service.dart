import 'package:dio/dio.dart';
import 'api_service.dart';

/// Central service for all Admin Panel API calls.
/// Uses the same Dio client as ApiService (with Firebase auth headers).
class AdminApiService {
  final Dio _dio;

  AdminApiService() : _dio = ApiService().dio;

  // ─────────────────────────────────────────────
  // DASHBOARD STATS
  // ─────────────────────────────────────────────

  /// Fetch real-time dashboard KPIs and weekly chart data.
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final res = await _dio.get('/admin/stats');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Fetch finance summary (revenue, withdrawals, recent transactions).
  Future<Map<String, dynamic>> fetchFinanceStats() async {
    final res = await _dio.get('/admin/finance');
    return res.data['data'] as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────
  // USERS
  // ─────────────────────────────────────────────

  /// Fetch all users with optional status/search filter.
  Future<List<dynamic>> fetchUsers({String? status, String? search, int page = 1}) async {
    final params = <String, dynamic>{'page': page, 'limit': 100};
    if (status != null && status != 'all') params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/admin/users', queryParameters: params);
    return res.data['data'] as List;
  }

  /// Block or unblock a user.
  Future<bool> blockUser(String id, {required bool block}) async {
    final res = await _dio.put('/admin/users/$id/block', data: {'block': block});
    return res.data['success'] == true;
  }

  /// Which customers picked Cash vs Wallet, and which wallet — synced from
  /// the customer app's own profile screen, not something admin sets here.
  Future<List<dynamic>> fetchCustomerPaymentMethods({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/admin/users/payment-methods', queryParameters: params);
    return res.data['data'] as List;
  }

  /// Move a user to the recycle bin. Reversible via [restoreUser]; the account
  /// is hidden everywhere and loses API access until it is restored.
  Future<bool> deleteUser(String id) async {
    final res = await _dio.delete('/admin/users/$id');
    return res.data['success'] == true;
  }

  /// Bring a user back from the recycle bin.
  Future<bool> restoreUser(String id) async {
    final res = await _dio.put('/admin/users/$id/restore');
    return res.data['success'] == true;
  }

  /// Bring a provider back from the recycle bin.
  Future<bool> restoreProvider(String id) async {
    final res = await _dio.put('/admin/providers/$id/restore');
    return res.data['success'] == true;
  }

  /// Set a provider's trade. Job matching is by category, and until this existed
  /// nothing could set one — every provider was filed under whatever category
  /// happened to be first in the table, so any new category an admin created
  /// stayed permanently empty and its jobs reached nobody.
  Future<bool> setProviderCategory(String providerId, String categoryId) async {
    final res = await _dio.put(
      '/admin/providers/$providerId/category',
      data: {'categoryId': categoryId},
    );
    return res.data['success'] == true;
  }

  // ─────────────────────────────────────────────
  // PROVIDERS
  // ─────────────────────────────────────────────

  /// Fetch all providers with optional status/search filter.
  Future<List<dynamic>> fetchProviders({String? status, String? search, int page = 1}) async {
    final params = <String, dynamic>{'page': page, 'limit': 100};
    if (status != null && status != 'all') params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _dio.get('/admin/providers', queryParameters: params);
    return res.data['data'] as List;
  }

  /// Verify or revoke verification for a provider.
  Future<bool> verifyProvider(String id, {required bool verify}) async {
    final res = await _dio.put('/admin/providers/$id/verify', data: {'verify': verify});
    return res.data['success'] == true;
  }

  /// Block or unblock a provider.
  Future<bool> blockProvider(String id, {required bool block}) async {
    final res = await _dio.put('/admin/providers/$id/block', data: {'block': block});
    return res.data['success'] == true;
  }

  /// Soft-delete a provider.
  Future<bool> deleteProvider(String id) async {
    final res = await _dio.delete('/admin/providers/$id');
    return res.data['success'] == true;
  }

  // ─── Ratings management ───

  /// Returns { 'threshold': double, 'data': List } of providers with rating info.
  Future<Map<String, dynamic>> fetchRatings() async {
    final res = await _dio.get('/admin/ratings');
    return {
      'threshold': (res.data['threshold'] as num?)?.toDouble() ?? 2.0,
      'data': res.data['data'] as List? ?? [],
    };
  }

  /// Admin sets/edits a provider's rating (0–5).
  Future<bool> setProviderRating(String id, double rating) async {
    final res = await _dio.put('/admin/providers/$id/rating', data: {'rating': rating});
    return res.data['success'] == true;
  }

  /// Admin removes/resets a provider's rating to 0.
  Future<bool> resetProviderRating(String id) async {
    final res = await _dio.delete('/admin/providers/$id/rating');
    return res.data['success'] == true;
  }

  /// Admin sets the auto-flag threshold (providers below it are flagged red).
  Future<bool> setRatingThreshold(double threshold) async {
    final res = await _dio.put('/admin/settings/rating-threshold', data: {'threshold': threshold});
    return res.data['success'] == true;
  }

  /// Platform settings: commission % + provider search radius (km).
  Future<Map<String, dynamic>> fetchPlatformSettings() async {
    final res = await _dio.get('/admin/settings/platform');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Changing these applies to ALL providers live (commission is read at every
  /// job completion; radius at every provider search) and is broadcast on socket.
  Future<bool> setPlatformSettings({double? commissionPercent, double? providerRadiusKm}) async {
    final res = await _dio.put('/admin/settings/platform', data: {
      if (commissionPercent != null) 'commission_percent': commissionPercent,
      if (providerRadiusKm != null) 'provider_radius_km': providerRadiusKm,
    });
    return res.data['success'] == true;
  }

  // ─────────────────────────────────────────────
  // BOOKINGS
  // ─────────────────────────────────────────────

  /// Fetch all bookings with optional status + trade (category) filter.
  Future<List<dynamic>> fetchBookings({String? status, String? categoryId, int page = 1}) async {
    final params = <String, dynamic>{'page': page, 'limit': 100};
    if (status != null && status != 'all') params['status'] = status;
    if (categoryId != null && categoryId != 'all') params['categoryId'] = categoryId;
    final res = await _dio.get('/admin/bookings', queryParameters: params);
    return res.data['data'] as List;
  }

  // ─────────────────────────────────────────────
  // WITHDRAWALS
  // ─────────────────────────────────────────────

  /// Fetch all withdrawal requests.
  Future<List<dynamic>> fetchWithdrawals({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status != 'all') params['status'] = status;
    final res = await _dio.get('/admin/withdrawals', queryParameters: params);
    return res.data['data'] as List;
  }

  /// Approve or reject a withdrawal request.
  Future<bool> updateWithdrawal(String id, {required bool approve, String? adminNote}) async {
    final res = await _dio.put('/admin/withdrawals/$id', data: {
      'action': approve ? 'APPROVED' : 'REJECTED',
      if (adminNote != null) 'admin_note': adminNote,
    });
    return res.data['success'] == true;
  }

  // ── Manual payout transactions (under a withdrawal) ──

  /// A provider's transaction history (top-ups, commissions, payouts).
  Future<List<dynamic>> fetchProviderTransactions(String providerId) async {
    final res = await _dio.get('/admin/providers/$providerId/transactions');
    return res.data['data'] as List;
  }

  /// Record that a provider was paid (status SUCCESS) or not yet (PENDING).
  Future<bool> createTransaction({required String userId, required double amount, String? type, String? paymentMethod, String? status, String? note}) async {
    final res = await _dio.post('/admin/transactions', data: {
      'userId': userId,
      'amount': amount,
      if (type != null) 'type': type,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
    });
    return res.data['success'] == true;
  }

  /// Edit a transaction (amount / paid-unpaid / note).
  Future<bool> updateTransaction(String id, {double? amount, String? status, String? paymentMethod, String? note}) async {
    final res = await _dio.put('/admin/transactions/$id', data: {
      if (amount != null) 'amount': amount,
      if (status != null) 'status': status,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (note != null) 'note': note,
    });
    return res.data['success'] == true;
  }

  /// Delete a transaction record.
  Future<bool> deleteTransaction(String id) async {
    final res = await _dio.delete('/admin/transactions/$id');
    return res.data['success'] == true;
  }

  // ─────────────────────────────────────────────
  // PROMOS
  // ─────────────────────────────────────────────

  /// Fetch all promo banners.
  Future<List<dynamic>> fetchPromos() async {
    final res = await _dio.get('/admin/promos');
    return res.data['data'] as List;
  }

  /// Create a new promo.
  Future<Map<String, dynamic>?> createPromo({
    required String title,
    String? subtitle,
    String? code,
    double discount = 0,
    int colorValue = 0xFF1565C0,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/admin/promos', data: {
      'title': title,
      'subtitle': subtitle,
      'code': code,
      'discount': discount,
      'color_value': colorValue,
      'is_active': isActive,
    });
    if (res.data['success'] == true) return res.data['data'];
    return null;
  }

  /// Update an existing promo.
  Future<bool> updatePromo(String id, Map<String, dynamic> updates) async {
    final res = await _dio.put('/admin/promos/$id', data: updates);
    return res.data['success'] == true;
  }

  /// Toggle promo active state.
  Future<bool> togglePromo(String id, bool isActive) async {
    return updatePromo(id, {'is_active': isActive});
  }

  /// Delete a promo.
  Future<bool> deletePromo(String id) async {
    final res = await _dio.delete('/admin/promos/$id');
    return res.data['success'] == true;
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS (FCM PUSH)
  // ─────────────────────────────────────────────

  /// Send an admin push notification.
  /// [targetType]: 'ALL', 'ALL_USERS', 'ALL_PROVIDERS', 'SPECIFIC'
  /// [userIds]: required if targetType is 'SPECIFIC'
  Future<int> sendAdminNotification({
    required String title,
    required String body,
    required String targetType,
    List<String>? userIds,
  }) async {
    final res = await _dio.post('/admin/notify', data: {
      'title': title,
      'body': body,
      'target_type': targetType,
      if (userIds != null) 'user_ids': userIds,
    });
    return res.data['sent_count'] ?? 0;
  }

  // ─────────────────────────────────────────────
  // CATEGORIES & SERVICES (from core routes)
  // ─────────────────────────────────────────────

  Future<List<dynamic>> fetchCategories() async {
    final res = await _dio.get('/categories');
    return res.data['data'] as List;
  }

  /// Builds the request body for a category/service icon: a multipart upload
  /// when the admin picked an image file, a plain JSON body otherwise.
  Future<dynamic> _withIcon(Map<String, dynamic> fields, String? iconPath) async {
    if (iconPath == null) return fields;
    return FormData.fromMap({
      ...fields.map((k, v) => MapEntry(k, v?.toString())),
      // The backend derives the stored file's extension from this name, so keep
      // the real basename (works for both / and \ paths).
      'icon': await MultipartFile.fromFile(
        iconPath,
        filename: iconPath.split(RegExp(r'[/\\]')).last,
      ),
    });
  }

  Future<Map<String, dynamic>?> createCategory(String name,
      {String? iconUrl, String? iconPath}) async {
    final res = await _dio.post('/categories',
        data: await _withIcon({'name': name, 'iconUrl': iconUrl}, iconPath));
    if (res.data['success'] == true) return res.data['data'];
    return null;
  }

  Future<bool> updateCategory(String id,
      {String? name, String? iconUrl, String? iconPath}) async {
    final res = await _dio.put('/categories/$id',
        data: await _withIcon({
          if (name != null) 'name': name,
          if (iconUrl != null) 'iconUrl': iconUrl,
        }, iconPath));
    return res.data['success'] == true;
  }

  Future<bool> deleteCategory(String id) async {
    final res = await _dio.delete('/categories/$id');
    return res.data['success'] == true;
  }

  Future<List<dynamic>> fetchServices({String? categoryId}) async {
    final params = categoryId != null ? {'categoryId': categoryId} : <String, dynamic>{};
    final res = await _dio.get('/services', queryParameters: params);
    return res.data['data'] as List;
  }

  Future<Map<String, dynamic>?> createService({
    required String categoryId,
    required String name,
    double price = 0,
    String? description,
    double? minPrice,
    double? maxPrice,
    String? iconPath,
  }) async {
    final res = await _dio.post('/services',
        data: await _withIcon({
          'categoryId': categoryId,
          'name': name,
          'price': price,
          'description': description,
          'minPrice': minPrice,
          'maxPrice': maxPrice,
        }, iconPath));
    if (res.data['success'] == true) return res.data['data'];
    return null;
  }

  // minPrice/maxPrice are always sent (value or null) so bounds can be set or cleared.
  Future<bool> updateService(String id,
      {String? name,
      double? price,
      String? description,
      double? minPrice,
      double? maxPrice,
      String? iconPath}) async {
    final res = await _dio.put('/services/$id',
        data: await _withIcon({
          if (name != null) 'name': name,
          if (price != null) 'price': price,
          if (description != null) 'description': description,
          'minPrice': minPrice,
          'maxPrice': maxPrice,
        }, iconPath));
    return res.data['success'] == true;
  }

  Future<bool> deleteService(String id) async {
    final res = await _dio.delete('/services/$id');
    return res.data['success'] == true;
  }
}

/// Singleton instance for use across admin screens.
final adminApiService = AdminApiService();
