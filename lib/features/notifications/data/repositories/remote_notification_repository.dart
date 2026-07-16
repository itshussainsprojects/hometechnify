import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/api_service.dart';
import '../models/notification_model.dart';

// Real notifications live in Postgres (prisma.notification), written by
// notificationService.sendPushNotification(). There is no Firestore
// mirror or security rule for users/{uid}/notifications — that path was
// dead code that only ever produced permission-denied errors. This talks
// to the same REST API the rest of the app uses.
class RemoteNotificationRepository {
  final ApiService _api = ApiService();

  // No server-sent-events/websocket channel for notifications yet, so we
  // poll on an interval and expose it as a stream to keep the provider's
  // subscription-based API unchanged.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    late StreamController<List<NotificationModel>> controller;
    Timer? timer;

    Future<void> fetchAndEmit() async {
      try {
        final list = await fetchNotifications();
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<NotificationModel>>(
      onListen: () {
        fetchAndEmit();
        timer = Timer.periodic(const Duration(seconds: 20), (_) => fetchAndEmit());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Future<List<NotificationModel>> fetchNotifications() async {
    final response = await _api.dio.get('/notifications');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _api.dio.put('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead(String userId) async {
    await _api.dio.put('/notifications/all/read');
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _api.dio.delete('/notifications/$notificationId');
  }

  // Dev helper: triggers a real FCM push + DB row via the backend.
  Future<void> sendTestNotification(String userId, String title, String message, String type) async {
    try {
      await _api.dio.post('/notifications/send-test', data: {
        'title': title,
        'message': message,
      });
      debugPrint('System Push Triggered via Backend');
    } catch (e) {
      debugPrint('Failed to trigger system push: $e');
      rethrow;
    }
  }
}
