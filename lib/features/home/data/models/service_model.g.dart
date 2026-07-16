// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceModel _$ServiceModelFromJson(Map<String, dynamic> json) => ServiceModel(
  id: json['id'] as String,
  name: json['name'] as String,
  iconUrl: json['iconUrl'] as String?,
  iconName: json['iconName'] as String?,
  colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF2196F3,
  isActive: json['isActive'] as bool? ?? true,
  bookingsCount: (json['bookingsCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ServiceModelToJson(ServiceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'iconUrl': instance.iconUrl,
      'iconName': instance.iconName,
      'colorValue': instance.colorValue,
      'isActive': instance.isActive,
      'bookingsCount': instance.bookingsCount,
    };
