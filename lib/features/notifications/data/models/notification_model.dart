
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'job', 'booking', 'message', 'payment', 'service', 'promo'
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data; // Extra data like bookingId, chatId, etc.

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
    );
  }

  // Backend REST shape (prisma Notification model): title, body, type,
  // is_read, created_at — different field names than the old Firestore map.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['body'] ?? '',
      type: (json['type'] ?? 'SYSTEM').toString().toLowerCase(),
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp,
      'isRead': isRead,
      'data': data,
    };
  }
}
