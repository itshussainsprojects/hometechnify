import 'package:shared_preferences/shared_preferences.dart';

/// The last signed-in user's role, cached on disk.
///
/// Firebase already keeps the auth session locally, so on a cold start we know
/// *that* someone is logged in without any network. What we don't know without a
/// round-trip is *which dashboard* to open. Caching the role lets the splash
/// jump straight to the right screen — no waiting on `/auth/me` across a remote
/// database — while the real check runs in the background. If that check later
/// says the account is blocked or gone, the 403 interceptor signs them out.
class SessionCache {
  static const _roleKey = 'cached_role';
  static const _pendingKey = 'cached_provider_pending';

  static Future<void> save(String role, {bool providerPending = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
    await prefs.setBool(_pendingKey, providerPending);
  }

  /// 'CUSTOMER' | 'PROVIDER' | 'ADMIN', or null if nothing cached.
  static Future<String?> role() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  /// True when the cached provider still awaits verification.
  static Future<bool> providerPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey) ?? false;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_pendingKey);
  }
}
