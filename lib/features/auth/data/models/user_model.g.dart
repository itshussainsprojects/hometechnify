// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String? ?? '',
  profileImage: json['profileImage'] as String?,
  status: json['status'] as String? ?? 'active',
  addresses:
      (json['addresses'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  paymentMethods:
      (json['paymentMethods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  favoriteProviders:
      (json['favoriteProviders'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
  totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
  rating: (json['rating'] as num?)?.toDouble() ?? 0,
  joinDate: DateTime.parse(json['created_at'] as String),
  lastActionDate: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  language: json['language'] as String? ?? 'English',
  role: json['role'] as String? ?? 'customer',
  isNotificationsEnabled: json['is_notifications_enabled'] as bool? ?? true,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'profileImage': instance.profileImage,
  'status': instance.status,
  'addresses': instance.addresses,
  'paymentMethods': instance.paymentMethods,
  'favoriteProviders': instance.favoriteProviders,
  'totalSpent': instance.totalSpent,
  'totalBookings': instance.totalBookings,
  'rating': instance.rating,
  'created_at': instance.joinDate.toIso8601String(),
  'updated_at': instance.lastActionDate?.toIso8601String(),
  'language': instance.language,
  'role': instance.role,
  'is_notifications_enabled': instance.isNotificationsEnabled,
};
