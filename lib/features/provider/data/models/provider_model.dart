class ProviderModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? profileImage;
  final String? bio;
  final double hourlyRate;
  final int experience;
  final double rating;
  final int reviewCount;
  final String category;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> services;

  // Bank Details
  final String? bankName;
  final String? accountTitle;
  final String? accountNumber;

  final double walletBalance;
  final bool isVerified;
  final bool isAvailable; // provider's availability toggle (is_online)
  final double? distanceKm; // distance from the customer (when a location was sent)

  ProviderModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profileImage,
    this.bio,
    this.hourlyRate = 0.0,
    this.experience = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.services = const [],
    this.bankName,
    this.accountTitle,
    this.accountNumber,
    this.walletBalance = 0.0,
    this.isVerified = false,
    this.isAvailable = false,
    this.distanceKm,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    // The base JSON is the User object
    // It contains 'provider_profile' which has details
    
    final profile = json['provider_profile'] ?? {};
    final categoryObj = profile['category'] ?? {};
    
    // Parse services: Handle if it's a List of Strings or List of Objects
    var servicesList = <String>[];
    if (profile['services'] != null) {
      if (profile['services'] is List) {
        servicesList = (profile['services'] as List).map((s) {
          if (s is String) return s;
          if (s is Map) return s['name']?.toString() ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList();
      }
    }

    return ProviderModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Provider',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profileImage']?.toString(),
      bio: profile['bio']?.toString(),
      hourlyRate: double.tryParse(profile['hourly_rate']?.toString() ?? '0') ?? 0.0,
      experience: int.tryParse(profile['experience']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(profile['rating']?.toString() ?? '0') ?? 0.0,
      reviewCount: int.tryParse(profile['review_count']?.toString() ?? '0') ?? 0,
      category: categoryObj['name']?.toString() ?? 'General',
      address: json['address']?.toString(), 
      latitude: double.tryParse(profile['current_lat']?.toString() ?? json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(profile['current_lng']?.toString() ?? json['longitude']?.toString() ?? ''),
      services: servicesList,
      bankName: profile['bank_name']?.toString(),
      accountTitle: profile['account_title']?.toString(),
      accountNumber: profile['account_number']?.toString(),
      walletBalance: double.tryParse(json['walletBalance']?.toString() ?? '0') ?? 0.0,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      isAvailable: profile['is_online'] == true || profile['is_online'] == 1,
      distanceKm: json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null,
    );
  }
}
