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

  // An active account can be signed out by TWO independent, unsynchronized
  // triggers at once: the socket 'account_blocked' event, and the 403 that
  // the account's own in-flight API calls (a dashboard poll, etc.) get back
  // moments later. Both used to race to call logout() -> SessionCache.clear()
  // and then separately push '/account-blocked' with a role — whichever push
  // executed second always read role AFTER the other had already wiped the
  // cache, landing null and silently defaulting the blocked screen's Logout
  // button to the CUSTOMER login regardless of the account's real role. This
  // in-memory (not persisted) guard lets whichever trigger fires first claim
  // the one navigation; the other becomes a no-op. Reset on every successful
  // login so a later block in the same app session is handled again.
  static bool _blockNavigationClaimed = false;

  static bool claimAccountBlockedNavigation() {
    if (_blockNavigationClaimed) return false;
    _blockNavigationClaimed = true;
    return true;
  }

  static void resetAccountBlockedNavigation() {
    _blockNavigationClaimed = false;
  }
}
