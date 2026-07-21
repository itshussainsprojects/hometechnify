// Remote Auth Repository - Firebase Authentication

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository for authentication operations using Firebase
class RemoteAuthRepository implements AuthRepository {
  /// Get current auth token (Firebase ID token)
  String? get token => FirebaseAuthService.getUserId();

  /// Check if user is authenticated
  bool get isAuthenticated => FirebaseAuthService.isAuthenticated();

  /// Get current user ID
  String? get userId => FirebaseAuthService.getUserId();

  final ApiService _apiService = ApiService();

  @override
  Future<Result<void>> login(String phone, String password) async {
    // Firebase uses OTP for phone login - this sends OTP
    try {
      await FirebaseAuthService.sendOtp(
        phoneNumber: phone,
        onCodeSent: (_) {},
        onError: (_) {},
        onAutoVerify: (_) {},
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<UserModel>> verifyOtp(String phone, String otp) async {
    try {
      final result = await FirebaseAuthService.verifyOtp(
        otp: otp,
        onError: (_) {},
      );
      if (result != null) {
        return Result.success(UserModel(
          id: result.user?.uid ?? '',
          name: result.user?.displayName ?? 'User',
          email: result.user?.email ?? '',
          phone: result.user?.phoneNumber ?? phone,
          joinDate: DateTime.now(),
        ));
      }
      return Result.failure(const AuthFailure('Verification failed'));
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<UserModel>> register(UserModel user, String password, {String role = 'CUSTOMER'}) async {
    // For Firebase, registration is done via phone OTP or email signup
    try {
      final result = await FirebaseAuthService.signUpWithEmail(
        email: user.email,
        password: password,
        onError: (_) {},
      );
      if (result != null) {
        await FirebaseAuthService.updateDisplayName(user.name);
        
        final userId = result.user?.uid ?? '';
        
        // SAVE TO FIRESTORE for fallback (when backend is down)
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'name': user.name,
            'email': user.email,
            'phone': user.phone,
            'role': role,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint("✅ Saved user data to Firestore for fallback");
        } catch (e) {
          debugPrint("⚠️ Failed to save to Firestore: $e");
        }
        
        // FORCE SYNC with Backend. Pass name + phone explicitly: this is an
        // email/password signup, so Firebase carries neither, and without them
        // the backend row would be created with a null phone and a placeholder
        // name — losing exactly the details the user just entered.
        String? fcmToken = await NotificationService().getFCMToken();
        try {
           await _apiService.syncUser(
             fcmToken: fcmToken,
             role: role,
             name: user.name,
             phone: user.phone,
           );
           debugPrint("Registered and Synced as $role");
        } catch (e) {
           debugPrint("Sync failed during Registration: $e");
        }

        return Result.success(UserModel(
          id: userId,
          name: user.name,
          email: result.user?.email ?? user.email,
          phone: user.phone,
          joinDate: DateTime.now(),
          role: role,
        ));
      }
      return Result.failure(const AuthFailure('Registration failed'));
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<void> logout() async {
    await FirebaseAuthService.signOut();
  }

  /// Housekeeping on every app start: refresh the FCM token on the backend.
  /// Never awaited on the startup path — it must not delay routing.
  Future<void> _syncSession(String firebaseId) async {
    try {
      final fcmToken = await NotificationService().getFCMToken();
      // A session refresh asserts no role: the account's role already lives in
      // the DB, and guessing one here would trip the backend's role guard.
      await _apiService.syncUser(fcmToken: fcmToken);
    } catch (e) {
      debugPrint('Session sync failed (non-fatal): $e');
    }
  }

  /// Builds the signed-in user from the backend response.
  ///
  /// The role comes from the backend DB and nothing else. It used to be
  /// overridable by the user's own Firestore document — which the security
  /// rules let that same user write — so anyone could set role: 'ADMIN' on
  /// themselves and be routed into the admin app.
  UserModel _userFromBackend(
    Map<String, dynamic> data, {
    required String firebaseId,
    required String firebaseName,
    required String firebaseEmail,
    required String firebasePhone,
  }) {
    return UserModel(
      id: data['id'] ?? firebaseId,
      name: data['name'] ?? firebaseName,
      email: data['email'] ?? firebaseEmail,
      phone: data['phone'] ?? firebasePhone,
      profileImage: data['profileImage'],
      joinDate: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      role: data['role'] ?? 'CUSTOMER',
      // /auth/me computes this server-side ('pending_verification' for an
      // unverified provider) — it was never read here, so UserModel's
      // 'active' default won every single login regardless of what the
      // backend actually sent. That's the one field every pending/blur-gate
      // check in the app (login routing, splash fast-path correction) reads,
      // so its absence silently defeated all of them.
      status: data['status'] ?? 'active',
    );
  }

  /// Mirrors the user into Firestore so the app can still open on the right
  /// screen when the backend is unreachable. Fire-and-forget.
  void _cacheToFirestore(String firebaseId, UserModel user) {
    FirebaseFirestore.instance.collection('users').doc(firebaseId).set({
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': user.role,
      'profileImage': user.profileImage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) {
      debugPrint('Firestore cache write failed (non-fatal): $e');
    });
  }

  @override
  Future<Result<UserModel>> getCurrentUser() async {
    if (FirebaseAuthService.isAuthenticated()) {
      // 1. Get Firebase basics (for fallback)
      final firebaseId = FirebaseAuthService.getUserId() ?? '';
      final firebaseName = FirebaseAuthService.getUserName();
      final firebaseEmail = FirebaseAuthService.getUserEmail() ?? '';
      final firebasePhone = FirebaseAuthService.getUserPhone() ?? '';

      debugPrint("=== getCurrentUser START ===");

      // Refreshing the FCM token and re-syncing the backend is housekeeping.
      // Awaiting it used to add three network round-trips before the app could
      // even decide which screen to open, so every returning user sat on the
      // splash for seconds. Fire it off and route on /auth/me alone.
      final housekeeping = _syncSession(firebaseId);

      try {
        final response = await _apiService.dio.get('/auth/me');
        final user = _userFromBackend(
          response.data['data'],
          firebaseId: firebaseId,
          firebaseName: firebaseName,
          firebaseEmail: firebaseEmail,
          firebasePhone: firebasePhone,
        );
        debugPrint("=== getCurrentUser SUCCESS - Role: ${user.role} ===");
        _cacheToFirestore(firebaseId, user); // offline fallback, not awaited
        return Result.success(user);
      } catch (e) {
        debugPrint('/auth/me failed: $e');

        // The DB row may not exist yet (first launch after a fresh install).
        // The sync creates it, so wait for it once and retry before giving up.
        try {
          await housekeeping;
          final response = await _apiService.dio.get('/auth/me');
          final user = _userFromBackend(
            response.data['data'],
            firebaseId: firebaseId,
            firebaseName: firebaseName,
            firebaseEmail: firebaseEmail,
            firebasePhone: firebasePhone,
          );
          debugPrint("=== getCurrentUser SUCCESS after sync - Role: ${user.role} ===");
          _cacheToFirestore(firebaseId, user);
          return Result.success(user);
        } catch (_) { /* fall through to the offline path below */ }
      }

      // Offline / backend-down fallback: use the copy we cached in Firestore on
      // the last successful start, so the app still opens on the right screen.
      debugPrint("=== getCurrentUser FALLBACK to Firestore cache ===");
      String role = 'CUSTOMER';
      String? fsName;
      String? fsEmail;
      String? fsProfileImage;
      String? fsPhone;
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          role = data['role'] ?? 'CUSTOMER';
          fsName = data['name'] as String?;
          fsEmail = data['email'] as String?;
          fsProfileImage = data['profileImage'] as String?;
          fsPhone = data['phone'] as String?;
          debugPrint("Firestore cache: Role=$role, Name=$fsName");
        }
      } catch (e) {
        debugPrint("Firestore fallback error: $e");
      }

      return Result.success(UserModel(
        id: firebaseId,
        name: fsName ?? (firebaseName.isNotEmpty ? firebaseName : 'User'),
        email: fsEmail ?? firebaseEmail,
        phone: fsPhone ?? firebasePhone,
        profileImage: fsProfileImage,
        joinDate: DateTime.now(),
        role: role,
      ));
    }
    return Result.failure(const AuthFailure('Not authenticated'));
  }

  @override
  Future<Result<void>> changePassword(String currentPassword, String newPassword) async {
    try {
      String? error;
      await FirebaseAuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        onError: (e) => error = e,
      );
      if (error != null) {
        return Result.failure(AuthFailure(error!));
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  /// Syncs the signed-in user with the backend under [role] and returns an
  /// error message if the backend says the account belongs to the other app.
  /// Any other sync failure returns null — it must not block a valid login.
  Future<String?> _rejectIfWrongApp(String role) async {
    try {
      final fcmToken = await NotificationService().getFCMToken();
      await _apiService.syncUser(fcmToken: fcmToken, role: role);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 403 &&
          data is Map &&
          data['code'] == 'ROLE_MISMATCH') {
        return data['message'] as String? ??
            'This account cannot be used on this app.';
      }
      debugPrint('Sync failed during login (non-fatal): $e');
      return null;
    } catch (e) {
      debugPrint('Sync failed during login (non-fatal): $e');
      return null;
    }
  }

  @override
  Future<Result<UserModel>> loginWithEmail(String email, String password,
      {String? role}) async {
    try {
      String? error;
      final credential = await FirebaseAuthService.signInWithEmail(
        email: email,
        password: password,
        onError: (e) => error = e,
      );

      if (credential != null && credential.user != null) {
        // A provider must not get into the customer app, or vice versa. The
        // backend is the authority; sign back out so a rejected login never
        // leaves a half-open Firebase session behind.
        if (role != null) {
          final rejection = await _rejectIfWrongApp(role);
          if (rejection != null) {
            await FirebaseAuthService.signOut();
            return Result.failure(AuthFailure(rejection));
          }
        }

        final userResult = await getCurrentUser();
        if (userResult.isSuccess) {
           return Result.success(userResult.data!);
        }

         return Result.success(UserModel(
            id: credential.user!.uid,
            name: credential.user!.displayName ?? 'User',
            email: credential.user!.email ?? '',
            phone: credential.user!.phoneNumber ?? '',
            joinDate: DateTime.now(),
         ));
      }
      return Result.failure(AuthFailure(error ?? 'Login failed'));
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Result<UserModel>> loginWithGoogle(String role) async {
    try {
      String? error;
      final credential = await FirebaseAuthService.signInWithGoogle(
        onError: (e) => error = e,
      );

      if (credential != null && credential.user != null) {
        // Same role gate as email login: a Google account already registered as
        // a provider cannot slip into the customer app.
        final rejection = await _rejectIfWrongApp(role);
        if (rejection != null) {
          await FirebaseAuthService.signOut();
          return Result.failure(AuthFailure(rejection));
        }

        // Fetch full profile
        final userResult = await getCurrentUser();
        if (userResult.isSuccess) {
           return Result.success(userResult.data!);
        }
        
        // Fallback
         return Result.success(UserModel(
            id: credential.user!.uid,
            name: credential.user!.displayName ?? 'User',
            email: credential.user!.email ?? '',
            phone: credential.user!.phoneNumber ?? '',
            joinDate: DateTime.now(),
         ));
      }
      
      return Result.failure(AuthFailure(error ?? 'Google sign-in failed'));
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _apiService.dio.post('/auth/forgot-password', data: {'email': email});
    } catch (e) {
      throw _extractError(e, 'Failed to send OTP');
    }
  }

  @override
  Future<void> verifyPasswordResetOtp(String email, String otp) async {
    try {
      await _apiService.dio.post('/auth/verify-reset-otp', data: {'email': email, 'otp': otp});
    } catch (e) {
      throw _extractError(e, 'Invalid or expired OTP');
    }
  }

  @override
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    try {
      await _apiService.dio.post('/auth/reset-password', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw _extractError(e, 'Failed to reset password');
    }
  }

  String _extractError(dynamic e, String fallback) {
    try {
      final response = (e as dynamic).response;
      if (response != null) {
        final msg = response.data?['message'] ?? response.data?['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      // 1. Delete from Backend (Postgres)
      try {
        await _apiService.dio.delete('/auth/me');
        debugPrint("Backend account deleted");
      } catch (e) {
        debugPrint("Backend delete failed (proceeding to Firebase delete anyway): $e");
      }

      // 2. Delete from Firebase
      String? error;
      await FirebaseAuthService.deleteUser(
        onError: (e) => error = e,
      );
      if (error != null) {
        return Result.failure(AuthFailure(error!));
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(friendlyErrorMessage(e)));
    }
  }
}
