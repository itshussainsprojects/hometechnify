class AddressModel {
  final String id;
  final String userId;
  final String label;
  final String address;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      userId: json['user_id'],
      label: json['label'] ?? 'Home',
      address: json['address'],
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
