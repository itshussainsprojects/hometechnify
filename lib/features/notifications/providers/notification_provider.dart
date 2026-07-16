import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/remote_notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final RemoteNotificationRepository _repository;
  StreamSubscription<List<NotificationModel>>? _subscription;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  NotificationProvider(this._repository);

  void init(String userId) {
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.getNotificationsStream(userId).listen((data) {
      _notifications = data;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
       debugPrint("Error streaming notifications: $error");
       _isLoading = false;
       notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      // Create a temporary read object for instant UI feedback (if stream is slow)
      // Actually stream should be fast enough, but let's call repo.
    }
    await _repository.markAsRead(userId, notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _repository.markAllAsRead(userId);
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _repository.deleteNotification(userId, notificationId);
  }
  
  // Dev helper
  Future<void> sendTestNotification(String userId) async {
    debugPrint("=== Sending Test Notification ===");
    debugPrint("Target UserId (Firebase UID): $userId");
    try {
      await _repository.sendTestNotification(
        userId, 
        "Test Notification", 
        "This is a test notification sent at ${DateTime.now()}", 
        "info"
      );
      debugPrint("=== Test Notification Sent Successfully ===");
    } catch (e) {
      debugPrint("=== FAILED to Send Test Notification ===");
      debugPrint("Error: $e");
    }
  }
}
