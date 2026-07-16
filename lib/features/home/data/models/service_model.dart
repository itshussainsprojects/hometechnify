import 'package:json_annotation/json_annotation.dart';

part 'service_model.g.dart';

@JsonSerializable()
class ServiceModel {
  final String id;
  final String name;
  final String? iconUrl; // From Backend
  final String? iconName; // Legacy/Local mapping
  final int colorValue;
  final bool isActive;
  final int bookingsCount;

  ServiceModel({
    required this.id,
    required this.name,
    this.iconUrl,
    this.iconName,
    this.colorValue = 0xFF2196F3, // Default Blue
    this.isActive = true,
    this.bookingsCount = 0,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) => _$ServiceModelFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceModelToJson(this);
}
