import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/socket_service.dart';
import '../domain/repositories/provider_repository.dart';
import '../data/models/provider_model.dart';

enum ProviderStatus { idle, loading, success, error }

class ProviderController extends ChangeNotifier {
  final ProviderRepository _repository;
  final SocketService _socket = SocketService();

  ProviderController(this._repository) {
    _wireRealtime();
  }

  /// The backend pushes these; nothing was listening, so the wallet only ever
  /// changed on a manual refresh and an admin's commission change never reached
  /// a running app.
  void _wireRealtime() {
    // Commission deducted on job completion, or a top-up credited.
    final prevWallet = _socket.onWalletUpdated;
    _socket.onWalletUpdated = (data) {
      prevWallet?.call(data);
      final balance = data['balance'];
      if (balance is num) {
        // dashboardStats is the single source of truth the walletBalance getter
        // reads, so updating it here refreshes every screen at once.
        _dashboardStats['walletBalance'] = balance.toDouble();
        notifyListeners();
      }
      fetchWalletHistory();
    };

    // Admin changed the commission % or the search radius.
    final prevSettings = _socket.onPlatformSettingsUpdated;
    _socket.onPlatformSettingsUpdated = (data) {
      prevSettings?.call(data);
      final pct = data['commission_percent'];
      if (pct is num) {
        _dashboardStats['commissionPercent'] = pct.toDouble();
        notifyListeners();
      }
      fetchDashboardStats();
    };
  }

  List<ProviderModel> _providers = [];
  List<ProviderModel> get providers => _providers;

  ProviderModel? _selectedProvider;
  ProviderModel? get selectedProvider => _selectedProvider;

  ProviderStatus _status = ProviderStatus.idle;
  ProviderStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == ProviderStatus.loading;

  // Provider availability (Available / Not Available). Controls whether the
  // provider is shown to customers and surfaced for new jobs.
  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;
  bool _togglingAvailability = false;
  bool get togglingAvailability => _togglingAvailability;
  // Bumped on every toggle; lets in-flight stats responses detect they are
  // stale so they never overwrite a newer toggle.
  int _availabilityStamp = 0;

  /// Toggle availability - REAL TIME. The API call fires immediately (no
  /// waiting on GPS), the switch flips optimistically and rolls back only if
  /// the server rejects it. The provider's position is captured in the
  /// background and pushed separately so "nearest first" stays accurate.
  Future<bool> setAvailability(bool value) async {
    if (_togglingAvailability) return _isAvailable;
    final previous = _isAvailable;
    _isAvailable = value;
    _togglingAvailability = true;
    notifyListeners();

    final result = await _repository.setAvailability(value);
    _togglingAvailability = false;
    _availabilityStamp++;
    if (result.isSuccess) {
      _isAvailable = result.data ?? value;
      // Keep the cached stats in sync so later reads agree with the toggle.
      _dashboardStats['isAvailable'] = _isAvailable;
      if (_isAvailable) {
        // Fire-and-forget: send the current GPS position after going
        // Available. Never blocks or affects the toggle itself.
        _pushLocationInBackground();
        _startLocationRefresh();
      } else {
        _stopLocationRefresh();
      }
    } else {
      _isAvailable = previous; // roll back
      _errorMessage = result.error?.message;
    }
    notifyListeners();
    return _isAvailable;
  }

  /// True when the provider is Available but their location could not be
  /// captured (permission off, or GPS timed out).
  ///
  /// This is not cosmetic: matching is by distance, so a provider with no known
  /// location is dropped from both the customer's nearby list AND job
  /// notifications. Without surfacing this, they would sit "Available" wondering
  /// why no work ever arrives. The dashboard shows a warning off this flag.
  bool _locationBlocked = false;
  bool get locationBlocked => _locationBlocked;

  // Location used to be captured once, at the exact moment the toggle went
  // Available, and never again — a provider who stayed Available while
  // actually moving around (a van, a different job site) kept matching
  // against wherever they were when they first flipped the switch, possibly
  // hours or a full day earlier. This re-captures on an interval for as long
  // as they stay Available, so "nearest first" reflects where they actually
  // are, not just where they were at toggle time.
  Timer? _locationRefreshTimer;

  void _startLocationRefresh() {
    // Idempotent — this is also called every time dashboard stats hydrate
    // isAvailable as true (not just from the toggle itself), and restarting
    // an already-running timer on every stats poll would mean it never
    // survives long enough to actually fire.
    if (_locationRefreshTimer != null) return;
    _locationRefreshTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _pushLocationInBackground(),
    );
  }

  void _stopLocationRefresh() {
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = null;
  }

  Future<void> _pushLocationInBackground() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        _locationBlocked = true;
        notifyListeners();
        return;
      }
      // 'high' instead of the previous 'medium' — matching is by distance
      // against a configurable radius as small as a few km, so a loose GPS
      // fix can misplace a provider across that boundary and drop them from
      // (or wrongly include them in) a customer's nearby list.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));
      await _repository.updateMyLocation(pos.latitude, pos.longitude);
      _locationBlocked = false;
      notifyListeners();
    } catch (_) {
      // GPS timed out or failed — the provider still won't be matched.
      _locationBlocked = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopLocationRefresh();
    super.dispose();
  }

  /// Hydrate availability from a loaded value (e.g. dashboard stats / profile).
  /// A provider who was already Available before the app was closed needs the
  /// refresh cycle restarted here too — otherwise it only ever started from
  /// the toggle itself, and a cold-started app would sit Available with a
  /// location that only ever updates again if they flip the switch off/on.
  void setAvailabilityLocal(bool value) {
    _isAvailable = value;
    if (value) {
      _pushLocationInBackground();
      _startLocationRefresh();
    } else {
      _stopLocationRefresh();
    }
    notifyListeners();
  }

  Future<void> fetchProviders({String? categoryId, String? search}) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.getProviders(categoryId: categoryId, search: search);

    if (result.isSuccess) {
      _providers = result.data!;
      _status = ProviderStatus.success;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<void> fetchProviderDetails(String id) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.getProviderById(id);

    if (result.isSuccess) {
      _selectedProvider = result.data;
      _status = ProviderStatus.success;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.updateProfile(data);

    if (result.isSuccess) {
      _status = ProviderStatus.success;
      notifyListeners();
      return true;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _dashboardStats = {};
  Map<String, dynamic> get dashboardStats => _dashboardStats;

  List<dynamic> _walletHistory = [];
  List<dynamic> get walletHistory => _walletHistory;

  List<dynamic> _activeBookings = [];
  List<dynamic> get activeBookings => _activeBookings;

  /// THE source of truth for the commission wallet. It lives in dashboardStats,
  /// which is refreshed after every top-up — reading it off `selectedProvider`
  /// instead (fetched once when the dashboard opens) is what made a top-up look
  /// like it never landed on the quote screen.
  double get walletBalance {
    final v = _dashboardStats['walletBalance'];
    if (v is num) return v.toDouble();
    return _selectedProvider?.walletBalance ?? 0.0;
  }

  /// Admin-set commission, live. Never hardcode this — the admin can change it
  /// at any time and every screen must charge the same rate the backend does.
  double get commissionPercent {
    final v = _dashboardStats['commissionPercent'];
    return v is num ? v.toDouble() : 12.0;
  }

  double get commissionRate => commissionPercent / 100;

  double get pendingCommission => _activeBookings.fold(0.0, (sum, b) {
    final raw = b['total_amount'];
    final amt = raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
    return sum + (amt * commissionRate);
  });

  Future<void> fetchActiveBookings() async {
    final result = await _repository.getActiveBookings();
    if (result.isSuccess) {
      _activeBookings = result.data!;
      notifyListeners();
    }
  }

  /// DEV MOCK top-up: credits the wallet instantly (no gateway yet) so the
  /// job flow can be tested. Returns the new balance, or null on failure.
  Future<double?> topUpWallet(double amount, String paymentMethod) async {
    final result = await _repository.topUpWallet(amount, paymentMethod);
    if (result.isSuccess) {
      // Refresh BOTH copies of the balance, not just the stats map — the
      // provider card carries one too, and a stale copy anywhere means some
      // screen still shows the pre-top-up amount.
      await fetchDashboardStats();
      if (_selectedProvider != null) {
        await fetchProviderDetails(_selectedProvider!.id);
      }
      fetchWalletHistory();
      return result.data;
    }
    _errorMessage = result.error?.message;
    notifyListeners();
    return null;
  }

  Future<void> fetchDashboardStats() async {
    // Only show full loading if we have no data
    if (_dashboardStats.isEmpty) {
       _status = ProviderStatus.loading;
       notifyListeners();
    }

    final stampBefore = _availabilityStamp;
    final result = await _repository.getDashboardStats();

    if (result.isSuccess) {
      _dashboardStats = result.data!;
      // Hydrate availability from the server so the toggle shows the real
      // state - but NEVER while a toggle is in flight, and never from a
      // stats response that started before the last toggle finished
      // (a stale response would silently flip the switch back).
      if (!_togglingAvailability &&
          stampBefore == _availabilityStamp &&
          _dashboardStats.containsKey('isAvailable')) {
        _isAvailable = _dashboardStats['isAvailable'] == true;
        // A provider who was already Available before the app was closed
        // needs the location-refresh cycle restarted here — otherwise it
        // only ever started from the toggle itself, and this is the actual
        // code path that runs the moment the dashboard loads.
        if (_isAvailable) {
          _startLocationRefresh();
        } else {
          _stopLocationRefresh();
        }
      } else {
        // Preserve the toggle's truth in the cached stats.
        _dashboardStats['isAvailable'] = _isAvailable;
      }
      _status = ProviderStatus.success; // Ensure we go back to loaded
      notifyListeners();
    } else {
      debugPrint("Failed to fetch dashboard stats: ${result.error?.message}");
      _status = ProviderStatus.error; // Or stay loaded if valid old data?
      // Better to stay loaded if we have data, but let's notify error
      _errorMessage = result.error?.message;
      notifyListeners();
    }
  }

  Future<void> fetchWalletHistory() async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.getWalletHistory();

    if (result.isSuccess) {
      _walletHistory = result.data!;
      _status = ProviderStatus.success;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();

    // The real ledger, fetched alongside so the wallet screen can show the
    // amounts that were actually charged instead of re-deriving them.
    fetchTransactions();
  }

  List<dynamic> _transactions = [];

  /// TOPUP / COMMISSION / WITHDRAWAL rows, newest first.
  List<dynamic> get transactions => _transactions;

  Future<void> fetchTransactions() async {
    final result = await _repository.getMyTransactions();
    if (result.isSuccess) {
      _transactions = result.data!;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.deleteAccount();

    if (result.isSuccess) {
      _status = ProviderStatus.success;
      notifyListeners();
      return true;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAndSetProfileImage(File image) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    // 1. Upload Image
    final uploadResult = await _repository.uploadProfileImage(image);
    
    if (!uploadResult.isSuccess) {
      _status = ProviderStatus.error;
      _errorMessage = uploadResult.error?.message;
      notifyListeners();
      return false;
    }

    // 2. Update Profile with new Image URL
    final imageUrl = uploadResult.data!;
    final updateResult = await _repository.updateProfile({'profileImage': imageUrl});

    if (updateResult.isSuccess) {
      // Improve: locally update the selected provider or fetch details again
      if (_selectedProvider != null) {
        // We need a copyWith on ProviderModel for cleaner updates, but for now fetch details again
        await fetchProviderDetails(_selectedProvider!.id);
      }
      _status = ProviderStatus.success;
      notifyListeners();
      return true;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = updateResult.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadFile(File file) async {
    // Helper to upload generic file (for banner image/voice)
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.uploadProfileImage(file); // Reuse repo method

    if (result.isSuccess) {
      _status = ProviderStatus.success; // Or keep loading if part of a larger flow?
      notifyListeners();
      return result.data;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> submitBannerRequest(Map<String, dynamic> data) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.submitBannerRequest(data);

    if (result.isSuccess) {
      _status = ProviderStatus.success;
      notifyListeners();
      return true;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleNotifications(bool enabled) async {
    // Optimistic update? Or loading?
    // Let's keep it simple
    final result = await _repository.toggleNotifications(enabled);
    
    if (result.isSuccess) {
      return true;
    } else {
      _errorMessage = result.error?.message;
      notifyListeners();
      return false;
    }
  }
  List<dynamic> _notifications = [];
  List<dynamic> get notifications => _notifications;

  Future<void> fetchNotifications({int page = 1}) async {
    if (page == 1 && _notifications.isEmpty) {
       _status = ProviderStatus.loading;
       notifyListeners();
    } else {
       // Just notify listeners with old data? No, we don't want to trigger loading
       // But if we want to show a spinner *somewhere*?
       // For now, let's just NOT change status to loading if we have data
    }

    final result = await _repository.getNotifications(page: page);

    if (result.isSuccess) {
      if (page == 1) {
        _notifications = result.data!['data'];
      } else {
        _notifications.addAll(result.data!['data']);
      }
      _status = ProviderStatus.success;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<void> markNotificationAsRead(String id) async {
    
    // Optimistic update
    if (id == 'all') {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
    } else {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
      }
    }
    notifyListeners();

    await _repository.markNotificationAsRead(id);
    // Silent fail/success
  }

  Future<void> deleteNotification(String id) async {
    // Optimistic removal
    final removed = _notifications.where((n) => n['id'] == id).toList();
    _notifications.removeWhere((n) => n['id'] == id);
    notifyListeners();

    final result = await _repository.deleteNotification(id);
    if (result.isFailure) {
      // Roll back on failure
      _notifications.addAll(removed);
      notifyListeners();
    }
  }

  Map<String, dynamic> _reviewsData = {};
  Map<String, dynamic> get reviewsData => _reviewsData;

  Future<void> fetchReviews() async {
    if (_reviewsData.isEmpty) {
      _status = ProviderStatus.loading;
      notifyListeners();
    }

    final result = await _repository.getMyReviews();

    if (result.isSuccess) {
      _reviewsData = result.data!;
      _status = ProviderStatus.success;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestWithdrawal(Map<String, dynamic> data) async {
    _status = ProviderStatus.loading;
    notifyListeners();

    final result = await _repository.requestWithdrawal(data);

    if (result.isSuccess) {
      _status = ProviderStatus.success;
      notifyListeners();
      // Refresh wallet data
      fetchWalletHistory();
      fetchDashboardStats();
      return result.data!;
    } else {
      _status = ProviderStatus.error;
      _errorMessage = result.error?.message;
      notifyListeners();
      return {'success': false, 'message': _errorMessage ?? 'Failed'};
    }
  }
}
