
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kReleaseMode
import '../../main.dart' show navigatorKey;

class ApiService {
  late final Dio _dio;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The backend the app talks to.
  ///
  /// Set it at build time and nothing else needs to change:
  ///
  ///   flutter build apk --release --dart-define=API_URL=https://api.yourdomain.com/api
  ///   flutter run --dart-define=API_URL=http://192.168.1.5:3000/api
  ///
  /// A compile-time define (not dotenv) because it must be baked into the
  /// release binary — there is no .env on a user's phone.
  ///
  /// The release build previously pointed at a placeholder Heroku domain that
  /// was never registered, so a shipped app would have talked to nothing at all;
  /// debug pointed at one developer's home-network IP. Release now REFUSES to
  /// build against a local address rather than shipping a dead app.
  static const String _apiUrl = String.fromEnvironment('API_URL');

  /// Debug fallback so `flutter run` still works with no flags.
  ///
  /// The host that means "this machine" is DIFFERENT per platform, and getting
  /// it wrong doesn't fail fast — it hangs on connect. This used to be hardcoded
  /// to 10.0.2.2, which is the Android emulator's alias for the host and reaches
  /// NOTHING anywhere else. So running the admin panel on Chrome or Windows
  /// desktop (the normal way to use an admin panel) pointed at an address the
  /// browser could never reach, and the app just spun.
  ///   • Web / desktop / iOS simulator  -> localhost
  ///   • Android emulator               -> 10.0.2.2 (its alias for the host)
  ///   • Physical Android phone         -> needs --dart-define=API_URL with the PC LAN IP
  static String get _debugFallback {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    // Windows / macOS / Linux desktop, iOS simulator
    return 'http://localhost:3000/api';
  }

  static String get staticBaseUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;

    assert(
      !kReleaseMode,
      'API_URL is not set. A release build must be given the real backend:\n'
      '  flutter build apk --release --dart-define=API_URL=https://api.yourdomain.com/api',
    );
    return _debugFallback;
  }

  /// True when the app is pointed at a machine on the local network. A release
  /// build in this state is broken for every user who is not on that network.
  static bool get isLocalBackend =>
      staticBaseUrl.contains('localhost') ||
      staticBaseUrl.contains('127.0.0.1') ||
      staticBaseUrl.contains('10.0.2.2') ||
      staticBaseUrl.contains('192.168.') ||
      staticBaseUrl.contains('10.0.0.');

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: staticBaseUrl,
      // Fail fast. These were 120s, so an unreachable backend meant the login
      // button spun for two full minutes before anything told the user. 15s to
      // connect / 30s to receive surfaces a real problem quickly while still
      // tolerating the slow remote database and large media uploads.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60), // uploads can be large
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Firebase ID Token to headers. This runs before EVERY request,
        // including public ones like /categories — if getIdToken() ever
        // hangs (Firebase Auth reachability hiccup, clock skew, stale
        // token-refresh state), the request never even leaves the device,
        // which looks identical to a dead backend from the UI's point of
        // view but leaves zero trace in the backend logs. A hard timeout
        // means a slow token fetch can only cost a few seconds, not the
        // whole 15s connectTimeout with nothing to show for it.
        final user = _auth.currentUser;
        if (user != null) {
          try {
            final token = await user.getIdToken().timeout(const Duration(seconds: 5));
            options.headers['Authorization'] = 'Bearer $token';
          } catch (e) {
            debugPrint('getIdToken() timed out or failed, sending request without a fresh token: $e');
          }
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        final code = (data is Map) ? data['code'] : null;

        // An account the admin blocked or moved to the recycle bin gets a 403
        // from every endpoint. Nothing acted on it, so the app just sat there
        // failing every request with no explanation.
        if (status == 403 && (code == 'ACCOUNT_BLOCKED' || code == 'ACCOUNT_DELETED')) {
          debugPrint('Account is $code — signing out');
          await _forceSignOut(route: '/account-blocked');
          return handler.next(e);
        }

        // 401 = the Firebase token is no longer valid (expired, revoked, or the
        // account is gone). Every subsequent request would 401 too. This used to
        // only debugPrint, leaving the user stranded in an app where nothing
        // worked and no screen ever said why.
        if (status == 401) {
          debugPrint('API Error 401: $data — session is dead, signing out');
          await _forceSignOut(route: '/login');
          return handler.next(e);
        }

        // On devices with more than one active network (dual-SIM + WiFi),
        // Android sometimes reassigns the app's default network mid-request
        // right after cold start, which aborts the in-flight connection
        // ("Software caused connection abort") rather than just timing out.
        // That settles down within a couple of seconds, so a couple of
        // retries with a short gap ride out the transition instead of
        // surfacing a "dead backend" to the user for what is a local
        // network hiccup.
        final isTransient = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.receiveTimeout;
        final attempt = (e.requestOptions.extra['retryAttempt'] as int?) ?? 0;
        const maxRetries = 2;
        if (isTransient && attempt < maxRetries) {
          try {
            e.requestOptions.extra['retryAttempt'] = attempt + 1;
            await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
            final response = await _dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (_) {
            // This attempt failed too — onError runs again for it, which
            // re-checks the (now incremented) attempt count.
          }
        }

        return handler.next(e);
      },
    ));
  }

  /// Ends the session and sends the user somewhere that makes sense. Guarded so
  /// a burst of failing requests cannot fire this a dozen times over.
  static bool _signingOut = false;
  Future<void> _forceSignOut({required String route}) async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {/* already signed out */}

    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(route, (r) => false);
    }
    _signingOut = false;
  }

  Dio get dio => _dio;
  String get baseUrl => ApiService.staticBaseUrl;

  // Sync User with Backend
  /// [name] and [phone] are explicit overrides for email/password registration:
  /// Firebase only fills displayName/phoneNumber for phone or Google auth, so on
  /// an email signup the phone the user typed would otherwise be dropped and
  /// never reach the database.
  Future<void> syncUser({String? fcmToken, String? role, String? name, String? phone}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final data = {
        'name': name ?? user.displayName,
        'email': user.email,
        'phone': phone ?? user.phoneNumber,
        'picture': user.photoURL,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (role != null) 'role': role,
      };

      await _dio.post('/auth/sync', data: data);
      debugPrint('User Synced with Backend (Role: $role)');
    } catch (e) {
      debugPrint('Sync Failed: $e');
      rethrow;
    }
  }
}
