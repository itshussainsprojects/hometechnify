import 'dart:async';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class MockAuthRepository implements AuthRepository {
  // Simulate a local "database" of users
  final List<UserModel> _mockUsers = [
    UserModel(
      id: 'u1',
      name: 'Hassaan Ali',
      email: 'hassaan@example.com',
      phone: '+923001234567',
      joinDate: DateTime.now().subtract(const Duration(days: 365)),
      rating: 4.8,
      totalBookings: 12,
      totalSpent: 15400,
    ),
  ];

  UserModel? _currentUser;

  @override
  Future<Result<void>> login(String phone, String password) async {
    // Simulate Network Latency
    await Future.delayed(const Duration(seconds: 2));
    // Just return success - OTP would be sent
    return Result.success(null);
  }

  @override
  Future<Result<UserModel>> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final user = _mockUsers.firstWhere(
        (u) => u.phone == phone,
        orElse: () {
          // Create new user if not found
          final newUser = UserModel(
            id: 'u${_mockUsers.length + 1}',
            name: 'New User',
            email: 'newuser@example.com',
            phone: phone,
            joinDate: DateTime.now(),
          );
          _mockUsers.add(newUser);
          return newUser;
        },
      );
      _currentUser = user;
      return Result.success(user);
    } catch (e) {
      return Result.failure(const AuthFailure('Invalid OTP'));
    }
  }

  @override
  Future<Result<UserModel>> register(UserModel user, String password, {String role = 'CUSTOMER'}) async {
     await Future.delayed(const Duration(seconds: 2));
     _mockUsers.add(user);
     _currentUser = user;
     return Result.success(user);
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    if (_currentUser != null) {
      return Result.success(_currentUser!);
    }
    return Result.failure(const AuthFailure('User not logged in'));
  }
  @override
  Future<Result<void>> changePassword(String currentPassword, String newPassword) async {
    await Future.delayed(const Duration(seconds: 1));
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = null;
    return Result.success(null);
  }

  @override
  Future<Result<UserModel>> loginWithEmail(String email, String password,
      {String? role}) async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final user = _mockUsers.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('User not found'),
      );
      _currentUser = user;
      return Result.success(user);
    } catch (e) {
      return Result.failure(const AuthFailure('Invalid email or password'));
    }
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<void> verifyPasswordResetOtp(String email, String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    if (otp != '123456') throw Exception('Invalid OTP');
  }

  @override
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<Result<UserModel>> loginWithGoogle(String role) async {
    await Future.delayed(const Duration(seconds: 1));
    // Mock Google login - create/return mock user
    final user = UserModel(
      id: 'google_user_1',
      name: 'Google User',
      email: 'google@example.com',
      phone: '+923001234567',
      joinDate: DateTime.now(),
    );
    _currentUser = user;
    return Result.success(user);
  }
}
