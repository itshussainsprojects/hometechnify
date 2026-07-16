import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String name;
  final String email;
  @JsonKey(defaultValue: '')
  final String phone;
  final String? profileImage;
  final String status;
  final List<String> addresses;
  final List<String> paymentMethods;
  final List<String> favoriteProviders;
  final double totalSpent;
  final int totalBookings;
  final double rating;
  @JsonKey(name: 'created_at')
  final DateTime joinDate;
  @JsonKey(name: 'updated_at')
  final DateTime? lastActionDate;
  final String language;
  final String role;
  @JsonKey(name: 'is_notifications_enabled')
  final bool isNotificationsEnabled;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    this.status = 'active',
    this.addresses = const [],
    this.paymentMethods = const [],
    this.favoriteProviders = const [],
    this.totalSpent = 0,
    this.totalBookings = 0,
    this.rating = 0,
    required this.joinDate,
    this.lastActionDate,
    this.language = 'English',
    this.role = 'customer',
    this.isNotificationsEnabled = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? status,
    List<String>? addresses,
    List<String>? paymentMethods,
    List<String>? favoriteProviders,
    double? totalSpent,
    int? totalBookings,
    double? rating,
    DateTime? joinDate,
    DateTime? lastActionDate,
    String? language,
    String? role,
    bool? isNotificationsEnabled,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      status: status ?? this.status,
      addresses: addresses ?? this.addresses,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      favoriteProviders: favoriteProviders ?? this.favoriteProviders,
      totalSpent: totalSpent ?? this.totalSpent,
      totalBookings: totalBookings ?? this.totalBookings,
      rating: rating ?? this.rating,
      joinDate: joinDate ?? this.joinDate,
      lastActionDate: lastActionDate ?? this.lastActionDate,
      language: language ?? this.language,
      role: role ?? this.role,
      isNotificationsEnabled: isNotificationsEnabled ?? this.isNotificationsEnabled,
    );
  }
}
