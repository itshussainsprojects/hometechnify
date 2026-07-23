import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  String? _currentUserName;

  // Callbacks
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onProviderLocation;
  Function(Map<String, dynamic>)? onBookingStatusChanged;
  Function(Map<String, dynamic>)? onNotification;
  Function(String, bool)? onUserTyping;
  Function(String, bool)? onUserStatus;
  // Admin blocked/unblocked THIS user — app should force-logout / resume instantly.
  Function(Map<String, dynamic>)? onAccountBlocked;
  Function(Map<String, dynamic>)? onAccountUnblocked;
  // Admin changed commission % / search radius — providers see it live.
  Function(Map<String, dynamic>)? onPlatformSettingsUpdated;
  // Commission deducted after a completed job — wallet balance changed.
  Function(Map<String, dynamic>)? onWalletUpdated;
  // Admin created/edited/deleted a promo — home screen refetches.
  void Function()? onPromosUpdated;
  // A customer changed their payment method — admin's Customer Payment
  // Select screen updates that row live.
  Function(Map<String, dynamic>)? onCustomerPaymentUpdated;
  // A customer just rated a provider — the provider's own app, the admin
  // Ratings/Providers screens, and anyone currently browsing that provider's
  // listing all update the number live instead of on next refetch.
  Function(Map<String, dynamic>)? onProviderRatingUpdated;
  // A provider toggled Available/Not Available — admin's Providers screen
  // updates that status live instead of on next manual refresh.
  Function(Map<String, dynamic>)? onProviderAvailabilityUpdated;
  // A provider updated their own profile (bank details, category, CNIC/
  // selfie docs, city, etc.) — admin's Providers screen picks it up live.
  Function(Map<String, dynamic>)? onProviderProfileUpdated;
  // A booking was created or changed status (any trade) — admin's Bookings
  // screen picks it up live instead of on next manual refresh.
  Function(Map<String, dynamic>)? onAdminBookingUpdated;

  bool get isConnected => _isConnected;

  /// Initialize and connect to Socket.IO server
  void connect(String userId, {String? baseUrl, String? userName}) {
    baseUrl ??= ApiService.staticBaseUrl.replaceAll('/api', '');
    if (_isConnected && _currentUserId == userId) {
      if (_currentUserName != userName && userName != null) {
          _currentUserName = userName;
          _socket!.emit('join', {'userId': userId, 'name': userName});
          debugPrint('🔄 Updated user name for socket: $userName');
      }
      debugPrint('✅ Socket already connected for user: $userId');
      return;
    }

    _currentUserId = userId;
    _currentUserName = userName;

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    // Connection events
    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('🔌 Socket.IO connected');
      
      // Join user room with name
      _socket!.emit('join', {'userId': userId, 'name': userName ?? 'User'});
      debugPrint('👤 Joined room for user: $userId ($userName)');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('❌ Socket.IO disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('🚨 Socket connection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('🚨 Socket error: $error');
    });

    // Listen to events
    _setupListeners();
  }

  void _setupListeners() {
    // New message
    _socket!.on('new_message', (data) {
      debugPrint('💬 New message received: $data');
      if (onNewMessage != null) {
        onNewMessage!(data as Map<String, dynamic>);
      }
    });

    // Message sent confirmation
    _socket!.on('message_sent', (data) {
      debugPrint('✅ Message sent: $data');
    });

    // Provider location update
    _socket!.on('provider_location', (data) {
      debugPrint('📍 Provider location: $data');
      if (onProviderLocation != null) {
        onProviderLocation!(data as Map<String, dynamic>);
      }
    });

    // Booking status changed
    _socket!.on('booking_status_changed', (data) {
      debugPrint('🔔 Booking status changed: $data');
      if (onBookingStatusChanged != null) {
        onBookingStatusChanged!(data as Map<String, dynamic>);
      }
    });

    // Notification
    _socket!.on('notification', (data) {
      debugPrint('🔔 Notification: $data');
      if (onNotification != null) {
        onNotification!(data as Map<String, dynamic>);
      }
    });

    // User typing
    _socket!.on('user_typing', (data) {
      final typingData = data as Map<String, dynamic>;
      final userId = typingData['userId'];
      final isTyping = typingData['isTyping'] ?? false;
      
      if (onUserTyping != null) {
        onUserTyping!(userId, isTyping);
      }
    });

    // Real-time admin block/unblock of THIS account
    _socket!.on('account_blocked', (data) {
      debugPrint('🚫 Account blocked by admin: $data');
      onAccountBlocked?.call(Map<String, dynamic>.from(data as Map));
    });
    _socket!.on('account_unblocked', (data) {
      debugPrint('✅ Account unblocked by admin: $data');
      onAccountUnblocked?.call(Map<String, dynamic>.from(data as Map));
    });

    // Live platform settings (commission % / provider search radius)
    _socket!.on('platform_settings_updated', (data) {
      debugPrint('⚙️ Platform settings updated: $data');
      onPlatformSettingsUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // Wallet changed (commission deduction on job completion)
    _socket!.on('wallet_updated', (data) {
      debugPrint('💰 Wallet updated: $data');
      onWalletUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // Admin promo change — was a global io.emit() nothing listened for.
    _socket!.on('promos_updated', (_) {
      debugPrint('🏷️ Promos updated');
      onPromosUpdated?.call();
    });

    // Customer's payment method choice changed.
    _socket!.on('customer_payment_updated', (data) {
      debugPrint('💳 Customer payment updated: $data');
      onCustomerPaymentUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // A provider's rating average just changed.
    _socket!.on('provider_rating_updated', (data) {
      debugPrint('⭐ Provider rating updated: $data');
      onProviderRatingUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // A provider toggled Available/Not Available.
    _socket!.on('provider_availability_updated', (data) {
      debugPrint('🟢 Provider availability updated: $data');
      onProviderAvailabilityUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // A provider updated their own profile (bank details, category, docs...).
    _socket!.on('provider_profile_updated', (data) {
      debugPrint('📝 Provider profile updated: $data');
      onProviderProfileUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // A booking was created or its status changed.
    _socket!.on('admin_booking_updated', (data) {
      debugPrint('📅 Booking updated: $data');
      onAdminBookingUpdated?.call(Map<String, dynamic>.from(data as Map));
    });

    // User status (online/offline)
    _socket!.on('user_status', (data) {
      final statusData = data as Map<String, dynamic>;
      final userId = statusData['userId'];
      final online = statusData['online'] ?? false;
      
      if (onUserStatus != null) {
        onUserStatus!(userId, online);
      }
    });
  }

  /// Send a chat message
  void sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    String type = 'text',
    String? mediaUrl,
  }) {
    if (!_isConnected) {
      debugPrint('❌ Socket not connected, cannot send message');
      return;
    }

    _socket!.emit('send_message', {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': _currentUserName ?? 'User',
      'receiverId': receiverId,
      'message': message,
      'type': type,
      'mediaUrl': mediaUrl,
    });

    debugPrint('📤 Sending message: $message');
  }

  /// Send typing indicator
  void sendTypingIndicator(String receiverId, bool isTyping) {
    if (!_isConnected) return;

    _socket!.emit('typing', {
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }

  /// Update provider location (for real-time tracking)
  void updateProviderLocation({
    required String bookingId,
    required String providerId,
    required double lat,
    required double lng,
  }) {
    if (!_isConnected) return;

    _socket!.emit('update_location', {
      'bookingId': bookingId,
      'providerId': providerId,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Join booking room (for tracking)
  void joinBookingRoom(String bookingId) {
    if (!_isConnected) return;

    _socket!.emit('join_booking', bookingId);
    debugPrint('📍 Joined booking room: $bookingId');
  }

  /// Leave a booking room when the tracking screen closes. Without this the
  /// client keeps receiving location fixes for bookings it is no longer showing.
  void leaveBookingRoom(String bookingId) {
    if (!_isConnected) return;

    _socket!.emit('leave_booking', bookingId);
    debugPrint('📍 Left booking room: $bookingId');
  }

  /// Send booking update
  void sendBookingUpdate({
    required String bookingId,
    required String status,
    required String userId,
    required String message,
  }) {
    if (!_isConnected) return;

    _socket!.emit('booking_update', {
      'bookingId': bookingId,
      'status': status,
      'userId': userId,
      'message': message,
    });
  }

  /// Update provider online/offline status
  void updateProviderStatus(String providerId, bool isOnline) {
    if (!_isConnected) return;

    _socket!.emit('provider_status', {
      'providerId': providerId,
      'isOnline': isOnline,
    });
  }

  /// Disconnect socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _currentUserId = null;
      debugPrint('🔌 Socket disconnected');
    }
  }

  /// Reconnect socket
  void reconnect() {
    if (_currentUserId != null) {
      disconnect();
      connect(_currentUserId!);
    }
  }
}
