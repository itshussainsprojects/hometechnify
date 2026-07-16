import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../main.dart'; // For navigatorKey
import 'api_service.dart';

// Must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // FCM rotates tokens (reinstall, restore, periodic refresh). Without this
    // the backend keeps pushing to a dead token and notifications silently stop
    // until the user logs out and back in.
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refreshed, re-syncing: $token');
      try {
        await ApiService().syncUser(fcmToken: token);
      } catch (e) {
        debugPrint('FCM token re-sync failed: $e');
      }
    });

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint("Notification Tapped: ${details.payload}");
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            if (data['route'] != null) {
              dynamic arguments = data['arguments'];
              if (arguments is String) {
                try {
                  arguments = jsonDecode(arguments);
                } catch (e) {
                  debugPrint("Error decoding arguments JSON: $e");
                }
              }
              navigatorKey.currentState?.pushNamed(
                data['route'],
                arguments: arguments,
              );
            }
          } catch (e) {
            debugPrint("Error parsing notification payload: $e");
          }
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool('app_notifications') ?? true;

      if (!enabled) {
        debugPrint("Notification suppressed by user preference");
        return;
      }

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _showLocalNotification(notification, message.data);
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint("Notification Interaction: ${message.data}");
    final route = message.data['route'];
    dynamic args = message.data['arguments'];

    if (args is String) {
      try {
        if (args.startsWith('{') || args.startsWith('[')) {
          args = jsonDecode(args);
        }
      } catch (e) {
        debugPrint("Error parsing notification arguments: $e");
      }
    }

    if (route != null) {
      navigatorKey.currentState?.pushNamed(route, arguments: args);
    }
  }

  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> _showLocalNotification(
    RemoteNotification notification,
    Map<String, dynamic> data,
  ) async {
    await showNotification(
      notification.title ?? 'New Notification',
      notification.body ?? '',
      payload: jsonEncode(data),
    );
  }

  Future<String?> getFCMToken() async {
    try {
      final String? token = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
      return null;
    }
  }
}
