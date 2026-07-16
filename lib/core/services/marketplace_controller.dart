// MarketplaceController - Centralized data management for Admin Panel
// Manages Users, Providers, Bookings, Services, and Finance in real-time

import 'package:flutter/foundation.dart';
import 'api_service.dart';

// ============== RESULT MODELS ==============

/// Result of a job acceptance attempt
class JobAcceptanceResult {
  final bool success;
  final String message;
  final double? requiredAmount;
  final double? shortfall;
  final double? commission;

  JobAcceptanceResult({
    required this.success,
    required this.message,
    this.requiredAmount,
    this.shortfall,
    this.commission,
  });

  factory JobAcceptanceResult.successful(double commission) {
    return JobAcceptanceResult(
      success: true,
      message: 'Job accepted successfully! Commission of Rs. ${commission.toStringAsFixed(0)} deducted.',
      commission: commission,
    );
  }

  factory JobAcceptanceResult.insufficientFunds({
    required double currentBalance,
    required double commission,
  }) {
    final shortfall = commission - currentBalance;
    return JobAcceptanceResult(
      success: false,
      message: 'Your balance is too low. Please add at least Rs. ${shortfall.toStringAsFixed(0)} to your wallet to accept this job.',
      requiredAmount: commission,
      shortfall: shortfall,
      commission: commission,
    );
  }
}

// ============== DATA MODELS ==============

/// User Model
class UserModel {
  final String id;
  String name;
  String email;
  String phone;
  String? profileImage;
  String status; // 'active', 'blocked', 'deleted'
  List<String> addresses;
  List<String> paymentMethods;
  List<String> favoriteProviders;
  double totalSpent;
  int totalBookings;
  double rating;
  DateTime joinDate;
  DateTime? lastActionDate;
  String language;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    this.status = 'active',
    List<String>? addresses,
    List<String>? paymentMethods,
    List<String>? favoriteProviders,
    this.totalSpent = 0,
    this.totalBookings = 0,
    this.rating = 0,
    DateTime? joinDate,
    this.lastActionDate,
    this.language = 'English',
  })  : addresses = addresses ?? [],
        paymentMethods = paymentMethods ?? [],
        favoriteProviders = favoriteProviders ?? [],
        joinDate = joinDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'phone': phone,
    'profileImage': profileImage, 'status': status, 'addresses': addresses,
    'paymentMethods': paymentMethods, 'favoriteProviders': favoriteProviders,
    'totalSpent': totalSpent, 'totalBookings': totalBookings, 'rating': rating,
    'joinDate': joinDate.toIso8601String(), 'language': language,
    'lastActionDate': lastActionDate?.toIso8601String(),
  };
}

/// Provider Model
class ProviderModel {
  final String id;
  String name;
  String email;
  String phone;
  String? profileImage;
  String status; // 'unverified', 'verified', 'blocked', 'deleted'
  String? cnicFront;
  String? cnicBack;
  String? cnicSelfie;
  double rating;
  int totalReviews;
  List<String> services;
  List<String> workers;
  double walletBalance;
  double pendingCommission;
  double totalEarnings;
  int totalBookings;
  String? paymentMethod; // 'EasyPaisa' or 'JazzCash'
  String? accountNumber;
  DateTime joinDate;
  DateTime? lastActionDate;
  bool? isCnicVerified;
  bool notificationsEnabled;

  ProviderModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    this.status = 'unverified',
    this.cnicFront,
    this.cnicBack,
    this.cnicSelfie,
    this.rating = 0,
    this.totalReviews = 0,
    List<String>? services,
    List<String>? workers,
    this.walletBalance = 0,
    this.pendingCommission = 0,
    this.totalEarnings = 0,
    this.totalBookings = 0,
    this.paymentMethod = 'EasyPaisa',
    this.accountNumber = '',
    DateTime? joinDate,
    this.lastActionDate,
    this.isCnicVerified = false,
    this.notificationsEnabled = true,
  })  : services = services ?? [],
        workers = workers ?? [],
        joinDate = joinDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'phone': phone,
    'profileImage': profileImage, 'status': status, 'cnicFront': cnicFront,
    'cnicBack': cnicBack, 'cnicSelfie': cnicSelfie, 'rating': rating, 'totalReviews': totalReviews,
    'services': services, 'workers': workers, 'walletBalance': walletBalance,
    'pendingCommission': pendingCommission, 'totalEarnings': totalEarnings,
    'totalBookings': totalBookings, 'paymentMethod': paymentMethod, 'accountNumber': accountNumber,
    'joinDate': joinDate.toIso8601String(), 'notificationsEnabled': notificationsEnabled,
    'lastActionDate': lastActionDate?.toIso8601String(),
    'isCnicVerified': isCnicVerified ?? false,
  };
}

/// Booking Model
class BookingModel {
  final String id;
  String userId;
  String userName;
  String providerId;
  String providerName;
  String serviceName;
  String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  String address;
  double price;
  double commissionDeducted;
  DateTime bookingDate;
  DateTime? providerArrivalTime;
  DateTime? serviceStartTime;
  DateTime? completionTime;
  double? ratingGiven;
  String? review;

  BookingModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
    required this.address,
    required this.price,
    this.status = 'pending',
    this.commissionDeducted = 0,
    DateTime? bookingDate,
    this.providerArrivalTime,
    this.serviceStartTime,
    this.completionTime,
    this.ratingGiven,
    this.review,
  }) : bookingDate = bookingDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'userId': userId, 'userName': userName, 'providerId': providerId,
    'providerName': providerName, 'serviceName': serviceName, 'status': status,
    'address': address, 'price': price, 'commissionDeducted': commissionDeducted,
    'bookingDate': bookingDate.toIso8601String(),
    'providerArrivalTime': providerArrivalTime?.toIso8601String(),
    'serviceStartTime': serviceStartTime?.toIso8601String(),
    'completionTime': completionTime?.toIso8601String(),
    'ratingGiven': ratingGiven, 'review': review,
  };
}

/// Service Category Model
class ServiceCategoryModel {
  final String id;
  String name;
  String iconName;
  int colorValue;
  bool isActive;
  int bookingsCount;

  ServiceCategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    this.isActive = true,
    this.bookingsCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'iconName': iconName,
    'colorValue': colorValue, 'isActive': isActive, 'bookingsCount': bookingsCount,
  };
}

/// Promo Banner Model
class PromoBannerModel {
  final String id;
  String title;
  String subtitle;
  int discountPercent;
  String? imagePath;
  int colorValue;
  bool isActive;
  String? linkAction;
  DateTime createdAt;

  PromoBannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.discountPercent = 0,
    this.imagePath,
    required this.colorValue,
    this.isActive = true,
    this.linkAction,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'subtitle': subtitle,
    'discountPercent': discountPercent, 'imagePath': imagePath,
    'colorValue': colorValue, 'isActive': isActive, 'linkAction': linkAction,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Transaction Model (for wallet)
class TransactionModel {
  final String id;
  String providerId;
  String type; // 'topup', 'commission', 'withdrawal', 'earning'
  double amount;
  String description;
  String status; // 'pending', 'completed', 'rejected'
  DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.providerId,
    required this.type,
    required this.amount,
    required this.description,
    this.status = 'completed',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isCredit => type == 'topup' || type == 'earning';
  bool get isDebit => type == 'commission' || type == 'withdrawal';

  Map<String, dynamic> toMap() => {
    'id': id, 'providerId': providerId, 'type': type,
    'amount': amount, 'description': description, 'status': status,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Withdrawal Request Model
class WithdrawalRequestModel {
  final String id;
  String providerId;
  String providerName;
  double amount;
  String? paymentMethod; // 'EasyPaisa' or 'JazzCash'
  String? accountNumber;
  String status; // 'pending', 'approved', 'rejected'
  DateTime requestDate;
  DateTime? processedDate;

  WithdrawalRequestModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.amount,
    this.paymentMethod = 'EasyPaisa',
    this.accountNumber = '',
    this.status = 'pending',
    DateTime? requestDate,
    this.processedDate,
  }) : requestDate = requestDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'providerId': providerId, 'providerName': providerName,
    'amount': amount, 'paymentMethod': paymentMethod, 'accountNumber': accountNumber,
    'status': status, 'requestDate': requestDate.toIso8601String(),
    'processedDate': processedDate?.toIso8601String(),
  };
}

/// Chat Message Model
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isProvider;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isProvider,
  });
}

/// Chat Session Model
class ChatSession {
  final String id;
  final String userId;
  final String providerId;
  final String userName;
  final String providerName;
  final List<ChatMessage> messages;
  final DateTime lastActivity;

  ChatSession({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.userName,
    required this.providerName,
    required this.messages,
    required this.lastActivity,
  });
}

/// Notification Model
class NotificationModel {
  final String id;
  final String targetId; // UserId or ProviderId
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final bool isProvider;

  NotificationModel({
    required this.id,
    required this.targetId,
    required this.title,
    required this.message,
    required this.isProvider,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============== MARKETPLACE CONTROLLER ==============

class MarketplaceController extends ChangeNotifier {
  // Commission rate (editable by admin)
  double _commissionRate = 0.10; // 10%
  double get commissionRate => _commissionRate;

  // Data stores
  final List<UserModel> _users = [];
  final List<ProviderModel> _providers = [];
  final List<BookingModel> _bookings = [];
  final List<ServiceCategoryModel> _services = [];
  final List<PromoBannerModel> _promos = [];
  final List<TransactionModel> _transactions = [];
  final List<WithdrawalRequestModel> _withdrawals = [];
  final List<ChatSession> _chats = [];
  final List<NotificationModel> _notifications = [];

  // Active Session tracking
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  void setCurrentUser(String userId) {
    _currentUser = getUserById(userId);
    notifyListeners();
  }

  void adminLogout() {
    _currentUser = null;
    // We intentionally DO NOT clear _users, _providers, etc. to maintain persistence during the session
    notifyListeners();
  }

  // Getters
  List<UserModel> get users => List.unmodifiable(_users);
  List<ProviderModel> get providers => List.unmodifiable(_providers);
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  List<ServiceCategoryModel> get services => List.unmodifiable(_services);
  List<PromoBannerModel> get promos => List.unmodifiable(_promos);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<WithdrawalRequestModel> get withdrawals => List.unmodifiable(_withdrawals);
  List<ChatSession> get chats => List.unmodifiable(_chats);

  // ===== STATS =====
  int get totalUsers => _users.where((u) => u.status != 'deleted').length;
  int get totalProviders => _providers.where((p) => p.status != 'deleted').length;
  int get verifiedProviders => _providers.where((p) => p.status == 'verified').length;
  int get pendingProviders => _providers.where((p) => p.status == 'pending').length;
  int get blockedProviders => _providers.where((p) => p.status == 'blocked').length;
  int get activeBookings => _bookings.where((b) => b.status == 'in_progress').length;
  int get completedBookings => _bookings.where((b) => b.status == 'completed').length;
  
  double get totalRevenue => _bookings
      .where((b) => b.status != 'cancelled')
      .fold(0.0, (sum, b) => sum + b.price);
  
  double get totalCommissionEarned => _bookings
      .where((b) => b.status != 'cancelled')
      .fold(0.0, (sum, b) => sum + b.commissionDeducted);

  double get pendingWithdrawalsAmount => _withdrawals
      .where((w) => w.status == 'pending')
      .fold(0, (sum, w) => sum + w.amount);

  // --- ANALYTICS DATA ---
  
  List<double> get weeklyRevenue => [4500, 3800, 5200, 4100, 6300, 4800, totalRevenue];
  
  List<int> get weeklyBookings => [10, 8, 12, 11, 15, 12, _bookings.length];
  
  List<Map<String, dynamic>> get commissionPerformance => [
    {'name': 'Mon', 'value': 450},
    {'name': 'Tue', 'value': 380},
    {'name': 'Wed', 'value': 520},
    {'name': 'Thu', 'value': 410},
    {'name': 'Fri', 'value': 630},
    {'name': 'Sat', 'value': 480},
    {'name': 'Sun', 'value': totalCommissionEarned},
  ];

  // --- USER METHODS ---
  void addUser(UserModel user) {
    _users.add(user);
    notifyListeners();
  }

  void updateUser(String id, Map<String, dynamic> updates) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      final user = _users[index];
      if (updates.containsKey('name')) user.name = updates['name'];
      if (updates.containsKey('email')) user.email = updates['email'];
      if (updates.containsKey('phone')) user.phone = updates['phone'];
      if (updates.containsKey('profileImage')) user.profileImage = updates['profileImage'];
      if (updates.containsKey('status')) {
        user.status = updates['status'];
        if (user.status == 'blocked' || user.status == 'deleted') {
          user.lastActionDate = DateTime.now();
        }
      }
      if (updates.containsKey('addresses')) user.addresses = List<String>.from(updates['addresses']);
      notifyListeners();
    }
  }

  void blockUser(String id) => updateUser(id, {'status': 'blocked'});
  void unblockUser(String id) => updateUser(id, {'status': 'active'});
  void deleteUser(String id) => updateUser(id, {'status': 'deleted'});
  
  void restoreUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].status = 'active';
      notifyListeners();
    }
  }

  void updateUserRating(String id, double rating) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].rating = rating;
      notifyListeners();
    }
  }

  void updateUserStats(String id, {double? spent, int? bookings}) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      if (spent != null) _users[index].totalSpent = spent;
      if (bookings != null) _users[index].totalBookings = bookings;
      notifyListeners();
    }
  }

  UserModel? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  List<UserModel> get activeUsers => _users.where((u) => u.status == 'active').toList();
  List<UserModel> get blockedUsers => _users.where((u) => u.status == 'blocked').toList();
  List<UserModel> get deletedUsers => _users.where((u) => u.status == 'deleted').toList();

  // ===== PROVIDER MANAGEMENT =====
  void addProvider(ProviderModel provider) {
    _providers.add(provider);
    notifyListeners();
  }

  void updateProvider(String id, Map<String, dynamic> updates) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      final provider = _providers[index];
      if (updates.containsKey('name')) provider.name = updates['name'];
      if (updates.containsKey('email')) provider.email = updates['email'];
      if (updates.containsKey('phone')) provider.phone = updates['phone'];
      if (updates.containsKey('profileImage')) provider.profileImage = updates['profileImage'];
      if (updates.containsKey('status')) {
        provider.status = updates['status'];
        if (provider.status == 'blocked' || provider.status == 'deleted') {
          provider.lastActionDate = DateTime.now();
        }
      }
      if (updates.containsKey('walletBalance')) provider.walletBalance = updates['walletBalance'];
      if (updates.containsKey('services')) provider.services = List<String>.from(updates['services']);
      if (updates.containsKey('paymentMethod')) provider.paymentMethod = updates['paymentMethod'];
      if (updates.containsKey('accountNumber')) provider.accountNumber = updates['accountNumber'];
      notifyListeners();
    }
  }

  void verifyProvider(String id) => updateProvider(id, {'status': 'verified'});
  void unverifyProvider(String id) => updateProvider(id, {'status': 'unverified'});
  void rejectProvider(String id) => updateProvider(id, {'status': 'unverified'});
  void blockProvider(String id) => updateProvider(id, {'status': 'blocked'});
  void unblockProvider(String id) => updateProvider(id, {'status': 'verified'});
  void deleteProvider(String id) => updateProvider(id, {'status': 'deleted'});
  
  void toggleProviderVerification(String id) {
    final provider = getProviderById(id);
    if (provider != null) {
      if (provider.status == 'verified') {
        unverifyProvider(id);
      } else {
        verifyProvider(id);
      }
    }
  }

  void approveCnic(String id) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _providers[index].isCnicVerified = true;
      notifyListeners();
    }
  }

  void rejectCnic(String id) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _providers[index].isCnicVerified = false;
      notifyListeners();
    }
  }

  void toggleCnicVerification(String id) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _providers[index].isCnicVerified = !(_providers[index].isCnicVerified ?? false);
      notifyListeners();
    }
  }
  
  void restoreProvider(String id) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _providers[index].status = 'verified';
      _providers[index].lastActionDate = null;
      notifyListeners();
    }
  }

  List<ProviderModel> get deletedProviders => _providers.where((p) => p.status == 'deleted').toList();

  void updateProviderRating(String id, double rating) {
    final index = _providers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _providers[index].rating = rating;
      notifyListeners();
    }
  }

  ProviderModel? getProviderById(String id) {
    try {
      return _providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ProviderModel> get unverifiedProviders => _providers.where((p) => p.status == 'unverified').toList();
  List<ProviderModel> get verifiedProvidersList => _providers.where((p) => p.status == 'verified').toList();
  
  int get pendingProvidersCount => unverifiedProviders.length;

  // ===== BOOKING MANAGEMENT =====
  void addBooking(BookingModel booking) {
    // Automatically calculate commission for the new booking
    booking.commissionDeducted = booking.price * _commissionRate;
    _bookings.add(booking);
    
    // Update user stats
    final userIndex = _users.indexWhere((u) => u.id == booking.userId);
    if (userIndex != -1) {
      _users[userIndex].totalBookings++;
      _users[userIndex].totalSpent += booking.price;
    }
    
    // Update provider stats
    final providerIndex = _providers.indexWhere((p) => p.id == booking.providerId);
    if (providerIndex != -1) {
      _providers[providerIndex].totalBookings++;
    }
    
    notifyListeners();
  }

  void updateBookingStatus(String id, String status, {DateTime? timestamp}) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index != -1) {
      final booking = _bookings[index];
      booking.status = status;
      if (status == 'in_progress' && timestamp != null) {
        booking.providerArrivalTime = timestamp;
      }
      if (status == 'completed') {
        booking.completionTime = timestamp ?? DateTime.now();
        booking.commissionDeducted = booking.price * _commissionRate;
      }
      notifyListeners();
    }
  }

  void submitReview(String bookingId, double rating, String review) {
    final bookingIndex = _bookings.indexWhere((b) => b.id == bookingId);
    if (bookingIndex != -1) {
      final booking = _bookings[bookingIndex];
      booking.ratingGiven = rating;
      booking.review = review;
      booking.status = 'completed';
      booking.commissionDeducted = booking.price * _commissionRate;
      booking.completionTime ??= DateTime.now();

      // Update provider's overall rating
      final providerIndex = _providers.indexWhere((p) => p.id == booking.providerId);
      if (providerIndex != -1) {
        final provider = _providers[providerIndex];
        
        // Calculate new average
        double totalRating = 0;
        int ratingCount = 0;
        
        // Find all rated bookings for this provider
        for (var b in _bookings.where((b) => b.providerId == provider.id && b.ratingGiven != null)) {
          totalRating += b.ratingGiven!;
          ratingCount++;
        }
        
        provider.rating = ratingCount > 0 ? totalRating / ratingCount : rating;
        provider.totalReviews = ratingCount;
      }
      
      notifyListeners();
    }
  }

  BookingModel? getBookingById(String id) {
    try {
      return _bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BookingModel> getBookingsByUser(String userId) => 
      _bookings.where((b) => b.userId == userId).toList();

  List<BookingModel> getBookingsByProvider(String providerId) => 
      _bookings.where((b) => b.providerId == providerId).toList();

  // ===== SERVICE CATEGORY MANAGEMENT =====
  void addService(ServiceCategoryModel service) {
    _services.add(service);
    notifyListeners();
  }

  void updateService(String id, Map<String, dynamic> updates) {
    final index = _services.indexWhere((s) => s.id == id);
    if (index != -1) {
      final service = _services[index];
      if (updates.containsKey('name')) service.name = updates['name'];
      if (updates.containsKey('iconName')) service.iconName = updates['iconName'];
      if (updates.containsKey('colorValue')) service.colorValue = updates['colorValue'];
      if (updates.containsKey('isActive')) service.isActive = updates['isActive'];
      notifyListeners();
    }
  }

  void toggleService(String id) {
    final index = _services.indexWhere((s) => s.id == id);
    if (index != -1) {
      _services[index].isActive = !_services[index].isActive;
      notifyListeners();
    }
  }

  void deleteService(String id) {
    _services.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  List<ServiceCategoryModel> get activeServices => _services.where((s) => s.isActive).toList();

  int getServiceBookingCount(String serviceName) {
    return _bookings.where((b) => b.serviceName == serviceName).length;
  }

  // ===== PROMO BANNER MANAGEMENT =====
  void addPromo(PromoBannerModel promo) {
    _promos.add(promo);
    notifyListeners();
  }

  void updatePromo(String id, Map<String, dynamic> updates) {
    final index = _promos.indexWhere((p) => p.id == id);
    if (index != -1) {
      final promo = _promos[index];
      if (updates.containsKey('title')) promo.title = updates['title'];
      if (updates.containsKey('subtitle')) promo.subtitle = updates['subtitle'];
      if (updates.containsKey('discountPercent')) promo.discountPercent = updates['discountPercent'];
      if (updates.containsKey('isActive')) promo.isActive = updates['isActive'];
      notifyListeners();
    }
  }

  void togglePromo(String id) {
    final index = _promos.indexWhere((p) => p.id == id);
    if (index != -1) {
      _promos[index].isActive = !_promos[index].isActive;
      notifyListeners();
    }
  }

  void deletePromo(String id) {
    _promos.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  List<PromoBannerModel> get activePromos => _promos.where((p) => p.isActive).toList();

  // ===== FINANCE MANAGEMENT =====
  void setCommissionRate(double rate) {
    _commissionRate = rate;
    
    // Recalculate commissions for all relevant bookings to match the new rate
    for (var booking in _bookings) {
      if (booking.status != 'cancelled') {
        booking.commissionDeducted = booking.price * _commissionRate;
      }
    }
    
    notifyListeners();
  }

  void addTransaction(TransactionModel transaction) {
    _transactions.add(transaction);
    notifyListeners();
  }

  void requestWithdrawal(WithdrawalRequestModel request) {
    _withdrawals.add(request);
    notifyListeners();
  }

  void approveWithdrawal(String id) {
    final index = _withdrawals.indexWhere((w) => w.id == id);
    if (index != -1) {
      final withdrawal = _withdrawals[index];
      withdrawal.status = 'approved';
      withdrawal.processedDate = DateTime.now();
      
      // Deduct from provider wallet
      final providerIndex = _providers.indexWhere((p) => p.id == withdrawal.providerId);
      if (providerIndex != -1) {
        _providers[providerIndex].walletBalance -= withdrawal.amount;
        
        // SEND NOTIFICATION TO PROVIDER
        sendNotification(
          targetId: withdrawal.providerId,
          title: 'Payout Approved',
          message: '1 hours main ap ka pasa ap ka account main again ga.',
          isProvider: true,
        );
      }
      
      notifyListeners();
    }
  }

  void undoWithdrawalApproval(String id) {
    final index = _withdrawals.indexWhere((w) => w.id == id);
    if (index != -1) {
      final withdrawal = _withdrawals[index];
      if (withdrawal.status == 'approved') {
        // Revert wallet deduction
        final providerIndex = _providers.indexWhere((p) => p.id == withdrawal.providerId);
        if (providerIndex != -1) {
          _providers[providerIndex].walletBalance += withdrawal.amount;
        }
        
        withdrawal.status = 'pending';
        withdrawal.processedDate = null;
        notifyListeners();
      }
    }
  }

  void restoreWithdrawal(String id) {
    final index = _withdrawals.indexWhere((w) => w.id == id);
    if (index != -1) {
      _withdrawals[index].status = 'pending';
      _withdrawals[index].processedDate = null;
      notifyListeners();
    }
  }

  void deleteWithdrawal(String id) {
    _withdrawals.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  void rejectWithdrawal(String id) {
    final index = _withdrawals.indexWhere((w) => w.id == id);
    if (index != -1) {
      _withdrawals[index].status = 'rejected';
      _withdrawals[index].processedDate = DateTime.now();
      notifyListeners();
    }
  }

  List<WithdrawalRequestModel> get pendingWithdrawals => 
      _withdrawals.where((w) => w.status == 'pending').toList();

  List<WithdrawalRequestModel> get approvedWithdrawals => 
      _withdrawals.where((w) => w.status == 'approved').toList();

  List<WithdrawalRequestModel> get rejectedWithdrawals => 
      _withdrawals.where((w) => w.status == 'rejected').toList();

  List<TransactionModel> getTransactionsByProvider(String providerId) =>
      _transactions.where((t) => t.providerId == providerId).toList();

  List<ChatSession> getChatsByUser(String userId) =>
      _chats.where((c) => c.userId == userId).toList();

  // ===== NOTIFICATION MANAGEMENT =====
  // UPDATED: Now calls Backend API for Real Push Notifications
  void sendNotification({
    required String targetId,
    required String title,
    required String message,
    required bool isProvider,
  }) async {
    // Optimistic Update (Local List)
    _notifications.add(NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetId: targetId,
      title: title,
      message: message,
      isProvider: isProvider,
    ));
    notifyListeners();

    // SERVER CALL
    try {
       final api = ApiService();
       await api.dio.post('/notifications/send-custom', data: {
         'targetId': targetId,
         'title': title,
         'message': message
       });
       if (kDebugMode) debugPrint("Admin Push Sent to $targetId");
    } catch (e) {
       if (kDebugMode) debugPrint("Failed to send Admin Push: $e");
    }
  }

  List<NotificationModel> getNotifications(String targetId) =>
      _notifications.where((n) => n.targetId == targetId).toList();

  void sendBroadcastNotification({
    required String title,
    required String message,
    required bool isProvider,
  }) async {
    // Optimistic Update
    if (isProvider) {
      for (var provider in _providers) {
        // Just adding to local list history
        _notifications.add(NotificationModel(
             id: DateTime.now().microsecondsSinceEpoch.toString(),
             targetId: provider.id, title: title, message: message, isProvider: true
        ));
      }
    } else {
      for (var user in _users) {
        _notifications.add(NotificationModel(
             id: DateTime.now().microsecondsSinceEpoch.toString(),
             targetId: user.id, title: title, message: message, isProvider: false
        ));
      }
    }
    notifyListeners();

    // SERVER CALL
    try {
       final api = ApiService();
       await api.dio.post('/notifications/send-broadcast', data: {
         'title': title,
         'message': message,
         'isProvider': isProvider
       });
       if (kDebugMode) debugPrint("Admin Broadcast Sent (Provider: $isProvider)");
    } catch (e) {
       if (kDebugMode) debugPrint("Failed to send Broadcast: $e");
    }
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  // ===== WALLET SERVICE (for provider app) =====
  double calculateCommission(double jobPrice) => jobPrice * _commissionRate;

  bool canAcceptJob(String providerId, double jobPrice) {
    final provider = getProviderById(providerId);
    if (provider == null) return false;
    return provider.walletBalance >= calculateCommission(jobPrice);
  }

  double getShortfall(String providerId, double jobPrice) {
    final provider = getProviderById(providerId);
    if (provider == null) return jobPrice;
    final commission = calculateCommission(jobPrice);
    if (provider.walletBalance >= commission) return 0;
    return commission - provider.walletBalance;
  }

  double balance(String providerId) {
    return getProviderById(providerId)?.walletBalance ?? 0;
  }

  JobAcceptanceResult acceptJob({
    required String providerId,
    required double jobPrice,
    required String jobId,
    String? serviceName,
    String? customerName,
  }) {
    final commission = calculateCommission(jobPrice);
    final providerIndex = _providers.indexWhere((p) => p.id == providerId);
    
    if (providerIndex == -1) {
      return JobAcceptanceResult(success: false, message: 'Provider not found');
    }
    
    if (_providers[providerIndex].walletBalance < commission) {
      return JobAcceptanceResult.insufficientFunds(
        currentBalance: _providers[providerIndex].walletBalance,
        commission: commission,
      );
    }

    // Deduct commission
    _providers[providerIndex].walletBalance -= commission;

    // Add transaction
    _transactions.add(TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      providerId: providerId,
      type: 'commission',
      amount: commission,
      description: 'Commission - ${serviceName ?? "Job"} (${customerName ?? "Customer"})',
    ));

    notifyListeners();
    return JobAcceptanceResult.successful(commission);
  }

  void addProviderFunds(String providerId, double amount, {String? method}) {
    final providerIndex = _providers.indexWhere((p) => p.id == providerId);
    if (providerIndex == -1 || amount <= 0) return;

    _providers[providerIndex].walletBalance += amount;
    
    _transactions.add(TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      providerId: providerId,
      type: 'topup',
      amount: amount,
      description: 'Wallet Top-up${method != null ? " via $method" : ""}',
    ));

    notifyListeners();
  }

  void addProviderEarning({
    required String providerId,
    required double amount,
    String? serviceName,
    String? customerName,
  }) {
    final providerIndex = _providers.indexWhere((p) => p.id == providerId);
    if (providerIndex == -1) return;

    _providers[providerIndex].walletBalance += amount;
    _providers[providerIndex].totalEarnings += amount;

    _transactions.add(TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      providerId: providerId,
      type: 'earning',
      amount: amount,
      description: 'Earning - ${serviceName ?? "Job"} (${customerName ?? "Customer"})',
    ));

    notifyListeners();
  }

  String getFormattedBalance(String providerId) {
    final provider = getProviderById(providerId);
    return 'Rs. ${provider?.walletBalance.toStringAsFixed(0) ?? "0"}';
  }

  bool isLowBalance(String providerId) {
    final provider = getProviderById(providerId);
    return (provider?.walletBalance ?? 0) < 500;
  }

  // ===== INITIALIZATION WITH SAMPLE DATA =====
  void initializeWithSampleData() {
    _users.clear();
    _providers.clear();
    _services.clear();
    _bookings.clear();
    _promos.clear();
    _transactions.clear();
    _withdrawals.clear();
    _chats.clear();

    // Sample Users
    _users.addAll([
      UserModel(
        id: 'u1', name: 'Fatima Khan', email: 'fatima@email.com', phone: '3001234567', 
        totalSpent: 4500, totalBookings: 3, status: 'deleted', rating: 4.8, 
        favoriteProviders: ['p1', 'p2'], 
        lastActionDate: DateTime.now().subtract(const Duration(days: 1))
      ),
      UserModel(
        id: 'u2', name: 'Hassan Ali', email: 'hassan@email.com', phone: '3009876543', 
        totalSpent: 2800, totalBookings: 2, rating: 4.5
      ),
      UserModel(
        id: 'u3', name: 'Ayesha Ahmed', email: 'ayesha@email.com', phone: '3005551234', 
        totalSpent: 1500, totalBookings: 1, status: 'blocked', rating: 3.2,
        lastActionDate: DateTime.now().subtract(const Duration(hours: 5))
      ),
    ]);

    // Sample Providers
    _providers.addAll([
      ProviderModel(id: 'p1', name: 'Ahmed Khan', email: 'ahmed@email.com', phone: '3111234567', status: 'verified', rating: 4.9, totalReviews: 156, services: ['Plumber', 'AC Repair'], walletBalance: 5000, totalEarnings: 45000, totalBookings: 67, isCnicVerified: true, paymentMethod: 'EasyPaisa', accountNumber: '03111234567'),
      ProviderModel(id: 'p2', name: 'Muhammad Hassan', email: 'mhassan@email.com', phone: '3119876543', status: 'verified', rating: 4.8, totalReviews: 89, services: ['Electrician'], walletBalance: 3200, totalEarnings: 32000, totalBookings: 45, isCnicVerified: true),
      ProviderModel(id: 'p3', name: 'Ali Raza', email: 'ali@email.com', phone: '3115551234', status: 'unverified', cnicFront: '/path/to/cnic', cnicBack: '/path/to/cnic_back', cnicSelfie: '/path/to/selfie', isCnicVerified: false),
      ProviderModel(id: 'p4', name: 'Usman Malik', email: 'usman@email.com', phone: '3117778899', status: 'blocked', rating: 2.1, totalReviews: 15, lastActionDate: DateTime.now().subtract(const Duration(hours: 3)), isCnicVerified: false),
    ]);

    // Sample Services
    _services.addAll([
      ServiceCategoryModel(id: 's1', name: 'Plumber', iconName: 'plumbing', colorValue: 0xFF1495FF, bookingsCount: 234),
      ServiceCategoryModel(id: 's2', name: 'Electrician', iconName: 'electrical', colorValue: 0xFFFFA726, bookingsCount: 187),
      ServiceCategoryModel(id: 's3', name: 'AC Repair', iconName: 'ac', colorValue: 0xFF6EC6FF, bookingsCount: 156),
      ServiceCategoryModel(id: 's4', name: 'Cleaner', iconName: 'cleaning', colorValue: 0xFF66BB6A, bookingsCount: 98),
      ServiceCategoryModel(id: 's5', name: 'Carpenter', iconName: 'carpentry', colorValue: 0xFF8D6E63, bookingsCount: 67),
      ServiceCategoryModel(id: 's6', name: 'Painter', iconName: 'painting', colorValue: 0xFFAB47BC, bookingsCount: 45),
    ]);

    // Sample Bookings
    _bookings.addAll([
      BookingModel(id: 'b1', userId: 'u1', userName: 'Fatima Khan', providerId: 'p1', providerName: 'Ahmed Khan', serviceName: 'Plumber', address: 'House 123, Johar Town', price: 1500, status: 'completed', commissionDeducted: 1500 * _commissionRate, ratingGiven: 5.0, review: 'Excellent work! Very professional and helpful.', providerArrivalTime: DateTime.now().subtract(const Duration(hours: 2)), completionTime: DateTime.now().subtract(const Duration(hours: 1))),
      BookingModel(id: 'b2', userId: 'u2', userName: 'Hassan Ali', providerId: 'p2', providerName: 'Muhammad Hassan', serviceName: 'Electrician', address: 'Flat 45, DHA', price: 800, status: 'in_progress', commissionDeducted: 800 * _commissionRate, providerArrivalTime: DateTime.now().subtract(const Duration(minutes: 30))),
      BookingModel(id: 'b3', userId: 'u1', userName: 'Fatima Khan', providerId: 'p1', providerName: 'Ahmed Khan', serviceName: 'AC Repair', address: 'House 123, Johar Town', price: 2500, status: 'completed', completionTime: DateTime.now().subtract(const Duration(days: 1)), commissionDeducted: 2500 * _commissionRate, ratingGiven: 4.0, review: 'Good service, but a bit expensive.'),
    ]);

    // Sample Promos
    _promos.addAll([
      PromoBannerModel(id: 'pr1', title: 'Flash Sale', subtitle: '50% Off on First Home Service', discountPercent: 50, colorValue: 0xFF1495FF, isActive: true),
      PromoBannerModel(id: 'pr2', title: 'Special Offer', subtitle: 'Free AC Checkup', discountPercent: 100, colorValue: 0xFF6EC6FF, isActive: true),
    ]);

    // Sample Withdrawals
    _withdrawals.addAll([
      WithdrawalRequestModel(
        id: 'w1',
        providerId: 'p1',
        providerName: 'Ahmed Khan',
        amount: 2000,
        paymentMethod: 'EasyPaisa',
        accountNumber: '03001234567',
        requestDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    // Sample Chats
    _chats.addAll([
      ChatSession(
        id: 'c1',
        userId: 'u1',
        userName: 'Fatima Khan',
        providerId: 'p1',
        providerName: 'Ahmed Khan',
        lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
        messages: [
          ChatMessage(id: 'm1', senderId: 'u1', text: 'Hi Ahmed, are you available for AC service today?', timestamp: DateTime.now().subtract(const Duration(hours: 1)), isProvider: false),
          ChatMessage(id: 'm2', senderId: 'p1', text: 'Yes Fatima! I can come around 4 PM.', timestamp: DateTime.now().subtract(const Duration(minutes: 45)), isProvider: true),
          ChatMessage(id: 'm3', senderId: 'u1', text: 'Perfect. See you then.', timestamp: DateTime.now().subtract(const Duration(minutes: 30)), isProvider: false),
        ],
      ),
      ChatSession(
        id: 'c2',
        userId: 'u2',
        userName: 'Hassan Ali',
        providerId: 'p2',
        providerName: 'Muhammad Hassan',
        lastActivity: DateTime.now().subtract(const Duration(hours: 2)),
        messages: [
          ChatMessage(id: 'm4', senderId: 'u2', text: 'How much for electrical repair?', timestamp: DateTime.now().subtract(const Duration(hours: 3)), isProvider: false),
          ChatMessage(id: 'm5', senderId: 'p2', text: 'It depends on the scope. Usually starting from Rs. 500.', timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)), isProvider: true),
        ],
      ),
    ]);

    notifyListeners();
  }
}

// Global instance
final marketplaceController = MarketplaceController();
