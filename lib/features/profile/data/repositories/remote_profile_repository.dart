import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/data/models/user_model.dart';

class RemoteProfileRepository {
  final ApiService _apiService = ApiService();

  Future<Result<UserModel>> getProfile(String userId) async {
    try {
      final response = await _apiService.dio.get('/auth/me');
      
      final data = response.data['data'];
      debugPrint("getProfile response - profileImage: ${data['profileImage']}");
      
      return Result.success(UserModel(
        id: data['id'] ?? userId,
        name: data['name'] ?? 'User',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        profileImage: data['profileImage'], // <-- THIS WAS MISSING!
        joinDate: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
        totalBookings: data['bookings_count'] ?? 0,
        totalSpent: (data['total_spent'] ?? 0).toDouble(),
        rating: (data['rating'] ?? 0).toDouble(),
      ));
    } catch (e) {
      debugPrint("getProfile error: $e");
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  Future<Result<UserModel>> updateProfile(UserModel user) async {
    try {
      debugPrint("=== UPDATE PROFILE ===");
      debugPrint("Sending profileImage: ${user.profileImage}");
      
      final response = await _apiService.dio.put(
        '/auth/me',
        data: {
          'name': user.name,
          'phone': user.phone,
          'profileImage': user.profileImage,
        },
      );

      final data = response.data['data'];
      debugPrint("Response profileImage: ${data['profileImage']}");
      
      return Result.success(UserModel(
        id: data['id'] ?? user.id,
        name: data['name'] ?? user.name,
        email: data['email'] ?? user.email,
        phone: data['phone'] ?? user.phone,
        profileImage: data['profileImage'], // <-- THIS WAS MISSING!
        joinDate: user.joinDate,
        totalBookings: user.totalBookings,
        totalSpent: user.totalSpent,
        rating: user.rating,
      ));
    } catch (e) {
      debugPrint("Update profile error: $e");
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  Future<String?> uploadProfileImage(File image) async {
    try {
      debugPrint("=== UPLOAD START ===");
      debugPrint("Image path: ${image.path}");
      
      String fileName = image.path.split('/').last;
      debugPrint("Filename: $fileName");
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(image.path, filename: fileName),
      });
      debugPrint("FormData created, making request to /upload...");

      final response = await _apiService.dio.post('/upload', data: formData);
      debugPrint("Response received: ${response.statusCode}");
      debugPrint("Response data: ${response.data}");
      
      final relativeUrl = response.data['data']['url'];
      debugPrint("Uploaded URL: $relativeUrl");
      
      // Fix: If backend returns a full URL (Supabase), use it directly.
      // If it returns a relative path (Local), prepend base URL.
      if (relativeUrl.toString().startsWith('http')) {
        return relativeUrl;
      }

      final baseUrl = _apiService.dio.options.baseUrl; 
      final rootUrl = baseUrl.replaceAll('/api', '');
      final fullUrl = '$rootUrl$relativeUrl';
      
      debugPrint("Full URL: $fullUrl");
      debugPrint("=== UPLOAD SUCCESS ===");
      
      return fullUrl;
    } catch (e, stack) {
      debugPrint("=== UPLOAD FAILED ===");
      debugPrint("Error: $e");
      debugPrint("Stack: $stack");
      return null;
    }
  }

  Future<Result<void>> toggleNotifications(bool enabled) async {
    try {
      await _apiService.dio.put('/notifications/toggle', data: {'enabled': enabled});
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  /// Was only ever saved to the device's own SharedPreferences — admin had
  /// no way to see which payment method a customer picked, and the choice
  /// didn't survive a reinstall or a new device.
  Future<Result<void>> updatePaymentPreference({
    String? paymentMethod,
    String? wallet,
  }) async {
    try {
      await _apiService.dio.put('/auth/me', data: {
        if (paymentMethod != null) 'preferred_payment_method': paymentMethod,
        if (wallet != null) 'preferred_wallet': wallet,
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  Future<Result<UserModel>> updateProfileImage(String userId, String imageUrl) async {
     try {
       // We can reuse updateProfile? No, updateProfile doesn't send profileImage in body currently.
       // We should verify if backend updateMe supports profileImage.
       // Looking at authController.js earlier: 
       /* 
          const { name, phone } = req.body;
          const user = await prisma.user.update({ ... data: { name, phone } });
       */
       // IT DOES NOT SUPPORT profileImage!
       // I MUST UPDATE BACKEND authController.js as well!
       return Result.failure(ServerFailure("Backend updateMe needs update"));
     } catch (e) {
       return Result.failure(ServerFailure(friendlyErrorMessage(e)));
     }
  }
}
