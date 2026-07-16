class JobPostModel {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final double? budget;
  final String location;
  final String status;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final String? customerName;
  final String? customerProfileImage;
  final String? customerAddress;
  final String? category;

  JobPostModel({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerProfileImage,
    this.customerAddress,
    required this.title,
    required this.description,
    this.budget,
    this.category,
    required this.location,
    required this.status,
    required this.mediaUrls,
    required this.createdAt,
  });

  factory JobPostModel.fromJson(Map<String, dynamic> json) {
    String? address;
    if (json['customer'] != null && json['customer']['addresses'] != null) {
       final addresses = json['customer']['addresses'];
       if (addresses is List && addresses.isNotEmpty) {
          final first = addresses.first;
          if (first is String) {
             address = first;
          } else if (first is Map) {
             address = first['address']?.toString();
          }
       }
    }

    return JobPostModel(
      id: json['id'],
      customerId: json['customer_id'],
      customerName: json['customer']?['name'],
      customerProfileImage: json['customer']?['profileImage'],
      customerAddress: address,
      title: json['title'],
      description: json['description'],
      budget: json['budget'] != null ? (json['budget'] as num).toDouble() : null,
      location: json['location'],
      status: json['status'],
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      category: json['category'],
    );
  }
}
