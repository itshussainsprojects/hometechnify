// Firebase Authentication Service - Centralized auth management
// Supports: Phone OTP, Email/Password, Google Sign-In

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Centralized service for Firebase authentication
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // serverClientId = Web OAuth client ID from google-services.json (client_type: 3)
  // Required on Android to receive idToken for Firebase authentication
  // Web OAuth client of the `hometechnify` Firebase project. It mints the
  // idToken that Firebase Auth verifies, so it must always match the
  // oauth_client (type 3) in android/app/google-services.json — a mismatch
  // silently breaks Google Sign-In with ApiException: 10.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '444217288447-371k5l1mpu8q1fmtqnjn33nsnubv0ae6.apps.googleusercontent.com',
  );

  // ============== AUTH STATE ==============

  /// Check if user is currently authenticated
  static bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============== PHONE AUTH ==============

  /// Verification ID for phone auth (used during OTP verification)
  static String? _verificationId;
  static int? _resendToken;

  /// Send OTP to phone number
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String message = 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Try again later.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Try again later.';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Verify OTP code
  static Future<UserCredential?> verifyOtp({
    required String otp,
    required Function(String error) onError,
  }) async {
    if (_verificationId == null) {
      onError('Verification ID not found. Please request OTP again.');
      return null;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      String message = 'Verification failed';
      if (e.code == 'invalid-verification-code') {
        message = 'Invalid OTP code. Please try again.';
      } else if (e.code == 'session-expired') {
        message = 'OTP expired. Please request a new code.';
      }
      onError(message);
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  /// Sign in with phone credential (for auto-verification)
  static Future<UserCredential?> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[FirebaseAuth] SignIn with credential error: $e');
      return null;
    }
  }

  // ============== EMAIL/PASSWORD AUTH ==============

  /// Sign up with email and password
  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required Function(String error) onError,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered. Please login.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      }
      onError(message);
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  /// Sign in with email and password
  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
    required Function(String error) onError,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      }
      onError(message);
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }


  // ============== GOOGLE SIGN-IN ==============

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle({
    required Function(String error) onError,
  }) async {
    try {
      // Always show account picker so the user can switch accounts
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User dismissed the account picker — not an error
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // idToken is null when serverClientId is not set or SHA-1 is not registered
      if (googleAuth.idToken == null) {
        onError(
          'Google sign-in failed: ID token is null.\n'
          'Please add the app SHA-1 fingerprint to Firebase Console:\n'
          'Debug: 9B:44:B8:B8:89:8B:8A:B6:6A:FA:18:B3:09:93:FA:03:E9:8F:CD:18\n'
          'Release: B1:3D:97:E6:E1:B1:5A:EF:C6:E4:D5:45:80:5E:0F:09:5C:06:00:32',
        );
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
        onError(
          'Google sign-in blocked (Error 10).\n'
          'Go to Firebase Console → Project hometechnify → Authentication → '
          'Sign-in method → Google → Add Android app SHA-1:\n'
          'Debug: 9B:44:B8:B8:89:8B:8A:B6:6A:FA:18:B3:09:93:FA:03:E9:8F:CD:18\n'
          'Release: B1:3D:97:E6:E1:B1:5A:EF:C6:E4:D5:45:80:5E:0F:09:5C:06:00:32',
        );
      } else if (msg.contains('network_error') || msg.contains('NETWORK_ERROR')) {
        onError('No internet connection. Please try again.');
      } else if (msg.contains('sign_in_canceled') || msg.contains('sign_in_cancelled')) {
        // User cancelled — silent, no error snackbar
      } else {
        onError('Google sign-in failed: $msg');
      }
      return null;
    }
  }

  // ============== USER DATA ==============

  /// Get user's phone number
  static String? getUserPhone() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Get user's email
  static String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get user's display name
  static String getUserName() {
    return _auth.currentUser?.displayName ?? 'User';
  }

  /// Get user's profile image URL
  static String? getProfileImageUrl() {
    return _auth.currentUser?.photoURL;
  }

  /// Get user's unique ID
  static String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Update user's display name and photo URL
  static Future<void> updateDisplayName(String name, {String? photoURL}) async {
    await _auth.currentUser?.updateProfile(displayName: name, photoURL: photoURL);
  }

  // ============== SIGN OUT ==============

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('[FirebaseAuth] Sign out error: $e');
    }
  }

  // ============== ACCOUNT MANAGEMENT ==============

  /// Change user password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required Function(String error) onError,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        onError('User not logged in');
        return;
      }

      // Re-authenticate user before changing password
      final email = user.email;
      if (email != null) {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
      } else {
        onError('Only email users can change password');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password';
      if (e.code == 'wrong-password') {
        message = 'Incorrect current password';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }
      onError(message);
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Delete user account
  static Future<void> deleteUser({
    required Function(String error) onError,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to delete account';
      if (e.code == 'requires-recent-login') {
        message = 'Please log in again to delete your account';
      }
      onError(message);
    } catch (e) {
      onError(e.toString());
    }
  }
}
