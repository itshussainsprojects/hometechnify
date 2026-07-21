import 'package:flutter/material.dart';
import '../domain/repositories/auth_repository.dart';
import '../data/models/user_model.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/session_cache.dart';
import '../../../main.dart' show navigatorKey;

enum AuthStatus { idle, loading, otpSent, success, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final SocketService _socketService = SocketService();

  AuthProvider(this._authRepository) {
    // Real-time admin block: the backend emits 'account_blocked' to this
    // user's socket room the moment admin blocks them. This used to just
    // show a SnackBar and force straight to the CUSTOMER '/login' route —
    // for a blocked PROVIDER that's the wrong login screen entirely, and
    // neither role saw the blurred "blocked" screen or the real helpline;
    // AccountBlockedScreen existed but was only ever reached via a stray
    // 403. Capture the role BEFORE logout() wipes it, so the blocked
    // screen's own Logout button can still send them to the right place.
    _socketService.onAccountBlocked = (data) {
      debugPrint('🚫 Blocked by admin');
      final blockedRole = _user?.role;
      logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/account-blocked',
        (r) => false,
        arguments: {'role': blockedRole},
      );
    };

    // Real-time provider verification: the backend emits this the instant an
    // admin approves (or revokes) a provider's documents. A pending provider
    // is confined to ProviderPendingScreen — it embeds the real dashboard
    // behind a blurred, non-interactive overlay — so the only way out was
    // logging out and back in for the status check to re-run. This refreshes
    // the cached status and swaps to the dashboard the moment approval lands,
    // with no logout required.
    _socketService.onNotification = (payload) {
      if (payload['type'] != 'verification') return;
      final verified = payload['data']?['verified']?.toString() == 'true';
      if (!verified) return;

      checkAuthStatus().then((_) {
        if (_user?.role == 'PROVIDER' && _user?.status != 'pending_verification') {
          navigatorKey.currentState?.pushReplacementNamed('/provider/dashboard');
        }
      });
    };
  }

  UserModel? _user;
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  UserModel? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == AuthStatus.loading;

  /// Refreshes the signed-in user's avatar after it has been uploaded, so every
  /// screen bound to AuthProvider (headers, drawers, chat) shows the new image
  /// without a re-login.
  void updateProfileImage(String url) {
    if (_user == null) return;
    _user = _user!.copyWith(profileImage: url);
    notifyListeners();
  }

  /// AuthProvider's cached user is only ever set at login/register — a save
  /// on the edit-profile screen goes through ProfileProvider instead, so
  /// without this every screen still bound to AuthProvider (the home banner
  /// greeting, chat, booking, job post) kept showing the name/phone/photo
  /// from before the edit until the next full login.
  void syncUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  /// Persist just enough to open the right dashboard instantly on the next cold
  /// start — the role, and whether a provider is still pending verification.
  void _cacheSession() {
    final u = _user;
    if (u == null || u.role.isEmpty) return;
    SessionCache.save(
      u.role,
      providerPending: u.role == 'PROVIDER' && u.status == 'pending_verification',
    );
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();
    
    final result = await _authRepository.getCurrentUser();
    
    if (result.isSuccess) {
      _user = result.data;
      debugPrint("📋 AuthProvider.checkAuthStatus - User Set:");
      debugPrint("   Name: ${_user?.name}");
      debugPrint("   Email: ${_user?.email}");
      debugPrint("   ProfileImage: ${_user?.profileImage}");
      debugPrint("   Role: ${_user?.role}");
      // STRICT CHECK: User must have a role
      if (_user?.role == null || _user!.role.isEmpty) {
         debugPrint("⚠️ User has no role. Logging out.");
         logout();
         return;
      }
      _status = AuthStatus.success;
      _cacheSession();
    } else {
      _user = null;
      _status = AuthStatus.idle;
    }
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    // Legacy Phone Login
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.login(phone, password);

    if (result.isSuccess) {
      _status = AuthStatus.otpSent;
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Unknown error';
    }
    notifyListeners();
  }

  /// [role] = the app being signed in from ('CUSTOMER' / 'PROVIDER'). Leave it
  /// null for the admin panel, which is open to any role.
  Future<void> loginWithEmail(String email, String password,
      {String? role}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result =
        await _authRepository.loginWithEmail(email, password, role: role);

    if (result.isSuccess) {
      _user = result.data;
      _status = AuthStatus.success;
      _cacheSession();
      
      // Connect Socket.IO
      if (_user != null) {
        _socketService.connect(_user!.id, userName: _user!.name);
        debugPrint('🔌 Socket connected for user: ${_user!.id} (${_user!.name})');
      }
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Login failed';
    }
    notifyListeners();
  }

  Future<void> verifyOtp(String phone, String otp) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.verifyOtp(phone, otp);

    if (result.isSuccess) {
      _user = result.data;
      _status = AuthStatus.success;
      _cacheSession();
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Invalid OTP';
    }
    notifyListeners();
  }

  Future<void> register(UserModel user, String password, {String role = 'CUSTOMER'}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.register(user, password, role: role);

    if (result.isSuccess) {
      // Email/password registration signs the user straight in — there is no
      // OTP step. The account is created and verified in one shot.
      _user = result.data;
      _status = AuthStatus.success;
      _cacheSession();
      if (_user != null) {
        _socketService.connect(_user!.id, userName: _user!.name);
      }
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Registration failed';
    }
    notifyListeners();
  }

  void logout() {
    _authRepository.logout();

    // Disconnect Socket.IO
    _socketService.disconnect();
    debugPrint('🔌 Socket disconnected on logout');

    // Drop the cached role so the next launch does NOT fast-path into a
    // dashboard for an account that just signed out.
    SessionCache.clear();

    _user = null;
    _status = AuthStatus.idle;
    notifyListeners();
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.changePassword(currentPassword, newPassword);

    if (result.isSuccess) {
      _status = AuthStatus.success;
      _cacheSession();
      notifyListeners();
      return true;
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Failed to change password';
      notifyListeners();
      return false;
    }
  }

  Future<void> signInWithGoogle({required String role}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.loginWithGoogle(role);

    if (result.isSuccess) {
      _user = result.data;
      
      // STRICT CHECK: Ensure returned user has the expected role or is blocked
      if (_user?.role != role && _user?.role != 'ADMIN') {
         // Mismatch! e.g. Customer trying to log in as Provider
         _status = AuthStatus.error;
         _errorMessage = "Account exists as ${_user?.role}. Please use the correct app.";
         _authRepository.logout(); // Auto-logout
      } else {
         _status = AuthStatus.success;
      _cacheSession();
         // Connect Socket.IO
         if (_user != null) {
           _socketService.connect(_user!.id, userName: _user!.name);
         }
      }
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Google Sign-In failed';
    }
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _authRepository.deleteAccount();

    if (result.isSuccess) {
      _user = null;
      _status = AuthStatus.success;
      _cacheSession();
      notifyListeners(); // Success usually means logout/redirect
      return true;
    } else {
      _status = AuthStatus.error;
      _errorMessage = result.error?.message ?? 'Failed to delete account';
      notifyListeners();
      return false;
    }
  }
}
