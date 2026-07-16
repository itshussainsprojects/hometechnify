

class BookingModel {
  final String id;
  final String customerId; // Fix: Declare customerId
  // final String userId; // Removed: Redundant
  // final String userName; // Removed: Redundant
  final String providerId;
  final String providerName;
  final String serviceName;
  final String serviceId;
  final String status;
  final String address;
  final double price;
  final double commissionDeducted;
  final DateTime bookingDate;
  final DateTime? providerArrivalTime;
  final DateTime? serviceStartTime;
  final DateTime? completionTime;
  final double lat;
  final double lng;
  final String paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastOfferBy;

  // Pending reschedule proposal (must be accepted by the other side)
  final DateTime? rescheduleProposedAt;
  final String? rescheduleBy; // 'CUSTOMER' or 'PROVIDER'

  /// When the reschedule was ASKED FOR (not the proposed new time). The backend
  /// auto-declines an unanswered proposal after a fixed window measured from
  /// here, so the app can tell the user how long they have left.
  final DateTime? rescheduleRequestedAt;

  final String? jobPostId; // Add this
  final Map<String, dynamic>? providerProfile; // Add this for Lat/Lng

  // The original job post this booking came from (title / description /
  // attachments), so the customer can see what they asked for.
  final String? jobTitle;
  final String? jobDescription;
  final List<String> jobMediaUrls;

  // Two-OTP work lock (OTPs are null for the provider — customer only)
  final String? startOtp;
  final String? completionOtp;
  final String? beforePhoto;
  final String? afterPhoto;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  BookingModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.serviceName,
    required this.providerName,
    required this.status,
    required this.price,
    required this.bookingDate,
    required this.address,
    required this.lat,
    required this.lng,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lastOfferBy,
    this.rescheduleProposedAt,
    this.rescheduleBy,
    this.rescheduleRequestedAt,
    this.commissionDeducted = 0,
    this.providerArrivalTime,
    this.serviceStartTime,
    this.completionTime,
    String? customerName,
    this.jobPostId,
    this.providerProfile,
    this.jobTitle,
    this.jobDescription,
    this.jobMediaUrls = const [],
    this.startOtp,
    this.completionOtp,
    this.beforePhoto,
    this.afterPhoto,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
  }) : _customerName = customerName;

  // Computed getter for total amount (price + commission, or just price if no commission)
  double get totalAmount => price + commissionDeducted;

  // Alias for bookingDate for provider screens compatibility
  DateTime get scheduledAt => bookingDate;

  // Alias for userName for provider screens compatibility  
  String get customerName => _customerName ?? customerId; 
  final String? _customerName; 

  // Helper to get Provider Location
  double get providerLat {
     if (providerProfile != null && providerProfile!['current_lat'] != null) {
       return (providerProfile!['current_lat'] as num).toDouble();
     }
     return 0.0;
  }

  double get providerLng {
     if (providerProfile != null && providerProfile!['current_lng'] != null) {
       return (providerProfile!['current_lng'] as num).toDouble();
     }
     return 0.0;
  }


  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      providerId: json['provider_id'] ?? '',
      serviceId: json['service_id'] ?? '',
      serviceName: json['service'] != null ? json['service']['name'] ?? 'Service' : 'Service',
      providerName: json['provider'] != null ? json['provider']['name'] ?? 'Provider' : 'Provider',
      status: json['status'] ?? 'pending',
      price: (json['total_amount'] ?? 0).toDouble(),
      bookingDate: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at']) : DateTime.now(),
      address: json['address'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? 'PENDING',
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      lastOfferBy: json['last_offer_by'],
      rescheduleProposedAt: json['reschedule_proposed_at'] != null
          ? DateTime.tryParse(json['reschedule_proposed_at'])
          : null,
      rescheduleBy: json['reschedule_by'],
      rescheduleRequestedAt: json['reschedule_requested_at'] != null
          ? DateTime.tryParse(json['reschedule_requested_at'])
          : null,
      commissionDeducted: (json['commission_deducted'] ?? 0).toDouble(),
      providerArrivalTime: json['provider_arrival_time'] != null ? DateTime.parse(json['provider_arrival_time']) : null,
      serviceStartTime: json['service_start_time'] != null ? DateTime.parse(json['service_start_time']) : null,
      completionTime: json['completion_time'] != null ? DateTime.parse(json['completion_time']) : null,
      customerName: json['customer'] != null ? json['customer']['name'] : null, 
      jobPostId: json['job_post_id'],
      providerProfile: json['provider'] != null ? json['provider']['provider_profile'] : null,
      jobTitle: json['job_post']?['title'],
      jobDescription: json['job_post']?['description'],
      jobMediaUrls: json['job_post']?['mediaUrls'] != null
          ? List<String>.from(json['job_post']['mediaUrls'])
          : const [],
      startOtp: json['start_otp'],
      completionOtp: json['completion_otp'],
      beforePhoto: json['before_photo'],
      afterPhoto: json['after_photo'],
      arrivedAt: json['arrived_at'] != null ? DateTime.tryParse(json['arrived_at']) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'provider_id': providerId,
    'service_id': serviceId,
    'total_amount': price,
    'status': status,
    'scheduled_at': bookingDate.toIso8601String(),
    'address': address,
    'lat': lat,
    'lng': lng,
    'notes': notes,
    'paymentStatus': paymentStatus,
    'job_post_id': (jobPostId != null && jobPostId!.isNotEmpty) ? jobPostId : null,
    // Add other fields if needed for creation
  };
}
